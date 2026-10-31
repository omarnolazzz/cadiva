import CadivaCore
import SwiftUI

/// El símbolo se dibuja solo; luego aparecen el nombre y el lema.
struct ArranqueView: View {
    @State private var inicio = Date.now
    @State private var mostrarNombre = false
    @State private var mostrarLema = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 104

    var body: some View {
        ZStack {
            Color.cadiva.background.ignoresSafeArea()
            VStack(spacing: 18) {
                SimboloAnimado(lado: lado, inicio: inicio)
                VStack(spacing: 8) {
                    Image("CadivaLogotipo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: lado * 0.34)
                        .opacity(mostrarNombre ? 1 : 0)
                        .offset(y: mostrarNombre ? 0 : 10)
                        .blur(radius: mostrarNombre ? 0 : 6)
                    Text("Tus precios, bajo control")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                        .opacity(mostrarLema ? 1 : 0)
                        .offset(y: mostrarLema ? 0 : 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cadiva. Tus precios, bajo control")
        }
        .task {
            inicio = .now
            let nombre = reducirMovimiento ? 0 : DibujoSimbolo.aparecer + DibujoSimbolo.trazar
            try? await Task.sleep(for: .seconds(nombre))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { mostrarNombre = true }
            try? await Task.sleep(for: .milliseconds(reducirMovimiento ? 0 : 280))
            withAnimation(.easeOut(duration: 0.5)) { mostrarLema = true }
        }
    }
}
