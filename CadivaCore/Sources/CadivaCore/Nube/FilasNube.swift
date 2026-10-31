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
    public static let columnas = "id,nombre,categoria,simbolo,notas,archivado,creado,foto,seguimiento,borrado,modificado"

    public var id: UUID
    public var nombre: String
    public var categoria: String
    public var simbolo: String
    public var notas: String?
    public var archivado: Bool
    public var creado: Date
    /// Huella de la foto (`FormatoNube.huellaFoto`); la imagen va aparte, en Storage.
    public var foto: String?
    /// `Seguimiento` elegido a mano; nil = automático.
    public var seguimiento: String?
    public var borrado: Bool

    public init(
        id: UUID, nombre: String, categoria: String, simbolo: String, notas: String?,
        archivado: Bool, creado: Date, foto: String? = nil, seguimiento: String? = nil, borrado: Bool = false
    ) {
        self.id = id
        self.nombre = nombre
        self.categoria = categoria
        self.simbolo = simbolo
        self.notas = notas
        self.archivado = archivado
        self.creado = FormatoNube.redondear(creado)
        self.foto = foto
        self.seguimiento = seguimiento
        self.borrado = borrado
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre, categoria, simbolo, notas, archivado, creado, foto, seguimiento, borrado
    }

    // Los vacíos van como null para que al borrar un campo también se borre en la nube.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(categoria, forKey: .categoria)
        try c.encode(simbolo, forKey: .simbolo)
        try c.encode(notas, forKey: .notas)
        try c.encode(archivado, forKey: .archivado)
        try c.encode(creado, forKey: .creado)
        try c.encode(foto, forKey: .foto)
        try c.encode(seguimiento, forKey: .seguimiento)
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
