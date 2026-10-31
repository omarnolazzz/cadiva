import CadivaCore
import Charts
import SwiftData
import SwiftUI

struct GastoView: View {
    @Query private var compras: [Compra]
    @Query(filter: #Predicate<Producto> { $0.archivado == false }, sort: \Producto.nombre)
    private var productos: [Producto]
    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto

    @State private var periodo: Periodo = .mes

    private let periodosEnGrafica = 6

    var body: some View {
        NavigationStack {
            Group {
                if compras.isEmpty {
                    EstadoVacio(
                        titulo: "Aún no hay gasto",
                        mensaje: "Agrega productos y registra sus compras. Aquí verás cuánto gastas por semana y por mes, y en qué tiendas."
                    )
                } else {
                    contenido
                }
            }
            .fondoCadiva()
            .navigationTitle("Gasto")
        }
    }

    private var contenido: some View {
        let calculadora = GastoCalculator.app
        let registros = compras.map {
            RegistroGasto(fecha: $0.fecha, monto: $0.precioTotal, categoria: $0.producto?.categoria.nombre ?? Categoria.otro.nombre)
        }
        let totales = calculadora.totales(registros, periodo: periodo, ultimos: periodosEnGrafica, hasta: .now)
        let actual = totales.last
        let anterior = totales.dropLast().last
        let categorias = actual.map { calculadora.porCategoria(registros, en: $0.intervalo) } ?? []
        let resumenes = productos.map { ($0, $0.resumen()) }
        let subieron = GastoCalculator.masSubieron(resumenes.map { ($0.0.nombre, $0.1.cambioPrecio) }, limite: 5)

        return List {
            Section {
                Picker("Periodo", selection: $periodo) {
                    Text("Semana").tag(Periodo.semana)
                    Text("Mes").tag(Periodo.mes)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                VStack(alignment: .leading, spacing: 4) {
                    Text(periodo == .semana ? "Esta semana" : "Este mes")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                    Text(Formato.moneda(actual?.total ?? 0, moneda))
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .minimumScaleFactor(0.7)
                    if let anterior {
                        Text("\(periodo == .semana ? "La semana pasada" : "El mes pasado"): \(Formato.moneda(anterior.total, moneda))")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Color.cadiva.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)

                GraficaPeriodos(totales: totales, periodo: periodo, moneda: moneda)
            }
            .celdaCadiva()

            Section {
                if categorias.isEmpty {
                    Text("Sin compras en este periodo.")
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                let maximo = categorias.first?.total.double ?? 1
                ForEach(categorias, id: \.categoria) { categoria in
                    BarraTotal(
                        nombre: categoria.categoria,
                        simbolo: Categoria(rawValue: categoria.categoria)?.simbolo ?? Categoria.otro.simbolo,
                        total: Formato.moneda(categoria.total, moneda),
                        fraccion: maximo > 0 ? categoria.total.double / maximo : 0
                    )
                }
            } header: {
                Text("Por categoría")
            }
            .celdaCadiva()

            Section {
                if subieron.isEmpty {
                    Text("Ningún producto subió de precio en su última compra.")
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                ForEach(subieron, id: \.nombre) { cambio in
                    LabeledContent {
                        IndicadorCambio(cambio: cambio.cambio)
                    } label: {
                        Text(cambio.nombre).foregroundStyle(Color.cadiva.textPrimary)
                    }
                }
            } header: {
                Text("Los que más subieron")
            } footer: {
                Text("Precio unitario de la última compra contra la anterior.")
            }
            .celdaCadiva()

            let tiendas = actual.map { porTienda(en: $0.intervalo) } ?? []
            if !tiendas.isEmpty {
                Section {
                    let maximo = tiendas.first?.total.double ?? 1
                    ForEach(tiendas, id: \.nombre) { tienda in
                        BarraTotal(
                            nombre: tienda.nombre,
                            simbolo: "storefront",
                            total: Formato.moneda(tienda.total, moneda),
                            fraccion: maximo > 0 ? tienda.total.double / maximo : 0
                        )
                    }
                } header: {
                    Text("Por tienda")
                }
                .celdaCadiva()
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: periodo)
    }

    private struct TotalTienda {
        var nombre: String
        var total: Decimal
    }

    private func porTienda(en intervalo: DateInterval) -> [TotalTienda] {
        var totales: [String: TotalTienda] = [:]
        for compra in compras where intervalo.contains(compra.fecha) {
            let nombre = compra.tienda?.recortado ?? ""
            let clave = nombre.isEmpty ? "—" : nombre.lowercased(with: .cadiva)
            var actual = totales[clave] ?? TotalTienda(nombre: nombre.isEmpty ? "Sin tienda" : nombre, total: 0)
            actual.total += compra.precioTotal
            totales[clave] = actual
        }
        return totales.values.sorted { $0.total > $1.total }
    }
}

#if DEBUG
#Preview("Claro") {
    GastoView()
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    GastoView()
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}

#Preview("Vacío") {
    GastoView()
        .modelContainer(DatosEjemplo.vacio())
}
#endif
