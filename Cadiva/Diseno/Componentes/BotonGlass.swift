import SwiftUI

/// Botón de vidrio con bordes redondeados. En iOS 26 es Liquid Glass interactivo;
/// antes, un material translúcido con un borde de luz.
struct BotonGlass: View {
    let titulo: String
    let simbolo: String
    /// Mientras es true el ícono late (por ejemplo, esperando a Face ID).
    var activo = false
    let accion: () -> Void

    @State private var toques = 0

    var body: some View {
        Button {
            toques += 1
            accion()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: simbolo)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.cadiva.brand)
                    .symbolEffect(.bounce, value: toques)
                    .symbolEffect(.pulse, isActive: activo)
                Text(titulo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 20)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .modifier(EstiloGlass())
        .sensoryFeedback(.impact(weight: .light), trigger: toques)
    }
}

private struct EstiloGlass: ViewModifier {
    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Color.cadiva.brand.opacity(0.12)).interactive(), in: forma)
        } else {
            vidrioPropio(content, forma)
        }
    }

    /// Antes de iOS 26: material, tinte y un borde de luz.
    private func vidrioPropio(_ content: Content, _ forma: RoundedRectangle) -> some View {
        content
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: forma)
            .background(Color.cadiva.brand.opacity(0.08), in: forma)
            .overlay(
                forma.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .clipShape(forma)
    }
}

#if DEBUG
#Preview("Botón glass") {
    ZStack {
        FondoBloqueo()
        BotonGlass(titulo: "Desbloquear con Face ID", simbolo: "faceid", activo: true) {}
            .padding(32)
    }
}
#endif
