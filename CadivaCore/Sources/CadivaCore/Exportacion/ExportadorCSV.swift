import Foundation

public struct FilaCSV: Sendable, Hashable {
    public var producto: String
    public var categoria: String
    public var fecha: Date
    public var precioTotal: Decimal
    public var cantidad: Decimal
    public var tienda: String?
    public var fechaAgotado: Date?
    public var duracionRealDias: Int?
    /// Cómo se describe la oferta ("2 por S/ 4.00"), si hubo.
    public var oferta: String?
    /// Lo que se ahorró con la oferta en toda la compra.
    public var ahorro: Decimal?

    public init(
        producto: String, categoria: String, fecha: Date,
        precioTotal: Decimal, cantidad: Decimal, tienda: String?, fechaAgotado: Date?, duracionRealDias: Int?,
        oferta: String? = nil, ahorro: Decimal? = nil
    ) {
        self.producto = producto
        self.categoria = categoria
        self.fecha = fecha
        self.precioTotal = precioTotal
        self.cantidad = cantidad
        self.tienda = tienda
        self.fechaAgotado = fechaAgotado
        self.duracionRealDias = duracionRealDias
        self.oferta = oferta
        self.ahorro = ahorro
    }
}

/// CSV con BOM para que Excel respete los acentos. Números con punto decimal y fechas ISO.
public enum ExportadorCSV {
    static let columnas = [
        "producto", "categoria", "fecha", "precio_total", "cantidad",
        "precio_unitario", "tienda", "fecha_agotado", "duracion_real_dias", "oferta", "ahorro",
    ]

    public static func csv(_ filas: [FilaCSV], calendar: Calendar) -> String {
        let estiloFecha = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        let cuerpo = filas.map { fila in
            let unitario = fila.cantidad > 0 ? numero(fila.precioTotal / fila.cantidad) : ""
            return [
                escapar(fila.producto),
                escapar(fila.categoria),
                fila.fecha.formatted(estiloFecha),
                numero(fila.precioTotal),
                numero(fila.cantidad),
                unitario,
                escapar(fila.tienda ?? ""),
                fila.fechaAgotado?.formatted(estiloFecha) ?? "",
                fila.duracionRealDias.map(String.init) ?? "",
                escapar(fila.oferta ?? ""),
                fila.ahorro.map(numero) ?? "",
            ].joined(separator: ",")
        }
        return "\u{FEFF}" + ([columnas.joined(separator: ",")] + cuerpo).joined(separator: "\n") + "\n"
    }

    static func escapar(_ texto: String) -> String {
        guard texto.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return texto }
        return "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func numero(_ valor: Decimal) -> String {
        var entrada = valor
        var redondeado = Decimal()
        NSDecimalRound(&redondeado, &entrada, 4, .plain)
        return "\(redondeado)"
    }
}
