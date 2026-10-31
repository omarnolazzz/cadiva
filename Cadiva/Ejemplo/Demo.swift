#if DEBUG
import Foundation

/// Launch arguments only for debug builds, used to capture screenshots with sample data.
/// `--datos-ejemplo` uses the in-memory container; it never touches the real store.
/// `--pestana 0|1|2` and `--pantalla detalle|registro|ajustes` open a specific screen.
enum Demo {
    private static var argumentos: [String] { ProcessInfo.processInfo.arguments }

    static var activo: Bool { argumentos.contains("--datos-ejemplo") }

    static func valor(_ clave: String) -> String? {
        guard let indice = argumentos.firstIndex(of: clave), argumentos.indices.contains(indice + 1) else { return nil }
        return argumentos[indice + 1]
    }
}
#endif
