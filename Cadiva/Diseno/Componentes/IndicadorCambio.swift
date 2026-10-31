import SwiftUI
import UIKit

/// Flecha con el % de cambio del precio unitario.
struct IndicadorCambio: View {
    let cambio: Decimal?

    var body: some View {
        if let cambio {
            let porcentaje = Formato.porcentaje(cambio.magnitude)
            HStack(spacing: 2) {
                Image(systemName: cambio > 0 ? "arrow.up" : cambio < 0 ? "arrow.down" : "equal")
                    .imageScale(.small)
                Text(porcentaje)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(cambio > 0 ? Color.cadiva.priceUp : cambio < 0 ? Color.cadiva.priceDown : Color.cadiva.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (cambio > 0 ? Color.cadiva.priceUp : cambio < 0 ? Color.cadiva.priceDown : Color.cadiva.textSecondary).opacity(0.12),
                in: Capsule()
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cambio > 0 ? "Subió \(porcentaje)" : cambio < 0 ? "Bajó \(porcentaje)" : "Mismo precio")
        }
    }
}
