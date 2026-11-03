#if DEBUG
import Foundation
import QuartzCore
import SwiftData

/// Mide cuánto tarda cada cuadro mientras se cambia de categoría (`--pantalla medir-filtro`).
/// Deja el resultado en Documents/medicion-fluidez.json para que la CI lo lea.
@MainActor
final class MedidorFluidez: NSObject {
    private var enlace: CADisplayLink?
    private var anterior: CFTimeInterval?
    private var cuadros: [Double] = []

    /// Recorre las opciones varias veces, con una pausa como la de una persona tocando los filtros.
    static func recorrer<Opcion>(_ opciones: [Opcion], cambiar: @MainActor (Opcion) -> Void) async {
        guard !opciones.isEmpty else { return }
        try? await Task.sleep(for: .seconds(3))
        let medidor = MedidorFluidez()
        medidor.iniciar()
        for indice in 0..<30 {
            cambiar(opciones[indice % opciones.count])
            try? await Task.sleep(for: .milliseconds(500))
        }
        medidor.terminar()
    }

    private func iniciar() {
        let enlace = CADisplayLink(target: self, selector: #selector(cuadro(_:)))
        enlace.add(to: .main, forMode: .common)
        self.enlace = enlace
    }

    @objc private func cuadro(_ enlace: CADisplayLink) {
        if let anterior { cuadros.append((enlace.timestamp - anterior) * 1000) }
        anterior = enlace.timestamp
    }

    private func terminar() {
        enlace?.invalidate()
        let orden = cuadros.sorted()
        func percentil(_ p: Double) -> Double { orden.isEmpty ? 0 : orden[min(Int(Double(orden.count) * p), orden.count - 1)] }
        let resultado: [String: Double] = [
            "cuadros": Double(orden.count),
            "p50_ms": percentil(0.5),
            "p95_ms": percentil(0.95),
            "p99_ms": percentil(0.99),
            "max_ms": orden.last ?? 0,
            "cuadros_lentos_mas_de_33ms": Double(orden.filter { $0 > 33.4 }.count),
            "tiempo_perdido_ms": orden.filter { $0 > 16.7 }.reduce(0) { $0 + ($1 - 16.7) },
        ]
        let url = URL.documentsDirectory.appending(path: "medicion-fluidez.json")
        if let datos = try? JSONSerialization.data(withJSONObject: resultado, options: [.sortedKeys, .prettyPrinted]) {
            try? datos.write(to: url)
        }
    }
}

extension DatosEjemplo {
    /// Muchos productos para medir (120, o los de `--cantidad`), de todas las categorías, con 8 compras cada uno.
    static func poblarMuchos(_ contexto: ModelContext, hoy: Date = .now) {
        let calendario = Calendar.cadiva
        let tiendas = ["Plaza Vea", "Tottus", "Makro", "Mass", "Metro", "Wong"]
        for numero in 0..<(Demo.valor("--cantidad").flatMap(Int.init) ?? 120) {
            let categoria = Categoria.allCases[numero % Categoria.allCases.count]
            let producto = Producto(nombre: "\(categoria.nombre) \(numero)", categoria: categoria, simbolo: categoria.simbolo)
            contexto.insert(producto)
            for compra in 0..<8 {
                let fecha = calendario.date(byAdding: .day, value: -(compra * 20 + numero % 15), to: hoy) ?? hoy
                let precio = Decimal(500 + numero * 7 + compra * 23) / 100
                contexto.insert(Compra(
                    producto: producto, fecha: fecha, precioTotal: precio, cantidad: 1,
                    tienda: tiendas[(numero + compra) % tiendas.count]
                ))
            }
        }
        try? contexto.save()
    }
}
#endif
