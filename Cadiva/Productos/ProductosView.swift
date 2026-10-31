import CadivaCore
import SwiftData
import SwiftUI

/// Pantalla principal: cada producto con su último precio, dónde se compró y cuánto cambió.
struct ProductosView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto

    @State private var ruta: [Producto] = []
    @State private var busqueda = ""
    @State private var categoria: Categoria?
    @State private var creando = false
    @State private var porBorrar: Producto?
    @Namespace private var transicion

    var body: some View {
        NavigationStack(path: $ruta) {
            Group {
                if productos.isEmpty {
                    EstadoVacio(
                        titulo: "Sin productos",
                        mensaje: "Agrega un producto y luego registra cada compra: cuánto pagaste por unidad y en qué tienda.",
                        tituloAccion: "Nuevo producto",
                        simboloAccion: "plus.square.on.square"
                    ) { creando = true }
                } else {
                    lista
                }
            }
            .fondoCadiva()
            .navigationTitle("Productos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        creando = true
                    } label: {
                        Label("Nuevo producto", systemImage: "plus.square.on.square")
                    }
                    .accessibilityIdentifier("nuevo-producto")
                }
            }
            .navigationDestination(for: Producto.self) { producto in
                DetalleProductoView(producto: producto)
                    .transicionZoom(id: producto.persistentModelID, en: transicion)
            }
            .sheet(isPresented: $creando) {
                EditarProductoView { nuevo in
                    Task {
                        // Se abre cuando la hoja termina de cerrarse.
                        try? await Task.sleep(for: .milliseconds(350))
                        ruta.append(nuevo)
                    }
                }
            }
            .confirmationDialog(
                "¿Borrar \(porBorrar?.nombre ?? "")?",
                isPresented: Binding(get: { porBorrar != nil }, set: { if !$0 { porBorrar = nil } }),
                titleVisibility: .visible,
                presenting: porBorrar
            ) { producto in
                Button("Borrar producto y compras", role: .destructive) {
                    withAnimation(.snappy) {
                        contexto.delete(producto)
                        try? contexto.save()
                    }
                }
            } message: { _ in
                Text("Se borrará también su historial de compras. Si solo quieres ocultarlo, archívalo.")
            }
            #if DEBUG
            .onAppear {
                if ["detalle", "registro"].contains(Demo.valor("--pantalla")), let primero = productos.first(where: { !$0.compras.isEmpty }) {
                    ruta = [primero]
                }
                creando = Demo.valor("--pantalla") == "nuevo-producto"
            }
            #endif
        }
    }

    // MARK: Lista

    private var filtrados: [Producto] {
        let texto = busqueda.recortado
        return productos
            .filter { texto.isEmpty || $0.nombre.localizedStandardContains(texto) || ($0.ultimaCompra?.tienda?.localizedStandardContains(texto) ?? false) }
            .filter { categoria == nil || $0.categoria == categoria }
            .sorted { ($0.ultimaCompra?.fecha ?? $0.creado) > ($1.ultimaCompra?.fecha ?? $1.creado) }
    }

    private var categoriasUsadas: [Categoria] {
        let usadas = Set(productos.map(\.categoria))
        return Categoria.allCases.filter(usadas.contains)
    }

    private var lista: some View {
        let filtrados = filtrados
        let activos = filtrados.filter { !$0.archivado }
        let archivados = filtrados.filter(\.archivado)

        return List {
            if categoriasUsadas.count > 1 {
                Section {
                    filtroCategorias
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if !activos.isEmpty {
                Section {
                    ForEach(Array(activos.enumerated()), id: \.element.persistentModelID) { indice, producto in
                        fila(producto)
                            .entrada(retraso: min(Double(indice) * 0.04, 0.4))
                    }
                } header: {
                    Text(activos.count == 1 ? "1 producto" : "\(activos.count) productos")
                }
                .celdaCadiva()
            }
            if !archivados.isEmpty {
                Section("Archivados") {
                    ForEach(archivados) { fila($0) }
                }
                .celdaCadiva()
            }
            if filtrados.isEmpty {
                ContentUnavailableView.search(text: busqueda)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: filtrados.map(\.persistentModelID))
        .searchable(text: $busqueda, prompt: "Buscar producto o tienda")
    }

    private var filtroCategorias: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                botonCategoria(nil, titulo: "Todas", simbolo: "square.grid.2x2")
                ForEach(categoriasUsadas) { opcion in
                    botonCategoria(opcion, titulo: opcion.nombre, simbolo: opcion.simbolo)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .sensoryFeedback(.selection, trigger: categoria)
    }

    private func botonCategoria(_ opcion: Categoria?, titulo: String, simbolo: String) -> some View {
        let elegida = categoria == opcion
        return Button {
            withAnimation(.snappy) { categoria = opcion }
        } label: {
            Label(titulo, systemImage: simbolo)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(elegida ? Color.white : Color.cadiva.textPrimary)
                .background {
                    if elegida {
                        Capsule().fill(Color.cadiva.brand).matchedGeometryEffect(id: "categoria", in: transicion)
                    } else {
                        Capsule().fill(Color.cadiva.surface)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? .isSelected : [])
    }

    private func fila(_ producto: Producto) -> some View {
        NavigationLink(value: producto) {
            FilaResumenProducto(producto: producto, moneda: moneda)
                .origenZoom(id: producto.persistentModelID, en: transicion)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                porBorrar = producto
            } label: {
                Label("Borrar", systemImage: "trash")
            }
            Button {
                withAnimation(.snappy) {
                    producto.archivado.toggle()
                    try? contexto.save()
                }
            } label: {
                if producto.archivado {
                    Label("Restaurar", systemImage: "tray.and.arrow.up")
                } else {
                    Label("Archivar", systemImage: "archivebox")
                }
            }
            .tint(Color.cadiva.textSecondary)
        }
    }
}

/// Miniatura, nombre, última tienda y fecha; a la derecha el último precio por unidad.
struct FilaResumenProducto: View {
    let producto: Producto
    let moneda: String

    @Environment(\.dynamicTypeSize) private var tamanoTexto

    var body: some View {
        let ultima = producto.ultimaCompra
        let cambio = producto.resumen().cambioPrecio
        // Con texto de accesibilidad todo va en columna para que nada se corte.
        let disposicion = tamanoTexto.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))
        disposicion {
            MiniaturaProducto(producto: producto, tamano: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(producto.nombre)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textPrimary)
                    .lineLimit(tamanoTexto.isAccessibilitySize ? nil : 3)
                if let ultima {
                    Label {
                        Text("\(ultima.tienda ?? "Sin tienda") · \(ultima.fecha.formatted(.relative(presentation: .named).locale(.cadiva)))")
                    } icon: {
                        Image(systemName: "storefront")
                    }
                    .labelStyle(EtiquetaCompacta())
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
                } else {
                    Text("Sin compras todavía")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
            }
            if !tamanoTexto.isAccessibilitySize { Spacer(minLength: 4) }
            if let precio = ultima?.precioUnitario {
                VStack(alignment: tamanoTexto.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                    Text(Formato.moneda(precio, moneda))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .contentTransition(.numericText(value: precio.double))
                    IndicadorCambio(cambio: cambio)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Ícono pequeño pegado al texto.
struct EtiquetaCompacta: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

extension View {
    /// En iOS 18 la pantalla de detalle crece desde la fila.
    @ViewBuilder
    func transicionZoom(id: some Hashable, en espacio: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: espacio))
        } else {
            self
        }
    }

    @ViewBuilder
    func origenZoom(id: some Hashable, en espacio: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: espacio)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("Claro") {
    ProductosView()
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    ProductosView()
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}

#Preview("Vacío") {
    ProductosView()
        .modelContainer(DatosEjemplo.vacio())
}
#endif
