import CadivaCore
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

    /// "≈ 1 día", "≈ 12 días", "≈ 9 semanas". Para duraciones aproximadas.
    static func duracion(_ dias: Double) -> String {
        let redondeado = max(Int(dias.rounded()), 1)
        if redondeado >= 56 { return "≈ \(Int((dias / 7).rounded())) semanas" }
        return "≈ \(Self.dias(redondeado))"
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

extension Formato {
    /// "2 por S/ 4.00", "3x2", "-20 %", "2.ª unidad -50 %", "Rebajado".
    static func oferta(_ oferta: Oferta, _ moneda: String) -> String {
        switch oferta.tipo {
        case .pack:
            return "\(oferta.cantidad ?? 2) por \(Formato.moneda(oferta.precioPack, moneda))"
        case .llevaPaga:
            return "\(oferta.cantidad ?? 3)x\(oferta.paga ?? 2)"
        case .descuento:
            return "-\(Formato.porcentaje((oferta.porcentaje ?? 0) / 100))"
        case .segundaUnidad:
            return "2.ª unidad -\(Formato.porcentaje((oferta.porcentaje ?? 0) / 100))"
        case .rebajado:
            return "Rebajado"
        }
    }

    /// Nombre del tipo, para el selector.
    static func tipoOferta(_ tipo: Oferta.Tipo) -> String {
        switch tipo {
        case .pack: "Pack (2 por S/ 4)"
        case .llevaPaga: "Lleva y paga (3x2)"
        case .descuento: "% de descuento"
        case .segundaUnidad: "2.ª unidad con descuento"
        case .rebajado: "Precio rebajado"
        }
    }
}

extension Formato {
    static func orden(_ orden: OrdenProductos) -> String {
        switch orden {
        case .recientes: "Compra más reciente"
        case .nombre: "Nombre (A–Z)"
        case .precioMenor: "Precio: menor a mayor"
        case .precioMayor: "Precio: mayor a menor"
        case .masSubieron: "Los que más subieron"
        case .porAcabarse: "Por acabarse"
        }
    }

    /// Para el botón del menú, donde comparte la línea con el filtro de categorías.
    static func ordenCorto(_ orden: OrdenProductos) -> String {
        switch orden {
        case .recientes: "Más reciente"
        case .nombre: "Nombre (A–Z)"
        case .precioMenor: "Menor precio"
        case .precioMayor: "Mayor precio"
        case .masSubieron: "Más subieron"
        case .porAcabarse: "Por acabarse"
        }
    }

    static func simboloOrden(_ orden: OrdenProductos) -> String {
        switch orden {
        case .recientes: "clock"
        case .nombre: "textformat"
        case .precioMenor: "arrow.down.circle"
        case .precioMayor: "arrow.up.circle"
        case .masSubieron: "chart.line.uptrend.xyaxis"
        case .porAcabarse: "hourglass"
        }
    }
}
