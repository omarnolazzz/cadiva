import Foundation

/// Qué se registra de un producto.
public enum Seguimiento: String, Sendable, CaseIterable, Identifiable {
    /// Se compra por cantidad y se consume en días o semanas: papel, shampoo, detergente.
    case duracion
    /// Se consume enseguida: un snack, una gaseosa. Solo interesan el precio y la tienda.
    case soloPrecio

    public var id: Self { self }
}

/// Sugiere el seguimiento de un producto a partir de su nombre y su categoría.
public enum ClasificadorSeguimiento {
    /// Productos que se consumen de una vez: ganan aunque la categoría diga otra cosa.
    static let deConsumoInmediato = [
        "snack", "galleta", "chocolate", "chicle", "caramelo", "golosina", "chupetin", "helado",
        "papita", "papas fritas", "chifle", "piqueo", "doritos", "cuates", "gaseosa", "refresco",
        "energizante", "cerveza", "lata", "barra de", "turron", "alfajor", "keke", "sandwich", "empanada",
    ]

    /// Productos que duran días o semanas.
    static let deDuracion = [
        "shampoo", "champu", "acondicionador", "jabon", "gel de ducha", "pasta dental", "crema dental",
        "enjuague", "desodorante", "talco", "crema", "papel", "servilleta", "toalla", "panal", "algodon",
        "hisopo", "afeitar", "detergente", "suavizante", "lejia", "cloro", "lavavajilla", "quitagrasa",
        "limpiador", "desinfectante", "ambientador", "bolsa de basura", "bolsas", "esponja", "insecticida",
        "croqueta", "alimento para", "arena para", "arroz", "azucar", "aceite", "sal ", "cafe", "avena",
        "harina", "leche", "mantequilla", "atun", "menestra", "lenteja", "frejol", "fideo", "te ",
        "infusion", "vinagre", "mayonesa", "ketchup", "condimento", "agua de mesa", "bidon",
    ]

    /// "24 rollos", "x6", "pack", "5 kg", "1.5 L": presentaciones que se consumen de a poco.
    static let presentacionGrande = #"(\b\d+\s*(rollos?|unid(ades)?|uds?|paquetes?|sobres?|bolsas?)\b)|(\bx\s?\d+\b)|(\bpack\b)|(\b\d+([.,]\d+)?\s*(kg|kilos?|l|lt|litros?)\b)"#

    static let categoriasDeDuracion: Set<String> = ["Limpieza", "Higiene personal", "Mascotas"]

    public static func sugerir(nombre: String, categoria: String) -> Seguimiento {
        let texto = " " + nombre.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased() + " "
        if deConsumoInmediato.contains(where: { texto.contains($0) }) { return .soloPrecio }
        if deDuracion.contains(where: { texto.contains($0) }) { return .duracion }
        if let patron = try? Regex(presentacionGrande), texto.contains(patron) { return .duracion }
        return categoriasDeDuracion.contains(categoria) ? .duracion : .soloPrecio
    }
}
