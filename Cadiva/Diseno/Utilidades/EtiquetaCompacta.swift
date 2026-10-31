import CadivaCore
import SwiftData
import SwiftUI

/// Ícono pequeño pegado al texto.
struct EtiquetaCompacta: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
