import SwiftUI
import UIKit

/// Estado vacío con el símbolo de Cadiva.
struct EstadoVacio: View {
    let titulo: String
    let mensaje: String
    var tituloAccion: String?
    var simboloAccion: String?
    var accion: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 72
    @State private var visible = false

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 16) {
                Image("CadivaSimbolo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: lado, height: lado)
                    .scaleEffect(visible ? 1 : 0.6)
                    .opacity(visible ? 1 : 0)
                    .accessibilityHidden(true)
                Text(titulo)
                    .font(.title2.bold())
                    .foregroundStyle(Color.cadiva.textPrimary)
            }
        } description: {
            Text(mensaje)
                .foregroundStyle(Color.cadiva.textSecondary)
        } actions: {
            if let tituloAccion, let accion {
                Button(action: accion) {
                    Label(tituloAccion, systemImage: simboloAccion ?? "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cadiva.brandDeep)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { visible = true }
        }
    }
}
