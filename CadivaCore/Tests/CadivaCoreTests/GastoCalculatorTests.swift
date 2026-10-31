import Foundation
import Testing
@testable import CadivaCore

@Suite("GastoCalculator")
struct GastoCalculatorTests {
    let calendario = Apoyo.calendario()
    var calculadora: GastoCalculator { GastoCalculator(calendar: calendario) }

    var registros: [RegistroGasto] {
        [
            RegistroGasto(fecha: Apoyo.fecha(2026, 10, 26), monto: 100, categoria: "Limpieza"), // lunes
            RegistroGasto(fecha: Apoyo.fecha(2026, 10, 29), monto: 50, categoria: "Snacks"),
            RegistroGasto(fecha: Apoyo.fecha(2026, 10, 30), monto: 25, categoria: "Snacks"),
            RegistroGasto(fecha: Apoyo.fecha(2026, 10, 25), monto: 40, categoria: "Bebidas"),   // domingo anterior
            RegistroGasto(fecha: Apoyo.fecha(2026, 9, 30), monto: 300, categoria: "Despensa"),
        ]
    }

    @Test func laSemanaEmpiezaEnLunes() {
        let intervalo = calculadora.intervalo(.semana, contiene: Apoyo.fecha(2026, 10, 30))
        #expect(intervalo.start == Apoyo.fecha(2026, 10, 26, 0))
        #expect(intervalo.end == Apoyo.fecha(2026, 11, 2, 0))
    }

    @Test func totalPorSemanaYPorMes() {
        let hoy = Apoyo.fecha(2026, 10, 30)
        #expect(calculadora.total(registros, en: calculadora.intervalo(.semana, contiene: hoy)) == 175)
        #expect(calculadora.total(registros, en: calculadora.intervalo(.mes, contiene: hoy)) == 215)
    }

    @Test func totalesDeLosUltimosPeriodosIncluyenLosVacios() {
        let totales = calculadora.totales(registros, periodo: .mes, ultimos: 3, hasta: Apoyo.fecha(2026, 10, 30))
        #expect(totales.map(\.total) == [0, 300, 215])
        #expect(totales.last?.intervalo.start == Apoyo.fecha(2026, 10, 1, 0))
    }

    @Test func porCategoriaOrdenaDeMayorAMenor() {
        let intervalo = calculadora.intervalo(.mes, contiene: Apoyo.fecha(2026, 10, 30))
        let categorias = calculadora.porCategoria(registros, en: intervalo)
        #expect(categorias.map(\.categoria) == ["Limpieza", "Snacks", "Bebidas"])
        #expect(categorias.map(\.total) == [100, 75, 40])
    }

    @Test func sinRegistrosTodoEsCero() {
        let intervalo = calculadora.intervalo(.semana, contiene: Apoyo.fecha(2026, 10, 30))
        #expect(calculadora.total([], en: intervalo) == 0)
        #expect(calculadora.porCategoria([], en: intervalo).isEmpty)
    }

    @Test func masSubieronSoloIncluyeAumentosOrdenados() {
        let cambios: [(String, Decimal?)] = [
            ("Café", Decimal(string: "0.12")), ("Papel", Decimal(string: "0.30")),
            ("Detergente", 0), ("Snacks", Decimal(string: "-0.1")), ("Toallas", nil),
        ]
        let resultado = GastoCalculator.masSubieron(cambios, limite: 5)
        #expect(resultado.map(\.nombre) == ["Papel", "Café"])
    }
}
