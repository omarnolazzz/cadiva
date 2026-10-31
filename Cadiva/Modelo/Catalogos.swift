import Foundation

enum Categoria: String, CaseIterable, Identifiable {
    case despensa = "Despensa"
    case limpieza = "Limpieza"
    case higiene = "Higiene personal"
    case snacks = "Snacks"
    case bebidas = "Bebidas"
    case mascotas = "Mascotas"
    case otro = "Otro"

    var id: Self { self }
    var nombre: String { rawValue }

    var simbolo: String {
        switch self {
        case .despensa: "basket.fill"
        case .limpieza: "bubbles.and.sparkles.fill"
        case .higiene: "hands.and.sparkles.fill"
        case .snacks: "popcorn.fill"
        case .bebidas: "cup.and.saucer.fill"
        case .mascotas: "pawprint.fill"
        case .otro: "shippingbox.fill"
        }
    }
}

/// Lista corta de SF Symbols para elegir el ícono de un producto.
enum SimbolosProducto {
    static let todos = [
        "scroll.fill", "humidity.fill", "drop.fill", "hands.and.sparkles.fill",
        "bubbles.and.sparkles.fill", "washer.fill", "sparkles", "trash.fill",
        "popcorn.fill", "birthday.cake.fill", "carrot.fill", "fork.knife",
        "cup.and.saucer.fill", "mug.fill", "waterbottle.fill", "wineglass.fill",
        "basket.fill", "cart.fill", "bag.fill", "shippingbox.fill",
        "pawprint.fill", "leaf.fill", "pills.fill", "cross.case.fill",
        "lightbulb.fill", "flame.fill", "tshirt.fill", "heart.fill",
    ]
}
