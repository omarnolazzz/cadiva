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
            } catch let error where ErrorNube.esFaltaDeRed(error) {
                estado = .error("Sin conexión. Se sincroniza al volver la red.")
            } catch {
                estado = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        } while pendiente && estado == .listo
    }

    /// Hubo cambios mientras se sincronizaba; se repite al terminar.
    @ObservationIgnored private var pendiente = false

    /// Al cerrar sesión borrando los datos del iPhone, se olvida la base; si no, al volver
    /// a entrar parecería que se borró todo aquí y se borraría también en la nube.
    func olvidar(usuario: String) {
        BaseSincronizacion.borrar(usuario: usuario)
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
        // Las fotos solo se leen del disco si hay que subirlas (ver abajo): leerlas todas calienta el iPhone.
        let productosPorId = Dictionary(
            productos.compactMap { p in p.uid.map { ($0, p) } },
            uniquingKeysWith: { primero, _ in primero }
        )

        let token = try await sesion.tokenVigente()
        async let remotosProductos = cliente.descargar(ProductoNube.self, token: token)
        async let remotasCompras = cliente.descargar(CompraNube.self, token: token)
        let (nubeProductos, nubeCompras) = try await (remotosProductos, remotasCompras)

        let base = BaseSincronizacion.leer(usuario: usuario)
        let planProductos = Fusion.planear(locales: filasProductos, remotas: nubeProductos, base: base.productos)
        let planCompras = Fusion.planear(locales: filasCompras, remotas: nubeCompras, base: base.compras)

        // Primero se sube; si falla, el iPhone queda igual y se reintenta después.
        // Las fotos van antes que las filas para que otro dispositivo nunca vea una huella sin imagen.
        for fila in planProductos.subir where !fila.borrado && fila.foto != nil {
            if let datos = productosPorId[fila.id]?.foto {
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
            } catch let error where ErrorNube.esFaltaDeRed(error) {
                throw error
            } catch {
                // La imagen ya no existe en la nube: el producto se queda sin foto.
            }
        }

        aplicar(planProductos, planCompras, fotos: fotosNuevas, en: contexto)
        try contexto.save()

        BaseSincronizacion.guardar(
            BaseSincronizacion(
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
                let nuevo = Producto(nombre: fila.nombre, categoria: .otro, simbolo: fila.simbolo)
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
