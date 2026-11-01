import CadivaCore
import SwiftData
import SwiftUI
import UIKit

/// Teclado numérico de botones redondos. En iOS 26 los botones son de Liquid Glass.
struct TecladoPIN: View {
    /// Símbolo de la tecla de abajo a la izquierda (Face ID), si hay.
    var simboloExtra: String?
    var etiquetaExtra = ""
    let alPulsar: (String) -> Void
    let alBorrar: () -> Void
    var alExtra: () -> Void = {}

    @ScaledMetric(relativeTo: .title) private var lado: CGFloat = 76

    private let filas = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(filas, id: \.self) { fila in
                HStack(spacing: 26) {
                    ForEach(fila, id: \.self) { digito in
                        tecla { Text(digito).font(.system(size: lado * 0.4, weight: .medium, design: .rounded)) } accion: { alPulsar(digito) }
                            .accessibilityLabel(digito)
                    }
                }
            }
            HStack(spacing: 26) {
                if let simboloExtra {
                    // Face ID: tecla de vidrio con el ícono en el color de la marca.
                    tecla(conFondo: true) { Image(systemName: simboloExtra).font(.system(size: lado * 0.36)).foregroundStyle(Color.cadiva.brand) } accion: { alExtra() }
                        .accessibilityLabel(etiquetaExtra)
                } else {
                    Color.clear.frame(width: lado, height: lado)
                }
                tecla { Text("0").font(.system(size: lado * 0.4, weight: .medium, design: .rounded)) } accion: { alPulsar("0") }
                    .accessibilityLabel("0")
                tecla(conFondo: false) { Image(systemName: "delete.left").font(.system(size: lado * 0.3)) } accion: { alBorrar() }
                    .accessibilityLabel("Borrar")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func tecla<Contenido: View>(conFondo: Bool = true, @ViewBuilder _ contenido: () -> Contenido, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            contenido()
                .foregroundStyle(Color.cadiva.textPrimary)
                .frame(width: lado, height: lado)
                .contentShape(Circle())
        }
        .buttonStyle(TeclaEstilo(conFondo: conFondo))
    }
}

private struct TeclaEstilo: ButtonStyle {
    let conFondo: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if conFondo {
                    if #available(iOS 26.0, *) {
                        Circle().fill(.clear).glassEffect(.regular.interactive(), in: .circle)
                    } else {
                        Circle().fill(Color.cadiva.surface.opacity(0.85))
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed && !conFondo ? 0.5 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed) { _, pulsado in pulsado }
    }
}
