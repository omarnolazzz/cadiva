import SwiftUI

/// Encima de todo mientras se inicia sesión: desenfoca la pantalla y muestra la órbita.
struct CargandoSesionView: View {
    var titulo = "Iniciando sesión"
    var detalle = "Preparando tus productos"

    @State private var visible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.cadiva.background.opacity(0.35))
                .ignoresSafeArea()
            VStack(spacing: 18) {
                OrbitaCarga()
                    .scaleEffect(visible ? 1 : 0.6)
                VStack(spacing: 4) {
                    Text(titulo)
                        .font(.headline)
                        .foregroundStyle(Color.cadiva.textPrimary)
                    Text(detalle)
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { visible = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titulo). \(detalle)")
    }
}
