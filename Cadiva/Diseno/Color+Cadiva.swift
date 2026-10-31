import SwiftUI

extension Color {
    /// Tokens de color de Cadiva. Cada uno tiene variante clara y oscura en Assets.xcassets.
    static let cadiva = PaletaCadiva()
}

struct PaletaCadiva: Sendable {
    /// Acento, tint global y botones.
    let brand = Color("brand")
    /// Botón principal.
    let brandDeep = Color("brandDeep")
    /// Destacados sobre fondos oscuros.
    let mint = Color("mint")
    /// Fondos de chips y etiquetas.
    let tint = Color("tint")
    let background = Color("background")
    /// Celdas y tarjetas.
    let surface = Color("surface")
    let textPrimary = Color("textPrimary")
    let textSecondary = Color("textSecondary")
    let priceUp = Color("priceUp")
    /// Precio que bajó.
    let priceDown = Color("priceDown")
    /// Se está acabando (≤ 25 % restante).
    let runningLow = Color("runningLow")
}
