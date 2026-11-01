import Foundation
import Testing
@testable import CadivaCore

@Suite("ExportadorCSV")
struct ExportadorCSVTests {
    let calendario = Apoyo.calendario()

    @Test func encabezadoYFilaBasica() {
        let fila = FilaCSV(
            producto: "Papel higiénico", categoria: "Higiene personal",
            fecha: Apoyo.fecha(2026, 10, 1, 23), precioTotal: Decimal(string: "189.90")!, cantidad: 12,
            tienda: "Costco", fechaAgotado: Apoyo.fecha(2026, 10, 21), duracionRealDias: 20
        )
        let lineas = ExportadorCSV.csv([fila], calendar: calendario).split(separator: "\n").map(String.init)
        #expect(lineas[0] == "\u{FEFF}producto,categoria,fecha,precio_total,cantidad,precio_unitario,tienda,fecha_agotado,duracion_real_dias,oferta,ahorro")
        #expect(lineas[1] == "Papel higiénico,Higiene personal,2026-10-01,189.9,12,15.825,Costco,2026-10-21,20,,")
    }

    @Test func escapaComasComillasYSaltosDeLinea() {
        #expect(ExportadorCSV.escapar("Galletas, surtidas") == "\"Galletas, surtidas\"")
        #expect(ExportadorCSV.escapar("Café \"de olla\"") == "\"Café \"\"de olla\"\"\"")
        #expect(ExportadorCSV.escapar("dos\nlíneas") == "\"dos\nlíneas\"")
        #expect(ExportadorCSV.escapar("simple") == "simple")
    }

    @Test func camposOpcionalesVaciosYCantidadCero() {
        let fila = FilaCSV(
            producto: "Snacks", categoria: "Snacks",
            fecha: Apoyo.fecha(2026, 10, 1), precioTotal: 45, cantidad: 0,
            tienda: nil, fechaAgotado: nil, duracionRealDias: nil
        )
        let lineas = ExportadorCSV.csv([fila], calendar: calendario).split(separator: "\n").map(String.init)
        #expect(lineas[1] == "Snacks,Snacks,2026-10-01,45,0,,,,,,")
    }

    @Test func precioUnitarioSeRedondeaACuatroDecimales() {
        let fila = FilaCSV(
            producto: "Café", categoria: "Bebidas",
            fecha: Apoyo.fecha(2026, 10, 1), precioTotal: 100, cantidad: 3,
            tienda: nil, fechaAgotado: nil, duracionRealDias: nil
        )
        #expect(ExportadorCSV.csv([fila], calendar: calendario).contains(",100,3,33.3333,"))
    }
}
