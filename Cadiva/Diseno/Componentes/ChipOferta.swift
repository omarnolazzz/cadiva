import CadivaCore
import SwiftUI

/// Etiqueta verde con la oferta: "2 por S/ 4.00".
struct ChipOferta: View {
    let oferta: Oferta
    let moneda: String

    var body: some View {
        Label(Formato.oferta(oferta, moneda), systemImage: "tag.fill")
            .labelStyle(EtiquetaCompacta())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.cadiva.priceDown)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.cadiva.priceDown.opacity(0.12), in: Capsule())
            .accessibilityLabel("Oferta: \(Formato.oferta(oferta, moneda))")
    }
}
