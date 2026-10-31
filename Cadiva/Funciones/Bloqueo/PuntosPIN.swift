import CadivaCore
import SwiftData
import SwiftUI
import UIKit

/// Cuatro puntos que se llenan con cada dígito. Tiemblan en rojo si el PIN es incorrecto.
struct PuntosPIN: View {
    enum Estado: Equatable { case normal, error, exito }

    let llenos: Int
    var estado: Estado = .normal
    var intentoFallido = 0

    var body: some View {
        HStack(spacing: 22) {
            ForEach(0..<Seguridad.largoPIN, id: \.self) { indice in
                let lleno = indice < llenos
                Circle()
                    .fill(lleno ? color : Color.clear)
                    .overlay(Circle().stroke(lleno ? color : Color.cadiva.textSecondary.opacity(0.5), lineWidth: 1.5))
                    .frame(width: 15, height: 15)
                    .scaleEffect(lleno ? 1.15 : 1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.5), value: lleno)
            }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: intentoFallido) { vista, desplazamiento in
            vista.offset(x: desplazamiento)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(-14, duration: 0.06)
                SpringKeyframe(12, duration: 0.065)
                SpringKeyframe(-9, duration: 0.07)
                SpringKeyframe(6, duration: 0.075)
                SpringKeyframe(-3, duration: 0.08)
                SpringKeyframe(0, duration: 0.085)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(llenos) de \(Seguridad.largoPIN) dígitos")
    }

    private var color: Color {
        switch estado {
        case .normal: Color.cadiva.brand
        case .error: Color.cadiva.priceUp
        case .exito: Color.cadiva.priceDown
        }
    }
}
