import SwiftUI
import UIKit

/// Foto del producto o, si no tiene, su símbolo sobre fondo `tint`.
struct MiniaturaProducto: View {
    let producto: Producto
    var tamano: CGFloat = 48

    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    private var lado: CGFloat { tamano * min(escala, 1.6) }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: lado * 0.26, style: .continuous)
        Group {
            if let imagen = CacheMiniaturas.imagen(de: producto, lado: lado) {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: producto.simbolo)
                    .font(.system(size: lado * 0.42, weight: .semibold))
                    .foregroundStyle(producto.archivado ? Color.cadiva.textSecondary : Color.cadiva.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cadiva.tint)
            }
        }
        .frame(width: lado, height: lado)
        .clipShape(forma)
        .accessibilityHidden(true)
    }
}

/// Las fotos se reducen una vez y se guardan en memoria para que las listas vayan fluidas.
@MainActor

enum CacheMiniaturas {
    private static let cache = NSCache<NSString, UIImage>()

    static func imagen(de producto: Producto, lado: CGFloat) -> UIImage? {
        guard let datos = producto.foto else { return nil }
        let pixeles = lado * 3
        let clave = "\(producto.persistentModelID.hashValue)-\(datos.count)-\(Int(pixeles))" as NSString
        if let guardada = cache.object(forKey: clave) { return guardada }
        guard let original = UIImage(data: datos) else { return nil }
        let reducida = original.preparingThumbnail(of: CGSize(width: pixeles, height: pixeles)) ?? original
        cache.setObject(reducida, forKey: clave)
        return reducida
    }
}
