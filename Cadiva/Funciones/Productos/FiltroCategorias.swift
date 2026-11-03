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
            CapsulaMenu(
                titulo: seleccion?.nombre ?? "Todas",
                simbolo: seleccion?.simbolo ?? "square.grid.2x2",
                activa: seleccion != nil
            )
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
                // La categoría de nombre más largo, para revisar que todo quepa.
                seleccion = categorias.max { $0.nombre.count < $1.nombre.count }
            default:
                break
            }
        }
        #endif
    }
}

/// Aspecto de los botones que abren un menú sobre la lista.
struct CapsulaMenu: View {
    let titulo: String
    var simbolo: String?
    var activa = false

    var body: some View {
        HStack(spacing: 6) {
            if let simbolo {
                Image(systemName: simbolo)
                    .accessibilityHidden(true)
            }
            Text(titulo)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(activa ? Color.white : Color.cadiva.textPrimary)
        .background(activa ? Color.cadiva.brand : Color.cadiva.surface, in: Capsule())
    }
}
