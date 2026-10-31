import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct ResumenTienda: Identifiable {
    let id: String
    let nombre: String
    let ultimoPrecio: Decimal
    let precioMinimo: Decimal
    let compras: Int
    let ultimaFecha: Date

    static func calcular(_ compras: [Compra]) -> [ResumenTienda] {
        let agrupadas = Dictionary(grouping: compras.filter { $0.precioUnitario != nil }) {
            ($0.tienda ?? "Sin tienda").lowercased(with: .cadiva)
        }
        return agrupadas.compactMap { clave, compras -> ResumenTienda? in
            let ordenadas = compras.sorted { $0.fecha < $1.fecha }
            guard let ultima = ordenadas.last, let precio = ultima.precioUnitario else { return nil }
            return ResumenTienda(
                id: clave,
                nombre: ultima.tienda ?? "Sin tienda",
                ultimoPrecio: precio,
                precioMinimo: ordenadas.compactMap(\.precioUnitario).min() ?? precio,
                compras: ordenadas.count,
                ultimaFecha: ultima.fecha
            )
        }
        .sorted { $0.ultimaFecha > $1.ultimaFecha }
    }
}

struct FilaTienda: View {
    let tienda: ResumenTienda
    let moneda: String
    let esLaMasBarata: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .foregroundStyle(esLaMasBarata ? Color.cadiva.priceDown : Color.cadiva.brand)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tienda.nombre)
                        .foregroundStyle(Color.cadiva.textPrimary)
                    if esLaMasBarata {
                        Text("Más barata")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.cadiva.priceDown)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cadiva.priceDown.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(tienda.compras == 1 ? "1 compra" : "\(tienda.compras) compras") · \(Formato.fechaCorta(tienda.ultimaFecha))")
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
            }
            Spacer(minLength: 4)
            Text(Formato.moneda(tienda.ultimoPrecio, moneda))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.cadiva.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
