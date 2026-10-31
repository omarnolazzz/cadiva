import SwiftUI

/// Transición con desenfoque: lo que entra pasa de borroso y algo más grande a nítido.
struct Desenfoque: ViewModifier {
    let radio: CGFloat
    let escala: CGFloat
    let opacidad: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radio)
            .scaleEffect(escala)
            .opacity(opacidad)
    }
}

extension AnyTransition {
    static var desenfoque: AnyTransition {
        .modifier(
            active: Desenfoque(radio: 24, escala: 1.06, opacidad: 0),
            identity: Desenfoque(radio: 0, escala: 1, opacidad: 1)
        )
    }
}
