import CryptoKit
import Foundation

/// Cómo quedó una fila en la última sincronización.
public struct EstadoSincronizado: Codable, Sendable, Equatable {
    public var huella: String
    public var version: String

    public init(huella: String, version: String) {
        self.huella = huella
        self.version = version
    }
}

/// Lo que hay que hacer con una tabla para que el iPhone y la nube queden iguales.
public struct PlanFusion<Fila: FilaSincronizable>: Sendable {
    /// Filas que se mandan a la nube (incluye las borradas, con `borrado = true`).
    public var subir: [Fila] = []
    /// Filas de la nube que se crean o actualizan en el iPhone.
    public var aplicar: [Fila] = []
    /// Filas que se borraron en otro dispositivo.
    public var borrarLocal: [UUID] = []
    /// Estado de las filas que no se suben; las subidas se agregan con su nueva versión.
    var baseConservada: [UUID: EstadoSincronizado] = [:]

    public var hayCambios: Bool { !subir.isEmpty || !aplicar.isEmpty || !borrarLocal.isEmpty }

    /// Base para la próxima vez. `versiones` son las que devolvió el servidor al subir.
    public func nuevaBase(versiones: [UUID: String]) -> [UUID: EstadoSincronizado] {
        var base = baseConservada
        for fila in subir where !fila.borrado {
            if let version = versiones[fila.id] {
                base[fila.id] = EstadoSincronizado(huella: fila.huella, version: version)
            }
        }
        return base
    }
}

public enum Fusion {
    /// Compara el iPhone, la nube y la última sincronización.
    /// - Si solo cambió un lado, gana ese lado.
    /// - Si cambiaron los dos, gana el iPhone.
    /// - Si se borró aquí pero se editó en otro lado, se conserva la edición.
    public static func planear<Fila: FilaSincronizable>(
        locales: [Fila], remotas: [FilaRemota<Fila>], base: [UUID: EstadoSincronizado]
    ) -> PlanFusion<Fila> {
        var plan = PlanFusion<Fila>()
        let porIdLocal = Dictionary(locales.map { ($0.id, $0) }, uniquingKeysWith: { primera, _ in primera })
        let porIdRemota = Dictionary(remotas.map { ($0.fila.id, $0) }, uniquingKeysWith: { primera, _ in primera })
        let ids = Set(porIdLocal.keys).union(porIdRemota.keys)

        for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
            let local = porIdLocal[id]
            let remota = porIdRemota[id]
            let anterior = base[id]
            let remotaCambio = remota.map { $0.version != anterior?.version } ?? false

            if let local {
                let huella = local.huella
                let localCambio = anterior?.huella != huella
                if let remota, remotaCambio, !localCambio {
                    if remota.fila.borrado {
                        plan.borrarLocal.append(id)
                    } else {
                        plan.aplicar.append(remota.fila)
                        plan.baseConservada[id] = EstadoSincronizado(huella: remota.fila.huella, version: remota.version)
                    }
                } else if localCambio || remota == nil || remota?.fila.borrado == true {
                    plan.subir.append(local)
                } else if let anterior {
                    plan.baseConservada[id] = anterior
                }
            } else if let remota, !remota.fila.borrado {
                if anterior == nil || remotaCambio {
                    plan.aplicar.append(remota.fila)
                    plan.baseConservada[id] = EstadoSincronizado(huella: remota.fila.huella, version: remota.version)
                } else {
                    var lapida = remota.fila
                    lapida.borrado = true
                    plan.subir.append(lapida)
                }
            }
        }
        return plan
    }
}
