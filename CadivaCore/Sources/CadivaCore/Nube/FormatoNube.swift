import CryptoKit
import Foundation

/// Fechas y números tal como viajan a Supabase.
public enum FormatoNube {
    /// Huella corta de una foto: cambia si cambia la imagen.
    public static func huellaFoto(_ datos: Data) -> String {
        SHA256.hash(data: datos).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// Milisegundos: lo que sobrevive al viaje de ida y vuelta.
    public static func redondear(_ fecha: Date) -> Date {
        Date(timeIntervalSince1970: (fecha.timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    public static var codificador: JSONEncoder {
        let codificador = JSONEncoder()
        codificador.outputFormatting = .sortedKeys
        codificador.dateEncodingStrategy = .custom { fecha, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(texto(de: fecha))
        }
        return codificador
    }

    public static var decodificador: JSONDecoder {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let texto = try c.decode(String.self)
            guard let fecha = fecha(de: texto) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha inválida: \(texto)")
            }
            return fecha
        }
        return decodificador
    }

    public static func texto(de fecha: Date) -> String {
        let formato = ISO8601DateFormatter()
        formato.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formato.string(from: fecha)
    }

    /// Acepta lo que devuelve Postgres: `2026-10-30T23:38:07.123456+00:00`, sin fracción o con `Z`.
    public static func fecha(de texto: String) -> Date? {
        var base = texto.replacingOccurrences(of: " ", with: "T")
        var fraccion = 0.0
        if let punto = base.firstIndex(of: "."), let t = base.firstIndex(of: "T"), punto > t {
            let digitos = base[base.index(after: punto)...].prefix { $0.isNumber }
            fraccion = Double("0." + digitos) ?? 0
            base.removeSubrange(punto..<base.index(base.index(after: punto), offsetBy: digitos.count))
        }
        let formato = ISO8601DateFormatter()
        formato.formatOptions = [.withInternetDateTime]
        guard let segundos = formato.date(from: base) else { return nil }
        return redondear(segundos.addingTimeInterval(fraccion))
    }

    static func decimal<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ clave: K) throws -> Decimal {
        if let texto = try? c.decode(String.self, forKey: clave), let valor = Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX")) {
            return valor
        }
        return try c.decode(Decimal.self, forKey: clave)
    }
}
