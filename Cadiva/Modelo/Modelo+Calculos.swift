import CadivaCore
import Foundation

extension Locale {
    static let cadiva = Locale(identifier: "es_PE")
}

extension Calendar {
    /// Calendario del dispositivo (su huso horario) con semanas de lunes a domingo.
    static var cadiva: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = .current
        calendario.locale = .cadiva
        calendario.firstWeekday = 2
        return calendario
    }
}

extension ConsumoCalculator {
    static var app: ConsumoCalculator { ConsumoCalculator(calendar: .cadiva) }
}

extension GastoCalculator {
    static var app: GastoCalculator { GastoCalculator(calendar: .cadiva) }
}

extension Compra {
    var datos: CompraDatos {
        CompraDatos(fecha: fecha, precioTotal: precioTotal, cantidad: cantidad, tienda: tienda, fechaAgotado: fechaAgotado)
    }

    var precioUnitario: Decimal? { ConsumoCalculator.app.precioUnitario(de: datos) }
    var duracionReal: Int? { ConsumoCalculator.app.duracionReal(de: datos) }
}

extension Producto {
    var comprasOrdenadas: [Compra] { compras.sorted { $0.fecha < $1.fecha } }

    var compraActiva: Compra? { comprasOrdenadas.last { $0.fechaAgotado == nil } }

    func resumen(hoy: Date = .now) -> ResumenConsumo {
        ConsumoCalculator.app.resumen(compras: compras.map(\.datos), hoy: hoy)
    }
}

extension Producto {
    var ultimaCompra: Compra? { comprasOrdenadas.last }
}

extension Compra {
    /// Las compras son de un solo producto: `cantidad` son las unidades que se llevaron.
    var unidades: Int { max(NSDecimalNumber(decimal: cantidad).intValue, 1) }
}

