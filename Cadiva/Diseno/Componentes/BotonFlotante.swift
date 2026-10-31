import SwiftUI
import UIKit

/// Botón principal flotante sobre el contenido. En iOS 26 es de Liquid Glass.
struct BotonFlotante: View {
    let titulo: String
    let simbolo: String
    let accion: () -> Void

    @State private var toques = 0

    var body: some View {
        Button {
            toques += 1
            accion()
        } label: {
            Label(titulo, systemImage: simbolo)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .symbolEffect(.bounce, value: toques)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
        }
        .modifier(EstiloFlotante())
        // Flota sobre el contenido: en tamaños enormes taparía demasiado.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.impact(weight: .light), trigger: toques)
    }
}

private struct EstiloFlotante: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(Color.cadiva.brandDeep).interactive(), in: .capsule)
                .buttonStyle(.plain)
        } else {
            content
                .foregroundStyle(.white)
                .background(Color.cadiva.brandDeep, in: Capsule())
                .buttonStyle(.plain)
        }
    }
}
