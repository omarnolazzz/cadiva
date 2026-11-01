import CadivaCore
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
    /// Huella corta de `foto`. Sirve para saber si hay foto o si cambió sin leerla del disco.
    var fotoHuella: String?
    /// `Seguimiento` elegido a mano; nil = se sugiere solo según el nombre y la categoría.
    var seguimientoRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \Compra.producto)
    var compras: [Compra] = []

    init(nombre: String, categoria: Categoria, simbolo: String, notas: String? = nil) {
        self.nombre = nombre
        self.categoriaRaw = categoria.rawValue
        self.simbolo = simbolo
        self.notas = notas
    }

    /// Única forma de cambiar la foto: mantiene la huella al día.
    func asignarFoto(_ datos: Data?) {
        let huella = datos.map(FormatoNube.huellaFoto)
        // Sin huella puede quedar una foto de antes de que existiera la huella: hay que mirarla.
        guard huella != fotoHuella || (huella == nil && foto != nil) else { return }
        foto = datos
        fotoHuella = huella
    }

    var categoria: Categoria {
        get { Categoria(rawValue: categoriaRaw) ?? .otro }
        set { categoriaRaw = newValue.rawValue }
    }
}
