import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct DetalleProductoView: View {
    let producto: Producto

    @Environment(\.modelContext) private var contexto
    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto

    @State private var editandoProducto = false
    @State private var compraEditada: Compra?
    @State private var registrando = false

    var body: some View {
        let compras = producto.comprasOrdenadas
        let resumen = producto.resumen()
        let cambios = ConsumoCalculator.app.cambiosDePrecio(compras.map(\.datos))

        List {
            Section {
                encabezado(compras: compras, cambio: resumen.cambioPrecio)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            if !compras.isEmpty {
                Section {
                    CuadriculaDatos(compras: compras, resumen: resumen, moneda: moneda)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if compras.count > 1 {
                Section("Precio por unidad") {
                    GraficaPrecio(compras: compras, moneda: moneda)
                }
                .celdaCadiva()
            }

            let tiendas = ResumenTienda.calcular(compras)
            if !tiendas.isEmpty {
                Section {
                    ForEach(tiendas) { tienda in
                        FilaTienda(tienda: tienda, moneda: moneda, esLaMasBarata: tiendas.count > 1 && tienda.id == tiendas.min { $0.precioMinimo < $1.precioMinimo }?.id)
                    }
                } header: {
                    Text("Por tienda")
                } footer: {
                    Text("Último precio por unidad en cada tienda.")
                }
                .celdaCadiva()
            }

            Section {
                if compras.isEmpty {
                    Text("Aún no registras compras de este producto. Toca \"Registrar compra\" para anotar la primera.")
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                ForEach(Array(compras.enumerated().reversed()), id: \.element.persistentModelID) { indice, compra in
                    Button {
                        compraEditada = compra
                    } label: {
                        FilaHistorial(compra: compra, moneda: moneda, cambio: cambios[indice])
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation(.snappy) {
                                contexto.delete(compra)
                                try? contexto.save()
                            }
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Historial de compras")
            } footer: {
                if !compras.isEmpty {
                    Text("Toca una compra para editarla o desliza para borrarla.")
                }
            }
            .celdaCadiva()

            // Espacio para que el botón flotante no tape la última fila.
            Color.clear.frame(height: 64).listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .fondoCadiva()
        .animation(.snappy, value: compras.map(\.persistentModelID))
        .navigationTitle(producto.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editandoProducto = true
                } label: {
                    Label("Editar producto", systemImage: "pencil")
                }
            }
        }
        .overlay(alignment: .bottom) {
            BotonFlotante(titulo: "Registrar compra", simbolo: "cart.badge.plus") { registrando = true }
                .padding(.bottom, 12)
                .entrada(retraso: 0.15)
        }
        .sheet(isPresented: $editandoProducto) { EditarProductoView(producto: producto) }
        .sheet(item: $compraEditada) { FormularioCompraView(producto: producto, compra: $0) }
        .sheet(isPresented: $registrando) { FormularioCompraView(producto: producto) }
        #if DEBUG
        .onAppear { registrando = Demo.valor("--pantalla") == "registro" }
        #endif
    }

    private func encabezado(compras: [Compra], cambio: Decimal?) -> some View {
        VStack(spacing: 14) {
            MiniaturaProducto(producto: producto, tamano: producto.foto == nil ? 88 : 150)
                .entrada()
            VStack(spacing: 6) {
                Text(producto.nombre)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.cadiva.textPrimary)
                Chip(texto: producto.categoria.nombre, simbolo: producto.categoria.simbolo)
            }
            if let ultima = compras.last, let precio = ultima.precioUnitario {
                VStack(spacing: 4) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            precioGrande(precio)
                            IndicadorCambio(cambio: cambio)
                        }
                        VStack(spacing: 6) {
                            precioGrande(precio)
                            IndicadorCambio(cambio: cambio)
                        }
                    }
                    Text("por unidad · \(ultima.tienda ?? "Sin tienda") · \(ultima.fecha.formatted(.relative(presentation: .named).locale(.cadiva)))")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .entrada(retraso: 0.05)
            }
            if let notas = producto.notas, !notas.isEmpty {
                Text(notas)
                    .font(.footnote)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func precioGrande(_ precio: Decimal) -> some View {
        Text(Formato.moneda(precio, moneda))
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Color.cadiva.textPrimary)
            .contentTransition(.numericText(value: precio.double))
    }
}

// MARK: Datos clave

private struct CuadriculaDatos: View {
    let compras: [Compra]
    let resumen: ResumenConsumo
    let moneda: String

    @ScaledMetric(relativeTo: .body) private var anchoMinimo: CGFloat = 150

    var body: some View {
        let precios = compras.compactMap(\.precioUnitario)
        let masBarata = compras.filter { $0.precioUnitario != nil }.min { $0.precioUnitario! < $1.precioUnitario! }
        let unidades = compras.reduce(0) { $0 + $1.unidades }
        let gastado = compras.reduce(Decimal.zero) { $0 + $1.precioTotal }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: anchoMinimo), spacing: 10)], spacing: 10) {
            Tarjeta(titulo: "Más barato", valor: Formato.moneda(masBarata?.precioUnitario, moneda), detalle: masBarata?.tienda, simbolo: "arrow.down.circle.fill", color: Color.cadiva.priceDown)
            Tarjeta(titulo: "Más caro", valor: Formato.moneda(precios.max(), moneda), detalle: nil, simbolo: "arrow.up.circle.fill", color: Color.cadiva.priceUp)
            Tarjeta(titulo: "Promedio", valor: Formato.moneda(resumen.precioUnitarioPromedio, moneda), detalle: "por unidad", simbolo: "equal.circle.fill", color: Color.cadiva.brand)
            Tarjeta(titulo: "Gastado", valor: Formato.moneda(gastado, moneda), detalle: "\(Formato.unidades(unidades)) en \(compras.count == 1 ? "1 compra" : "\(compras.count) compras")", simbolo: "creditcard.fill", color: Color.cadiva.brand)
            if let duracion = resumen.duracionPromedioDias {
                Tarjeta(titulo: "Te dura", valor: Formato.dias(Int(duracion.rounded())), detalle: "en promedio", simbolo: "hourglass", color: Color.cadiva.runningLow)
            }
        }
    }
}

private struct Tarjeta: View {
    let titulo: String
    let valor: String
    let detalle: String?
    let simbolo: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(titulo, systemImage: simbolo)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(valor)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.cadiva.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let detalle {
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cadiva.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: Tiendas

private struct ResumenTienda: Identifiable {
    let id: String
    let nombre: String
    let ultimoPrecio: Decimal
    let precioMinimo: Decimal
    let compras: Int
    let ultimaFecha: Date

    static func calcular(_ compras: [Compra]) -> [ResumenTienda] {
        let agrupadas = Dictionary(grouping: compras.filter { $0.precioUnitario != nil }) {
            ($0.tienda ?? "Sin tienda").lowercased(with: .cadiva)
        }
        return agrupadas.compactMap { clave, compras -> ResumenTienda? in
            let ordenadas = compras.sorted { $0.fecha < $1.fecha }
            guard let ultima = ordenadas.last, let precio = ultima.precioUnitario else { return nil }
            return ResumenTienda(
                id: clave,
                nombre: ultima.tienda ?? "Sin tienda",
                ultimoPrecio: precio,
                precioMinimo: ordenadas.compactMap(\.precioUnitario).min() ?? precio,
                compras: ordenadas.count,
                ultimaFecha: ultima.fecha
            )
        }
        .sorted { $0.ultimaFecha > $1.ultimaFecha }
    }
}

private struct FilaTienda: View {
    let tienda: ResumenTienda
    let moneda: String
    let esLaMasBarata: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .foregroundStyle(esLaMasBarata ? Color.cadiva.priceDown : Color.cadiva.brand)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tienda.nombre)
                        .foregroundStyle(Color.cadiva.textPrimary)
                    if esLaMasBarata {
                        Text("Más barata")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.cadiva.priceDown)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cadiva.priceDown.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(tienda.compras == 1 ? "1 compra" : "\(tienda.compras) compras") · \(Formato.fechaCorta(tienda.ultimaFecha))")
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
            }
            Spacer(minLength: 4)
            Text(Formato.moneda(tienda.ultimoPrecio, moneda))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.cadiva.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Historial

private struct FilaHistorial: View {
    let compra: Compra
    let moneda: String
    let cambio: Decimal?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formato.fechaLarga(compra.fecha))
                    .foregroundStyle(Color.cadiva.textPrimary)
                Label {
                    Text("\(compra.tienda ?? "Sin tienda") · \(Formato.unidades(compra.unidades))")
                } icon: {
                    Image(systemName: "storefront")
                }
                .labelStyle(EtiquetaCompacta())
                .font(.subheadline)
                .foregroundStyle(Color.cadiva.textSecondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formato.moneda(compra.precioUnitario, moneda))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cadiva.textPrimary)
                IndicadorCambio(cambio: cambio)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Editar compra")
    }
}

// MARK: Gráfica

private struct GraficaPrecio: View {
    let compras: [Compra]
    let moneda: String

    @State private var progreso: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private struct Punto: Identifiable {
        let id: Int
        let fecha: Date
        let valor: Double
        let texto: String
        let tienda: String
    }

    private var puntos: [Punto] {
        compras.enumerated().compactMap { indice, compra in
            compra.precioUnitario.map {
                Punto(id: indice, fecha: compra.fecha, valor: $0.double, texto: Formato.moneda($0, moneda), tienda: compra.tienda ?? "")
            }
        }
    }

    var body: some View {
        let puntos = puntos
        let ultimo = puntos.last?.id
        let minimo = puntos.map(\.valor).min() ?? 0
        Chart(puntos) { punto in
            let valor = minimo + (punto.valor - minimo) * progreso
            AreaMark(x: .value("Fecha", punto.fecha), y: .value("Precio", valor))
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.cadiva.brand.opacity(0.12))
            LineMark(x: .value("Fecha", punto.fecha), y: .value("Precio", valor))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(Color.cadiva.brand)
            PointMark(x: .value("Fecha", punto.fecha), y: .value("Precio", valor))
                .symbolSize(punto.id == ultimo ? 110 : 36)
                .foregroundStyle(punto.id == ultimo ? Color.cadiva.brandDeep : Color.cadiva.brand)
                .annotation(position: .top, alignment: .center, spacing: 6) {
                    if punto.id == ultimo {
                        Text(punto.texto)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.cadiva.brand)
                            .opacity(progreso)
                    }
                }
                .accessibilityLabel("\(Formato.fechaLarga(punto.fecha)), \(punto.tienda)")
                .accessibilityValue("\(punto.texto) por unidad")
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(.cadiva))
            }
        }
        .frame(minHeight: 180)
        .padding(.top, 12)
        .onAppear {
            if reducirMovimiento {
                progreso = 1
            } else {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { progreso = 1 }
            }
        }
    }
}

#if DEBUG
#Preview("Claro") {
    NavigationStack {
        DetalleProductoView(producto: DatosEjemplo.arroz)
    }
    .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    NavigationStack {
        DetalleProductoView(producto: DatosEjemplo.producto(llamado: "Café Altomayo 250 g"))
    }
    .modelContainer(DatosEjemplo.contenedor)
    .preferredColorScheme(.dark)
}
#endif
