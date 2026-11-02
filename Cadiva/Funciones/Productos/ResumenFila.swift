import CadivaCore
import Foundation
import SwiftData

/// Todo lo que muestra una fila, ya calculado y formateado. Se prepara cuando cambian los datos;
/// filtrar y ordenar trabajan solo con estos valores, sin volver a la base de datos.
struct ResumenFila: Identifiable {
    let producto: Producto
    let id: PersistentIdentifier
    let nombre: String
    let categoria: Categoria
    let archivado: Bool
    let tienda: String?
    /// "Plaza Vea · hace 3 días". nil si no hay compras.
    let lineaCompra: String?
    let precioTexto: String?
    let cambio: Decimal?
    let conOferta: Bool
    let estimacion: EstimacionDuracion?
    let clave: OrdenProductos.Clave

    init(producto: Producto, moneda: String, hoy: Date) {
        let calculadora = ConsumoCalculator.app
        let ultima = producto.ultimaCompra
        let ordenadas = calculadora.ordenadas(producto.compras.map { $0.datos })
        let estimacion = producto.seguimiento == .duracion
            ? calculadora.duracionAproximada(compras: ordenadas, hoy: hoy)
            : nil
        let cambio = ordenadas.count > 1
            ? calculadora.cambioPrecio(de: ordenadas[ordenadas.count - 1], anterior: ordenadas[ordenadas.count - 2])
            : nil
        let precio = ultima?.precioUnitario

        self.producto = producto
        id = producto.persistentModelID
        nombre = producto.nombre
        categoria = producto.categoria
        archivado = producto.archivado
        tienda = ultima?.tienda
        lineaCompra = ultima.map { compra in
            let cuando = compra.fecha.formatted(.relative(presentation: .named).locale(.cadiva))
            return "\(compra.tienda ?? "Sin tienda") · \(cuando)"
        }
        precioTexto = precio.map { Formato.moneda($0, moneda) }
        self.cambio = cambio
        conOferta = ultima?.ofertaJSON != nil
        self.estimacion = estimacion
        clave = OrdenProductos.Clave(
            nombre: producto.nombre,
            fecha: ultima?.fecha ?? producto.creado,
            precio: precio,
            cambio: cambio,
            // Una compra ya marcada como acabada no está "por acabarse".
            diasRestantes: estimacion.flatMap { $0.terminada ? nil : $0.diasRestantes }
        )
    }
}
