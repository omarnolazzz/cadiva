import CadivaCore
import SwiftData
import SwiftUI

/// Lista con búsqueda, filtro por categoría y orden. Recibe los resúmenes ya calculados:
/// cambiar de categoría u orden solo filtra y reordena valores en memoria.
/// Usa un contenedor perezoso: con 20 productos, `List` perdía tres veces más tiempo al filtrar.
struct ListaProductos: View {
    let resumenes: [ResumenFila]
    let navegacion: NavegacionProductos

    @Environment(\.modelContext) private var contexto
    @Environment(\.dynamicTypeSize) private var tamanoTexto
    @AppStorage(Preferencias.ordenProductos) private var orden: OrdenProductos = .recientes

    @State private var busqueda = ""
    @State private var categoria: Categoria?

    var body: some View {
        let categorias = categoriasUsadas
        let visibles = filtrados
        let activos = visibles.filter { !$0.archivado }
        let archivados = visibles.filter(\.archivado)

        listaLigera(activos: activos, archivados: archivados, vacia: visibles.isEmpty)
            .safeAreaInset(edge: .top, spacing: 0) {
                encabezado(categorias)
            }
            .searchable(text: $busqueda, prompt: "Buscar producto o tienda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Ordenar por", selection: $orden) {
                            ForEach(OrdenProductos.allCases) { opcion in
                                Label(Formato.orden(opcion), systemImage: Formato.simboloOrden(opcion)).tag(opcion)
                            }
                        }
                    } label: {
                        Label("Ordenar", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityIdentifier("ordenar-productos")
                }
            }
            // Si se borró el último producto de la categoría elegida, se vuelve a "Todas".
            .onChange(of: categorias) { _, nuevas in
                if let categoria, !nuevas.contains(categoria) { self.categoria = nil }
            }
    }

    private func encabezado(_ categorias: [Categoria]) -> some View {
        HStack(spacing: 8) {
            if categorias.count > 1 {
                FiltroCategorias(categorias: categorias, resumenes: resumenes, seleccion: $categoria)
            } else {
                Text(cuenta(resumenes.count))
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            // Con texto muy grande solo cabe el filtro.
            if !tamanoTexto.isAccessibilitySize {
                Text(Formato.orden(orden))
                    .lineLimit(1)
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color.cadiva.textSecondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        // Sin extenderse a la zona segura: si no, el color sube y tapa el título de la pantalla.
        .background(Color.cadiva.background, ignoresSafeAreaEdges: [])
    }

    private func listaLigera(activos: [ResumenFila], archivados: [ResumenFila], vacia: Bool) -> some View {
        ScrollViewReader { lector in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Color.clear.frame(height: 0).id("inicio")
                    if !activos.isEmpty {
                        bloque(activos)
                    }
                    if !archivados.isEmpty {
                        Text("Archivados")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.cadiva.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.top, 12)
                            .accessibilityAddTraits(.isHeader)
                        bloque(archivados)
                    }
                    if vacia {
                        ContentUnavailableView.search(text: busqueda)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            // Al filtrar se vuelve arriba, sin animación.
            .onChange(of: categoria) { lector.scrollTo("inicio", anchor: .top) }
        }
    }

    /// Las filas de una sección sobre una tarjeta, separadas por una línea.
    private func bloque(_ filas: [ResumenFila]) -> some View {
        let ultima = filas.last?.id
        return LazyVStack(spacing: 0) {
            ForEach(filas) { resumen in
                fila(resumen)
                    .overlay(alignment: .bottom) {
                        if resumen.id != ultima {
                            Rectangle()
                                .fill(Color.cadiva.textSecondary.opacity(0.18))
                                .frame(height: 0.5)
                                .padding(.leading, 80)
                        }
                    }
            }
        }
        .background(Color.cadiva.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func cuenta(_ total: Int) -> String {
        total == 1 ? "1 producto" : "\(total) productos"
    }

    private var categoriasUsadas: [Categoria] {
        let usadas = Set(resumenes.map(\.categoria))
        return Categoria.allCases.filter(usadas.contains)
    }

    private var filtrados: [ResumenFila] {
        let texto = busqueda.recortado
        let elegidos = resumenes.filter { resumen in
            guard categoria == nil || resumen.categoria == categoria else { return false }
            return texto.isEmpty || resumen.nombre.localizedStandardContains(texto)
                || (resumen.tienda?.localizedStandardContains(texto) ?? false)
        }
        return orden.ordenar(elegidos, clave: \.clave)
    }

    private func fila(_ resumen: ResumenFila) -> some View {
        NavigationLink(value: resumen.producto) {
            HStack(spacing: 8) {
                FilaResumenProducto(resumen: resumen)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textSecondary.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloFilaProducto())
        // Mantener presionado: lo que antes era deslizar la fila.
        .contextMenu {
            Button {
                resumen.producto.archivado.toggle()
                try? contexto.save()
            } label: {
                if resumen.archivado {
                    Label("Restaurar", systemImage: "tray.and.arrow.up")
                } else {
                    Label("Archivar", systemImage: "archivebox")
                }
            }
            Button(role: .destructive) {
                navegacion.porBorrar = resumen.producto
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}

/// Resalta la fila mientras se toca, como una celda de lista.
private struct EstiloFilaProducto: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.cadiva.tint : Color.clear)
    }
}
