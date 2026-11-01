import CadivaCore
import Foundation
import SwiftData

extension Producto {
    var fila: ProductoNube {
        ProductoNube(
            id: uid ?? UUID(), nombre: nombre, categoria: categoriaRaw, simbolo: simbolo,
            notas: notas, archivado: archivado, creado: creado,
            foto: fotoHuella,
            seguimiento: seguimientoRaw
        )
    }

    /// `nueva` es la foto descargada; si es nil y la huella no coincide, la foto ya no existe.
    func aplicar(_ fila: ProductoNube, foto nueva: Data?) {
        if fila.foto == nil {
            asignarFoto(nil)
        } else if let nueva {
            asignarFoto(nueva)
        } else if fotoHuella != fila.foto {
            asignarFoto(nil)
        }
        nombre = fila.nombre
        categoriaRaw = fila.categoria
        simbolo = fila.simbolo
        notas = fila.notas
        archivado = fila.archivado
        seguimientoRaw = fila.seguimiento
        creado = fila.creado
    }
}

extension Compra {
    var fila: CompraNube {
        CompraNube(
            id: uid ?? UUID(), productoId: producto?.uid, fecha: fecha, precioTotal: precioTotal,
            cantidad: cantidad, tienda: tienda, fechaAgotado: fechaAgotado,
            oferta: ofertaJSON
        )
    }

    func aplicar(_ fila: CompraNube, producto: Producto?) {
        self.producto = producto
        fecha = fila.fecha
        precioTotal = fila.precioTotal
        cantidad = fila.cantidad
        tienda = fila.tienda
        fechaAgotado = fila.fechaAgotado
        ofertaJSON = fila.oferta
    }
}
