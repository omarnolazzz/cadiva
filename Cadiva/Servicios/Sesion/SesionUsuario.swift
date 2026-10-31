import AuthenticationServices
import CadivaCore
import Foundation
import Observation
import SwiftUI

/// Estado de la cuenta: quién usa la app y cómo entró.
@Observable
@MainActor
final class SesionUsuario {
    enum Estado: Equatable {
        case cargando
        case sinSesion
        case invitado
        case conectado(Usuario)
        /// Hay sesión (o modo invitado, con `nil`) pero falta el PIN o Face ID.
        case bloqueado(Usuario?)
    }

    private(set) var estado: Estado
    /// Mientras se inicia sesión se muestra la animación de "Iniciando sesión".
    private(set) var iniciando = false
    /// Tras iniciar sesión sin PIN ni Face ID, se ofrece configurarlos.
    var ofrecerBloqueo = false
    @ObservationIgnored private let cliente: ClienteAuth?
    @ObservationIgnored private var sesion: Sesion?

    private static let claveInvitado = "entroComoInvitado"
    static let esquemaRedireccion = "cadiva"
    static let redireccion = URL(string: "cadiva://auth")!

    init(estado: Estado = .cargando, cliente: ClienteAuth? = SesionUsuario.clienteConfigurado()) {
        self.estado = estado
        self.cliente = cliente
    }

    /// `false` mientras no haya proyecto de Supabase en `Config/Supabase.xcconfig`.
    var cuentasDisponibles: Bool { cliente != nil }

    var usuario: Usuario? {
        if case let .conectado(usuario) = estado { return usuario }
        return nil
    }

    /// Quién está detrás del bloqueo, para saludar.
    var usuarioBloqueado: Usuario? {
        if case let .bloqueado(usuario) = estado { return usuario }
        return nil
    }

    var estaBloqueado: Bool {
        if case .bloqueado = estado { return true }
        return false
    }

    nonisolated static func clienteConfigurado() -> ClienteAuth? {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let host = (info["SupabaseHost"] as? String)?.trimmingCharacters(in: .whitespaces), !host.isEmpty,
              let clave = (info["SupabaseAnonKey"] as? String)?.trimmingCharacters(in: .whitespaces), !clave.isEmpty,
              let url = URL(string: "https://\(host)") else { return nil }
        return ClienteAuth(configuracion: ConfiguracionAuth(url: url, claveAnonima: clave))
    }

    // MARK: Arranque

    /// Lo que dura la animación de arranque.
    static let duracionArranque: Duration = .milliseconds(2700)

    func cargar() async {
        async let pausa: Void = Task.sleep(for: Self.duracionArranque)
        let siguiente = restaurar()
        try? await pausa
        estado = siguiente
    }

    /// Al abrir siempre se pide algo: PIN o Face ID si están configurados; si no, iniciar sesión.
    private func restaurar() -> Estado {
        let guardada = Llavero.leer().flatMap { try? JSONDecoder().decode(Sesion.self, from: $0) }
        guard Seguridad.bloqueoConfigurado else {
            // Sin PIN ni Face ID la sesión no se reutiliza: hay que volver a entrar.
            Llavero.borrar()
            return .sinSesion
        }
        if let guardada {
            sesion = guardada
            return .bloqueado(guardada.usuario)
        }
        return UserDefaults.standard.bool(forKey: Self.claveInvitado) ? .bloqueado(nil) : .sinSesion
    }

    // MARK: Bloqueo

    /// Al volver a la app después de un rato, se vuelve a pedir el PIN o Face ID.
    func bloquear() {
        guard Seguridad.bloqueoConfigurado else { return }
        switch estado {
        case let .conectado(usuario): estado = .bloqueado(usuario)
        case .invitado: estado = .bloqueado(nil)
        default: break
        }
    }

    func desbloquear() {
        guard estaBloqueado else { return }
        Seguridad.reiniciarIntentos()
        estado = sesion.map { .conectado($0.usuario) } ?? .invitado
        if let sesion, sesion.usuario.foto == nil {
            Task { await actualizarPerfil() }
        }
    }

    /// Trae de nuevo el perfil (nombre y foto) renovando la sesión. Sirve para sesiones guardadas
    /// antes de que Cadiva leyera la foto de Google. Sin internet no pasa nada.
    func actualizarPerfil() async {
        guard let actual = sesion, let cliente,
              let nueva = try? await cliente.refrescar(actual) else { return }
        guardar(nueva)
        sesion = nueva
        if case .conectado = estado { estado = .conectado(nueva.usuario) }
    }

    /// Olvidó el PIN o agotó los intentos: se quita el bloqueo y vuelve a iniciar sesión.
    func entrarConCuenta() {
        Seguridad.reiniciar()
        cerrarLocalmente()
    }

    // MARK: Acciones

    func iniciarSesion(email: String, contrasena: String) async throws {
        let cliente = try requerirCliente()
        try await conAnimacion {
            try await cliente.iniciarSesion(email: email, contrasena: contrasena)
        }
    }

    func registrar(nombre: String, email: String, contrasena: String) async throws -> ResultadoRegistro {
        let cliente = try requerirCliente()
        let resultado = try await cliente.registrar(email: email, contrasena: contrasena, nombre: nombre)
        if case let .sesion(sesion) = resultado {
            try await conAnimacion { sesion }
        }
        return resultado
    }

    /// Muestra "Iniciando sesión" mientras se espera y un momento más, para que la entrada se sienta suave.
    private func conAnimacion(_ obtener: () async throws -> Sesion) async throws {
        iniciando = true
        let inicio = ContinuousClock.now
        do {
            let nueva = try await obtener()
            let minimo = Duration.milliseconds(1600)
            let transcurrido = ContinuousClock.now - inicio
            if transcurrido < minimo { try? await Task.sleep(for: minimo - transcurrido) }
            entrar(nueva)
            try? await Task.sleep(for: .milliseconds(250))
            iniciando = false
        } catch {
            iniciando = false
            throw error
        }
    }

    func recuperarContrasena(email: String) async throws {
        try await requerirCliente().recuperarContrasena(email: email)
    }

    /// Abre el proveedor en una hoja segura del sistema y canjea el código con PKCE.
    func entrar(con proveedor: ProveedorOAuth, usando web: WebAuthenticationSession) async throws {
        let cliente = try requerirCliente()
        let pkce = PKCE.generar()
        let url = cliente.urlOAuth(proveedor, redireccion: Self.redireccion, pkce: pkce)
        let regreso: URL
        do {
            regreso = try await web.authenticate(
                using: url, callbackURLScheme: Self.esquemaRedireccion, preferredBrowserSession: .ephemeral
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw ErrorAuth.cancelado
        }
        let codigo = try ClienteAuth.codigo(de: regreso)
        try await conAnimacion { try await cliente.canjearCodigo(codigo, pkce: pkce) }
    }

    // MARK: Datos en la nube

    var clienteDatos: ClienteDatos? {
        cliente.map { ClienteDatos(configuracion: $0.configuracion) }
    }

    /// Token de acceso vigente; lo refresca si está por vencer.
    func tokenVigente() async throws -> String {
        guard var actual = sesion, let cliente else { throw ErrorAuth.sinConfiguracion }
        if actual.necesitaRefresco(ahora: .now) {
            actual = try await cliente.refrescar(actual)
            guardar(actual)
            sesion = actual
        }
        return actual.tokenAcceso
    }

    func continuarComoInvitado() {
        UserDefaults.standard.set(true, forKey: Self.claveInvitado)
        estado = .invitado
    }

    /// Desde invitado vuelve a la bienvenida para entrar o crear cuenta. Los datos se conservan.
    func irABienvenida() {
        UserDefaults.standard.set(false, forKey: Self.claveInvitado)
        estado = .sinSesion
    }

    func cerrarSesion() async {
        if let sesion, let cliente {
            await cliente.cerrarSesion(sesion)
        }
        // El PIN y Face ID eran de esta cuenta; quien entre después configura los suyos.
        Seguridad.reiniciar()
        cerrarLocalmente()
    }

    #if DEBUG
    func simularIniciando() { iniciando = true }
    #endif

    // MARK: Privado

    private func requerirCliente() throws -> ClienteAuth {
        guard let cliente else { throw ErrorAuth.sinConfiguracion }
        return cliente
    }

    private func entrar(_ nueva: Sesion) {
        guardar(nueva)
        sesion = nueva
        UserDefaults.standard.set(false, forKey: Self.claveInvitado)
        estado = .conectado(nueva.usuario)
        ofrecerBloqueo = !Seguridad.bloqueoConfigurado
    }

    private func guardar(_ sesion: Sesion) {
        if let datos = try? JSONEncoder().encode(sesion) {
            Llavero.guardar(datos)
        }
    }

    private func cerrarLocalmente() {
        Llavero.borrar()
        sesion = nil
        UserDefaults.standard.set(false, forKey: Self.claveInvitado)
        estado = .sinSesion
    }
}
