import CadivaCore
import Foundation
import Observation
import SwiftData

/// Cómo quedó cada fila en la última sincronización, por cuenta. Vive en Application Support.
struct BaseSincronizacion: Codable {
    var productos: [UUID: EstadoSincronizado] = [:]
    var compras: [UUID: EstadoSincronizado] = [:]

    private static func archivo(usuario: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "sincronizacion-\(usuario).json")
    }

    static func leer(usuario: String) -> BaseSincronizacion {
        guard let datos = try? Data(contentsOf: archivo(usuario: usuario)) else { return BaseSincronizacion() }
        return (try? JSONDecoder().decode(BaseSincronizacion.self, from: datos)) ?? BaseSincronizacion()
    }

    static func guardar(_ base: BaseSincronizacion, usuario: String) {
        let url = archivo(usuario: usuario)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let datos = try? JSONEncoder().encode(base) {
            try? datos.write(to: url, options: .atomic)
        }
    }

    static func borrar(usuario: String) {
        try? FileManager.default.removeItem(at: archivo(usuario: usuario))
    }
}
