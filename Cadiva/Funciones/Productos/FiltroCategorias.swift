import SwiftUI

/// Botones para filtrar por categoría. Solo se anima la cápsula elegida:
/// la lista cambia sin animación, para que moverse entre categorías no pierda cuadros.
struct FiltroCategorias: View {
    let categorias: [Categoria]
    @Binding var seleccion: Categoria?

    /// La cápsula se mueve con este estado propio; así la animación no alcanza a la lista.
    @State private var visual: Categoria?
    @Namespace private var espacio

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                boton(nil, titulo: "Todas", simbolo: "square.grid.2x2")
                ForEach(categorias) { opcion in
                    boton(opcion, titulo: opcion.nombre, simbolo: opcion.simbolo)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        // Sin extenderse a la zona segura: si no, el color sube y tapa el título de la pantalla.
        .background(Color.cadiva.background, ignoresSafeAreaEdges: [])
        .sensoryFeedback(.selection, trigger: visual)
        .onAppear { visual = seleccion }
        .onChange(of: seleccion) { _, nueva in
            if visual != nueva { visual = nueva }
        }
        #if DEBUG
        .task {
            guard Demo.valor("--pantalla") == "medir-filtro" else { return }
            await MedidorFluidez.recorrer([Categoria?.none] + categorias.map(Optional.some), cambiar: elegir)
        }
        #endif
    }

    private func elegir(_ opcion: Categoria?) {
        withAnimation(.snappy) { visual = opcion }
        seleccion = opcion
    }

    private func boton(_ opcion: Categoria?, titulo: String, simbolo: String) -> some View {
        let elegida = visual == opcion
        return Button {
            elegir(opcion)
        } label: {
            Label(titulo, systemImage: simbolo)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(elegida ? Color.white : Color.cadiva.textPrimary)
                .background {
                    if elegida {
                        Capsule().fill(Color.cadiva.brand).matchedGeometryEffect(id: "categoria", in: espacio)
                    } else {
                        Capsule().fill(Color.cadiva.surface)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? .isSelected : [])
    }
}
