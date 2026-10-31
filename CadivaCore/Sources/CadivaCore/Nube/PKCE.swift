import CryptoKit
import Foundation

/// Proof Key for Code Exchange (RFC 7636) para el inicio de sesión con proveedores.
public struct PKCE: Sendable, Equatable {
    public let verificador: String
    public let reto: String

    public init(verificador: String) {
        self.verificador = verificador
        reto = Self.base64URL(Data(SHA256.hash(data: Data(verificador.utf8))))
    }

    public static func generar() -> PKCE {
        var generador = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generador) }
        return PKCE(verificador: base64URL(Data(bytes)))
    }

    static func base64URL(_ datos: Data) -> String {
        datos.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
