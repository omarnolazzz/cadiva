import Foundation

/// Tiendas del historial para autocompletar: primero las más usadas.
public enum TiendasFrecuentes {
    /// Lo mínimo de una compra que importa aquí.
    public struct Registro: Sendable, Equatable {
        public var tienda: String?
        public var fecha: Date

        public init(tienda: String?, fecha: Date) {
            self.tienda = tienda
            self.fecha = fecha
        }
    }

    /// De la más usada a la menos usada; si empatan, la más reciente primero.
    /// "plaza vea" y "Plaza Vea" cuentan como la misma y se muestra como se escribió la última vez.
    public static func ordenar(_ registros: [Registro], locale: Locale) -> [String] {
        var conteo: [String: (nombre: String, veces: Int, ultima: Date)] = [:]
        for registro in registros {
            guard let tienda = registro.tienda?.trimmingCharacters(in: .whitespacesAndNewlines), !tienda.isEmpty else { continue }
            let clave = tienda.lowercased(with: locale)
            var actual = conteo[clave] ?? (tienda, 0, .distantPast)
            actual.veces += 1
            if registro.fecha > actual.ultima {
                actual.ultima = registro.fecha
                actual.nombre = tienda
            }
            conteo[clave] = actual
        }
        return conteo.values
            .sorted { $0.veces != $1.veces ? $0.veces > $1.veces : $0.ultima > $1.ultima }
            .map(\.nombre)
    }

    /// Las que contienen lo escrito (sin distinguir mayúsculas ni acentos), sin repetir lo ya escrito.
    public static func sugerencias(_ tiendas: [String], para texto: String, limite: Int = 6) -> [String] {
        let escrito = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !escrito.isEmpty else { return Array(tiendas.prefix(limite)) }
        let opciones: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return tiendas
            .filter { $0.range(of: escrito, options: opciones) != nil && $0.compare(escrito, options: opciones) != .orderedSame }
            .prefix(limite)
            .map { $0 }
    }
}
