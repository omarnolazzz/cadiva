import CryptoKit
import Foundation
import Security

/// Cómo se guarda el PIN: una sal aleatoria y el SHA-256 de sal + PIN. Nunca el PIN en texto.
public struct RegistroPIN: Codable, Sendable, Equatable {
    public var sal: Data
    public var hash: Data

    /// Crea el registro con una sal nueva de 16 bytes.
    public init(pin: String) {
        var sal = Data(count: 16)
        sal.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        self.init(pin: pin, sal: sal)
    }

    init(pin: String, sal: Data) {
        self.sal = sal
        hash = Self.hash(pin, sal: sal)
    }

    public func coincide(_ pin: String) -> Bool {
        Self.hash(pin, sal: sal) == hash
    }

    static func hash(_ pin: String, sal: Data) -> Data {
        Data(SHA256.hash(data: sal + Data(pin.utf8)))
    }

    /// Solo dígitos y del largo pedido.
    public static func esValido(_ pin: String, largo: Int) -> Bool {
        pin.count == largo && pin.allSatisfy(\.isASCII) && pin.allSatisfy(\.isNumber)
    }
}
