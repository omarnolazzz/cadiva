import CadivaCore
import SwiftUI

/// Miniatura, nombre, última tienda y fecha; a la derecha el último precio por unidad.
/// No calcula nada: muestra lo que ya trae `ResumenFila`.
struct FilaResumenProducto: View {
    let resumen: ResumenFila

    @Environment(\.dynamicTypeSize) private var tamanoTexto

    var body: some View {
        // Con texto de accesibilidad todo va en columna para que nada se corte.
        let disposicion = tamanoTexto.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))
        disposicion {
            MiniaturaProducto(producto: resumen.producto, tamano: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(resumen.nombre)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textPrimary)
                    .lineLimit(tamanoTexto.isAccessibilitySize ? nil : 3)
                if let linea = resumen.lineaCompra {
                    Label {
                        Text(linea)
                    } icon: {
                        Image(systemName: "storefront")
                    }
                    .labelStyle(EtiquetaCompacta())
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    if let estimacion = resumen.estimacion, !estimacion.terminada {
                        IndicadorDuracion(estimacion: estimacion)
                    }
                } else {
                    Text("Sin compras todavía")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
            }
            if !tamanoTexto.isAccessibilitySize { Spacer(minLength: 4) }
            if let precio = resumen.precioTexto {
                VStack(alignment: tamanoTexto.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                    Text(precio)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textPrimary)
                    HStack(spacing: 4) {
                        if resumen.conOferta {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.cadiva.priceDown)
                                .accessibilityLabel("Con oferta")
                        }
                        IndicadorCambio(cambio: resumen.cambio)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// "≈ 12 días" con un reloj de arena; en naranja si queda poco y en rojo si ya debió acabarse.
struct IndicadorDuracion: View {
    let estimacion: EstimacionDuracion

    var body: some View {
        Label {
            Text(texto)
        } icon: {
            Image(systemName: "hourglass")
        }
        .labelStyle(EtiquetaCompacta())
        .font(.footnote.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(color)
    }

    private var texto: String {
        switch estimacion.diasRestantes {
        case ..<1: "Ya debería acabarse"
        case 1: "Queda ≈ 1 día"
        default: "Quedan ≈ \(estimacion.diasRestantes) días"
        }
    }

    private var color: Color {
        if estimacion.diasRestantes < 1 { return Color.cadiva.priceUp }
        return estimacion.progresoRestante <= 0.25 ? Color.cadiva.runningLow : Color.cadiva.textSecondary
    }
}
