import Observation
import SwiftData
import SwiftUI

/// A dónde navega la pantalla de productos. Es un objeto para que abrir una hoja o un detalle
/// no vuelva a calcular la lista, que solo recibe la referencia.
@Observable
@MainActor
final class NavegacionProductos {
    var ruta: [Producto] = []
    var creando = false
    var porBorrar: Producto?
    /// Referencia para "hace 3 días" y los días restantes; se actualiza al volver a la app.
    var hoy = Date.now
}

/// Pantalla principal: cada producto con su último precio, dónde se compró y cuánto cambió.
struct ProductosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.scenePhase) private var fase

    @State private var navegacion = NavegacionProductos()

    var body: some View {
        @Bindable var navegacion = navegacion

        NavigationStack(path: $navegacion.ruta) {
            FuenteProductos(navegacion: navegacion)
                .fondoCadiva()
                .navigationTitle("Productos")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            navegacion.creando = true
                        } label: {
                            Label("Agregar producto", systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                        }
                        .accessibilityIdentifier("nuevo-producto")
                    }
                }
                .navigationDestination(for: Producto.self) { producto in
                    DetalleProductoView(producto: producto)
                }
                .sheet(isPresented: $navegacion.creando) {
                    EditarProductoView { nuevo in
                        Task {
                            // Se abre cuando la hoja termina de cerrarse.
                            try? await Task.sleep(for: .milliseconds(350))
                            navegacion.ruta.append(nuevo)
                        }
                    }
                }
                .confirmationDialog(
                    "¿Borrar \(navegacion.porBorrar?.nombre ?? "")?",
                    isPresented: Binding(get: { navegacion.porBorrar != nil }, set: { if !$0 { navegacion.porBorrar = nil } }),
                    titleVisibility: .visible,
                    presenting: navegacion.porBorrar
                ) { producto in
                    Button("Borrar producto y compras", role: .destructive) {
                        contexto.delete(producto)
                        try? contexto.save()
                    }
                } message: { _ in
                    Text("Se borrará también su historial de compras. Si solo quieres ocultarlo, archívalo.")
                }
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .active { navegacion.hoy = .now }
        }
    }
}

/// Consulta los productos y prepara el resumen de cada fila.
/// Su cuerpo solo se vuelve a evaluar cuando cambian los datos, no al filtrar ni al navegar.
private struct FuenteProductos: View {
    let navegacion: NavegacionProductos

    // La animación de la consulta cubre altas y bajas de productos; filtrar no pasa por aquí.
    @Query(sort: \Producto.nombre, animation: .snappy) private var productos: [Producto]
    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto

    var body: some View {
        Group {
            if productos.isEmpty {
                EstadoVacio(
                    titulo: "Sin productos",
                    mensaje: "Agrega un producto y luego registra cada compra: cuánto pagaste por unidad y en qué tienda.",
                    tituloAccion: "Agregar producto",
                    simboloAccion: "plus"
                ) { navegacion.creando = true }
            } else {
                ListaProductos(
                    resumenes: productos.map { ResumenFila(producto: $0, moneda: moneda, hoy: navegacion.hoy) },
                    navegacion: navegacion
                )
            }
        }
        #if DEBUG
        .onAppear {
            if ["detalle", "registro"].contains(Demo.valor("--pantalla")), let primero = productos.first(where: { !$0.compras.isEmpty }) {
                navegacion.ruta = [primero]
            }
            navegacion.creando = ["nuevo-producto", "buscar-imagen"].contains(Demo.valor("--pantalla"))
            if ["oferta-detalle", "oferta-compra"].contains(Demo.valor("--pantalla")),
               let papas = productos.first(where: { $0.nombre.hasPrefix("Papas") }) {
                navegacion.ruta = [papas]
            }
        }
        #endif
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
