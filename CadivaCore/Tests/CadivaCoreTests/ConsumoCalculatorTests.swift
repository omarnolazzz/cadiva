import Foundation
import Testing
@testable import CadivaCore

@Suite("ConsumoCalculator")
struct ConsumoCalculatorTests {
    let calendario = Apoyo.calendario()
    var calculadora: ConsumoCalculator { ConsumoCalculator(calendar: calendario) }
    var hoy: Date { Apoyo.fecha(2026, 10, 30) }

    // MARK: Sin compras

    @Test func sinComprasDevuelveResumenVacio() {
        let resumen = calculadora.resumen(compras: [], duracionInicial: nil, hoy: hoy)
        #expect(resumen == .vacio)
        #expect(resumen.compraActiva == nil)
        #expect(resumen.diasRestantes == nil)
        #expect(resumen.costoPorDia == nil)
        #expect(resumen.gastoMensualEstimado == nil)
    }

    @Test func sinComprasConservaLaEstimacionInicialPeroNoHayDiasRestantes() {
        let resumen = calculadora.resumen(compras: [], duracionInicial: 14, hoy: hoy)
        #expect(resumen.duracionEstimadaDias == 14)
        #expect(resumen.diasRestantes == nil)
        #expect(resumen.fechaRecompra == nil)
        #expect(resumen.progresoRestante == nil)
    }

    // MARK: Una sola compra

    @Test func unaSolaCompraSinEstimacionInicial() {
        let compra = Apoyo.compra(Apoyo.fecha(2026, 10, 27), precio: 120, cantidad: 12)
        let resumen = calculadora.resumen(compras: [compra], duracionInicial: nil, hoy: hoy)
        #expect(resumen.compraActiva == compra)
        #expect(resumen.ultimaCompra == compra)
        #expect(resumen.precioUnitarioActual == 10)
        #expect(resumen.cambioPrecio == nil)
        #expect(resumen.duracionEstimadaDias == nil)
        #expect(resumen.diasDesdeCompra == 3)
        #expect(resumen.diasRestantes == nil)
        #expect(resumen.fechaRecompra == nil)
        #expect(resumen.costoPorDia == nil)
    }

    @Test func unaSolaCompraUsaLaEstimacionInicial() {
        let compra = Apoyo.compra(Apoyo.fecha(2026, 10, 27, 9), precio: 150, cantidad: 4)
        let resumen = calculadora.resumen(compras: [compra], duracionInicial: 10, hoy: hoy)
        #expect(resumen.duracionEstimadaDias == 10)
        #expect(resumen.diasDesdeCompra == 3)
        #expect(resumen.diasRestantes == 7)
        #expect(resumen.fechaRecompra == Apoyo.fecha(2026, 11, 6, 0))
        #expect(resumen.progresoRestante == 0.7)
        #expect(resumen.costoPorDia == 15)
        #expect(resumen.gastoMensualEstimado == Decimal(string: "456.6"))
    }

    @Test func diasRestantesPuedenSerNegativosYElProgresoSeQuedaEnCero() {
        let compra = Apoyo.compra(Apoyo.fecha(2026, 10, 10), precio: 50)
        let resumen = calculadora.resumen(compras: [compra], duracionInicial: 5, hoy: hoy)
        #expect(resumen.diasRestantes == -15)
        #expect(resumen.progresoRestante == 0)
    }

    // MARK: Compras sin duración real

    @Test func comprasSinDuracionRealUsanLaEstimacionInicialYLaActivaEsLaMasReciente() {
        let vieja = Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 100)
        let reciente = Apoyo.compra(Apoyo.fecha(2026, 10, 20), precio: 110)
        let resumen = calculadora.resumen(compras: [reciente, vieja], duracionInicial: 20, hoy: hoy)
        #expect(resumen.compraActiva == reciente)
        #expect(resumen.duracionEstimadaDias == 20)
        #expect(resumen.diasRestantes == 10)
        #expect(resumen.duracionPromedioDias == nil)
    }

    @Test func comprasSinDuracionRealNiEstimacionNoInventanUnaDuracion() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 100),
            Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 100),
        ]
        let resumen = calculadora.resumen(compras: compras, duracionInicial: nil, hoy: hoy)
        #expect(resumen.duracionEstimadaDias == nil)
        #expect(resumen.diasRestantes == nil)
        #expect(resumen.costoPorDia == nil)
    }

    // MARK: Duración estimada

    @Test func duracionEstimadaPromediaLasUltimasTresDuracionesReales() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 6, 1), precio: 10, agotado: Apoyo.fecha(2026, 6, 11)),  // 10
            Apoyo.compra(Apoyo.fecha(2026, 7, 1), precio: 10, agotado: Apoyo.fecha(2026, 7, 21)),  // 20
            Apoyo.compra(Apoyo.fecha(2026, 8, 1), precio: 10, agotado: Apoyo.fecha(2026, 8, 31)),  // 30
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 10, agotado: Apoyo.fecha(2026, 10, 11)), // 40
            Apoyo.compra(Apoyo.fecha(2026, 10, 25), precio: 10),
        ]
        let resumen = calculadora.resumen(compras: compras.shuffled(), duracionInicial: 5, hoy: hoy)
        #expect(resumen.duracionEstimadaDias == 30)
        #expect(resumen.diasRestantes == 25)
        #expect(resumen.duracionPromedioDias == 25)
    }

    @Test func duracionEstimadaRedondeaAlEnteroMasCercano() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 8, 1), precio: 10, agotado: Apoyo.fecha(2026, 8, 11)), // 10
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 10, agotado: Apoyo.fecha(2026, 9, 12)), // 11
        ]
        #expect(calculadora.duracionEstimada(compras: compras, inicial: nil) == 11)
    }

    @Test func laDuracionRealTieneMasPesoQueLaEstimacionInicial() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 10, agotado: Apoyo.fecha(2026, 9, 9)),
        ]
        #expect(calculadora.duracionEstimada(compras: compras, inicial: 30) == 8)
    }

    @Test func fechaAgotadoAnteriorALaCompraNoCuentaComoDuracion() {
        let compra = Apoyo.compra(Apoyo.fecha(2026, 9, 10), precio: 10, agotado: Apoyo.fecha(2026, 9, 5))
        #expect(calculadora.duracionReal(de: compra) == nil)
    }

    @Test func compraActivaIgnoraLasAgotadasAunqueSeanMasRecientes() {
        let activa = Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 10)
        let agotada = Apoyo.compra(Apoyo.fecha(2026, 10, 5), precio: 10, agotado: Apoyo.fecha(2026, 10, 9))
        #expect(calculadora.compraActiva([activa, agotada]) == activa)
        #expect(calculadora.compraActiva([agotada]) == nil)
    }

    // MARK: Precio

    @Test func precioIgualDaCambioCero() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 60, cantidad: 6),
            Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 40, cantidad: 4),
        ]
        let resumen = calculadora.resumen(compras: compras, duracionInicial: nil, hoy: hoy)
        #expect(resumen.precioUnitarioActual == 10)
        #expect(resumen.cambioPrecio == 0)
    }

    @Test func cambioDePrecioCompararElPrecioUnitarioContraLaCompraAnterior() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 8, 1), precio: 100, cantidad: 10),  // 10
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 120, cantidad: 10),  // 12
            Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 108, cantidad: 12), // 9
        ]
        #expect(calculadora.cambiosDePrecio(compras) == [nil, Decimal(string: "0.2"), Decimal(string: "-0.25")])
        let resumen = calculadora.resumen(compras: compras, duracionInicial: nil, hoy: hoy)
        #expect(resumen.cambioPrecio == Decimal(string: "-0.25"))
    }

    @Test func compraMasBarataYPrecioPromedio() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 8, 1), precio: 100, cantidad: 10, tienda: "Walmart"),
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 80, cantidad: 10, tienda: "Costco"),
            Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 120, cantidad: 10, tienda: "Oxxo"),
        ]
        let resumen = calculadora.resumen(compras: compras, duracionInicial: nil, hoy: hoy)
        #expect(resumen.compraMasBarata?.tienda == "Costco")
        #expect(resumen.precioUnitarioPromedio == 10)
    }

    // MARK: División entre cero

    @Test func cantidadCeroNoTienePrecioUnitario() {
        let compra = Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 50, cantidad: 0)
        #expect(calculadora.precioUnitario(de: compra) == nil)
    }

    @Test func cambioDePrecioContraUnaCompraSinPrecioUnitarioEsNulo() {
        let sinCantidad = Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 50, cantidad: 0)
        let gratis = Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 0, cantidad: 3)
        let actual = Apoyo.compra(Apoyo.fecha(2026, 10, 1), precio: 50, cantidad: 5)
        #expect(calculadora.cambioPrecio(de: actual, anterior: sinCantidad) == nil)
        #expect(calculadora.cambioPrecio(de: actual, anterior: gratis) == nil)
        #expect(calculadora.cambioPrecio(de: sinCantidad, anterior: actual) == nil)
    }

    @Test func duracionDeCeroDiasNoProduceCostoPorDia() {
        let mismaFecha = Apoyo.compra(
            Apoyo.fecha(2026, 10, 1, 9), precio: 30, agotado: Apoyo.fecha(2026, 10, 1, 21)
        )
        #expect(calculadora.duracionReal(de: mismaFecha) == 0)
        #expect(calculadora.costoPorDia(de: mismaFecha, duracionEstimada: nil) == nil)
        #expect(calculadora.costoPorDia(de: Apoyo.compra(hoy, precio: 30), duracionEstimada: 0) == nil)
    }

    @Test func estimacionInicialDeCeroNoDivideEntreCero() {
        let compra = Apoyo.compra(Apoyo.fecha(2026, 10, 30), precio: 30)
        let resumen = calculadora.resumen(compras: [compra], duracionInicial: 0, hoy: hoy)
        #expect(resumen.diasRestantes == 0)
        #expect(resumen.progresoRestante == 0)
        #expect(resumen.costoPorDia == nil)
    }

    @Test func costoPorDiaPonderaLasComprasTerminadas() {
        let compras = [
            Apoyo.compra(Apoyo.fecha(2026, 8, 1), precio: 100, agotado: Apoyo.fecha(2026, 8, 11)), // 10 días
            Apoyo.compra(Apoyo.fecha(2026, 9, 1), precio: 200, agotado: Apoyo.fecha(2026, 9, 21)), // 20 días
            Apoyo.compra(Apoyo.fecha(2026, 10, 25), precio: 500),
        ]
        let resumen = calculadora.resumen(compras: compras, duracionInicial: nil, hoy: hoy)
        #expect(resumen.costoPorDia == 10)
    }

    // MARK: Husos horarios

    @Test func losDiasSeCuentanEnElHusoDelCalendario() {
        let mexico = Apoyo.calendario("America/Mexico_City")
        let compra = Apoyo.compra(
            Apoyo.fecha(2026, 1, 1, 23, 30, en: mexico), precio: 70,
            agotado: Apoyo.fecha(2026, 1, 8, 8, 0, en: mexico)
        )
        #expect(ConsumoCalculator(calendar: mexico).duracionReal(de: compra) == 7)
        // Los mismos instantes vistos en UTC caen el 2 y el 8 de enero.
        #expect(ConsumoCalculator(calendar: Apoyo.calendario("UTC")).duracionReal(de: compra) == 6)
    }

    @Test func elCambioDeHorarioNoAcortaLosDias() {
        let nuevaYork = Apoyo.calendario("America/New_York")
        let compra = Apoyo.compra(
            Apoyo.fecha(2026, 3, 7, 12, en: nuevaYork), precio: 10,
            agotado: Apoyo.fecha(2026, 3, 9, 11, en: nuevaYork)
        )
        #expect(ConsumoCalculator(calendar: nuevaYork).duracionReal(de: compra) == 2)
    }

    @Test func comprasRegistradasEnOtroHusoSeComparanConHoyLocal() {
        let tokio = Apoyo.calendario("Asia/Tokyo")
        let mexico = Apoyo.calendario("America/Mexico_City")
        // 31 oct 08:00 en Tokio = 30 oct 17:00 en Ciudad de México.
        let compra = Apoyo.compra(Apoyo.fecha(2026, 10, 31, 8, en: tokio), precio: 10)
        let resumen = ConsumoCalculator(calendar: mexico)
            .resumen(compras: [compra], duracionInicial: 4, hoy: Apoyo.fecha(2026, 10, 30, 20, en: mexico))
        #expect(resumen.diasDesdeCompra == 0)
        #expect(resumen.diasRestantes == 4)
        #expect(resumen.fechaRecompra == Apoyo.fecha(2026, 11, 3, 0, en: mexico))
    }
}
