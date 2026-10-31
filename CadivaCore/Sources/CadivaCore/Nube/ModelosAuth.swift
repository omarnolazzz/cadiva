import CryptoKit
import Foundation

public struct ConfiguracionAuth: Sendable, Equatable {
    public var url: URL
    public var claveAnonima: String

    public init(url: URL, claveAnonima: String) {
        self.url = url
        self.claveAnonima = claveAnonima
    }
}

public struct Usuario: Codable, Sendable, Equatable {
    public var id: String
    public var email: String?
    public var nombre: String?
    /// Foto de perfil del proveedor (Google la manda como `avatar_url` o `picture`).
    public var foto: URL?

    public init(id: String, email: String?, nombre: String?, foto: URL? = nil) {
        self.id = id
        self.email = email
        self.nombre = nombre
        self.foto = foto
    }
}

public struct Sesion: Codable, Sendable, Equatable {
    public var tokenAcceso: String
    public var tokenRefresco: String
    public var expiraEn: Date
    public var usuario: Usuario

    public init(tokenAcceso: String, tokenRefresco: String, expiraEn: Date, usuario: Usuario) {
        self.tokenAcceso = tokenAcceso
        self.tokenRefresco = tokenRefresco
        self.expiraEn = expiraEn
        self.usuario = usuario
    }

    /// Se refresca un minuto antes de que expire para no mandar tokens vencidos.
    public func necesitaRefresco(ahora: Date) -> Bool {
        expiraEn.timeIntervalSince(ahora) <= 60
    }
}

public enum ResultadoRegistro: Sendable, Equatable {
    case sesion(Sesion)
    /// Supabase pide confirmar el correo antes de iniciar sesión.
    case confirmacionPendiente(email: String)
}

public enum ProveedorOAuth: String, Sendable, CaseIterable, Identifiable {
    case facebook, google, apple

    public var id: Self { self }
}
