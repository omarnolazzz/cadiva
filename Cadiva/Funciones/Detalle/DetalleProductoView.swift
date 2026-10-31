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
