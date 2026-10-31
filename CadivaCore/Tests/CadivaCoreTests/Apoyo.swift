import Foundation
@testable import CadivaCore

/// Utilidades compartidas por las pruebas: calendarios con huso fijo y fechas legibles.
enum Apoyo {
    static func calendario(_ identificador: String = "America/Mexico_City") -> Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: identificador)!
        calendario.locale = Locale(identifier: "es_MX")
        calendario.firstWeekday = 2
        return calendario
    }

    static func fecha(
        _ anio: Int, _ mes: Int, _ dia: Int, _ hora: Int = 12, _ minuto: Int = 0,
        en calendario: Calendar = calendario()
    ) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    static func compra(
        _ fecha: Date, precio: Decimal, cantidad: Decimal = 1,
        tienda: String? = nil, agotado: Date? = nil
    ) -> CompraDatos {
        CompraDatos(fecha: fecha, precioTotal: precio, cantidad: cantidad, tienda: tienda, fechaAgotado: agotado)
    }
}
