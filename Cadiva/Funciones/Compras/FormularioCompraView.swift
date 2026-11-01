import CadivaCore
import SwiftData
import SwiftUI
import UIKit

/// Registra una compra de un producto o edita una existente.
/// Cada compra es de un solo producto: se anota el precio por unidad y cuántas unidades se llevaron.
/// Si hubo oferta, se calcula el precio real por unidad y lo que se ahorró.
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

    // Oferta
    @State private var conOferta: Bool
    @State private var tipoOferta: Oferta.Tipo
    @State private var ofertaCantidad: Int
    @State private var ofertaPaga: Int
    @State private var porcentajeTexto: String
    @State private var precioPackTexto: String
    @State private var precioNormalTexto: String

    private enum Campo: Hashable { case precio, precioPack, precioNormal, porcentaje, tienda }

    init(producto: Producto, compra: Compra? = nil) {
        self.producto = producto
        self.compra = compra
        let oferta = compra?.oferta
        let unitario = compra.flatMap(\.precioUnitario)
        // Con lleva y paga, descuento o segunda unidad, el campo de precio es el precio normal.
        let precioEscrito: Decimal? = switch oferta?.tipo {
        case .llevaPaga, .descuento, .segundaUnidad: oferta?.precioNormal
        case .pack: nil
        default: unitario
        }
        func texto(_ valor: Decimal?) -> String { valor.map { Formato.texto($0.redondeado(2)) } ?? "" }
        _precioTexto = State(initialValue: texto(precioEscrito))
        _unidades = State(initialValue: compra?.unidades ?? 1)
        _fecha = State(initialValue: compra?.fecha ?? .now)
        _tienda = State(initialValue: compra?.tienda ?? producto.ultimaCompra?.tienda ?? "")
        _agotado = State(initialValue: compra?.fechaAgotado != nil)
        _fechaAgotado = State(initialValue: compra?.fechaAgotado ?? .now)
        _conOferta = State(initialValue: oferta != nil)
        _tipoOferta = State(initialValue: oferta?.tipo ?? .pack)
        _ofertaCantidad = State(initialValue: oferta?.cantidad ?? 2)
        _ofertaPaga = State(initialValue: oferta?.paga ?? 2)
        _porcentajeTexto = State(initialValue: oferta?.porcentaje.map { Formato.texto($0) } ?? "")
        _precioPackTexto = State(initialValue: texto(oferta?.precioPack))
        _precioNormalTexto = State(initialValue: oferta?.tipo == .pack || oferta?.tipo == .rebajado ? texto(oferta?.precioNormal) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    encabezado
                }
                .listRowBackground(Color.clear)

                seccionPrecio
                seccionOferta
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
                    if foco == .tienda {
                        Button("Guardar", action: guardar).fontWeight(.semibold)
                    } else {
                        Button("Siguiente") { foco = .tienda }
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
            .onChange(of: unidadesMinimas) { _, minimas in
                // "2 por S/ 4" o "3x2" piden llevar al menos esas unidades.
                if unidades < minimas { withAnimation(.snappy) { unidades = minimas } }
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
            if muestraPrecio {
                LabeledContent(etiquetaPrecio) {
                    HStack(spacing: 8) {
                        if let cambio {
                            IndicadorCambio(cambio: cambio)
                                .transition(.scale.combined(with: .opacity))
                        }
                        campoDinero($precioTexto, foco: .precio)
                            .font(.body.weight(.semibold))
                            .accessibilityLabel("\(etiquetaPrecio) en \(moneda)")
                    }
                    .animation(.snappy, value: cambio)
                }
                .transition(.opacity)
            }
            Stepper(value: $unidades.animation(.snappy), in: max(unidadesMinimas, 1)...99) {
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
            if intentoGuardar && muestraPrecio && precio == nil {
                Text("Escribe el precio de una unidad.")
                    .foregroundStyle(Color.cadiva.priceUp)
            }
        }
        .celdaCadiva()
    }

    private var seccionOferta: some View {
        Section {
            Toggle(isOn: $conOferta.animation(.snappy)) {
                Label("Compré con oferta", systemImage: "tag.fill")
                    .symbolEffect(.bounce, value: conOferta)
            }
            .tint(Color.cadiva.priceDown)

            if conOferta {
                Picker("Tipo", selection: $tipoOferta.animation(.snappy)) {
                    ForEach(Oferta.Tipo.allCases) { tipo in
                        Text(Formato.tipoOferta(tipo)).tag(tipo)
                    }
                }
                .pickerStyle(.menu)

                camposOferta
                    .transition(.opacity.combined(with: .move(edge: .top)))

                resumenOferta
                    .transition(.opacity)
            }
        } header: {
            Text("Oferta")
        } footer: {
            if conOferta {
                Text(ayudaOferta)
            }
        }
        .celdaCadiva()
    }

    @ViewBuilder
    private var camposOferta: some View {
        switch tipoOferta {
        case .pack:
            Stepper(value: $ofertaCantidad.animation(.snappy), in: 2...48) {
                LabeledContent("Unidades del pack") {
                    Text("\(ofertaCantidad)").monospacedDigit().foregroundStyle(Color.cadiva.textPrimary)
                }
            }
            LabeledContent("Precio del pack") {
                campoDinero($precioPackTexto, foco: .precioPack)
            }
            LabeledContent("Precio normal c/u") {
                campoDinero($precioNormalTexto, foco: .precioNormal, marcador: "Opcional")
            }
        case .llevaPaga:
            Stepper(value: $ofertaCantidad.animation(.snappy), in: 2...12) {
                LabeledContent("Lleva") {
                    Text("\(ofertaCantidad)").monospacedDigit().foregroundStyle(Color.cadiva.textPrimary)
                }
            }
            .onChange(of: ofertaCantidad) { _, lleva in
                if ofertaPaga >= lleva { ofertaPaga = lleva - 1 }
            }
            Stepper(value: $ofertaPaga.animation(.snappy), in: 1...max(ofertaCantidad - 1, 1)) {
                LabeledContent("Paga") {
                    Text("\(ofertaPaga)").monospacedDigit().foregroundStyle(Color.cadiva.textPrimary)
                }
            }
        case .descuento, .segundaUnidad:
            LabeledContent(tipoOferta == .descuento ? "Descuento" : "Descuento en la 2.ª") {
                HStack(spacing: 4) {
                    TextField("0", text: $porcentajeTexto)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .focused($foco, equals: .porcentaje)
                    Text("%").foregroundStyle(Color.cadiva.textSecondary)
                }
            }
            if tipoOferta == .segundaUnidad {
                HStack(spacing: 8) {
                    ForEach([30, 50, 70], id: \.self) { valor in
                        Button {
                            withAnimation(.snappy) { porcentajeTexto = "\(valor)" }
                        } label: {
                            Chip(texto: "\(valor) %")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .rebajado:
            LabeledContent("Precio normal c/u") {
                campoDinero($precioNormalTexto, foco: .precioNormal)
            }
        }
    }

    /// "Pagas S/ 2.00 c/u · ahorras S/ 1.00 (20 %)", con animación al cambiar.
    @ViewBuilder
    private var resumenOferta: some View {
        if let resultado = resultadoOferta {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pagas por unidad")
                        .font(.caption)
                        .foregroundStyle(Color.cadiva.textSecondary)
                    Text(Formato.moneda(resultado.precioUnitario.redondeado(2), moneda))
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .contentTransition(.numericText(value: resultado.precioUnitario.double))
                }
                Spacer()
                if let ahorro = resultado.ahorroPorUnidad, ahorro > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Ahorras en total")
                            .font(.caption)
                            .foregroundStyle(Color.cadiva.textSecondary)
                        Text(Formato.moneda((ahorro * Decimal(unidades)).redondeado(2), moneda))
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(Color.cadiva.priceDown)
                            .contentTransition(.numericText(value: (ahorro * Decimal(unidades)).double))
                        if let porcentaje = resultado.porcentajeAhorro {
                            Text("\(Formato.porcentaje(porcentaje)) menos")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.cadiva.priceDown)
                        }
                    }
                }
            }
            .animation(.snappy, value: resultado)
            .accessibilityElement(children: .combine)
        } else if intentoGuardar {
            Label("Completa los datos de la oferta.", systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.cadiva.priceUp)
        }
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

    private func campoDinero(_ texto: Binding<String>, foco campo: Campo, marcador: String? = nil) -> some View {
        TextField(marcador ?? Formato.moneda(0, moneda), text: texto)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($foco, equals: campo)
    }

    // MARK: Estado derivado

    private var precio: Decimal? {
        guard let valor = Formato.decimal(precioTexto), valor >= 0 else { return nil }
        return valor
    }

    /// En el pack no se escribe precio por unidad: sale del precio del pack.
    private var muestraPrecio: Bool { !(conOferta && tipoOferta == .pack) }

    private var etiquetaPrecio: String {
        guard conOferta else { return "Precio por unidad" }
        return tipoOferta == .rebajado ? "Precio de oferta c/u" : "Precio normal c/u"
    }

    private var ofertaActual: Oferta? {
        guard conOferta else { return nil }
        switch tipoOferta {
        case .pack:
            return Oferta(
                tipo: .pack, cantidad: ofertaCantidad,
                precioPack: Formato.decimal(precioPackTexto), precioNormal: Formato.decimal(precioNormalTexto)
            )
        case .llevaPaga:
            return Oferta(tipo: .llevaPaga, cantidad: ofertaCantidad, paga: ofertaPaga)
        case .descuento, .segundaUnidad:
            return Oferta(tipo: tipoOferta, porcentaje: Formato.decimal(porcentajeTexto))
        case .rebajado:
            return Oferta(tipo: .rebajado, precioNormal: Formato.decimal(precioNormalTexto))
        }
    }

    private var resultadoOferta: Oferta.Resultado? { ofertaActual?.calcular(precioEscrito: precio) }

    /// Lo que se pagó de verdad por unidad: con oferta, el calculado; sin oferta, el escrito.
    private var precioEfectivo: Decimal? { conOferta ? resultadoOferta?.precioUnitario : precio }

    private var unidadesMinimas: Int { ofertaActual?.unidadesMinimas ?? 1 }

    private var ayudaOferta: String {
        switch tipoOferta {
        case .pack: "Escribe cuántas unidades trae la oferta y cuánto cuesta. Con el precio normal, Cadiva calcula lo que ahorraste."
        case .llevaPaga: "Escribe arriba el precio normal de una unidad."
        case .descuento: "Escribe arriba el precio normal de una unidad y el porcentaje de descuento."
        case .segundaUnidad: "La segunda unidad tiene descuento: Cadiva promedia el precio de las dos."
        case .rebajado: "Escribe arriba el precio rebajado y aquí el precio de siempre."
        }
    }

    /// La compra anterior a esta (o la última, si es nueva), para comparar el precio.
    private var ultimaAnterior: Compra? {
        let compras = producto.comprasOrdenadas.filter { $0.persistentModelID != compra?.persistentModelID }
        return compras.last { $0.fecha <= fecha } ?? compras.last
    }

    private var cambio: Decimal? {
        guard let actual = precioEfectivo, actual > 0, let anterior = ultimaAnterior?.precioUnitario, anterior > 0 else { return nil }
        return (actual - anterior) / anterior
    }

    private var tiendasFrecuentes: [String] {
        TiendasFrecuentes.ordenar(todas.map { .init(tienda: $0.tienda, fecha: $0.fecha) }, locale: .cadiva)
    }

    private var sugerencias: [String] { TiendasFrecuentes.sugerencias(tiendasFrecuentes, para: tienda) }

    // MARK: Acciones

    private func guardar() {
        withAnimation { intentoGuardar = true }
        let nombreTienda = tienda.recortado
        guard let precioEfectivo, !nombreTienda.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if conOferta && resultadoOferta == nil {
                foco = switch tipoOferta {
                case .pack: .precioPack
                case .llevaPaga: .precio
                case .descuento, .segundaUnidad: precio == nil ? .precio : .porcentaje
                case .rebajado: precio == nil ? .precio : .precioNormal
                }
            } else {
                foco = precio == nil ? .precio : .tienda
            }
            return
        }
        let cantidad = Decimal(unidades)
        let total = precioEfectivo * cantidad
        let oferta = zip(ofertaActual, resultadoOferta).map { $0.conPrecioNormal($1) }
        if let compra {
            compra.precioTotal = total
            compra.cantidad = cantidad
            compra.fecha = fecha
            compra.tienda = nombreTienda
            compra.fechaAgotado = agotado ? max(fechaAgotado, fecha) : nil
            compra.oferta = oferta
        } else {
            let nueva = Compra(producto: producto, fecha: fecha, precioTotal: total, cantidad: cantidad, tienda: nombreTienda)
            nueva.oferta = oferta
            contexto.insert(nueva)
        }
        try? contexto.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Las dos opcionales juntas, o nil si falta alguna.
private func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}

#if DEBUG
#Preview("Nueva") {
    FormularioCompraView(producto: DatosEjemplo.arroz)
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Con oferta · oscuro") {
    let papas = DatosEjemplo.producto(llamado: "Papas Lay's 42 g")
    FormularioCompraView(producto: papas, compra: papas.comprasOrdenadas.last)
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
#endif
