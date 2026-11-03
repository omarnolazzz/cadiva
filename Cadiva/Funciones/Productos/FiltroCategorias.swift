import SwiftUI

/// Botón que abre el menú de categorías, con cuántos productos tiene cada una.
struct FiltroCategorias: View {
    let categorias: [Categoria]
    let resumenes: [ResumenFila]
    @Binding var seleccion: Categoria?

    var body: some View {
        let conteos = Dictionary(resumenes.map { ($0.categoria, 1) }, uniquingKeysWith: +)

        Menu {
            Picker("Categoría", selection: $seleccion) {
                Label("Todas · \(resumenes.count)", systemImage: "square.grid.2x2")
                    .tag(Categoria?.none)
                ForEach(categorias) { opcion in
                    Label("\(opcion.nombre) · \(conteos[opcion] ?? 0)", systemImage: opcion.simbolo)
                        .tag(Optional(opcion))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Label(seleccion?.nombre ?? "Todas", systemImage: seleccion?.simbolo ?? "square.grid.2x2")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(seleccion == nil ? Color.cadiva.textPrimary : Color.white)
            .background(seleccion == nil ? Color.cadiva.surface : Color.cadiva.brand, in: Capsule())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("Categoría: \(seleccion?.nombre ?? "Todas")")
        .accessibilityIdentifier("filtro-categorias")
        .sensoryFeedback(.selection, trigger: seleccion)
        #if DEBUG
        .task {
            switch Demo.valor("--pantalla") {
            case "medir-filtro":
                await MedidorFluidez.recorrer([Categoria?.none] + categorias.map(Optional.some)) { seleccion = $0 }
            case "filtro-elegido":
                seleccion = categorias.first
            default:
                break
            }
        }
        #endif
    }
}
