import Foundation

public enum Periodo: String, CaseIterable, Identifiable, Sendable {
    case semana, mes

    public var id: Self { self }
}

/// Lo mínimo de una compra que hace falta para sumar gasto.
public struct RegistroGasto: Sendable, Hashable {
    public var fecha: Date
    public var monto: Decimal
    public var categoria: String

    public init(fecha: Date, monto: Decimal, categoria: String) {
        self.fecha = fecha
        self.monto = monto
        self.categoria = categoria
    }
}

public struct TotalPeriodo: Sendable, Hashable {
    public var intervalo: DateInterval
    public var total: Decimal
}

public struct TotalCategoria: Sendable, Hashable {
    public var categoria: String
    public var total: Decimal
}

public struct CambioProducto: Sendable, Hashable {
    public var nombre: String
    public var cambio: Decimal
}

/// Suma lo gastado por periodo y categoría según la fecha de cada compra.
public struct GastoCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func intervalo(_ periodo: Periodo, contiene fecha: Date) -> DateInterval {
        let componente: Calendar.Component = periodo == .semana ? .weekOfYear : .month
        return calendar.dateInterval(of: componente, for: fecha) ?? DateInterval(start: fecha, duration: 0)
    }

    public func total(_ registros: [RegistroGasto], en intervalo: DateInterval) -> Decimal {
        registros.filter { contiene(intervalo, $0.fecha) }.reduce(Decimal.zero) { $0 + $1.monto }
    }

    /// Los últimos `ultimos` periodos que terminan en el que contiene `hasta`, del más viejo al actual.
    public func totales(_ registros: [RegistroGasto], periodo: Periodo, ultimos: Int, hasta fecha: Date) -> [TotalPeriodo] {
        let componente: Calendar.Component = periodo == .semana ? .weekOfYear : .month
        let actual = intervalo(periodo, contiene: fecha)
        return (0..<max(ultimos, 0)).reversed().compactMap { atras in
            guard let inicio = calendar.date(byAdding: componente, value: -atras, to: actual.start) else { return nil }
            let rango = intervalo(periodo, contiene: inicio)
            return TotalPeriodo(intervalo: rango, total: total(registros, en: rango))
        }
    }

    public func porCategoria(_ registros: [RegistroGasto], en intervalo: DateInterval) -> [TotalCategoria] {
        let agrupado = Dictionary(grouping: registros.filter { contiene(intervalo, $0.fecha) }, by: \.categoria)
        return agrupado
            .map { TotalCategoria(categoria: $0.key, total: $0.value.reduce(Decimal.zero) { $0 + $1.monto }) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.categoria < $1.categoria }
    }

    public static func masSubieron(_ cambios: [(String, Decimal?)], limite: Int) -> [CambioProducto] {
        cambios
            .compactMap { nombre, cambio in cambio.flatMap { $0 > 0 ? CambioProducto(nombre: nombre, cambio: $0) : nil } }
            .sorted { $0.cambio > $1.cambio }
            .prefix(limite)
            .map { $0 }
    }

    private func contiene(_ intervalo: DateInterval, _ fecha: Date) -> Bool {
        fecha >= intervalo.start && fecha < intervalo.end
    }
}
