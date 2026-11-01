import SwiftUI

/// Fondo de las pantallas de PIN: la imagen de bienvenida muy desenfocada.
/// La imagen va como capa sobre un color: así llena la pantalla sin ensancharla
/// (con "llenar" sin marco, la imagen hacía más ancha toda la pantalla y los botones se salían).
struct FondoBloqueo: View {
    var body: some View {
        Color.cadiva.background
            .overlay {
                Image("BienvenidaFoto")
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .opacity(0.55)
            }
            .overlay { Rectangle().fill(.ultraThinMaterial) }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
