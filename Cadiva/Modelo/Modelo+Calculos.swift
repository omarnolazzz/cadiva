import CadivaCore
import Foundation

extension Locale {
    static let cadiva = Locale(identifier: "es_PE")
}

extension Calendar {
    /// Calendario del dispositivo (su huso horario) con semanas de lunes a domingo.
    static var cadiva: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = .current
        calendario.locale = .cadiva
        calendario.firstWeekday = 2
        return calendario
    }
}

extension ConsumoCalculator {
    static var app: ConsumoCalculator { ConsumoCalculator(calendar: .cadiva) }
}

extension GastoCalculator {
    static var app: GastoCalculator { GastoCalculator(calendar: .cadiva) }
}

extension Compra {
    var datos: CompraDatos {
        CompraDatos(fecha: fecha, precioTotal: precioTotal, cantidad: cantidad, tienda: tienda, fechaAgotado: fechaAgotado)
    }

    var precioUnitario: Decimal? { ConsumoCalculator.app.precioUnitario(de: datos) }
    var duracionReal: Int? { ConsumoCalculator.app.duracionReal(de: datos) }
}

extension Producto {
    var comprasOrdenadas: [Compra] { compras.sorted { $0.fecha < $1.fecha } }

    var compraActiva: Compra? { comprasOrdenadas.last { $0.fechaAgotado == nil } }

    func resumen(hoy: Date = .now) -> ResumenConsumo {
        ConsumoCalculator.app.resumen(compras: compras.map(\.datos), duracionInicial: duracionEstimadaDias, hoy: hoy)
    }
}

extension Producto {
    var ultimaCompra: Compra? { comprasOrdenadas.last }
}

extension Compra {
    /// Las compras son de un solo producto: `cantidad` son las unidades que se llevaron.
    var unidades: Int { max(NSDecimalNumber(decimal: cantidad).intValue, 1) }
}

/// Tiendas del historial, de la más usada a la menos usada.
enum TiendasFrecuentes {
    static func ordenar(_ compras: [Compra]) -> [String] {
        var conteo: [String: (nombre: String, veces: Int, ultima: Date)] = [:]
        for compra in compras {
            guard let tienda = compra.tienda?.recortado, !tienda.isEmpty else { continue }
            let clave = tienda.lowercased(with: .cadiva)
            var actual = conteo[clave] ?? (tienda, 0, .distantPast)
            actual.veces += 1
            if compra.fecha > actual.ultima {
                actual.ultima = compra.fecha
                actual.nombre = tienda
            }
            conteo[clave] = actual
        }
        return conteo.values
            .sorted { $0.veces != $1.veces ? $0.veces > $1.veces : $0.ultima > $1.ultima }
            .map(\.nombre)
    }

    /// Las que coinciden con lo escrito (sin distinguir mayúsculas ni acentos), sin repetir lo ya escrito.
    static func sugerencias(_ tiendas: [String], para texto: String, limite: Int = 6) -> [String] {
        let escrito = texto.recortado
        guard !escrito.isEmpty else { return Array(tiendas.prefix(limite)) }
        let opciones: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return tiendas
            .filter { $0.range(of: escrito, options: opciones) != nil && $0.compare(escrito, options: opciones) != .orderedSame }
            .prefix(limite)
            .map { $0 }
    }
}
