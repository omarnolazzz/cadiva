import CryptoKit
import Foundation

/// Errores al leer o escribir los datos en la nube (tablas y fotos).
public enum ErrorNube: Error, Sendable, Equatable, LocalizedError {
    case sinConexion
    case servidor(String)
    case respuestaInvalida

    public var errorDescription: String? {
        switch self {
        case .sinConexion: "No hay conexión a internet."
        case let .servidor(mensaje): "Algo salió mal en el servidor: \(mensaje)"
        case .respuestaInvalida: "No pudimos leer la respuesta del servidor."
        }
    }

    /// Sin red, da igual si el fallo vino de la sesión o de los datos.
    public static func esFaltaDeRed(_ error: Error) -> Bool {
        error as? ErrorNube == .sinConexion || error as? ErrorAuth == .sinConexion
    }
}
