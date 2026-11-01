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
    /// Una sola instancia: crear el calendario en cada fila y en cada redibujado costaba.
    static let app = ConsumoCalculator(calendar: .cadiva)
}

extension GastoCalculator {
    static let app = GastoCalculator(calendar: .cadiva)
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
    /// Recorre las compras una vez: no hace falta ordenarlas para saber cuál es la última.
    var ultimaCompra: Compra? { compras.max { $0.fecha < $1.fecha } }
}

extension Compra {
    /// Las compras son de un solo producto: `cantidad` son las unidades que se llevaron.
    var unidades: Int { max(NSDecimalNumber(decimal: cantidad).intValue, 1) }
}

extension Producto {
    /// Lo elegido a mano o, si no, lo que sugiere el clasificador según el nombre y la categoría.
    var seguimiento: Seguimiento {
        seguimientoRaw.flatMap(Seguimiento.init(rawValue:))
            ?? ClasificadorSeguimiento.sugerir(nombre: nombre, categoria: categoria.rawValue)
    }

    /// Solo para productos que se siguen por duración.
    func duracionAproximada(hoy: Date = .now) -> EstimacionDuracion? {
        guard seguimiento == .duracion else { return nil }
        return ConsumoCalculator.app.duracionAproximada(compras: compras.map(\.datos), hoy: hoy)
    }
}

extension Compra {
    var oferta: Oferta? {
        get { Oferta(json: ofertaJSON) }
        set { ofertaJSON = newValue?.json }
    }

    /// Lo que se ahorró en esta compra gracias a la oferta, si se sabe el precio normal.
    var ahorro: Decimal? { oferta?.ahorro(precioTotal: precioTotal, unidades: cantidad) }
}
