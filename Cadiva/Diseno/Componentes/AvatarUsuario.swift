import AuthenticationServices
import CadivaCore
import SwiftUI

/// Foto de perfil de la cuenta (la de Google) en un círculo. Mientras carga o si no hay, las iniciales.
struct AvatarUsuario: View {
    let usuario: Usuario
    var lado: CGFloat = 44

    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    private var tamano: CGFloat { lado * min(escala, 1.5) }

    var body: some View {
        ZStack {
            iniciales
            if let foto = usuario.foto {
                AsyncImage(url: foto, transaction: Transaction(animation: .easeOut(duration: 0.35))) { fase in
                    if let imagen = fase.image {
                        imagen
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.cadiva.surface, lineWidth: 2))
        .accessibilityHidden(true)
    }

    private var iniciales: some View {
        let base = usuario.nombre ?? usuario.email ?? "?"
        let letras = String(base.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
        return Text(letras)
            .font(.system(size: tamano * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.cadiva.brand)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cadiva.tint)
    }
}
