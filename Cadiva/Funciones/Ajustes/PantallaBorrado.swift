import CadivaCore
import SwiftData
import SwiftUI
import UIKit

enum EstadoBorrado: Equatable {
    case borrando
    case listo(productos: Int, compras: Int)
}

/// Tarjeta sobre el contenido mientras se borran los datos y al terminar.
struct PantallaBorrado: View {
    let estado: EstadoBorrado

    @State private var pulso = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 112, height: 112)
                        .scaleEffect(pulso && estado == .borrando ? 1.12 : 1)
                    Image(systemName: estado == .borrando ? "trash.fill" : "checkmark.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(color)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: estado)
                }
                VStack(spacing: 6) {
                    Text(titulo)
                        .font(.title3.bold())
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .contentTransition(.opacity)
                    Text(detalle)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                if estado == .borrando {
                    ProgressView()
                        .tint(color)
                        .transition(.opacity)
                }
            }
            .padding(32)
            .frame(maxWidth: 320)
            .background(Color.cadiva.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
        .sensoryFeedback(trigger: estado) { _, nuevo in
            nuevo == .borrando ? .impact(weight: .medium) : .success
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulso = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var color: Color { estado == .borrando ? Color.cadiva.priceUp : Color.cadiva.priceDown }

    private var titulo: String { estado == .borrando ? "Eliminando tus datos…" : "Datos eliminados" }

    private var detalle: String {
        switch estado {
        case .borrando:
            return "Esto toma solo un momento."
        case let .listo(productos, compras):
            let p = productos == 1 ? "1 producto" : "\(productos) productos"
            let c = compras == 1 ? "1 compra" : "\(compras) compras"
            return "Se borraron \(p) y \(c) correctamente."
        }
    }
}
