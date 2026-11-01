import CadivaCore
import Foundation
import LocalAuthentication

/// Bloqueo de la app: PIN de 4 dígitos y/o Face ID / Touch ID.
/// El PIN se guarda como hash con sal en el Keychain; nunca en texto.
@MainActor
enum Seguridad {
    static let largoPIN = 4
    static let intentosMaximos = 5

    private static let cuentaPIN = "pin"
    private static let claveBiometria = "bloqueoBiometrico"
    private static let claveIntentos = "intentosPINFallidos"

    #if DEBUG
    /// Las capturas muestran la pantalla de bloqueo sin tocar el Keychain.
    static var simulado = false
    /// Con `simulado`: bloqueo solo con Face ID, sin PIN.
    static var simuladoSinPIN = false
    #endif

    // MARK: Estado

    static var tienePIN: Bool {
        #if DEBUG
        if simulado { return !simuladoSinPIN }
        #endif
        return Llavero.leer(cuenta: cuentaPIN) != nil
    }

    static var biometriaActiva: Bool {
        get {
            #if DEBUG
            if simulado { return true }
            #endif
            return UserDefaults.standard.bool(forKey: claveBiometria) && biometriaDisponible
        }
        set { UserDefaults.standard.set(newValue, forKey: claveBiometria) }
    }

    /// Hay algo configurado para entrar sin escribir la contraseña.
    static var bloqueoConfigurado: Bool { tienePIN || biometriaActiva }

    // MARK: PIN

    static func guardarPIN(_ pin: String) {
        let registro = RegistroPIN(pin: pin)
        if let datos = try? JSONEncoder().encode(registro) {
            Llavero.guardar(datos, cuenta: cuentaPIN)
        }
        reiniciarIntentos()
    }

    static func quitarPIN() {
        Llavero.borrar(cuenta: cuentaPIN)
        reiniciarIntentos()
    }

    /// Compara el PIN y lleva la cuenta de los intentos fallidos.
    static func verificar(_ pin: String) -> Bool {
        #if DEBUG
        if simulado { return pin == "1234" }
        #endif
        guard let datos = Llavero.leer(cuenta: cuentaPIN),
              let registro = try? JSONDecoder().decode(RegistroPIN.self, from: datos) else { return false }
        let correcto = registro.coincide(pin)
        if correcto {
            reiniciarIntentos()
        } else {
            UserDefaults.standard.set(intentosFallidos + 1, forKey: claveIntentos)
        }
        return correcto
    }

    static var intentosFallidos: Int { UserDefaults.standard.integer(forKey: claveIntentos) }

    static var intentosRestantes: Int { max(intentosMaximos - intentosFallidos, 0) }

    static func reiniciarIntentos() {
        UserDefaults.standard.removeObject(forKey: claveIntentos)
    }

    /// Quita PIN y biometría (al olvidar el PIN o al cerrar sesión).
    static func reiniciar() {
        quitarPIN()
        biometriaActiva = false
    }

    // MARK: Biometría

    enum Biometria {
        case faceID, touchID, opticID

        var nombre: String {
            switch self {
            case .faceID: "Face ID"
            case .touchID: "Touch ID"
            case .opticID: "Optic ID"
            }
        }

        var simbolo: String {
            switch self {
            case .faceID: "faceid"
            case .touchID: "touchid"
            case .opticID: "opticid"
            }
        }
    }

    static var biometria: Biometria? {
        #if DEBUG
        if simulado { return .faceID }
        #endif
        let contexto = LAContext()
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        switch contexto.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return nil
        }
    }

    static var biometriaDisponible: Bool { biometria != nil }

    /// Pide Face ID / Touch ID. `false` si se cancela o falla.
    static func autenticarConBiometria(motivo: String) async -> Bool {
        let contexto = LAContext()
        contexto.localizedCancelTitle = "Usar PIN"
        contexto.localizedFallbackTitle = ""
        do {
            return try await contexto.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: motivo)
        } catch {
            return false
        }
    }
}
