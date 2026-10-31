import Foundation
import SwiftUI

enum Formato {
    static func moneda(_ valor: Decimal, _ codigo: String) -> String {
        valor.formatted(.currency(code: codigo).locale(.cadiva))
    }

    static func moneda(_ valor: Decimal?, _ codigo: String) -> String {
        valor.map { moneda($0, codigo) } ?? "—"
    }

    /// 0.125 → "12.5 %".
    static func porcentaje(_ valor: Decimal) -> String {
        valor.formatted(.percent.precision(.fractionLength(0...1)).locale(.cadiva))
    }

    /// "3 nov".
    static func fechaCorta(_ fecha: Date) -> String {
        fecha.formatted(.dateTime.day().month(.abbreviated).locale(.cadiva))
    }

    /// "3 de noviembre de 2026".
    static func fechaLarga(_ fecha: Date) -> String {
        fecha.formatted(.dateTime.day().month(.wide).year().locale(.cadiva))
    }

    static func dias(_ cantidad: Int) -> String {
        cantidad == 1 ? "1 día" : "\(cantidad) días"
    }

    static func unidades(_ cantidad: Int) -> String {
        cantidad == 1 ? "1 unidad" : "\(cantidad) unidades"
    }

    /// Acepta coma o punto como separador decimal.
    static func decimal(_ texto: String) -> Decimal? {
        let limpio = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !limpio.isEmpty else { return nil }
        return Decimal(string: limpio, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Para precargar campos de texto con un Decimal.
    static func texto(_ valor: Decimal) -> String {
        "\(valor)"
    }
}

extension Decimal {
    var double: Double { NSDecimalNumber(decimal: self).doubleValue }
}

extension String {
    var recortado: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension View {
    /// Fondo de lista con los tokens de Cadiva.
    func fondoCadiva() -> some View {
        scrollContentBackground(.hidden).background(Color.cadiva.background)
    }

    /// Fondo de celda con los tokens de Cadiva.
    func celdaCadiva() -> some View {
        listRowBackground(Color.cadiva.surface)
    }
}
