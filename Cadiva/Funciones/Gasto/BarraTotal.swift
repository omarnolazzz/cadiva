import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct BarraTotal: View {
    let nombre: String
    let simbolo: String
    let total: String
    let fraccion: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Label { Text(nombre) } icon: { Image(systemName: simbolo).foregroundStyle(Color.cadiva.brand) }
                    Spacer()
                    Text(total).monospacedDigit()
                }
                VStack(alignment: .leading) {
                    Label { Text(nombre) } icon: { Image(systemName: simbolo).foregroundStyle(Color.cadiva.brand) }
                    Text(total).monospacedDigit()
                }
            }
            .foregroundStyle(Color.cadiva.textPrimary)
            ProgressView(value: min(max(fraccion, 0), 1))
                .tint(Color.cadiva.brand)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
