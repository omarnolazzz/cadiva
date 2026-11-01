import SwiftData
import SwiftUI
import UIKit

/// Crea un producto (sin `producto`) o edita uno existente. Las compras se registran después, dentro del producto.
struct EditarProductoView: View {
    let producto: Producto?
    /// Se llama con el producto recién creado, para abrirlo.
    var alCrear: (@MainActor (Producto) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto

    @State private var borrador: BorradorProducto
    @State private var notas: String
    @State private var archivado: Bool
    @FocusState private var enfocado: Bool

    init(producto: Producto? = nil, alCrear: (@MainActor (Producto) -> Void)? = nil) {
        self.producto = producto
        self.alCrear = alCrear
        _borrador = State(initialValue: producto.map(BorradorProducto.init) ?? BorradorProducto())
        _notas = State(initialValue: producto?.notas ?? "")
        _archivado = State(initialValue: producto?.archivado ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SelectorFoto(foto: $borrador.foto, simbolo: borrador.simbolo, consulta: borrador.nombre)
                }
                .listRowBackground(Color.clear)

                Section("Producto") {
                    TextField("Nombre, p. ej. Arroz Costeño 5 kg", text: $borrador.nombre)
                        .textInputAutocapitalization(.sentences)
                        .focused($enfocado)
                    CamposProducto(borrador: $borrador)
                }
                .celdaCadiva()

                SeccionSeguimiento(borrador: $borrador)

                Section("Notas") {
                    TextField("Marca, presentación, sabor…", text: $notas, axis: .vertical)
                        .lineLimit(2...6)
                }
                .celdaCadiva()

                if producto != nil {
                    Section {
                        Toggle("Archivado", isOn: $archivado.animation())
                    } footer: {
                        Text("Los productos archivados se muestran al final de la lista y no generan avisos. Su historial se conserva.")
                    }
                    .celdaCadiva()
                }
            }
            .fondoCadiva()
            .navigationTitle(producto == nil ? "Nuevo producto" : "Editar producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(producto == nil ? "Crear" : "Guardar", action: guardar)
                        .fontWeight(.semibold)
                        .disabled(borrador.nombre.recortado.isEmpty)
                }
            }
            .task {
                guard producto == nil else { return }
                try? await Task.sleep(for: .milliseconds(450))
                enfocado = true
            }
        }
    }

    private func guardar() {
        let destino: Producto
        if let producto {
            destino = producto
            borrador.aplicar(a: destino)
        } else {
            destino = borrador.crear()
            contexto.insert(destino)
        }
        let texto = notas.recortado
        destino.notas = texto.isEmpty ? nil : texto
        destino.archivado = archivado
        try? contexto.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
        if producto == nil { alCrear?(destino) }
    }
}

#if DEBUG
#Preview("Claro") {
    EditarProductoView(producto: DatosEjemplo.arroz)
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    EditarProductoView()
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
#endif
