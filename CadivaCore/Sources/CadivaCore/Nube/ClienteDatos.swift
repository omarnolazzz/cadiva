import CryptoKit
import Foundation

/// Lee y escribe las tablas de Supabase (PostgREST). Las políticas RLS limitan cada cuenta a sus filas.
public struct ClienteDatos: Sendable {
    public let configuracion: ConfiguracionAuth
    private let transporte: Transporte
    static let tamanoPagina = 1000

    public init(
        configuracion: ConfiguracionAuth,
        transporte: @escaping Transporte = { try await URLSession.shared.data(for: $0) }
    ) {
        self.configuracion = configuracion
        self.transporte = transporte
    }

    public func descargar<Fila: FilaSincronizable>(_ tipo: Fila.Type, token: String) async throws -> [FilaRemota<Fila>] {
        var filas: [FilaRemota<Fila>] = []
        while true {
            let consulta = "select=\(Fila.columnas)&order=id&limit=\(Self.tamanoPagina)&offset=\(filas.count)"
            let datos = try await enviar(Fila.tabla, metodo: "GET", consulta: consulta, token: token)
            guard let pagina = try? FormatoNube.decodificador.decode([FilaRemota<Fila>].self, from: datos) else {
                throw ErrorNube.respuestaInvalida
            }
            filas += pagina
            if pagina.count < Self.tamanoPagina { return filas }
        }
    }

    /// Crea o actualiza las filas y devuelve la versión nueva de cada una.
    public func subir<Fila: FilaSincronizable>(_ filas: [Fila], token: String) async throws -> [UUID: String] {
        var versiones: [UUID: String] = [:]
        var inicio = 0
        while inicio < filas.count {
            let lote = Array(filas[inicio..<min(inicio + 500, filas.count)])
            let datos = try await enviar(
                Fila.tabla, metodo: "POST", consulta: "on_conflict=id&select=id,modificado", token: token,
                cuerpo: try FormatoNube.codificador.encode(lote),
                preferencia: "resolution=merge-duplicates,return=representation"
            )
            guard let respuesta = try? JSONDecoder().decode([Version].self, from: datos) else {
                throw ErrorNube.respuestaInvalida
            }
            for version in respuesta { versiones[version.id] = version.modificado }
            inicio += lote.count
        }
        return versiones
    }

    // MARK: Fotos (Storage)

    static let cubeta = "fotos"

    /// `usuario/producto.jpg`: la política del bucket solo deja tocar la carpeta propia.
    public static func rutaFoto(usuario: String, producto: UUID) -> String {
        "\(usuario.lowercased())/\(producto.uuidString.lowercased()).jpg"
    }

    public func subirFoto(_ datos: Data, ruta: String, token: String) async throws {
        _ = try await solicitar(
            configuracion.url.appending(path: "storage/v1/object/\(Self.cubeta)/\(ruta)"), metodo: "POST", token: token,
            cuerpo: datos, cabeceras: ["Content-Type": "image/jpeg", "x-upsert": "true", "Cache-Control": "3600"]
        )
    }

    public func descargarFoto(ruta: String, token: String) async throws -> Data {
        try await solicitar(
            configuracion.url.appending(path: "storage/v1/object/authenticated/\(Self.cubeta)/\(ruta)"), metodo: "GET", token: token
        )
    }

    private struct Version: Decodable {
        var id: UUID
        var modificado: String
    }

    private func enviar(
        _ tabla: String, metodo: String, consulta: String, token: String,
        cuerpo: Data? = nil, preferencia: String? = nil
    ) async throws -> Data {
        var partes = URLComponents(url: configuracion.url.appending(path: "rest/v1/\(tabla)"), resolvingAgainstBaseURL: false)!
        partes.percentEncodedQuery = consulta
        var cabeceras = ["Content-Type": "application/json"]
        if let preferencia { cabeceras["Prefer"] = preferencia }
        return try await solicitar(partes.url!, metodo: metodo, token: token, cuerpo: cuerpo, cabeceras: cabeceras)
    }

    private func solicitar(
        _ url: URL, metodo: String, token: String, cuerpo: Data? = nil, cabeceras: [String: String] = [:]
    ) async throws -> Data {
        var solicitud = URLRequest(url: url)
        solicitud.httpMethod = metodo
        solicitud.timeoutInterval = 30
        solicitud.setValue(configuracion.claveAnonima, forHTTPHeaderField: "apikey")
        solicitud.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        for (campo, valor) in cabeceras { solicitud.setValue(valor, forHTTPHeaderField: campo) }
        solicitud.httpBody = cuerpo

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await transporte(solicitud)
        } catch let error as URLError where ClienteAuth.esFaltaDeRed(error) {
            throw ErrorNube.sinConexion
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ErrorNube.respuestaInvalida }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorPostgrest.self, from: datos)
            throw ErrorNube.servidor(error?.message ?? error?.error ?? "Error \(http.statusCode)")
        }
        return datos
    }

    /// PostgREST responde `message`; Storage, `message` o `error`.
    private struct ErrorPostgrest: Decodable {
        var message: String?
        var error: String?
    }
}
