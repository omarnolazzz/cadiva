import CadivaCore
import SwiftData
import SwiftUI
import UIKit

struct AjustesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(SesionUsuario.self) private var sesion
    @Query(sort: \Compra.fecha) private var compras: [Compra]

    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto

    @State private var confirmarBorrado = false
    @State private var archivoCSV: URL?
    @State private var borrado: EstadoBorrado?
    @State private var creandoPIN = false
    @State private var versionSeguridad = 0

    var body: some View {
        NavigationStack {
            Form {
                SeccionCuenta()
                SeccionSeguridad(creandoPIN: $creandoPIN, version: $versionSeguridad)

                Section("Moneda") {
                    Picker("Moneda", selection: $moneda) {
                        ForEach(Preferencias.monedas, id: \.self) { codigo in
                            Text("\(codigo) · \(Locale.cadiva.localizedString(forCurrencyCode: codigo) ?? codigo)")
                                .tag(codigo)
                        }
                    }
                }
                .celdaCadiva()

                Section {
                    if let archivoCSV {
                        ShareLink(item: archivoCSV, preview: SharePreview("Compras de Cadiva")) {
                            Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(compras.isEmpty)
                    }
                    Button(role: .destructive) {
                        confirmarBorrado = true
                    } label: {
                        Label("Borrar todos los datos", systemImage: "trash")
                            .foregroundStyle(Color.cadiva.priceUp)
                    }
                } header: {
                    Text("Datos")
                } footer: {
                    Text("El CSV incluye una fila por compra.")
                }
                .celdaCadiva()

                Section {
                    LabeledContent("Versión", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                }
                .celdaCadiva()
            }
            .fondoCadiva()
            .navigationTitle("Ajustes")
            .sheet(isPresented: $creandoPIN, onDismiss: { versionSeguridad += 1 }) {
                CrearPINView()
            }
            .overlay {
                if let borrado {
                    PantallaBorrado(estado: borrado)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: borrado)
            #if DEBUG
            .onAppear {
                if Demo.valor("--pantalla") == "borrado" { borrado = .listo(productos: 6, compras: 24) }
                creandoPIN = Demo.valor("--pantalla") == "crear-pin"
            }
            #endif
            .task(id: compras.count) { archivoCSV = try? exportarCSV() }
            .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { Task { await borrarConAnimacion() } }
            } message: {
                Text(sesion.usuario == nil
                     ? "Se eliminarán todos tus productos y compras de este iPhone. No se puede deshacer."
                     : "Se eliminarán todos tus productos y compras de este iPhone y de tu cuenta. No se puede deshacer.")
            }
        }
    }

    private func exportarCSV() throws -> URL {
        let filas = compras.compactMap { compra -> FilaCSV? in
            guard let producto = compra.producto else { return nil }
            return FilaCSV(
                producto: producto.nombre, categoria: producto.categoria.nombre,
                fecha: compra.fecha, precioTotal: compra.precioTotal, cantidad: compra.cantidad,
                tienda: compra.tienda, fechaAgotado: compra.fechaAgotado, duracionRealDias: compra.duracionReal
            )
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "cadiva-compras.csv")
        try ExportadorCSV.csv(filas, calendar: .cadiva).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Muestra "Eliminando…", borra y confirma con el resultado.
    private func borrarConAnimacion() async {
        let conteo = AlmacenLocal.contar(en: contexto)
        borrado = .borrando
        // Una pausa breve para que la animación se alcance a ver aunque haya pocos datos.
        try? await Task.sleep(for: .milliseconds(1300))
        AlmacenLocal.borrarTodo(en: contexto)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        borrado = .listo(productos: conteo.productos, compras: conteo.compras)
        try? await Task.sleep(for: .seconds(2.2))
        borrado = nil
    }
}

#if DEBUG
#Preview("Borrando") {
    PantallaBorrado(estado: .borrando)
}

#Preview("Borrado · oscuro") {
    PantallaBorrado(estado: .listo(productos: 6, compras: 24))
        .preferredColorScheme(.dark)
}

#Preview("Claro") {
    AjustesView()
        .environment(SesionUsuario(estado: .invitado, cliente: nil))
        .environment(Sincronizador())
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    AjustesView()
        .environment(SesionUsuario(estado: .invitado, cliente: nil))
        .environment(Sincronizador())
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
#endif
