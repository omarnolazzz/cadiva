#if DEBUG
import Foundation
import SwiftData

/// Datos de ejemplo en memoria para los #Preview y las capturas. Nunca se cargan en la app real.
@MainActor
enum DatosEjemplo {
    static let contenedor: ModelContainer = {
        let contenedor = vacio()
        poblar(contenedor.mainContext)
        return contenedor
    }()

    static func vacio() -> ModelContainer {
        let configuracion = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Producto.self, Compra.self, configurations: configuracion)
        } catch {
            fatalError("No se pudo crear el contenedor de ejemplo: \(error)")
        }
    }

    static var arroz: Producto { producto(llamado: "Arroz Costeño 5 kg") }

    static func producto(llamado nombre: String) -> Producto {
        let descriptor = FetchDescriptor<Producto>(predicate: #Predicate { $0.nombre == nombre })
        guard let producto = try? contenedor.mainContext.fetch(descriptor).first else {
            fatalError("No existe el producto de ejemplo \(nombre)")
        }
        return producto
    }

    /// Una compra: hace cuántos días, precio por unidad en céntimos, unidades y tienda.
    private struct Muestra {
        let hace: Int
        let centimos: Int
        var unidades: Decimal = 1
        let tienda: String
        var agotadoHace: Int?
    }

    static func poblar(_ contexto: ModelContext, hoy: Date = .now) {
        let calendario = Calendar.cadiva
        func dia(_ hace: Int) -> Date {
            calendario.date(byAdding: .day, value: -hace, to: hoy) ?? hoy
        }
        func agregar(_ producto: Producto, _ muestras: [Muestra]) {
            contexto.insert(producto)
            for muestra in muestras {
                let compra = Compra(
                    producto: producto, fecha: dia(muestra.hace), precioTotal: Decimal(muestra.centimos) / 100 * muestra.unidades,
                    cantidad: muestra.unidades, tienda: muestra.tienda, fechaAgotado: muestra.agotadoHace.map(dia)
                )
                contexto.insert(compra)
            }
        }

        agregar(
            Producto(nombre: "Arroz Costeño 5 kg", categoria: .despensa, simbolo: "basket.fill"),
            [
                Muestra(hace: 88, centimos: 2190, tienda: "Plaza Vea", agotadoHace: 58),
                Muestra(hace: 58, centimos: 2250, tienda: "Tottus", agotadoHace: 30),
                Muestra(hace: 30, centimos: 2090, tienda: "Makro", agotadoHace: 3),
                Muestra(hace: 3, centimos: 2340, tienda: "Plaza Vea"),
            ]
        )
        agregar(
            Producto(nombre: "Papel higiénico Elite 24 rollos", categoria: .higiene, simbolo: "scroll.fill"),
            [
                Muestra(hace: 80, centimos: 3290, tienda: "Tottus", agotadoHace: 52),
                Muestra(hace: 52, centimos: 2990, tienda: "Makro", agotadoHace: 24),
                Muestra(hace: 24, centimos: 3350, tienda: "Plaza Vea"),
            ]
        )
        agregar(
            Producto(nombre: "Leche Gloria 400 g", categoria: .despensa, simbolo: "drop.fill"),
            [
                Muestra(hace: 60, centimos: 420, unidades: 6, tienda: "Mass"),
                Muestra(hace: 40, centimos: 430, unidades: 6, tienda: "Tambo"),
                Muestra(hace: 20, centimos: 410, unidades: 12, tienda: "Mass"),
                Muestra(hace: 6, centimos: 440, unidades: 6, tienda: "Mass"),
            ]
        )
        agregar(
            Producto(nombre: "Detergente Ariel 4 kg", categoria: .limpieza, simbolo: "washer.fill"),
            [
                Muestra(hace: 75, centimos: 4990, tienda: "Metro", agotadoHace: 40),
                Muestra(hace: 40, centimos: 4690, tienda: "Makro", agotadoHace: 9),
                Muestra(hace: 9, centimos: 5290, tienda: "Wong"),
            ]
        )
        agregar(
            Producto(nombre: "Café Altomayo 250 g", categoria: .bebidas, simbolo: "cup.and.saucer.fill"),
            [
                Muestra(hace: 70, centimos: 1850, tienda: "Plaza Vea"),
                Muestra(hace: 42, centimos: 1890, tienda: "Tottus"),
                Muestra(hace: 14, centimos: 1790, unidades: 2, tienda: "Plaza Vea"),
            ]
        )
        agregar(
            Producto(nombre: "Croquetas Ricocan 15 kg", categoria: .mascotas, simbolo: "pawprint.fill"),
            [
                Muestra(hace: 50, centimos: 13900, tienda: "Makro"),
                Muestra(hace: 12, centimos: 14590, tienda: "Tottus"),
            ]
        )
        agregar(
            Producto(nombre: "Papas Lay's 42 g", categoria: .snacks, simbolo: "popcorn.fill"),
            [
                Muestra(hace: 21, centimos: 250, tienda: "Tambo"),
                Muestra(hace: 9, centimos: 230, tienda: "Mass"),
                Muestra(hace: 2, centimos: 270, tienda: "Tambo"),
            ]
        )
        agregar(
            Producto(nombre: "Shampoo Head & Shoulders 375 ml", categoria: .higiene, simbolo: "drop.fill"),
            [
                Muestra(hace: 64, centimos: 2290, tienda: "Plaza Vea"),
                Muestra(hace: 40, centimos: 2190, unidades: 2, tienda: "Makro"),
                Muestra(hace: 1, centimos: 2390, tienda: "Plaza Vea"),
            ]
        )
        let nuevo = Producto(nombre: "Aceite Primor 1 L", categoria: .despensa, simbolo: "drop.fill")
        nuevo.creado = dia(1)
        contexto.insert(nuevo)
    }
}
#endif
