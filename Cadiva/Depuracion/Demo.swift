#if DEBUG
import Foundation

/// Argumentos de arranque solo en DEBUG, para las capturas de la CI con datos de ejemplo.
/// `--datos-ejemplo` usa el contenedor en memoria; nunca toca los datos reales.
/// `--pestana 0|1|2` elige Productos, Gasto o Ajustes.
/// `--pantalla` abre una pantalla: detalle, registro, oferta-detalle, oferta-compra, nuevo-producto, borrado, crear-pin, oferta,
/// arranque, login, registro-cuenta, recuperar, bloqueo o cargando.
enum Demo {
    private static var argumentos: [String] { ProcessInfo.processInfo.arguments }

    static var activo: Bool { argumentos.contains("--datos-ejemplo") }

    static func valor(_ clave: String) -> String? {
        guard let indice = argumentos.firstIndex(of: clave), argumentos.indices.contains(indice + 1) else { return nil }
        return argumentos[indice + 1]
    }
}
#endif
