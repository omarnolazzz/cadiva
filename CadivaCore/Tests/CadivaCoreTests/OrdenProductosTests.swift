import Foundation
import Testing
@testable import CadivaCore

@Suite("Orden de productos")
struct OrdenProductosTests {
    typealias Clave = OrdenProductos.Clave

    let arroz = Clave(nombre: "Arroz", fecha: Apoyo.fecha(2026, 10, 10), precio: 20, cambio: 0.1, diasRestantes: 25)
    let cafe = Clave(nombre: "Café", fecha: Apoyo.fecha(2026, 10, 20), precio: 18, cambio: -0.05, diasRestantes: 4)
    let papas = Clave(nombre: "Papas", fecha: Apoyo.fecha(2026, 10, 30), precio: 2, cambio: 0.3)
    let aceite = Clave(nombre: "Aceite", fecha: Apoyo.fecha(2026, 10, 1))

    var todos: [Clave] { [papas, aceite, cafe, arroz] }

    func nombres(_ orden: OrdenProductos) -> [String] {
        orden.ordenar(todos) { $0 }.map(\.nombre)
    }

    @Test func recientesPrimeroLaUltimaCompra() {
        #expect(nombres(.recientes) == ["Papas", "Café", "Arroz", "Aceite"])
    }

    @Test func nombreAlfabetico() {
        #expect(nombres(.nombre) == ["Aceite", "Arroz", "Café", "Papas"])
    }

    @Test func nombreRespetaLosNumeros() {
        let claves = ["Pack 10", "Pack 2"].map { Clave(nombre: $0, fecha: .distantPast) }
        #expect(OrdenProductos.nombre.ordenar(claves) { $0 }.map(\.nombre) == ["Pack 2", "Pack 10"])
    }

    @Test func precioSinDatoVaAlFinalEnAmbosSentidos() {
        #expect(nombres(.precioMenor) == ["Papas", "Café", "Arroz", "Aceite"])
        #expect(nombres(.precioMayor) == ["Arroz", "Café", "Papas", "Aceite"])
    }

    @Test func losQueMasSubieron() {
        #expect(nombres(.masSubieron) == ["Papas", "Arroz", "Café", "Aceite"])
    }

    @Test func porAcabarseLosDeMenosDiasPrimero() {
        // Sin duración: al final y por nombre.
        #expect(nombres(.porAcabarse) == ["Café", "Arroz", "Aceite", "Papas"])
    }

    @Test func empatesPorNombre() {
        let fecha = Apoyo.fecha(2026, 10, 1)
        let claves = ["Zanahoria", "Ajo"].map { Clave(nombre: $0, fecha: fecha, precio: 5) }
        #expect(OrdenProductos.recientes.ordenar(claves) { $0 }.first?.nombre == "Ajo")
        #expect(OrdenProductos.precioMenor.ordenar(claves) { $0 }.first?.nombre == "Ajo")
    }

    @Test func listaVacia() {
        #expect(OrdenProductos.nombre.ordenar([Clave]()) { $0 }.isEmpty)
    }
}
