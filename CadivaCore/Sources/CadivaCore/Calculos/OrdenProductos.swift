import Foundation

/// Cómo ordenar la lista de productos.
public enum OrdenProductos: String, CaseIterable, Identifiable, Sendable {
    case recientes
    case nombre
    case precioMenor
    case precioMayor
    case masSubieron
    case porAcabarse

    public var id: Self { self }

    /// Lo que hace falta saber de un producto para ordenarlo.
    public struct Clave: Sendable, Equatable {
        public var nombre: String
        /// Última compra o, si no tiene, cuándo se creó el producto.
        public var fecha: Date
        public var precio: Decimal?
        public var cambio: Decimal?
        public var diasRestantes: Int?

        public init(nombre: String, fecha: Date, precio: Decimal? = nil, cambio: Decimal? = nil, diasRestantes: Int? = nil) {
            self.nombre = nombre
            self.fecha = fecha
            self.precio = precio
            self.cambio = cambio
            self.diasRestantes = diasRestantes
        }
    }

    /// Los productos sin el dato van al final; los empates se resuelven por nombre.
    public func ordenar<Elemento>(_ elementos: [Elemento], clave: (Elemento) -> Clave) -> [Elemento] {
        elementos
            .map { (elemento: $0, clave: clave($0)) }
            .sorted { antes($0.clave, $1.clave) }
            .map(\.elemento)
    }

    private func antes(_ a: Clave, _ b: Clave) -> Bool {
        let resultado: Bool? = switch self {
        case .recientes: a.fecha == b.fecha ? nil : a.fecha > b.fecha
        case .nombre: nil
        case .precioMenor: Self.comparar(a.precio, b.precio, <)
        case .precioMayor: Self.comparar(a.precio, b.precio, >)
        case .masSubieron: Self.comparar(a.cambio, b.cambio, >)
        case .porAcabarse: Self.comparar(a.diasRestantes, b.diasRestantes, <)
        }
        return resultado ?? (a.nombre.localizedStandardCompare(b.nombre) == .orderedAscending)
    }

    /// nil si empatan. Quien tiene el dato va antes que quien no lo tiene.
    private static func comparar<Valor: Comparable>(_ a: Valor?, _ b: Valor?, _ orden: (Valor, Valor) -> Bool) -> Bool? {
        switch (a, b) {
        case (nil, nil): nil
        case (nil, _): false
        case (_, nil): true
        case let (a?, b?): a == b ? nil : orden(a, b)
        }
    }
}
