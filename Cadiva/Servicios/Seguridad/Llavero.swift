import Foundation
import Security

/// Guarda datos sensibles (la sesión, el PIN) en el Keychain, solo en este dispositivo.
enum Llavero {
    private static let servicio = "com.cadiva.app.sesion"

    static func guardar(_ datos: Data, cuenta: String = "sesion") {
        borrar(cuenta: cuenta)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: datos,
        ]
        SecItemAdd(consulta as CFDictionary, nil)
    }

    static func leer(cuenta: String = "sesion") -> Data? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess else { return nil }
        return resultado as? Data
    }

    static func borrar(cuenta: String = "sesion") {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }
}
