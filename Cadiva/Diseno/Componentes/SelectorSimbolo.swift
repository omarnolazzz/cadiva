import SwiftUI
import UIKit

/// Cuadrícula para elegir el SF Symbol de un producto.
struct SelectorSimbolo: View {
    @Binding var seleccion: String

    @ScaledMetric(relativeTo: .body) private var celda: CGFloat = 44

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: celda), spacing: 8)], spacing: 8) {
            ForEach(SimbolosProducto.todos, id: \.self) { simbolo in
                let elegido = simbolo == seleccion
                Button {
                    withAnimation(.snappy) { seleccion = simbolo }
                } label: {
                    Image(systemName: simbolo)
                        .font(.title3)
                        .frame(width: celda, height: celda)
                        .foregroundStyle(elegido ? Color.white : Color.cadiva.brand)
                        .background(elegido ? Color.cadiva.brand : Color.cadiva.tint, in: Circle())
                        .scaleEffect(elegido ? 1.08 : 1)
                        .symbolEffect(.bounce, value: elegido)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(simbolo.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                .accessibilityAddTraits(elegido ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
