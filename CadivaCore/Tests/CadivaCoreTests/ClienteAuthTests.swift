import Foundation
import Testing
@testable import CadivaCore

/// Transporte falso: guarda las solicitudes y responde lo que se le indique.
final class TransporteFalso: @unchecked Sendable {
    private let candado = NSLock()
    private var _solicitudes: [URLRequest] = []
    var estado = 200
    var cuerpo = "{}"

    var solicitudes: [URLRequest] { candado.withLock { _solicitudes } }

    func responder(_ estado: Int, _ cuerpo: String) {
        self.estado = estado
        self.cuerpo = cuerpo
    }

    var transporte: Transporte {
        { [self] solicitud in
            candado.withLock { _solicitudes.append(solicitud) }
            let respuesta = HTTPURLResponse(url: solicitud.url!, statusCode: estado, httpVersion: nil, headerFields: nil)!
            return (Data(cuerpo.utf8), respuesta)
        }
    }
}

@Suite("ClienteAuth")
struct ClienteAuthTests {
    let configuracion = ConfiguracionAuth(url: URL(string: "https://demo.supabase.co")!, claveAnonima: "anon-123")
    let ahora = Date(timeIntervalSince1970: 1_800_000_000)

    func cliente(_ falso: TransporteFalso) -> ClienteAuth {
        let fijo = ahora
        return ClienteAuth(configuracion: configuracion, transporte: falso.transporte, ahora: { fijo })
    }

    static let respuestaSesion = """
    {"access_token":"acceso","token_type":"bearer","expires_in":3600,"refresh_token":"refresco",
     "user":{"id":"u1","email":"ana@correo.mx","user_metadata":{"nombre":"Ana"}}}
    """

    func cuerpo(_ solicitud: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: solicitud.httpBody ?? Data())) as? [String: Any] ?? [:]
    }

    // MARK: Iniciar sesión

    @Test func iniciarSesionEnviaCredencialesYDevuelveLaSesion() async throws {
        let falso = TransporteFalso()
        falso.responder(200, Self.respuestaSesion)
        let sesion = try await cliente(falso).iniciarSesion(email: " Ana@Correo.mx ", contrasena: "secreta1")

        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.httpMethod == "POST")
        #expect(solicitud.url?.absoluteString == "https://demo.supabase.co/auth/v1/token?grant_type=password")
        #expect(solicitud.value(forHTTPHeaderField: "apikey") == "anon-123")
        #expect(cuerpo(solicitud)["email"] as? String == "ana@correo.mx")
        #expect(cuerpo(solicitud)["password"] as? String == "secreta1")

        #expect(sesion.tokenAcceso == "acceso")
        #expect(sesion.tokenRefresco == "refresco")
        #expect(sesion.expiraEn == ahora.addingTimeInterval(3600))
        #expect(sesion.usuario == Usuario(id: "u1", email: "ana@correo.mx", nombre: "Ana"))
    }

    @Test(arguments: [
        (400, #"{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#, ErrorAuth.credencialesInvalidas),
        (400, #"{"error":"invalid_grant","error_description":"Invalid login credentials"}"#, ErrorAuth.credencialesInvalidas),
        (400, #"{"error_code":"email_not_confirmed","msg":"Email not confirmed"}"#, ErrorAuth.correoNoConfirmado),
        (422, #"{"error_code":"user_already_exists","msg":"User already registered"}"#, ErrorAuth.correoYaRegistrado),
        (422, #"{"error_code":"weak_password","msg":"Password should be at least 6 characters."}"#, ErrorAuth.contrasenaDebil),
        (429, #"{"error_code":"over_email_send_rate_limit","msg":"Too many"}"#, ErrorAuth.demasiadosIntentos),
        (400, #"{"error_code":"validation_failed","msg":"Unsupported provider: provider is not enabled"}"#, ErrorAuth.proveedorDeshabilitado),
        (500, #"{"msg":"boom"}"#, ErrorAuth.servidor("boom")),
        (502, "<html>", ErrorAuth.servidor("Error 502")),
    ])
    func erroresSeTraducen(estado: Int, cuerpo: String, esperado: ErrorAuth) async {
        let falso = TransporteFalso()
        falso.responder(estado, cuerpo)
        await #expect(throws: esperado) {
            try await cliente(falso).iniciarSesion(email: "a@b.mx", contrasena: "123456")
        }
    }

    @Test func todosLosErroresTienenMensajeEnEspanol() {
        let errores: [ErrorAuth] = [
            .credencialesInvalidas, .correoNoConfirmado, .correoYaRegistrado, .contrasenaDebil,
            .demasiadosIntentos, .proveedorDeshabilitado, .sinConexion, .servidor("x"), .respuestaInvalida,
            .sinConfiguracion, .cancelado,
        ]
        for error in errores {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test func sinConexionSeTraduce() async {
        let fijo = ahora
        let sinRed = ClienteAuth(
            configuracion: configuracion,
            transporte: { _ in throw URLError(.notConnectedToInternet) },
            ahora: { fijo }
        )
        await #expect(throws: ErrorAuth.sinConexion) {
            try await sinRed.iniciarSesion(email: "a@b.mx", contrasena: "123456")
        }
    }

    // MARK: Registro

    @Test func registroConConfirmacionPendiente() async throws {
        let falso = TransporteFalso()
        falso.responder(200, #"{"id":"u2","email":"leo@correo.mx","user_metadata":{"nombre":"Leo"}}"#)
        let resultado = try await cliente(falso).registrar(email: "leo@correo.mx", contrasena: "secreta1", nombre: "Leo")

        #expect(resultado == .confirmacionPendiente(email: "leo@correo.mx"))
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.url?.path == "/auth/v1/signup")
        let datos = cuerpo(solicitud)["data"] as? [String: Any]
        #expect(datos?["nombre"] as? String == "Leo")
    }

    @Test func registroSinConfirmacionDevuelveSesion() async throws {
        let falso = TransporteFalso()
        falso.responder(200, Self.respuestaSesion)
        let resultado = try await cliente(falso).registrar(email: "ana@correo.mx", contrasena: "secreta1", nombre: "Ana")
        guard case let .sesion(sesion) = resultado else {
            Issue.record("Se esperaba una sesión")
            return
        }
        #expect(sesion.usuario.nombre == "Ana")
    }

    @Test func googleTraeNombreYFotoGrande() async throws {
        let falso = TransporteFalso()
        falso.responder(200, """
        {"access_token":"a","token_type":"bearer","expires_in":3600,"refresh_token":"r",
         "user":{"id":"g1","email":"gabriel@gmail.com","user_metadata":{
           "avatar_url":"https://lh3.googleusercontent.com/a/ACg8oc=s96-c",
           "picture":"https://lh3.googleusercontent.com/a/ACg8oc=s96-c",
           "full_name":"Gabriel Nolazco","email_verified":true}}}
        """)
        let sesion = try await cliente(falso).canjearCodigo("c", pkce: PKCE(verificador: "v"))
        #expect(sesion.usuario.nombre == "Gabriel Nolazco")
        #expect(sesion.usuario.foto?.absoluteString == "https://lh3.googleusercontent.com/a/ACg8oc=s256-c")
    }

    @Test func sesionGuardadaSinFotoSigueLeyendose() throws {
        let vieja = #"{"id":"u1","email":"ana@correo.mx","nombre":"Ana"}"#
        let usuario = try JSONDecoder().decode(Usuario.self, from: Data(vieja.utf8))
        #expect(usuario.foto == nil)
        #expect(usuario.nombre == "Ana")
    }

    // MARK: Refresco, recuperación y salida

    @Test func refrescarUsaElTokenDeRefresco() async throws {
        let falso = TransporteFalso()
        falso.responder(200, Self.respuestaSesion)
        let vieja = Sesion(tokenAcceso: "a", tokenRefresco: "r-viejo", expiraEn: ahora, usuario: Usuario(id: "u1", email: nil, nombre: nil))
        _ = try await cliente(falso).refrescar(vieja)

        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.url?.query == "grant_type=refresh_token")
        #expect(cuerpo(solicitud)["refresh_token"] as? String == "r-viejo")
    }

    @Test func laSesionPideRefrescoUnMinutoAntesDeExpirar() {
        let usuario = Usuario(id: "u", email: nil, nombre: nil)
        let vigente = Sesion(tokenAcceso: "a", tokenRefresco: "r", expiraEn: ahora.addingTimeInterval(300), usuario: usuario)
        let porVencer = Sesion(tokenAcceso: "a", tokenRefresco: "r", expiraEn: ahora.addingTimeInterval(30), usuario: usuario)
        #expect(!vigente.necesitaRefresco(ahora: ahora))
        #expect(porVencer.necesitaRefresco(ahora: ahora))
    }

    @Test func recuperarContrasenaEnviaElCorreo() async throws {
        let falso = TransporteFalso()
        try await cliente(falso).recuperarContrasena(email: "ana@correo.mx")
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.url?.path == "/auth/v1/recover")
        #expect(cuerpo(solicitud)["email"] as? String == "ana@correo.mx")
    }

    @Test func cerrarSesionMandaElTokenDeAcceso() async throws {
        let falso = TransporteFalso()
        falso.responder(204, "")
        let sesion = Sesion(tokenAcceso: "token-x", tokenRefresco: "r", expiraEn: ahora, usuario: Usuario(id: "u", email: nil, nombre: nil))
        await cliente(falso).cerrarSesion(sesion)
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.url?.path == "/auth/v1/logout")
        #expect(solicitud.value(forHTTPHeaderField: "Authorization") == "Bearer token-x")
    }

    // MARK: OAuth con PKCE

    @Test func pkceCoincideConElEjemploDelRFC7636() {
        let pkce = PKCE(verificador: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.reto == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func pkceGeneradoEsUrlSeguroYDistinto() {
        let uno = PKCE.generar()
        let otro = PKCE.generar()
        #expect(uno.verificador != otro.verificador)
        #expect(uno.verificador.count >= 43)
        #expect(!uno.verificador.contains(where: { "+/=".contains($0) }))
    }

    @Test func urlDeOAuthLlevaProveedorRedireccionYReto() throws {
        let pkce = PKCE(verificador: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        let url = cliente(TransporteFalso()).urlOAuth(.google, redireccion: URL(string: "cadiva://auth")!, pkce: pkce)
        let partes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let consulta = Dictionary(uniqueKeysWithValues: (partes.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(partes.path == "/auth/v1/authorize")
        #expect(consulta["provider"] == "google")
        #expect(consulta["redirect_to"] == "cadiva://auth")
        #expect(consulta["code_challenge"] == pkce.reto)
        #expect(consulta["code_challenge_method"] == "s256")
    }

    @Test func codigoDeLaRedireccion() throws {
        #expect(try ClienteAuth.codigo(de: URL(string: "cadiva://auth?code=abc123")!) == "abc123")
        #expect(throws: ErrorAuth.proveedorDeshabilitado) {
            try ClienteAuth.codigo(de: URL(string: "cadiva://auth?error=invalid_request&error_description=Unsupported%20provider")!)
        }
        #expect(throws: ErrorAuth.respuestaInvalida) {
            try ClienteAuth.codigo(de: URL(string: "cadiva://auth")!)
        }
    }

    @Test func canjearCodigoEnviaElVerificador() async throws {
        let falso = TransporteFalso()
        falso.responder(200, Self.respuestaSesion)
        _ = try await cliente(falso).canjearCodigo("abc123", pkce: PKCE(verificador: "verificador-1"))
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.url?.query == "grant_type=pkce")
        #expect(cuerpo(solicitud)["auth_code"] as? String == "abc123")
        #expect(cuerpo(solicitud)["code_verifier"] as? String == "verificador-1")
    }

    @Test func elNombreSaleDeLosMetadatosDeGoogle() async throws {
        let falso = TransporteFalso()
        falso.responder(200, """
        {"access_token":"a","expires_in":3600,"refresh_token":"r",
         "user":{"id":"u3","email":"g@gmail.com","user_metadata":{"full_name":"Gaby N"}}}
        """)
        let sesion = try await cliente(falso).canjearCodigo("c", pkce: PKCE(verificador: "v"))
        #expect(sesion.usuario.nombre == "Gaby N")
    }

    @Test func validacionesLocales() {
        #expect(ClienteAuth.esCorreoValido("ana@correo.mx"))
        #expect(!ClienteAuth.esCorreoValido("ana@correo"))
        #expect(!ClienteAuth.esCorreoValido("anacorreo.mx"))
        #expect(!ClienteAuth.esCorreoValido(""))
    }
}
