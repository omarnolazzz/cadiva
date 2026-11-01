import SwiftUI
import UIKit

/// Foto del producto o, si no tiene, su símbolo sobre fondo `tint`.
/// La foto se lee del disco y se reduce una sola vez, fuera del hilo principal; después sale de la caché.
struct MiniaturaProducto: View {
    let producto: Producto
    var tamano: CGFloat = 48

    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1
    @State private var cargada: UIImage?
    @Environment(\.displayScale) private var escalaPantalla

    private var lado: CGFloat { tamano * min(escala, 1.6) }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: lado * 0.26, style: .continuous)
        let clave = CacheMiniaturas.clave(de: producto, lado: lado)
        let imagen = clave.flatMap(CacheMiniaturas.guardada) ?? (clave == nil ? nil : cargada)
        ZStack {
            if let imagen {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
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
        .task(id: clave) {
            guard let clave, CacheMiniaturas.guardada(clave) == nil, let datos = producto.foto else { return }
            let pixeles = lado * escalaPantalla
            let reducida = await CacheMiniaturas.reducir(datos, pixeles: pixeles)
            guard let reducida, !Task.isCancelled else { return }
            CacheMiniaturas.guardar(reducida, clave)
            withAnimation(.easeOut(duration: 0.2)) { cargada = reducida }
        }
    }
}

/// Miniaturas ya reducidas, en memoria. La clave usa la huella de la foto: no hace falta leerla para saber si cambió.
@MainActor
enum CacheMiniaturas {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    /// nil si el producto no tiene foto.
    static func clave(de producto: Producto, lado: CGFloat) -> NSString? {
        guard let huella = producto.fotoHuella else { return nil }
        return "\(huella)-\(Int(lado))" as NSString
    }

    static func guardada(_ clave: NSString) -> UIImage? { cache.object(forKey: clave) }

    static func guardar(_ imagen: UIImage, _ clave: NSString) { cache.setObject(imagen, forKey: clave) }

    /// Decodifica y reduce en segundo plano.
    nonisolated static func reducir(_ datos: Data, pixeles: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let original = UIImage(data: datos) else { return nil }
            return await original.byPreparingThumbnail(ofSize: CGSize(width: pixeles, height: pixeles)) ?? original
        }.value
    }
}
