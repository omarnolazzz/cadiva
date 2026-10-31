import CadivaCore
import SwiftUI

/// Cuánto dura una unidad y cuánto le queda a la compra actual, con una barra que se vacía.
struct TarjetaDuracion: View {
    let estimacion: EstimacionDuracion?

    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Duración aproximada", systemImage: "hourglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                if let estimacion {
                    Text(estimacion.muestras == 1 ? "con 1 dato" : "con \(estimacion.muestras) datos")
                        .font(.caption)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
            }

            if let estimacion {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Formato.duracion(estimacion.diasPorUnidad))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textPrimary)
                    Text("por unidad")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }

                Capsule()
                    .fill(Color.cadiva.tint)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .scaleEffect(x: visible ? max(estimacion.progresoRestante, 0.02) : 0, anchor: .leading)
                    }
                    .clipShape(Capsule())
                    .accessibilityHidden(true)

                Text(estado(estimacion))
                    .font(.subheadline)
                    .foregroundStyle(estimacion.diasRestantes <= 0 && !estimacion.terminada ? Color.cadiva.priceUp : Color.cadiva.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Registra la siguiente compra, o marca cuándo se acabó esta, y Cadiva calculará cuánto te dura.")
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cadiva.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear {
            if reducirMovimiento {
                visible = true
            } else {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) { visible = true }
            }
        }
    }

    private var color: Color {
        guard let estimacion, !estimacion.terminada else { return Color.cadiva.brand }
        if estimacion.diasRestantes <= 0 { return Color.cadiva.priceUp }
        return estimacion.progresoRestante <= 0.25 ? Color.cadiva.runningLow : Color.cadiva.brand
    }

    private func estado(_ estimacion: EstimacionDuracion) -> String {
        if estimacion.terminada { return "La última compra ya se acabó." }
        let fin = Formato.fechaCorta(estimacion.fechaFin)
        switch estimacion.diasRestantes {
        case ..<0: return "Ya debería haberse acabado (≈ \(fin))."
        case 0: return "Se acabaría hoy."
        // Sin punto final: la abreviatura del mes ya lo trae ("25 nov.").
        case 1: return "Te queda ≈ 1 día · hasta el \(fin)"
        default: return "Te quedan ≈ \(estimacion.diasRestantes) días · hasta el \(fin)"
        }
    }
}

#if DEBUG
#Preview("Duración") {
    VStack(spacing: 16) {
        TarjetaDuracion(estimacion: EstimacionDuracion(
            diasPorUnidad: 28.3, muestras: 3, diasTotales: 28, diasRestantes: 25,
            fechaFin: .now.addingTimeInterval(25 * 86_400), progresoRestante: 0.89, terminada: false
        ))
        TarjetaDuracion(estimacion: nil)
    }
    .padding()
    .background(Color.cadiva.background)
}
#endif
