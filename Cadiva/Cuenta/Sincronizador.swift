import CadivaCore
import Foundation
import Observation
import SwiftData

/// Mantiene iguales los productos y compras del iPhone y los de la cuenta.
/// El iPhone conserva su copia para abrir al instante y funcionar sin internet.
@Observable
@MainActor
final class Sincronizador {
    enum Estado: Equatable {
        case inactivo
        case sincronizando
        case listo
        case error(String)
    }

    private(set) var estado: Estado = .inactivo
    private(set) var ultima: Date?

    /// Sincroniza y espera si ya hay una en curso, para no pisarse.
    func sincronizar(contexto: ModelContext, sesion: SesionUsuario) async {
        guard let usuario = sesion.usuario, let cliente = sesion.clienteDatos else {
            estado = .inactivo
            return
        }
        guard estado != .sincronizando else {
            pendiente = true
            return
        }
        repeat {
            pendiente = false
            estado = .sincronizando
            do {
                try await ejecutar(contexto: contexto, usuario: usuario.id, cliente: cliente, sesion: sesion)
                ultima = .now
                estado = .listo
            } catch ErrorAuth.sinConexion {
                estado = .error("Sin conexión. Se sincroniza al volver la red.")
            } catch {
                estado = .error(MensajeError.texto(error))
            }
        } while pendiente && estado == .listo
    }

    /// Hubo cambios mientras se sincronizaba; se repite al terminar.
    @ObservationIgnored private var pendiente = false

    /// Al cerrar sesión borrando los datos del iPhone, se olvida la base; si no, al volver
    /// a entrar parecería que se borró todo aquí y se borraría también en la nube.
    func olvidar(usuario: String) {
        Base.borrar(usuario: usuario)
        ultima = nil
        estado = .inactivo
    }

    // MARK: Pasos

    private func ejecutar(contexto: ModelContext, usuario: String, cliente: ClienteDatos, sesion: SesionUsuario) async throws {
        let productos = try contexto.fetch(FetchDescriptor<Producto>())
        let compras = try contexto.fetch(FetchDescriptor<Compra>())
        for producto in productos where producto.uid == nil { producto.uid = UUID() }
        for compra in compras where compra.uid == nil { compra.uid = UUID() }

        let filasProductos = productos.map(\.fila)
        let filasCompras = compras.map(\.fila)
        let fotosLocales = Dictionary(
            productos.compactMap { p in p.uid.flatMap { id in p.foto.map { (id, $0) } } },
            uniquingKeysWith: { primera, _ in primera }
        )

        let token = try await sesion.tokenVigente()
        async let remotosProductos = cliente.descargar(ProductoNube.self, token: token)
        async let remotasCompras = cliente.descargar(CompraNube.self, token: token)
        let (nubeProductos, nubeCompras) = try await (remotosProductos, remotasCompras)

        let base = Base.leer(usuario: usuario)
        let planProductos = Fusion.planear(locales: filasProductos, remotas: nubeProductos, base: base.productos)
        let planCompras = Fusion.planear(locales: filasCompras, remotas: nubeCompras, base: base.compras)

        // Primero se sube; si falla, el iPhone queda igual y se reintenta después.
        // Las fotos van antes que las filas para que otro dispositivo nunca vea una huella sin imagen.
        for fila in planProductos.subir where !fila.borrado && fila.foto != nil {
            if let datos = fotosLocales[fila.id] {
                try await cliente.subirFoto(datos, ruta: ClienteDatos.rutaFoto(usuario: usuario, producto: fila.id), token: token)
            }
        }
        let versionesProductos = try await cliente.subir(planProductos.subir, token: token)
        let versionesCompras = try await cliente.subir(planCompras.subir, token: token)

        var fotosNuevas: [UUID: Data] = [:]
        let huellasLocales = Dictionary(filasProductos.map { ($0.id, $0.foto) }, uniquingKeysWith: { primera, _ in primera })
        for fila in planProductos.aplicar where fila.foto != nil && fila.foto != huellasLocales[fila.id] ?? nil {
            do {
                fotosNuevas[fila.id] = try await cliente.descargarFoto(ruta: ClienteDatos.rutaFoto(usuario: usuario, producto: fila.id), token: token)
            } catch ErrorAuth.sinConexion {
                throw ErrorAuth.sinConexion
            } catch {
                // La imagen ya no existe en la nube: el producto se queda sin foto.
            }
        }

        aplicar(planProductos, planCompras, fotos: fotosNuevas, en: contexto)
        try contexto.save()

        Base.guardar(
            Base(
                productos: planProductos.nuevaBase(versiones: versionesProductos),
                compras: planCompras.nuevaBase(versiones: versionesCompras)
            ),
            usuario: usuario
        )
    }

    private func aplicar(
        _ planProductos: PlanFusion<ProductoNube>, _ planCompras: PlanFusion<CompraNube>, fotos: [UUID: Data], en contexto: ModelContext
    ) {
        // Se vuelve a leer: mientras se esperaba a la red pudo haber cambios.
        var productos = Dictionary(
            ((try? contexto.fetch(FetchDescriptor<Producto>())) ?? []).compactMap { p in p.uid.map { ($0, p) } },
            uniquingKeysWith: { primero, _ in primero }
        )
        let compras = Dictionary(
            ((try? contexto.fetch(FetchDescriptor<Compra>())) ?? []).compactMap { c in c.uid.map { ($0, c) } },
            uniquingKeysWith: { primero, _ in primero }
        )

        for fila in planProductos.aplicar {
            if let producto = productos[fila.id] {
                producto.aplicar(fila, foto: fotos[fila.id])
            } else {
                let nuevo = Producto(nombre: fila.nombre, categoria: .otro, unidad: .piezas, simbolo: fila.simbolo)
                nuevo.uid = fila.id
                nuevo.aplicar(fila, foto: fotos[fila.id])
                contexto.insert(nuevo)
                productos[fila.id] = nuevo
            }
        }
        for fila in planCompras.aplicar {
            let producto = fila.productoId.flatMap { productos[$0] }
            if let compra = compras[fila.id] {
                compra.aplicar(fila, producto: producto)
            } else {
                let nueva = Compra(producto: nil, fecha: fila.fecha, precioTotal: fila.precioTotal, cantidad: fila.cantidad)
                nueva.uid = fila.id
                contexto.insert(nueva)
                nueva.aplicar(fila, producto: producto)
            }
        }
        for id in planCompras.borrarLocal {
            if let compra = compras[id] { contexto.delete(compra) }
        }
        for id in planProductos.borrarLocal {
            if let producto = productos[id] { contexto.delete(producto) }
        }
    }
}

// MARK: Conversión

extension Producto {
    var fila: ProductoNube {
        ProductoNube(
            id: uid ?? UUID(), nombre: nombre, categoria: categoriaRaw, unidad: unidadRaw, simbolo: simbolo,
            notas: notas, archivado: archivado, duracionEstimadaDias: duracionEstimadaDias, creado: creado,
            foto: foto.map(FormatoNube.huellaFoto)
        )
    }

    /// `nueva` es la foto descargada; si es nil y la huella no coincide, la foto ya no existe.
    func aplicar(_ fila: ProductoNube, foto nueva: Data?) {
        if fila.foto == nil {
            foto = nil
        } else if let nueva {
            foto = nueva
        } else if foto.map(FormatoNube.huellaFoto) != fila.foto {
            foto = nil
        }
        nombre = fila.nombre
        categoriaRaw = fila.categoria
        unidadRaw = fila.unidad
        simbolo = fila.simbolo
        notas = fila.notas
        archivado = fila.archivado
        duracionEstimadaDias = fila.duracionEstimadaDias
        creado = fila.creado
    }
}

extension Compra {
    var fila: CompraNube {
        CompraNube(
            id: uid ?? UUID(), productoId: producto?.uid, fecha: fecha, precioTotal: precioTotal,
            cantidad: cantidad, tienda: tienda, fechaAgotado: fechaAgotado
        )
    }

    func aplicar(_ fila: CompraNube, producto: Producto?) {
        self.producto = producto
        fecha = fila.fecha
        precioTotal = fila.precioTotal
        cantidad = fila.cantidad
        tienda = fila.tienda
        fechaAgotado = fila.fechaAgotado
    }
}

// MARK: Base

/// Cómo quedó cada fila en la última sincronización, por cuenta. Vive en Application Support.
private struct Base: Codable {
    var productos: [UUID: EstadoSincronizado] = [:]
    var compras: [UUID: EstadoSincronizado] = [:]

    private static func archivo(usuario: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "sincronizacion-\(usuario).json")
    }

    static func leer(usuario: String) -> Base {
        guard let datos = try? Data(contentsOf: archivo(usuario: usuario)) else { return Base() }
        return (try? JSONDecoder().decode(Base.self, from: datos)) ?? Base()
    }

    static func guardar(_ base: Base, usuario: String) {
        let url = archivo(usuario: usuario)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let datos = try? JSONEncoder().encode(base) {
            try? datos.write(to: url, options: .atomic)
        }
    }

    static func borrar(usuario: String) {
        try? FileManager.default.removeItem(at: archivo(usuario: usuario))
    }
}
