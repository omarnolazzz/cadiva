import SwiftUI
import UIKit

/// Etiqueta con fondo `tint`.
struct Chip: View {
    let texto: String
    var simbolo: String?

    var body: some View {
        HStack(spacing: 4) {
            if let simbolo {
                Image(systemName: simbolo)
                    .accessibilityHidden(true)
            }
            Text(texto)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.cadiva.brand)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.cadiva.tint, in: Capsule())
    }
}
