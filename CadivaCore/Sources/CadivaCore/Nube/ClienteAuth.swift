import CryptoKit
import Foundation

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
        let foto = ["avatar_url", "picture"].lazy.compactMap { metadatos[$0]?.texto }.compactMap(Self.fotoGrande).first
        return Sesion(
            tokenAcceso: respuesta.access_token,
            tokenRefresco: respuesta.refresh_token,
            expiraEn: ahora().addingTimeInterval(respuesta.expires_in),
            usuario: Usuario(id: respuesta.user.id, email: respuesta.user.email, nombre: nombre, foto: foto)
        )
    }

    /// Google entrega la foto a 96 px (`=s96-c`); se pide a 256 para que se vea nítida.
    static func fotoGrande(_ texto: String) -> URL? {
        guard texto.hasPrefix("https://") else { return nil }
        let grande = texto.replacingOccurrences(of: "=s96-c", with: "=s256-c")
        return URL(string: grande)
    }

    static func normalizar(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
