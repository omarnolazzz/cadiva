import Foundation
import Testing
@testable import CadivaCore

@Suite("Ofertas")
struct OfertaTests {
    func d(_ texto: String) -> Decimal { Decimal(string: texto)! }

    @Test func packDosPorCuatro() throws {
        // La oferta del snack: 2 por S/ 4.00, normal S/ 2.50.
        let oferta = Oferta(tipo: .pack, cantidad: 2, precioPack: 4, precioNormal: d("2.50"))
        let resultado = try #require(oferta.calcular(precioEscrito: nil))
        #expect(resultado.precioUnitario == 2)
        #expect(resultado.ahorroPorUnidad == d("0.5"))
        #expect(resultado.porcentajeAhorro == d("0.2"))
        #expect(oferta.unidadesMinimas == 2)
        #expect(oferta.ahorro(precioTotal: 4, unidades: 2) == 1)
    }

    @Test func packSinPrecioNormalNoSabeElAhorro() throws {
        let resultado = try #require(Oferta(tipo: .pack, cantidad: 3, precioPack: 10).calcular(precioEscrito: nil))
        #expect(resultado.precioNormal == nil)
        #expect(resultado.ahorroPorUnidad == nil)
        #expect(resultado.porcentajeAhorro == nil)
    }

    @Test func llevaTresPagaDos() throws {
        let oferta = Oferta(tipo: .llevaPaga, cantidad: 3, paga: 2)
        let resultado = try #require(oferta.calcular(precioEscrito: 6))
        #expect(resultado.precioUnitario == 4)
        #expect(resultado.precioNormal == 6)
        #expect(oferta.unidadesMinimas == 3)
    }

    @Test func descuentoPorcentual() throws {
        let resultado = try #require(Oferta(tipo: .descuento, porcentaje: 20).calcular(precioEscrito: 50))
        #expect(resultado.precioUnitario == 40)
        #expect(resultado.porcentajeAhorro == d("0.2"))
    }

    @Test func segundaUnidadAlCincuenta() throws {
        // Una a S/ 10 y la otra a S/ 5: S/ 7.50 cada una.
        let oferta = Oferta(tipo: .segundaUnidad, porcentaje: 50)
        let resultado = try #require(oferta.calcular(precioEscrito: 10))
        #expect(resultado.precioUnitario == d("7.5"))
        #expect(oferta.unidadesMinimas == 2)
    }

    @Test func precioRebajado() throws {
        let resultado = try #require(Oferta(tipo: .rebajado, precioNormal: 5).calcular(precioEscrito: 4))
        #expect(resultado.precioUnitario == 4)
        #expect(resultado.ahorroPorUnidad == 1)
    }

    @Test func datosQueNoTienenSentido() {
        #expect(Oferta(tipo: .pack, cantidad: 1, precioPack: 4).calcular(precioEscrito: nil) == nil)
        #expect(Oferta(tipo: .pack, cantidad: 2).calcular(precioEscrito: nil) == nil)
        #expect(Oferta(tipo: .llevaPaga, cantidad: 2, paga: 2).calcular(precioEscrito: 5) == nil)
        #expect(Oferta(tipo: .llevaPaga, cantidad: 3, paga: 2).calcular(precioEscrito: nil) == nil)
        #expect(Oferta(tipo: .descuento, porcentaje: 0).calcular(precioEscrito: 5) == nil)
        #expect(Oferta(tipo: .descuento, porcentaje: 100).calcular(precioEscrito: 5) == nil)
        #expect(Oferta(tipo: .rebajado, precioNormal: 3).calcular(precioEscrito: 4) == nil)
    }

    @Test func conPrecioNormalLoGuarda() throws {
        let oferta = Oferta(tipo: .llevaPaga, cantidad: 3, paga: 2)
        let resultado = try #require(oferta.calcular(precioEscrito: 6))
        #expect(oferta.conPrecioNormal(resultado).precioNormal == 6)
    }

    @Test func idaYVueltaEnJSONConservaCentavos() throws {
        let oferta = Oferta(tipo: .pack, cantidad: 2, precioPack: d("4.90"), precioNormal: d("2.65"))
        let json = try #require(oferta.json)
        #expect(json.contains(#""precio_pack":"4.9""#))
        #expect(Oferta(json: json) == oferta)
        #expect(Oferta(json: nil) == nil)
        #expect(Oferta(json: "no es json") == nil)
    }

    @Test func compraNubeLlevaLaOferta() throws {
        let oferta = Oferta(tipo: .descuento, porcentaje: 15, precioNormal: 10).json
        let compra = CompraNube(
            id: UUID(), productoId: nil, fecha: .now, precioTotal: d("8.5"), cantidad: 1,
            tienda: "Tottus", fechaAgotado: nil, oferta: oferta
        )
        let datos = try FormatoNube.codificador.encode(compra)
        #expect(try FormatoNube.decodificador.decode(CompraNube.self, from: datos).oferta == oferta)
        let sinOferta = CompraNube(id: UUID(), productoId: nil, fecha: .now, precioTotal: 1, cantidad: 1, tienda: nil, fechaAgotado: nil)
        let json = try #require(String(data: FormatoNube.codificador.encode(sinOferta), encoding: .utf8))
        #expect(json.contains(#""oferta":null"#))
    }

    @Test func csvIncluyeOfertaYAhorro() {
        let fila = FilaCSV(
            producto: "Papas Lay's", categoria: "Snacks", fecha: Apoyo.fecha(2026, 10, 31), precioTotal: 4, cantidad: 2,
            tienda: "Tambo", fechaAgotado: nil, duracionRealDias: nil, oferta: "2 por S/ 4.00", ahorro: 1
        )
        let lineas = ExportadorCSV.csv([fila], calendar: Apoyo.calendario()).split(separator: "\n").map(String.init)
        #expect(lineas[1] == "Papas Lay's,Snacks,2026-10-31,4,2,2,Tambo,,,2 por S/ 4.00,1")
    }
}
