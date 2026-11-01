import Foundation

/// Una oferta con la que se hizo una compra. Se guarda junto a la compra para saber
/// cuánto se pagó de verdad por unidad y cuánto se ahorró.
public struct Oferta: Codable, Sendable, Equatable {
    public enum Tipo: String, Codable, Sendable, CaseIterable, Identifiable {
        /// "2 por S/ 4.00": varias unidades a un precio fijo.
        case pack
        /// "3x2": lleva 3 y paga 2.
        case llevaPaga
        /// "-20 %" sobre el precio normal.
        case descuento
        /// "2.ª unidad al 50 %": la segunda unidad tiene descuento.
        case segundaUnidad
        /// El precio bajó: "antes S/ 5.00".
        case rebajado

        public var id: Self { self }
    }

    public var tipo: Tipo
    /// Pack: unidades del pack. Lleva y paga: cuántas lleva.
    public var cantidad: Int?
    /// Lleva y paga: cuántas paga.
    public var paga: Int?
    /// Descuento y segunda unidad: porcentaje entre 0 y 100.
    public var porcentaje: Decimal?
    /// Pack: lo que cuesta el pack completo.
    public var precioPack: Decimal?
    /// Precio normal de una unidad, sin oferta. En el pack es opcional.
    public var precioNormal: Decimal?

    public init(
        tipo: Tipo, cantidad: Int? = nil, paga: Int? = nil, porcentaje: Decimal? = nil,
        precioPack: Decimal? = nil, precioNormal: Decimal? = nil
    ) {
        self.tipo = tipo
        self.cantidad = cantidad
        self.paga = paga
        self.porcentaje = porcentaje
        self.precioPack = precioPack
        self.precioNormal = precioNormal
    }

    /// Lo mínimo que hay que llevar para que la oferta aplique.
    public var unidadesMinimas: Int {
        switch tipo {
        case .pack, .llevaPaga: max(cantidad ?? 1, 1)
        case .segundaUnidad: 2
        case .descuento, .rebajado: 1
        }
    }

    // MARK: Cálculo

    public struct Resultado: Sendable, Equatable {
        /// Lo que se pagó de verdad por unidad.
        public var precioUnitario: Decimal
        /// Lo que habría costado sin oferta, si se sabe.
        public var precioNormal: Decimal?

        public var ahorroPorUnidad: Decimal? {
            precioNormal.map { $0 - precioUnitario }
        }

        /// 0.2 = 20 % menos que el precio normal.
        public var porcentajeAhorro: Decimal? {
            guard let precioNormal, precioNormal > 0, let ahorro = ahorroPorUnidad else { return nil }
            return ahorro / precioNormal
        }
    }

    /// `precioEscrito` es lo que la persona puso en "Precio por unidad": el precio normal en
    /// lleva y paga, descuento y segunda unidad; el precio rebajado en rebajado; en el pack no se usa.
    /// Devuelve nil si faltan datos o no tienen sentido.
    public func calcular(precioEscrito: Decimal?) -> Resultado? {
        switch tipo {
        case .pack:
            guard let cantidad, cantidad >= 2, let precioPack, precioPack > 0 else { return nil }
            return Resultado(precioUnitario: precioPack / Decimal(cantidad), precioNormal: precioNormal.flatMap { $0 > 0 ? $0 : nil })
        case .llevaPaga:
            guard let normal = precioEscrito, normal > 0, let cantidad, let paga,
                  paga >= 1, cantidad > paga else { return nil }
            return Resultado(precioUnitario: normal * Decimal(paga) / Decimal(cantidad), precioNormal: normal)
        case .descuento:
            guard let normal = precioEscrito, normal > 0, let porcentaje, porcentaje > 0, porcentaje < 100 else { return nil }
            return Resultado(precioUnitario: normal * (100 - porcentaje) / 100, precioNormal: normal)
        case .segundaUnidad:
            // Promedio de las dos: una a precio normal y la otra con descuento.
            guard let normal = precioEscrito, normal > 0, let porcentaje, porcentaje > 0, porcentaje <= 100 else { return nil }
            return Resultado(precioUnitario: normal * (200 - porcentaje) / 200, precioNormal: normal)
        case .rebajado:
            guard let rebajado = precioEscrito, rebajado > 0, let precioNormal, precioNormal > rebajado else { return nil }
            return Resultado(precioUnitario: rebajado, precioNormal: precioNormal)
        }
    }

    /// La misma oferta con el precio normal ya resuelto, para guardarla.
    public func conPrecioNormal(_ resultado: Resultado) -> Oferta {
        var copia = self
        copia.precioNormal = resultado.precioNormal
        return copia
    }

    /// Ahorro total de una compra con esta oferta: (precio normal − pagado) × unidades.
    public func ahorro(precioTotal: Decimal, unidades: Decimal) -> Decimal? {
        guard let precioNormal, unidades > 0 else { return nil }
        let ahorro = precioNormal * unidades - precioTotal
        return ahorro > 0 ? ahorro : nil
    }

    // MARK: Guardado

    /// En JSON para guardarla en una sola columna (SwiftData y Supabase).
    public var json: String? {
        (try? JSONEncoder.ordenado.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }

    public init?(json: String?) {
        guard let datos = json?.data(using: .utf8), let oferta = try? JSONDecoder().decode(Oferta.self, from: datos) else { return nil }
        self = oferta
    }

    enum CodingKeys: String, CodingKey {
        case tipo, cantidad, paga, porcentaje, precioPack = "precio_pack", precioNormal = "precio_normal"
    }

    // Los decimales van como texto para no perder centavos.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tipo = try c.decode(Tipo.self, forKey: .tipo)
        cantidad = try c.decodeIfPresent(Int.self, forKey: .cantidad)
        paga = try c.decodeIfPresent(Int.self, forKey: .paga)
        porcentaje = try FormatoNube.decimalOpcional(c, .porcentaje)
        precioPack = try FormatoNube.decimalOpcional(c, .precioPack)
        precioNormal = try FormatoNube.decimalOpcional(c, .precioNormal)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tipo, forKey: .tipo)
        try c.encodeIfPresent(cantidad, forKey: .cantidad)
        try c.encodeIfPresent(paga, forKey: .paga)
        try c.encodeIfPresent(porcentaje.map { "\($0)" }, forKey: .porcentaje)
        try c.encodeIfPresent(precioPack.map { "\($0)" }, forKey: .precioPack)
        try c.encodeIfPresent(precioNormal.map { "\($0)" }, forKey: .precioNormal)
    }
}

extension JSONEncoder {
    static var ordenado: JSONEncoder {
        let codificador = JSONEncoder()
        codificador.outputFormatting = .sortedKeys
        return codificador
    }
}
