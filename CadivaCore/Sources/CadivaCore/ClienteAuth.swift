import CryptoKit
import Foundation

public struct ConfiguracionAuth: Sendable, Equatable {
    public var url: URL
    public var claveAnonima: String

    public init(url: URL, claveAnonima: String) {
        self.url = url
        self.claveAnonima = claveAnonima
    }
}

public struct Usuario: Codable, Sendable, Equatable {
    public var id: String
    public var email: String?
    public var nombre: String?

    public init(id: String, email: String?, nombre: String?) {
        self.id = id
        self.email = email
        self.nombre = nombre
    }
}

public struct Sesion: Codable, Sendable, Equatable {
    public var tokenAcceso: String
    public var tokenRefresco: String
    public var expiraEn: Date
    public var usuario: Usuario

    public init(tokenAcceso: String, tokenRefresco: String, expiraEn: Date, usuario: Usuario) {
        self.tokenAcceso = tokenAcceso
        self.tokenRefresco = tokenRefresco
        self.expiraEn = expiraEn
        self.usuario = usuario
    }

    /// Se refresca un minuto antes de que expire para no mandar tokens vencidos.
    public func necesitaRefresco(ahora: Date) -> Bool {
        expiraEn.timeIntervalSince(ahora) <= 60
    }
}

public enum ResultadoRegistro: Sendable, Equatable {
    case sesion(Sesion)
    /// Supabase pide confirmar el correo antes de iniciar sesión.
    case confirmacionPendiente(email: String)
}

public enum ProveedorOAuth: String, Sendable, CaseIterable, Identifiable {
    case facebook, google, apple

    public var id: Self { self }
}

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

public typealias Transporte = @Sendable (URLRequest) async throws -> (Data, URLResponse)

/// Cliente mínimo de Supabase Auth (GoTrue) por REST, sin SDK.
public struct ClienteAuth: Sendable {
    public let configuracion: ConfiguracionAuth
    private let transporte: Transporte
    private let ahora: @Sendable () -> Date

    public init(
        configuracion: ConfiguracionAuth,
        transporte: @escaping Transporte = { try await URLSession.shared.data(for: $0) },
        ahora: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuracion = configuracion
        self.transporte = transporte
        self.ahora = ahora
    }

    // MARK: Operaciones

    public func iniciarSesion(email: String, contrasena: String) async throws -> Sesion {
        let datos = try await enviar("token", consulta: "grant_type=password", cuerpo: [
            "email": Self.normalizar(email), "password": contrasena,
        ])
        return try sesion(de: datos)
    }

    public func registrar(email: String, contrasena: String, nombre: String) async throws -> ResultadoRegistro {
        let correo = Self.normalizar(email)
        let datos = try await enviar("signup", cuerpo: [
            "email": correo, "password": contrasena, "data": ["nombre": nombre],
        ])
        if let sesion = try? sesion(de: datos) {
            return .sesion(sesion)
        }
        return .confirmacionPendiente(email: correo)
    }

    public func refrescar(_ sesion: Sesion) async throws -> Sesion {
        let datos = try await enviar("token", consulta: "grant_type=refresh_token", cuerpo: [
            "refresh_token": sesion.tokenRefresco,
        ])
        return try self.sesion(de: datos)
    }

    public func recuperarContrasena(email: String) async throws {
        _ = try await enviar("recover", cuerpo: ["email": Self.normalizar(email)])
    }

    /// Avisa al servidor; si falla no importa, la sesión local se borra de todos modos.
    public func cerrarSesion(_ sesion: Sesion) async {
        _ = try? await enviar("logout", cuerpo: [:], token: sesion.tokenAcceso)
    }

    public func urlOAuth(_ proveedor: ProveedorOAuth, redireccion: URL, pkce: PKCE) -> URL {
        var partes = URLComponents(url: endpoint("authorize"), resolvingAgainstBaseURL: false)!
        partes.queryItems = [
            URLQueryItem(name: "provider", value: proveedor.rawValue),
            URLQueryItem(name: "redirect_to", value: redireccion.absoluteString),
            URLQueryItem(name: "code_challenge", value: pkce.reto),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        return partes.url!
    }

    public func canjearCodigo(_ codigo: String, pkce: PKCE) async throws -> Sesion {
        let datos = try await enviar("token", consulta: "grant_type=pkce", cuerpo: [
            "auth_code": codigo, "code_verifier": pkce.verificador,
        ])
        return try sesion(de: datos)
    }

    /// Lee `?code=` de la redirección del proveedor, o el error que trae.
    public static func codigo(de url: URL) throws -> String {
        let consulta = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func valor(_ nombre: String) -> String? { consulta.first { $0.name == nombre }?.value }
        if let codigo = valor("code"), !codigo.isEmpty { return codigo }
        if let error = valor("error_description") ?? valor("error") {
            throw traducir(codigo: valor("error_code") ?? valor("error"), mensaje: error, estado: 400)
        }
        throw ErrorAuth.respuestaInvalida
    }

    public static func esCorreoValido(_ texto: String) -> Bool {
        let correo = normalizar(texto)
        guard let arroba = correo.firstIndex(of: "@"), arroba != correo.startIndex else { return false }
        let dominio = correo[correo.index(after: arroba)...]
        return dominio.contains(".") && !dominio.hasPrefix(".") && !dominio.hasSuffix(".") && !correo.contains(" ")
    }

    // MARK: Red

    private func endpoint(_ ruta: String) -> URL {
        configuracion.url.appending(path: "auth/v1/\(ruta)")
    }

    private func enviar(_ ruta: String, consulta: String? = nil, cuerpo: [String: Any], token: String? = nil) async throws -> Data {
        var partes = URLComponents(url: endpoint(ruta), resolvingAgainstBaseURL: false)!
        partes.percentEncodedQuery = consulta
        var solicitud = URLRequest(url: partes.url!)
        solicitud.httpMethod = "POST"
        solicitud.timeoutInterval = 20
        solicitud.setValue("application/json", forHTTPHeaderField: "Content-Type")
        solicitud.setValue(configuracion.claveAnonima, forHTTPHeaderField: "apikey")
        solicitud.setValue("Bearer \(token ?? configuracion.claveAnonima)", forHTTPHeaderField: "Authorization")
        solicitud.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await transporte(solicitud)
        } catch let error as URLError where Self.esFaltaDeRed(error) {
            throw ErrorAuth.sinConexion
        } catch let error as URLError where error.code == .cancelled {
            throw ErrorAuth.cancelado
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ErrorAuth.respuestaInvalida }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(RespuestaError.self, from: datos)
            throw Self.traducir(
                codigo: error?.error_code ?? error?.error,
                mensaje: error?.msg ?? error?.error_description ?? error?.message,
                estado: http.statusCode
            )
        }
        return datos
    }

    static func esFaltaDeRed(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed]
            .contains(error.code)
    }

    static func traducir(codigo: String?, mensaje: String?, estado: Int) -> ErrorAuth {
        let texto = (mensaje ?? "").lowercased()
        switch codigo {
        case "invalid_credentials": return .credencialesInvalidas
        case "email_not_confirmed": return .correoNoConfirmado
        case "user_already_exists", "email_exists": return .correoYaRegistrado
        case "weak_password": return .contrasenaDebil
        case "over_email_send_rate_limit", "over_request_rate_limit", "over_sms_send_rate_limit": return .demasiadosIntentos
        case "provider_disabled", "oauth_provider_not_supported": return .proveedorDeshabilitado
        default: break
        }
        if texto.contains("invalid login credentials") { return .credencialesInvalidas }
        if texto.contains("email not confirmed") { return .correoNoConfirmado }
        if texto.contains("already registered") { return .correoYaRegistrado }
        if texto.contains("provider") && (texto.contains("not enabled") || texto.contains("unsupported")) {
            return .proveedorDeshabilitado
        }
        if estado == 429 { return .demasiadosIntentos }
        return .servidor(mensaje ?? "Error \(estado)")
    }

    // MARK: Decodificación

    private struct RespuestaError: Decodable {
        var error: String?
        var error_code: String?
        var error_description: String?
        var msg: String?
        var message: String?
    }

    private struct RespuestaSesion: Decodable {
        var access_token: String
        var refresh_token: String
        var expires_in: Double
        var user: RespuestaUsuario
    }

    private struct RespuestaUsuario: Decodable {
        var id: String
        var email: String?
        var user_metadata: [String: Metadato]?
    }

    /// Los metadatos traen valores de cualquier tipo; solo nos interesan los textos.
    private struct Metadato: Decodable {
        var texto: String?

        init(from decoder: Decoder) throws {
            texto = try? decoder.singleValueContainer().decode(String.self)
        }
    }

    private func sesion(de datos: Data) throws -> Sesion {
        guard let respuesta = try? JSONDecoder().decode(RespuestaSesion.self, from: datos) else {
            throw ErrorAuth.respuestaInvalida
        }
        let metadatos = respuesta.user.user_metadata ?? [:]
        let nombre = ["nombre", "full_name", "name"].lazy.compactMap { metadatos[$0]?.texto }.first { !$0.isEmpty }
        return Sesion(
            tokenAcceso: respuesta.access_token,
            tokenRefresco: respuesta.refresh_token,
            expiraEn: ahora().addingTimeInterval(respuesta.expires_in),
            usuario: Usuario(id: respuesta.user.id, email: respuesta.user.email, nombre: nombre)
        )
    }

    static func normalizar(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Proof Key for Code Exchange (RFC 7636) para el inicio de sesión con proveedores.
public struct PKCE: Sendable, Equatable {
    public let verificador: String
    public let reto: String

    public init(verificador: String) {
        self.verificador = verificador
        reto = Self.base64URL(Data(SHA256.hash(data: Data(verificador.utf8))))
    }

    public static func generar() -> PKCE {
        var generador = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generador) }
        return PKCE(verificador: base64URL(Data(bytes)))
    }

    static func base64URL(_ datos: Data) -> String {
        datos.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
