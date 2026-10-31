import PhotosUI
import SwiftUI
import UIKit

enum FotoProducto {
    /// Lado mayor de 1024 px en JPEG: buena calidad y poco peso para sincronizar.
    static func comprimir(_ imagen: UIImage) -> Data? {
        let maximo: CGFloat = 1024
        let escala = min(1, maximo / max(imagen.size.width, imagen.size.height))
        let tamano = CGSize(width: (imagen.size.width * escala).rounded(), height: (imagen.size.height * escala).rounded())
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let reducida = UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }
        return reducida.jpegData(compressionQuality: 0.75)
    }
}
