import Foundation
import SwiftData

@Model
final class Producto {
    var nombre: String = ""
    var categoriaRaw: String = Categoria.otro.rawValue
    var simbolo: String = "basket.fill"
    var notas: String?
    var archivado: Bool = false
    var creado: Date = Date.now
    /// Identificador en la nube; se asigna la primera vez que se sincroniza.
    var uid: UUID?
    /// Foto del producto en JPEG; SwiftData la guarda fuera de la base.
    @Attribute(.externalStorage) var foto: Data?

    @Relationship(deleteRule: .cascade, inverse: \Compra.producto)
    var compras: [Compra] = []

    init(nombre: String, categoria: Categoria, simbolo: String, notas: String? = nil) {
        self.nombre = nombre
        self.categoriaRaw = categoria.rawValue
        self.simbolo = simbolo
        self.notas = notas
    }

    var categoria: Categoria {
        get { Categoria(rawValue: categoriaRaw) ?? .otro }
        set { categoriaRaw = newValue.rawValue }
    }
}
