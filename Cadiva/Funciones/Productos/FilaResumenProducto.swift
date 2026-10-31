import CadivaCore
import SwiftData
import SwiftUI

/// Miniatura, nombre, última tienda y fecha; a la derecha el último precio por unidad.
struct FilaResumenProducto: View {
    let producto: Producto
    let moneda: String

    @Environment(\.dynamicTypeSize) private var tamanoTexto

    var body: some View {
        let ultima = producto.ultimaCompra
        let cambio = producto.resumen().cambioPrecio
        // Con texto de accesibilidad todo va en columna para que nada se corte.
        let disposicion = tamanoTexto.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))
        disposicion {
            MiniaturaProducto(producto: producto, tamano: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(producto.nombre)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textPrimary)
                    .lineLimit(tamanoTexto.isAccessibilitySize ? nil : 3)
                if let ultima {
                    Label {
                        Text("\(ultima.tienda ?? "Sin tienda") · \(ultima.fecha.formatted(.relative(presentation: .named).locale(.cadiva)))")
                    } icon: {
                        Image(systemName: "storefront")
                    }
                    .labelStyle(EtiquetaCompacta())
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
                } else {
                    Text("Sin compras todavía")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
            }
            if !tamanoTexto.isAccessibilitySize { Spacer(minLength: 4) }
            if let precio = ultima?.precioUnitario {
                VStack(alignment: tamanoTexto.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                    Text(Formato.moneda(precio, moneda))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .contentTransition(.numericText(value: precio.double))
                    IndicadorCambio(cambio: cambio)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
