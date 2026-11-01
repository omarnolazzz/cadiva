import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct GraficaPrecio: View {
    let compras: [Compra]
    let moneda: String

    @State private var progreso: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private struct Punto: Identifiable {
        let id: Int
        let fecha: Date
        let valor: Double
        let texto: String
        let tienda: String
        let conOferta: Bool
    }

    private var puntos: [Punto] {
        compras.enumerated().compactMap { indice, compra in
            compra.precioUnitario.map {
                Punto(id: indice, fecha: compra.fecha, valor: $0.double, texto: Formato.moneda($0, moneda), tienda: compra.tienda ?? "", conOferta: compra.ofertaJSON != nil)
            }
        }
    }

    var body: some View {
        let puntos = puntos
        let ultimo = puntos.last?.id
        let minimo = puntos.map(\.valor).min() ?? 0
        Chart(puntos) { punto in
            let valor = minimo + (punto.valor - minimo) * progreso
            AreaMark(x: .value("Fecha", punto.fecha), y: .value("Precio", valor))
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.cadiva.brand.opacity(0.12))
            LineMark(x: .value("Fecha", punto.fecha), y: .value("Precio", valor))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(Color.cadiva.brand)
            PointMark(x: .value("Fecha", punto.fecha), y: .value("Precio", valor))
                .symbolSize(punto.id == ultimo ? 110 : 36)
                .foregroundStyle(punto.conOferta ? Color.cadiva.priceDown : punto.id == ultimo ? Color.cadiva.brandDeep : Color.cadiva.brand)
                .annotation(position: .top, alignment: .center, spacing: 6) {
                    if punto.id == ultimo {
                        Text(punto.texto)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.cadiva.brand)
                            .opacity(progreso)
                    }
                }
                .accessibilityLabel("\(Formato.fechaLarga(punto.fecha)), \(punto.tienda)\(punto.conOferta ? ", con oferta" : "")")
                .accessibilityValue("\(punto.texto) por unidad")
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(.cadiva))
            }
        }
        .frame(minHeight: 180)
        .padding(.top, 12)
        .onAppear {
            if reducirMovimiento {
                progreso = 1
            } else {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { progreso = 1 }
            }
        }
    }
}
