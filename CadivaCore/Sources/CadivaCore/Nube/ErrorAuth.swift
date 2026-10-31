import CryptoKit
import Foundation

public enum ErrorAuth: Error, Sendable, Equatable, LocalizedError {
    case credencialesInvalidas
    case correoNoConfirmado
    case correoYaRegistrado
    case contrasenaDebil
    case demasiadosIntentos
    case proveedorDeshabilitado
    case sinConexion
    case servidor(String)
    case respuestaInvalida
    case sinConfiguracion
    case cancelado

    public var errorDescription: String? {
        switch self {
        case .credencialesInvalidas: "El correo o la contraseña no son correctos."
        case .correoNoConfirmado: "Confirma tu correo con el enlace que te enviamos y vuelve a intentarlo."
        case .correoYaRegistrado: "Ya existe una cuenta con ese correo. Inicia sesión."
        case .contrasenaDebil: "La contraseña es muy débil. Usa al menos 8 caracteres."
        case .demasiadosIntentos: "Demasiados intentos. Espera unos minutos."
        case .proveedorDeshabilitado: "Este método de inicio de sesión todavía no está disponible."
        case .sinConexion: "No hay conexión a internet."
        case let .servidor(mensaje): "Algo salió mal en el servidor: \(mensaje)"
        case .respuestaInvalida: "No pudimos leer la respuesta del servidor."
        case .sinConfiguracion: "Las cuentas todavía no están configuradas en esta versión."
        case .cancelado: "Se canceló el inicio de sesión."
        }
    }
}
