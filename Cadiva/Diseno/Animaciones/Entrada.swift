import SwiftUI
import UIKit

extension View {
    /// Entra con un leve desplazamiento hacia arriba y fundido. Respeta "Reducir movimiento".
    func entrada(retraso: Double = 0) -> some View {
        modifier(Entrada(retraso: retraso))
    }
}

private struct Entrada: ViewModifier {
    let retraso: Double

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reducirMovimiento ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(retraso)) { visible = true }
            }
    }
}
