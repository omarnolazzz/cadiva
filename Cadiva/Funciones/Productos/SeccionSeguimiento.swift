import CadivaCore
import SwiftUI

/// Si el producto lleva control de cuánto dura o solo de precio y tienda.
/// Se sugiere solo con el nombre y la categoría; la persona puede cambiarlo.
struct SeccionSeguimiento: View {
    @Binding var borrador: BorradorProducto

    var body: some View {
        Section {
            Picker("Seguimiento", selection: Binding(
                get: { borrador.seguimiento },
                set: { nuevo in
                    withAnimation(.snappy) {
                        // Si coincide con lo sugerido, se vuelve automático.
                        borrador.seguimientoElegido = nuevo == borrador.seguimientoSugerido ? nil : nuevo
                    }
                }
            )) {
                Text("Precio y duración").tag(Seguimiento.duracion)
                Text("Solo precio").tag(Seguimiento.soloPrecio)
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            Label {
                Text(explicacion)
                    .font(.footnote)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            } icon: {
                Image(systemName: borrador.seguimiento == .duracion ? "hourglass" : "tag")
                    .foregroundStyle(Color.cadiva.brand)
                    .contentTransition(.symbolEffect(.replace))
            }
        } header: {
            HStack {
                Text("Seguimiento")
                Spacer()
                if borrador.seguimientoElegido == nil {
                    Label("Automático", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.cadiva.brand)
                        .textCase(nil)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button("Usar sugerencia") {
                        withAnimation(.snappy) { borrador.seguimientoElegido = nil }
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
        .celdaCadiva()
        .animation(.snappy, value: borrador.seguimiento)
    }

    private var explicacion: String {
        switch borrador.seguimiento {
        case .duracion:
            "Cadiva calcula cuánto te dura cada unidad con el tiempo entre una compra y la siguiente."
        case .soloPrecio:
            "Solo se guardan el precio y la tienda, para llevar el control de cuánto pagas."
        }
    }
}
