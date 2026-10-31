import CadivaCore
import SwiftData
import SwiftUI
import UIKit

/// Fondo de las pantallas de PIN: la imagen de bienvenida muy desenfocada.
struct FondoBloqueo: View {
    var body: some View {
        ZStack {
            Color.cadiva.background
            Image("BienvenidaFoto")
                .resizable()
                .scaledToFill()
                .blur(radius: 40)
                .opacity(0.55)
            Rectangle().fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
