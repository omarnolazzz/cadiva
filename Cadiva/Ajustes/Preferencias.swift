import Foundation

/// Claves de `@AppStorage` y sus valores por defecto.
enum Preferencias {
    static let moneda = "moneda"
    static let avisosActivos = "avisosActivos"
    static let diasAviso = "diasAviso"

    static let monedaPorDefecto = "PEN"
    static let diasAvisoPorDefecto = 2

    static let monedas = ["PEN", "USD", "EUR", "MXN", "COP", "CLP", "ARS"]
}
