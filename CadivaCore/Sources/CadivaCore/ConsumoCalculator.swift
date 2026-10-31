import Foundation

/// Una compra vista como valor puro, sin dependencias de SwiftData.
public struct CompraDatos: Sendable, Hashable {
    public var fecha: Date
    public var precioTotal: Decimal
    public var cantidad: Decimal
    public var tienda: String?
    public var fechaAgotado: Date?

    public init(fecha: Date, precioTotal: Decimal, cantidad: Decimal, tienda: String? = nil, fechaAgotado: Date? = nil) {
        self.fecha = fecha
        self.precioTotal = precioTotal
        self.cantidad = cantidad
        self.tienda = tienda
        self.fechaAgotado = fechaAgotado
    }
}

/// Todo lo que se deriva de las compras de un producto.
public struct ResumenConsumo: Sendable, Equatable {
    public var compraActiva: CompraDatos?
    public var ultimaCompra: CompraDatos?
    public var precioUnitarioActual: Decimal?
    /// Variación del precio unitario contra la compra anterior (0.2 = +20 %).
    public var cambioPrecio: Decimal?
    public var duracionEstimadaDias: Int?
    public var diasDesdeCompra: Int?
    public var diasRestantes: Int?
    public var fechaRecompra: Date?
    /// Fracción de vida restante de la compra activa, entre 0 y 1.
    public var progresoRestante: Double?
    public var costoPorDia: Decimal?
    public var gastoMensualEstimado: Decimal?
    public var precioUnitarioPromedio: Decimal?
    public var compraMasBarata: CompraDatos?
    public var duracionPromedioDias: Double?

    public static let vacio = ResumenConsumo()
}

/// Cálculos de precio y duración. Es puro: el resultado depende solo de las compras,
/// la fecha de referencia y el calendario (que define el huso horario de los días).
public struct ConsumoCalculator: Sendable {
    public static let diasPorMes: Decimal = 3044 / 100
    /// Cuántas duraciones reales recientes se promedian para estimar la siguiente.
    public static let duracionesParaEstimar = 3

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: Piezas

    public func ordenadas(_ compras: [CompraDatos]) -> [CompraDatos] {
        compras.sorted { $0.fecha < $1.fecha }
    }

    public func precioUnitario(de compra: CompraDatos) -> Decimal? {
        guard compra.cantidad > 0 else { return nil }
        return compra.precioTotal / compra.cantidad
    }

    public func cambioPrecio(de compra: CompraDatos, anterior: CompraDatos) -> Decimal? {
        guard let actual = precioUnitario(de: compra),
              let previo = precioUnitario(de: anterior),
              previo != 0 else { return nil }
        return (actual - previo) / previo
    }

    /// El cambio de precio de cada compra contra la anterior, en orden cronológico.
    public func cambiosDePrecio(_ compras: [CompraDatos]) -> [Decimal?] {
        let orden = ordenadas(compras)
        return orden.indices.map { indice in
            indice == 0 ? nil : cambioPrecio(de: orden[indice], anterior: orden[indice - 1])
        }
    }

    /// Días de calendario entre dos fechas, contados en el huso del calendario.
    public func dias(desde inicio: Date, hasta fin: Date) -> Int {
        let desde = calendar.startOfDay(for: inicio)
        let hasta = calendar.startOfDay(for: fin)
        return calendar.dateComponents([.day], from: desde, to: hasta).day ?? 0
    }

    public func duracionReal(de compra: CompraDatos) -> Int? {
        guard let agotado = compra.fechaAgotado else { return nil }
        let total = dias(desde: compra.fecha, hasta: agotado)
        return total >= 0 ? total : nil
    }

    public func compraActiva(_ compras: [CompraDatos]) -> CompraDatos? {
        ordenadas(compras).last { $0.fechaAgotado == nil }
    }

    /// Promedio de las últimas duraciones reales o, si no hay ninguna, la estimación inicial.
    public func duracionEstimada(compras: [CompraDatos], inicial: Int?) -> Int? {
        let recientes = ordenadas(compras).compactMap(duracionReal(de:)).suffix(Self.duracionesParaEstimar)
        guard !recientes.isEmpty else { return inicial }
        let promedio = Double(recientes.reduce(0, +)) / Double(recientes.count)
        return Int(promedio.rounded(.toNearestOrAwayFromZero))
    }

    public func costoPorDia(de compra: CompraDatos, duracionEstimada: Int?) -> Decimal? {
        guard let duracion = duracionReal(de: compra) ?? duracionEstimada, duracion > 0 else { return nil }
        return compra.precioTotal / Decimal(duracion)
    }

    // MARK: Resumen

    public func resumen(compras: [CompraDatos], duracionInicial: Int?, hoy: Date) -> ResumenConsumo {
        let orden = ordenadas(compras)
        var resumen = ResumenConsumo()
        resumen.duracionEstimadaDias = duracionEstimada(compras: orden, inicial: duracionInicial)
        guard let ultima = orden.last else { return resumen }

        resumen.ultimaCompra = ultima
        resumen.precioUnitarioActual = precioUnitario(de: ultima)
        if orden.count > 1 {
            resumen.cambioPrecio = cambioPrecio(de: ultima, anterior: orden[orden.count - 2])
        }

        let activa = compraActiva(orden)
        resumen.compraActiva = activa
        if let activa {
            let transcurridos = dias(desde: activa.fecha, hasta: hoy)
            resumen.diasDesdeCompra = transcurridos
            if let estimada = resumen.duracionEstimadaDias {
                let restantes = estimada - transcurridos
                resumen.diasRestantes = restantes
                resumen.fechaRecompra = calendar.date(
                    byAdding: .day, value: estimada, to: calendar.startOfDay(for: activa.fecha)
                )
                resumen.progresoRestante = estimada > 0
                    ? min(max(Double(restantes) / Double(estimada), 0), 1)
                    : 0
            }
        }

        let terminadas = orden.compactMap { compra in
            duracionReal(de: compra).flatMap { $0 > 0 ? (compra.precioTotal, $0) : nil }
        }
        if !terminadas.isEmpty {
            let gasto = terminadas.reduce(Decimal.zero) { $0 + $1.0 }
            let diasTotales = terminadas.reduce(0) { $0 + $1.1 }
            resumen.costoPorDia = gasto / Decimal(diasTotales)
        } else {
            resumen.costoPorDia = costoPorDia(de: activa ?? ultima, duracionEstimada: resumen.duracionEstimadaDias)
        }
        resumen.gastoMensualEstimado = resumen.costoPorDia.map { $0 * Self.diasPorMes }

        let unitarios = orden.compactMap { compra in precioUnitario(de: compra).map { (compra, $0) } }
        if !unitarios.isEmpty {
            resumen.precioUnitarioPromedio = unitarios.reduce(Decimal.zero) { $0 + $1.1 } / Decimal(unitarios.count)
            resumen.compraMasBarata = unitarios.min { $0.1 < $1.1 }?.0
        }

        let duraciones = orden.compactMap(duracionReal(de:))
        if !duraciones.isEmpty {
            resumen.duracionPromedioDias = Double(duraciones.reduce(0, +)) / Double(duraciones.count)
        }
        return resumen
    }
}
