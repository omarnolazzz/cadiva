import Foundation
import SwiftData

@Model
final class Compra {
    var producto: Producto?
    var fecha: Date = Date.now
    var precioTotal: Decimal = 0
    /// Unidades que se llevaron; `precioTotal` es el precio por unidad × unidades.
    var cantidad: Decimal = 1
    var tienda: String?
    /// Se marca cuando el producto se acaba.
    var fechaAgotado: Date?
    /// Identificador en la nube; se asigna la primera vez que se sincroniza.
    var uid: UUID?
    /// `Oferta` en JSON (ver CadivaCore); nil si se compró a precio normal.
    var ofertaJSON: String?

    init(
        producto: Producto?, fecha: Date, precioTotal: Decimal, cantidad: Decimal,
        tienda: String? = nil, fechaAgotado: Date? = nil
    ) {
        self.producto = producto
        self.fecha = fecha
        self.precioTotal = precioTotal
        self.cantidad = cantidad
        self.tienda = tienda
        self.fechaAgotado = fechaAgotado
    }
}
