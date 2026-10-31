import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct GraficaPeriodos: View {
    let totales: [TotalPeriodo]
    let periodo: Periodo
    let moneda: String

    @State private var progreso: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        let actual = totales.last?.intervalo.start
        let maximo = max(totales.map(\.total.double).max() ?? 0, 1)
        Chart(totales, id: \.intervalo.start) { total in
            BarMark(x: .value("Periodo", etiqueta(total)), y: .value("Total", total.total.double * progreso))
                .foregroundStyle(total.intervalo.start == actual ? Color.cadiva.brand : Color.cadiva.brand.opacity(0.35))
                .cornerRadius(6)
                .accessibilityLabel(etiqueta(total))
                .accessibilityValue(Formato.moneda(total.total, moneda))
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYScale(domain: 0...(maximo * 1.1))
        .frame(minHeight: 160)
        .padding(.vertical, 8)
        .task(id: periodo) {
            progreso = 0
            if reducirMovimiento {
                progreso = 1
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { progreso = 1 }
            }
        }
    }

    private func etiqueta(_ total: TotalPeriodo) -> String {
        switch periodo {
        case .semana: Formato.fechaCorta(total.intervalo.start)
        case .mes: total.intervalo.start.formatted(.dateTime.month(.abbreviated).locale(.cadiva))
        }
    }
}
