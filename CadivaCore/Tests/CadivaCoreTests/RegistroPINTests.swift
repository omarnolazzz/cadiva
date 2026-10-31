import Foundation
import Testing
@testable import CadivaCore

@Suite("RegistroPIN")
struct RegistroPINTests {
    @Test func coincideSoloConElMismoPIN() {
        let registro = RegistroPIN(pin: "4821")
        #expect(registro.coincide("4821"))
        #expect(!registro.coincide("4822"))
        #expect(!registro.coincide(""))
    }

    @Test func noGuardaElPINEnTexto() throws {
        let registro = RegistroPIN(pin: "4821")
        let json = try #require(String(data: JSONEncoder().encode(registro), encoding: .utf8))
        #expect(!json.contains("4821"))
        #expect(registro.hash.count == 32)
        #expect(registro.sal.count == 16)
    }

    @Test func cadaRegistroLlevaSuPropiaSal() {
        let a = RegistroPIN(pin: "1234")
        let b = RegistroPIN(pin: "1234")
        #expect(a.sal != b.sal)
        #expect(a.hash != b.hash)
    }

    @Test func mismoPINYSalDanElMismoHash() {
        let sal = Data(repeating: 7, count: 16)
        #expect(RegistroPIN(pin: "0000", sal: sal) == RegistroPIN(pin: "0000", sal: sal))
    }

    @Test func registroGuardadoAntesSigueSirviendo() throws {
        // Mismo formato que guardaba la app antes de mover esto a CadivaCore.
        let sal = Data(repeating: 1, count: 16)
        let viejo = #"{"sal":"\#(sal.base64EncodedString())","hash":"\#(RegistroPIN.hash("2468", sal: sal).base64EncodedString())"}"#
        let registro = try JSONDecoder().decode(RegistroPIN.self, from: Data(viejo.utf8))
        #expect(registro.coincide("2468"))
    }

    @Test(arguments: [("1234", true), ("123", false), ("12a4", false), ("١٢٣٤", false), ("12345", false)])
    func validaLargoYDigitos(pin: String, valido: Bool) {
        #expect(RegistroPIN.esValido(pin, largo: 4) == valido)
    }
}
