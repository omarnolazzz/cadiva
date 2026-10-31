import Foundation
import Testing
@testable import CadivaCore

@Suite("TiendasFrecuentes")
struct TiendasFrecuentesTests {
    let peru = Locale(identifier: "es_PE")

    func registro(_ tienda: String?, _ dia: Int) -> TiendasFrecuentes.Registro {
        .init(tienda: tienda, fecha: Apoyo.fecha(2026, 10, dia))
    }

    @Test func ordenaPorFrecuenciaYLuegoPorLaMasReciente() {
        let tiendas = TiendasFrecuentes.ordenar([
            registro("Tottus", 1), registro("Plaza Vea", 2), registro("Makro", 9),
            registro("Plaza Vea", 3), registro("Tottus", 4), registro("Plaza Vea", 5),
        ], locale: peru)
        // Plaza Vea 3 veces; Tottus 2; Makro 1.
        #expect(tiendas == ["Plaza Vea", "Tottus", "Makro"])
    }

    @Test func empateGanaLaMasReciente() {
        let tiendas = TiendasFrecuentes.ordenar([registro("Mass", 1), registro("Tambo", 8)], locale: peru)
        #expect(tiendas == ["Tambo", "Mass"])
    }

    @Test func juntaMayusculasYUsaComoSeEscribioLaUltimaVez() {
        let tiendas = TiendasFrecuentes.ordenar([
            registro("plaza vea", 1), registro("  Plaza Vea ", 6), registro(nil, 7), registro("   ", 8),
        ], locale: peru)
        #expect(tiendas == ["Plaza Vea"])
    }

    @Test func sugerenciasSinTextoSonLasPrimeras() {
        let tiendas = ["A", "B", "C", "D", "E", "F", "G"]
        #expect(TiendasFrecuentes.sugerencias(tiendas, para: "  ") == ["A", "B", "C", "D", "E", "F"])
        #expect(TiendasFrecuentes.sugerencias(tiendas, para: "", limite: 2) == ["A", "B"])
    }

    @Test func sugerenciasIgnoranAcentosYMayusculasYNoRepitenLoEscrito() {
        let tiendas = ["Plaza Vea", "Metro", "Mass", "Makro", "Wong"]
        #expect(TiendasFrecuentes.sugerencias(tiendas, para: "ma") == ["Mass", "Makro"])
        #expect(TiendasFrecuentes.sugerencias(tiendas, para: "VEA") == ["Plaza Vea"])
        #expect(TiendasFrecuentes.sugerencias(tiendas, para: "mét") == ["Metro"])
        #expect(TiendasFrecuentes.sugerencias(tiendas, para: "métro").isEmpty)
    }
}
