import CadivaCore
import SwiftData
import SwiftUI

/// Lista con búsqueda, filtro por categoría y orden. Recibe los resúmenes ya calculados:
/// cambiar de categoría u orden solo filtra y reordena valores en memoria.
struct ListaProductos: View {
    let resumenes: [ResumenFila]
    let navegacion: NavegacionProductos
    let espacio: Namespace.ID

    @Environment(\.modelContext) private var contexto
    @AppStorage(Preferencias.ordenProductos) private var orden: OrdenProductos = .recientes

    @State private var busqueda = ""
    @State private var categoria: Categoria?

    var body: some View {
        let categorias = categoriasUsadas
        let visibles = filtrados
        let activos = visibles.filter { !$0.archivado }
        let archivados = visibles.filter(\.archivado)

        List {
            if !activos.isEmpty {
                Section {
                    ForEach(activos) { fila($0) }
                } header: {
                    HStack {
                        Text(activos.count == 1 ? "1 producto" : "\(activos.count) productos")
                        Spacer()
                        Text(Formato.orden(orden))
                            .textCase(nil)
                    }
                }
                .celdaCadiva()
            }
            if !archivados.isEmpty {
                Section("Archivados") {
                    ForEach(archivados) { fila($0) }
                }
                .celdaCadiva()
            }
            if visibles.isEmpty {
                ContentUnavailableView.search(text: busqueda)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            if categorias.count > 1 {
                FiltroCategorias(categorias: categorias, seleccion: $categoria)
            }
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
            FilaResumenProducto(resumen: resumen)
                .origenZoom(id: resumen.id, en: espacio)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                navegacion.porBorrar = resumen.producto
            } label: {
                Label("Borrar", systemImage: "trash")
            }
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
            .tint(Color.cadiva.textSecondary)
        }
    }
}
