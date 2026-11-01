import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct FilaHistorial: View {
    let compra: Compra
    let moneda: String
    let cambio: Decimal?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formato.fechaLarga(compra.fecha))
                    .foregroundStyle(Color.cadiva.textPrimary)
                Label {
                    Text("\(compra.tienda ?? "Sin tienda") · \(Formato.unidades(compra.unidades))")
                } icon: {
                    Image(systemName: "storefront")
                }
                .labelStyle(EtiquetaCompacta())
                .font(.subheadline)
                .foregroundStyle(Color.cadiva.textSecondary)
                if let oferta = compra.oferta {
                    ChipOferta(oferta: oferta, moneda: moneda)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                if let normal = compra.oferta?.precioNormal {
                    Text(Formato.moneda(normal, moneda))
                        .font(.caption)
                        .strikethrough()
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textSecondary)
                        .accessibilityLabel("Precio normal \(Formato.moneda(normal, moneda))")
                }
                Text(Formato.moneda(compra.precioUnitario, moneda))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cadiva.textPrimary)
                IndicadorCambio(cambio: cambio)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Editar compra")
    }
}
