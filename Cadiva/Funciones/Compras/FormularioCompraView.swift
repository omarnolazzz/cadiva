import CadivaCore
import SwiftData
import SwiftUI
import UIKit

/// Registra una compra de un producto o edita una existente.
/// Cada compra es de un solo producto: se anota el precio por unidad y cuántas unidades se llevaron.
struct FormularioCompraView: View {
    let producto: Producto
    let compra: Compra?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Compra.fecha, order: .reverse) private var todas: [Compra]
    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto

    @State private var precioTexto: String
    @State private var unidades: Int
    @State private var fecha: Date
    @State private var tienda: String
    @State private var agotado: Bool
    @State private var fechaAgotado: Date
    @State private var intentoGuardar = false
    @State private var confirmarBorrado = false
    @FocusState private var foco: Campo?

    private enum Campo: Hashable { case precio, tienda }

    init(producto: Producto, compra: Compra? = nil) {
        self.producto = producto
        self.compra = compra
        let unitario = compra.flatMap(\.precioUnitario)
        _precioTexto = State(initialValue: unitario.map { Formato.texto($0.redondeado(2)) } ?? "")
        _unidades = State(initialValue: compra?.unidades ?? 1)
        _fecha = State(initialValue: compra?.fecha ?? .now)
        _tienda = State(initialValue: compra?.tienda ?? producto.ultimaCompra?.tienda ?? "")
        _agotado = State(initialValue: compra?.fechaAgotado != nil)
        _fechaAgotado = State(initialValue: compra?.fechaAgotado ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    encabezado
                }
                .listRowBackground(Color.clear)

                seccionPrecio
                seccionTienda

                if compra != nil {
                    if producto.seguimiento == .duracion {
                        seccionAgotado
                    }
                    Section {
                        Button("Borrar compra", role: .destructive) { confirmarBorrado = true }
                    }
                    .celdaCadiva()
                }
            }
            .fondoCadiva()
            .navigationTitle(compra == nil ? "Registrar compra" : "Editar compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardar)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if foco == .precio {
                        Button("Siguiente") { foco = .tienda }
                    } else {
                        Button("Guardar", action: guardar).fontWeight(.semibold)
                    }
                }
            }
            .confirmationDialog("¿Borrar esta compra?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar compra", role: .destructive) {
                    if let compra { contexto.delete(compra) }
                    try? contexto.save()
                    dismiss()
                }
            } message: {
                Text("Se quitará del historial y de los cálculos.")
            }
            .task {
                guard compra == nil else { return }
                try? await Task.sleep(for: .milliseconds(450))
                foco = .precio
            }
        }
    }

    // MARK: Secciones

    private var encabezado: some View {
        HStack(spacing: 14) {
            MiniaturaProducto(producto: producto, tamano: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(producto.nombre)
                    .font(.headline)
                    .foregroundStyle(Color.cadiva.textPrimary)
                if let ultima = ultimaAnterior, let precio = ultima.precioUnitario {
                    Text("Última vez \(Formato.moneda(precio, moneda)) en \(ultima.tienda ?? "—")")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var seccionPrecio: some View {
        Section {
            LabeledContent("Precio por unidad") {
                HStack(spacing: 8) {
                    if let cambio {
                        IndicadorCambio(cambio: cambio)
                            .transition(.scale.combined(with: .opacity))
                    }
                    TextField(Formato.moneda(0, moneda), text: $precioTexto)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .font(.body.weight(.semibold))
                        .focused($foco, equals: .precio)
                        .accessibilityLabel("Precio por unidad en \(moneda)")
                }
                .animation(.snappy, value: cambio)
            }
            Stepper(value: $unidades.animation(.snappy), in: 1...99) {
                LabeledContent("Unidades") {
                    Text("\(unidades)")
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(unidades)))
                        .foregroundStyle(Color.cadiva.textPrimary)
                }
            }
            DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
        } header: {
            Text("Compra")
        } footer: {
            if intentoGuardar && precio == nil {
                Text("Escribe el precio que pagaste por una unidad.")
                    .foregroundStyle(Color.cadiva.priceUp)
            }
        }
        .celdaCadiva()
    }

    private var seccionTienda: some View {
        Section {
            HStack {
                Image(systemName: "storefront")
                    .foregroundStyle(Color.cadiva.brand)
                    .accessibilityHidden(true)
                TextField("¿Dónde lo compraste?", text: $tienda)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($foco, equals: .tienda)
                    .onSubmit(guardar)
                if !tienda.isEmpty {
                    Button {
                        tienda = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.cadiva.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar tienda")
                }
            }
            if !sugerencias.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sugerencias, id: \.self) { sugerida in
                            Button {
                                withAnimation(.snappy) { tienda = sugerida }
                            } label: {
                                Chip(texto: sugerida, simbolo: "storefront")
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityHint("Usar esta tienda")
                        }
                    }
                    .animation(.snappy, value: sugerencias)
                }
            }
        } header: {
            Text("Tienda")
        } footer: {
            if intentoGuardar && tienda.recortado.isEmpty {
                Text("La tienda es obligatoria.")
                    .foregroundStyle(Color.cadiva.priceUp)
            } else if !tiendasFrecuentes.isEmpty {
                Text("Tus tiendas más frecuentes aparecen primero.")
            }
        }
        .celdaCadiva()
    }

    private var seccionAgotado: some View {
        Section {
            Toggle("Ya se acabó", isOn: $agotado.animation())
            if agotado {
                DatePicker("Se acabó el", selection: $fechaAgotado, in: fecha..., displayedComponents: .date)
            }
        } footer: {
            if agotado {
                let dias = ConsumoCalculator.app.dias(desde: fecha, hasta: fechaAgotado)
                Text("Duró \(Formato.dias(max(dias, 0))).")
            }
        }
        .celdaCadiva()
    }

    // MARK: Estado derivado

    private var precio: Decimal? {
        guard let valor = Formato.decimal(precioTexto), valor >= 0 else { return nil }
        return valor
    }

    /// La compra anterior a esta (o la última, si es nueva), para comparar el precio.
    private var ultimaAnterior: Compra? {
        let compras = producto.comprasOrdenadas.filter { $0.persistentModelID != compra?.persistentModelID }
        return compras.last { $0.fecha <= fecha } ?? compras.last
    }

    private var cambio: Decimal? {
        guard let precio, precio > 0, let anterior = ultimaAnterior?.precioUnitario, anterior > 0 else { return nil }
        return (precio - anterior) / anterior
    }

    private var tiendasFrecuentes: [String] {
        TiendasFrecuentes.ordenar(todas.map { .init(tienda: $0.tienda, fecha: $0.fecha) }, locale: .cadiva)
    }

    private var sugerencias: [String] { TiendasFrecuentes.sugerencias(tiendasFrecuentes, para: tienda) }

    // MARK: Acciones

    private func guardar() {
        withAnimation { intentoGuardar = true }
        let nombreTienda = tienda.recortado
        guard let precio, !nombreTienda.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            foco = precio == nil ? .precio : .tienda
            return
        }
        let cantidad = Decimal(unidades)
        let total = precio * cantidad
        if let compra {
            compra.precioTotal = total
            compra.cantidad = cantidad
            compra.fecha = fecha
            compra.tienda = nombreTienda
            compra.fechaAgotado = agotado ? max(fechaAgotado, fecha) : nil
        } else {
            contexto.insert(Compra(producto: producto, fecha: fecha, precioTotal: total, cantidad: cantidad, tienda: nombreTienda))
        }
        try? contexto.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#if DEBUG
#Preview("Nueva") {
    FormularioCompraView(producto: DatosEjemplo.arroz)
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Editar · oscuro") {
    FormularioCompraView(producto: DatosEjemplo.arroz, compra: DatosEjemplo.arroz.comprasOrdenadas.last)
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
#endif
