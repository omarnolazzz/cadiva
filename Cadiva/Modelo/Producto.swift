import Foundation
import SwiftData

@Model
final class Producto {
    var nombre: String = ""
    var categoriaRaw: String = Categoria.otro.rawValue
    var unidadRaw: String = Unidad.piezas.rawValue
    var simbolo: String = "basket.fill"
    var notas: String?
    var archivado: Bool = false
    /// Estimación inicial que se usa mientras no haya ninguna duración real.
    var duracionEstimadaDias: Int?
    var creado: Date = Date.now
    /// Identificador en la nube; se asigna la primera vez que se sincroniza.
    var uid: UUID?
    /// Foto del producto en JPEG; SwiftData la guarda fuera de la base.
    @Attribute(.externalStorage) var foto: Data?

    @Relationship(deleteRule: .cascade, inverse: \Compra.producto)
    var compras: [Compra] = []

    init(
        nombre: String, categoria: Categoria, unidad: Unidad, simbolo: String,
        notas: String? = nil, duracionEstimadaDias: Int? = nil
    ) {
        self.nombre = nombre
        self.categoriaRaw = categoria.rawValue
        self.unidadRaw = unidad.rawValue
        self.simbolo = simbolo
        self.notas = notas
        self.duracionEstimadaDias = duracionEstimadaDias
    }

    var categoria: Categoria {
        get { Categoria(rawValue: categoriaRaw) ?? .otro }
        set { categoriaRaw = newValue.rawValue }
    }

    var unidad: Unidad {
        get { Unidad(rawValue: unidadRaw) ?? .piezas }
        set { unidadRaw = newValue.rawValue }
    }
}
