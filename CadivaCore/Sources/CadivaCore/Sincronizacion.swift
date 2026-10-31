import CryptoKit
import Foundation

/// Una fila que se guarda en la nube: un producto o una compra.
public protocol FilaSincronizable: Codable, Sendable, Equatable {
    static var tabla: String { get }
    /// Columnas que se piden al servidor. Los números van como texto para no perder decimales.
    static var columnas: String { get }
    var id: UUID { get }
    var borrado: Bool { get set }
}

extension FilaSincronizable {
    /// Resumen estable del contenido; si cambia, la fila cambió.
    public var huella: String {
        let datos = (try? FormatoNube.codificador.encode(self)) ?? Data()
        return SHA256.hash(data: datos).map { String(format: "%02x", $0) }.joined()
    }
}

public struct ProductoNube: FilaSincronizable {
    public static let tabla = "productos"
    public static let columnas = "id,nombre,categoria,unidad,simbolo,notas,archivado,duracion_estimada_dias,creado,foto,borrado,modificado"

    public var id: UUID
    public var nombre: String
    public var categoria: String
    public var unidad: String
    public var simbolo: String
    public var notas: String?
    public var archivado: Bool
    public var duracionEstimadaDias: Int?
    public var creado: Date
    /// Huella de la foto (`FormatoNube.huellaFoto`); la imagen va aparte, en Storage.
    public var foto: String?
    public var borrado: Bool

    public init(
        id: UUID, nombre: String, categoria: String, unidad: String, simbolo: String, notas: String?,
        archivado: Bool, duracionEstimadaDias: Int?, creado: Date, foto: String? = nil, borrado: Bool = false
    ) {
        self.id = id
        self.nombre = nombre
        self.categoria = categoria
        self.unidad = unidad
        self.simbolo = simbolo
        self.notas = notas
        self.archivado = archivado
        self.duracionEstimadaDias = duracionEstimadaDias
        self.creado = FormatoNube.redondear(creado)
        self.foto = foto
        self.borrado = borrado
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre, categoria, unidad, simbolo, notas, archivado, creado, foto, borrado
        case duracionEstimadaDias = "duracion_estimada_dias"
    }

    // Los vacíos van como null para que al borrar un campo también se borre en la nube.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(categoria, forKey: .categoria)
        try c.encode(unidad, forKey: .unidad)
        try c.encode(simbolo, forKey: .simbolo)
        try c.encode(notas, forKey: .notas)
        try c.encode(archivado, forKey: .archivado)
        try c.encode(duracionEstimadaDias, forKey: .duracionEstimadaDias)
        try c.encode(creado, forKey: .creado)
        try c.encode(foto, forKey: .foto)
        try c.encode(borrado, forKey: .borrado)
    }
}

public struct CompraNube: FilaSincronizable {
    public static let tabla = "compras"
    public static let columnas = "id,producto_id,fecha,precio_total::text,cantidad::text,tienda,fecha_agotado,borrado,modificado"

    public var id: UUID
    public var productoId: UUID?
    public var fecha: Date
    public var precioTotal: Decimal
    public var cantidad: Decimal
    public var tienda: String?
    public var fechaAgotado: Date?
    public var borrado: Bool

    public init(
        id: UUID, productoId: UUID?, fecha: Date, precioTotal: Decimal, cantidad: Decimal,
        tienda: String?, fechaAgotado: Date?, borrado: Bool = false
    ) {
        self.id = id
        self.productoId = productoId
        self.fecha = FormatoNube.redondear(fecha)
        self.precioTotal = precioTotal
        self.cantidad = cantidad
        self.tienda = tienda
        self.fechaAgotado = fechaAgotado.map(FormatoNube.redondear)
        self.borrado = borrado
    }

    enum CodingKeys: String, CodingKey {
        case id, fecha, cantidad, tienda, borrado
        case productoId = "producto_id"
        case precioTotal = "precio_total"
        case fechaAgotado = "fecha_agotado"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        productoId = try c.decodeIfPresent(UUID.self, forKey: .productoId)
        fecha = try c.decode(Date.self, forKey: .fecha)
        precioTotal = try FormatoNube.decimal(c, .precioTotal)
        cantidad = try FormatoNube.decimal(c, .cantidad)
        tienda = try c.decodeIfPresent(String.self, forKey: .tienda)
        fechaAgotado = try c.decodeIfPresent(Date.self, forKey: .fechaAgotado)
        borrado = try c.decodeIfPresent(Bool.self, forKey: .borrado) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(productoId, forKey: .productoId)
        try c.encode(fecha, forKey: .fecha)
        // Como texto: Postgres lo convierte a numeric sin pasar por Double.
        try c.encode("\(precioTotal)", forKey: .precioTotal)
        try c.encode("\(cantidad)", forKey: .cantidad)
        try c.encode(tienda, forKey: .tienda)
        try c.encode(fechaAgotado, forKey: .fechaAgotado)
        try c.encode(borrado, forKey: .borrado)
    }
}

/// Fila como la devuelve el servidor, con su versión (`modificado`, la pone un trigger).
public struct FilaRemota<Fila: FilaSincronizable>: Decodable, Sendable, Equatable {
    public var fila: Fila
    public var version: String

    public init(fila: Fila, version: String) {
        self.fila = fila
        self.version = version
    }

    private enum Claves: String, CodingKey { case modificado }

    public init(from decoder: Decoder) throws {
        fila = try Fila(from: decoder)
        version = try decoder.container(keyedBy: Claves.self).decode(String.self, forKey: .modificado)
    }
}

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

/// Fechas y números tal como viajan a Supabase.
public enum FormatoNube {
    /// Huella corta de una foto: cambia si cambia la imagen.
    public static func huellaFoto(_ datos: Data) -> String {
        SHA256.hash(data: datos).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// Milisegundos: lo que sobrevive al viaje de ida y vuelta.
    public static func redondear(_ fecha: Date) -> Date {
        Date(timeIntervalSince1970: (fecha.timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    public static var codificador: JSONEncoder {
        let codificador = JSONEncoder()
        codificador.outputFormatting = .sortedKeys
        codificador.dateEncodingStrategy = .custom { fecha, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(texto(de: fecha))
        }
        return codificador
    }

    public static var decodificador: JSONDecoder {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let texto = try c.decode(String.self)
            guard let fecha = fecha(de: texto) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha inválida: \(texto)")
            }
            return fecha
        }
        return decodificador
    }

    public static func texto(de fecha: Date) -> String {
        let formato = ISO8601DateFormatter()
        formato.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formato.string(from: fecha)
    }

    /// Acepta lo que devuelve Postgres: `2026-10-30T23:38:07.123456+00:00`, sin fracción o con `Z`.
    public static func fecha(de texto: String) -> Date? {
        var base = texto.replacingOccurrences(of: " ", with: "T")
        var fraccion = 0.0
        if let punto = base.firstIndex(of: "."), let t = base.firstIndex(of: "T"), punto > t {
            let digitos = base[base.index(after: punto)...].prefix { $0.isNumber }
            fraccion = Double("0." + digitos) ?? 0
            base.removeSubrange(punto..<base.index(base.index(after: punto), offsetBy: digitos.count))
        }
        let formato = ISO8601DateFormatter()
        formato.formatOptions = [.withInternetDateTime]
        guard let segundos = formato.date(from: base) else { return nil }
        return redondear(segundos.addingTimeInterval(fraccion))
    }

    static func decimal<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ clave: K) throws -> Decimal {
        if let texto = try? c.decode(String.self, forKey: clave), let valor = Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX")) {
            return valor
        }
        return try c.decode(Decimal.self, forKey: clave)
    }
}

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
                throw ErrorAuth.respuestaInvalida
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
                throw ErrorAuth.respuestaInvalida
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
            throw ErrorAuth.sinConexion
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ErrorAuth.respuestaInvalida }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorPostgrest.self, from: datos)
            throw ErrorAuth.servidor(error?.message ?? error?.error ?? "Error \(http.statusCode)")
        }
        return datos
    }

    /// PostgREST responde `message`; Storage, `message` o `error`.
    private struct ErrorPostgrest: Decodable {
        var message: String?
        var error: String?
    }
}
