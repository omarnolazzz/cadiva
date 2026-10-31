import Foundation
import Testing
@testable import CadivaCore

@Suite("Duración aproximada")
struct DuracionAproximadaTests {
    let calculadora = ConsumoCalculator(calendar: Apoyo.calendario())

    func compra(_ dia: Int, mes: Int = 10, unidades: Decimal = 1, agotado: Date? = nil) -> CompraDatos {
        CompraDatos(fecha: Apoyo.fecha(2026, mes, dia), precioTotal: 20 * unidades, cantidad: unidades, fechaAgotado: agotado)
    }

    @Test func unaSolaCompraNoAlcanza() {
        #expect(calculadora.duracionAproximada(compras: [compra(1)], hoy: Apoyo.fecha(2026, 10, 5)) == nil)
        #expect(calculadora.duracionAproximada(compras: [], hoy: Apoyo.fecha(2026, 10, 5)) == nil)
    }

    @Test func usaLosDiasEntreCompras() throws {
        // Shampoo comprado el 1, el 21 y el 10 de noviembre: dura ~20 días.
        let estimacion = try #require(calculadora.duracionAproximada(
            compras: [compra(1), compra(21), compra(10, mes: 11)], hoy: Apoyo.fecha(2026, 11, 15)
        ))
        #expect(estimacion.diasPorUnidad == 20)
        #expect(estimacion.muestras == 2)
        #expect(estimacion.diasTotales == 20)
        #expect(estimacion.diasRestantes == 15)
        #expect(estimacion.progresoRestante == 0.75)
        #expect(estimacion.fechaFin == Apoyo.calendario().startOfDay(for: Apoyo.fecha(2026, 11, 30)))
        #expect(!estimacion.terminada)
    }

    @Test func dividePorLasUnidadesCompradas() throws {
        // Se llevaron 2 y la siguiente compra fue 30 días después: 15 días por unidad.
        // La última compra es de 3 unidades: debería durar 45 días.
        let estimacion = try #require(calculadora.duracionAproximada(
            compras: [compra(1, unidades: 2), compra(31, unidades: 3)], hoy: Apoyo.fecha(2026, 10, 31)
        ))
        #expect(estimacion.diasPorUnidad == 15)
        #expect(estimacion.diasTotales == 45)
        #expect(estimacion.diasRestantes == 45)
    }

    @Test func preferiLaFechaMarcadaComoAcabada() throws {
        // Se acabó a los 10 días aunque la siguiente compra fue a los 30.
        let estimacion = try #require(calculadora.duracionAproximada(
            compras: [compra(1, agotado: Apoyo.fecha(2026, 10, 11)), compra(31)], hoy: Apoyo.fecha(2026, 10, 31)
        ))
        #expect(estimacion.diasPorUnidad == 10)
    }

    @Test func unaCompraMarcadaComoAcabadaYaSirve() throws {
        let estimacion = try #require(calculadora.duracionAproximada(
            compras: [compra(1, agotado: Apoyo.fecha(2026, 10, 8))], hoy: Apoyo.fecha(2026, 10, 20)
        ))
        #expect(estimacion.diasPorUnidad == 7)
        #expect(estimacion.terminada)
        #expect(estimacion.diasRestantes == 0)
        #expect(estimacion.progresoRestante == 0)
    }

    @Test func comprasDelMismoDiaNoCuentan() {
        #expect(calculadora.duracionAproximada(compras: [compra(5), compra(5)], hoy: Apoyo.fecha(2026, 10, 6)) == nil)
    }

    @Test func promediaSoloLasTresMasRecientes() throws {
        // Intervalos: 40, 10, 10, 10 días. Solo cuentan los últimos tres.
        let compras = [compra(1, mes: 8), compra(10, mes: 9), compra(20, mes: 9), compra(30, mes: 9), compra(10, mes: 10)]
        let estimacion = try #require(calculadora.duracionAproximada(compras: compras.shuffled(), hoy: Apoyo.fecha(2026, 10, 10)))
        #expect(estimacion.diasPorUnidad == 10)
        #expect(estimacion.muestras == 3)
    }

    @Test func pasadaLaFechaQuedaNegativoYProgresoCero() throws {
        let estimacion = try #require(calculadora.duracionAproximada(
            compras: [compra(1), compra(11)], hoy: Apoyo.fecha(2026, 10, 25)
        ))
        #expect(estimacion.diasRestantes == -4)
        #expect(estimacion.progresoRestante == 0)
    }
}

@Suite("Clasificador de seguimiento")
struct ClasificadorSeguimientoTests {
    @Test(arguments: [
        ("Shampoo Head & Shoulders 375 ml", "Higiene personal"),
        ("Papel higiénico Elite 24 rollos", "Higiene personal"),
        ("Servilletas Nova", "Otro"),
        ("Toallas húmedas Huggies", "Otro"),
        ("Detergente Ariel 4 kg", "Limpieza"),
        ("Arroz Costeño 5 kg", "Despensa"),
        ("Café Altomayo 250 g", "Bebidas"),
        ("Croquetas Ricocan 15 kg", "Mascotas"),
        ("Pañales Babysec XG", "Otro"),
        ("Yogurt Gloria x6", "Despensa"),
        ("Esponjas Scotch-Brite", "Otro"),
        ("Cualquier cosa de limpieza", "Limpieza"),
    ])
    func productosQueDuran(nombre: String, categoria: String) {
        #expect(ClasificadorSeguimiento.sugerir(nombre: nombre, categoria: categoria) == .duracion)
    }

    @Test(arguments: [
        ("Papas Lay's 42 g", "Snacks"),
        ("Galletas Oreo", "Despensa"),
        ("Chocolate Sublime", "Snacks"),
        ("Gaseosa Inca Kola 500 ml", "Bebidas"),
        ("Chicles Trident", "Otro"),
        ("Pilas", "Otro"),
        ("Helado D'Onofrio", "Despensa"),
    ])
    func productosDeConsumoInmediato(nombre: String, categoria: String) {
        #expect(ClasificadorSeguimiento.sugerir(nombre: nombre, categoria: categoria) == .soloPrecio)
    }
}
