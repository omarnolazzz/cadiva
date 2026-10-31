import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct CuadriculaDatos: View {
    let compras: [Compra]
    let resumen: ResumenConsumo
    let moneda: String

    @ScaledMetric(relativeTo: .body) private var anchoMinimo: CGFloat = 150

    var body: some View {
        let precios = compras.compactMap(\.precioUnitario)
        let masBarata = compras.filter { $0.precioUnitario != nil }.min { $0.precioUnitario! < $1.precioUnitario! }
        let unidades = compras.reduce(0) { $0 + $1.unidades }
        let gastado = compras.reduce(Decimal.zero) { $0 + $1.precioTotal }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: anchoMinimo), spacing: 10)], spacing: 10) {
            Tarjeta(titulo: "Más barato", valor: Formato.moneda(masBarata?.precioUnitario, moneda), detalle: masBarata?.tienda, simbolo: "arrow.down.circle.fill", color: Color.cadiva.priceDown)
            Tarjeta(titulo: "Más caro", valor: Formato.moneda(precios.max(), moneda), detalle: nil, simbolo: "arrow.up.circle.fill", color: Color.cadiva.priceUp)
            Tarjeta(titulo: "Promedio", valor: Formato.moneda(resumen.precioUnitarioPromedio, moneda), detalle: "por unidad", simbolo: "equal.circle.fill", color: Color.cadiva.brand)
            Tarjeta(titulo: "Gastado", valor: Formato.moneda(gastado, moneda), detalle: "\(Formato.unidades(unidades)) en \(compras.count == 1 ? "1 compra" : "\(compras.count) compras")", simbolo: "creditcard.fill", color: Color.cadiva.brand)
        }
    }
}

private struct Tarjeta: View {
    let titulo: String
    let valor: String
    let detalle: String?
    let simbolo: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(titulo, systemImage: simbolo)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(valor)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.cadiva.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let detalle {
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cadiva.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
