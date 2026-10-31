import Foundation

/// Cuánto dura un producto, calculado solo con las compras.
public struct EstimacionDuracion: Sendable, Equatable {
    /// Días que dura una unidad, en promedio.
    public var diasPorUnidad: Double
    /// Cuántos datos se promediaron (intervalos entre compras o duraciones marcadas).
    public var muestras: Int
    /// Lo que debería durar la última compra (días por unidad × unidades).
    public var diasTotales: Int
    /// Días que le quedan a la última compra. Negativo si ya debió acabarse.
    public var diasRestantes: Int
    /// Cuándo se acabaría la última compra.
    public var fechaFin: Date
    /// Lo que le queda a la última compra, entre 0 y 1.
    public var progresoRestante: Double
    /// La última compra ya se marcó como acabada.
    public var terminada: Bool

    public init(
        diasPorUnidad: Double, muestras: Int, diasTotales: Int, diasRestantes: Int,
        fechaFin: Date, progresoRestante: Double, terminada: Bool
    ) {
        self.diasPorUnidad = diasPorUnidad
        self.muestras = muestras
        self.diasTotales = diasTotales
        self.diasRestantes = diasRestantes
        self.fechaFin = fechaFin
        self.progresoRestante = progresoRestante
        self.terminada = terminada
    }
}

extension ConsumoCalculator {
    /// Cuántos datos recientes se promedian.
    public static let muestrasParaDuracion = 3

    /// Duración aproximada sin que haga falta marcar nada: si una compra se marcó como acabada,
    /// cuenta esa duración; si no, cuenta los días hasta la siguiente compra. Todo por unidad,
    /// porque llevar 2 shampoo hace que la siguiente compra tarde el doble.
    /// Necesita al menos una muestra: dos compras en días distintos o una compra marcada como acabada.
    public func duracionAproximada(compras: [CompraDatos], hoy: Date) -> EstimacionDuracion? {
        let orden = ordenadas(compras)
        guard let ultima = orden.last else { return nil }

        var porUnidad: [Double] = []
        for (indice, compra) in orden.enumerated() {
            let unidades = max(NSDecimalNumber(decimal: compra.cantidad).doubleValue, 1)
            if let real = duracionReal(de: compra), real > 0 {
                porUnidad.append(Double(real) / unidades)
            } else if indice + 1 < orden.count {
                let intervalo = dias(desde: compra.fecha, hasta: orden[indice + 1].fecha)
                // Dos compras el mismo día no dicen nada de cuánto dura.
                if intervalo > 0 { porUnidad.append(Double(intervalo) / unidades) }
            }
        }
        let recientes = porUnidad.suffix(Self.muestrasParaDuracion)
        guard !recientes.isEmpty else { return nil }
        let diasPorUnidad = recientes.reduce(0, +) / Double(recientes.count)

        let unidades = max(NSDecimalNumber(decimal: ultima.cantidad).doubleValue, 1)
        let total = max(Int((diasPorUnidad * unidades).rounded(.toNearestOrAwayFromZero)), 1)
        let inicio = calendar.startOfDay(for: ultima.fecha)
        let fin = calendar.date(byAdding: .day, value: total, to: inicio) ?? inicio

        let terminada = ultima.fechaAgotado != nil
        let restantes = terminada ? 0 : total - dias(desde: ultima.fecha, hasta: hoy)
        return EstimacionDuracion(
            diasPorUnidad: diasPorUnidad,
            muestras: recientes.count,
            diasTotales: total,
            diasRestantes: restantes,
            fechaFin: fin,
            progresoRestante: terminada ? 0 : min(max(Double(restantes) / Double(total), 0), 1),
            terminada: terminada
        )
    }
}
