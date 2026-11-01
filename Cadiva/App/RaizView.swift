import SwiftData
import SwiftUI
import UserNotifications

struct RaizView: View {
    @Query private var compras: [Compra]
    @Query private var productos: [Producto]

    @Environment(\.modelContext) private var contexto
    @Environment(\.scenePhase) private var fase
    @Environment(SesionUsuario.self) private var sesion
    @Environment(Sincronizador.self) private var sincronizador

    @State private var pestana = 0
    @State private var activaciones = 0
    @State private var mostrarOferta = false

    var body: some View {
        TabView(selection: $pestana) {
            ProductosView()
                .tabItem { Label("Productos", systemImage: "shippingbox") }
                .tag(0)
            GastoView()
                .tabItem { Label("Gasto", systemImage: "chart.bar") }
                .tag(1)
            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(Color.cadiva.brand)
        .modifier(BarraQueSeEncoge())
        .sensoryFeedback(.selection, trigger: pestana)
        #if DEBUG
        .onAppear {
            pestana = Demo.valor("--pestana").flatMap(Int.init) ?? pestana
            mostrarOferta = Demo.valor("--pantalla") == "oferta"
        }
        #endif
        // Cadiva ya no manda avisos de recompra: se quitan los que hubieran quedado programados.
        .task { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
        // Con cuenta: sincroniza al entrar, al volver a la app y poco después de cada cambio.
        .task(id: Disparo(usuario: sesion.usuario?.id, datos: huellaDatos, activaciones: activaciones)) {
            guard sesion.usuario != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await sincronizador.sincronizar(contexto: contexto, sesion: sesion)
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .active { activaciones += 1 }
        }
        // Recién iniciada la sesión, si no hay PIN ni Face ID, se ofrece configurarlos.
        .task(id: sesion.ofrecerBloqueo) {
            guard sesion.ofrecerBloqueo else { return }
            try? await Task.sleep(for: .milliseconds(900))
            sesion.ofrecerBloqueo = false
            mostrarOferta = true
        }
        .sheet(isPresented: $mostrarOferta) { OfertaBloqueoView() }
    }

    private struct Disparo: Equatable {
        var usuario: String?
        var datos: Int
        var activaciones: Int
    }

    /// Cambia con cualquier edición de productos o compras.
    private var huellaDatos: Int {
        var huella = Hasher()
        for producto in productos {
            huella.combine(producto.uid)
            huella.combine(producto.nombre)
            huella.combine(producto.categoriaRaw)
            huella.combine(producto.simbolo)
            huella.combine(producto.notas)
            huella.combine(producto.archivado)
            huella.combine(producto.foto?.count)
            huella.combine(producto.seguimientoRaw)
        }
        for compra in compras {
            huella.combine(compra.uid)
            huella.combine(compra.producto?.persistentModelID)
            huella.combine(compra.fecha)
            huella.combine(compra.precioTotal)
            huella.combine(compra.cantidad)
            huella.combine(compra.tienda)
            huella.combine(compra.fechaAgotado)
            huella.combine(compra.ofertaJSON)
        }
        return huella.finalize()
    }
}

/// En iOS 26 la barra de pestañas de Liquid Glass se encoge al desplazarse.
private struct BarraQueSeEncoge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Claro") {
    RaizView()
        .environment(SesionUsuario(estado: .invitado, cliente: nil))
        .environment(Sincronizador())
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    RaizView()
        .environment(SesionUsuario(estado: .invitado, cliente: nil))
        .environment(Sincronizador())
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
#endif
