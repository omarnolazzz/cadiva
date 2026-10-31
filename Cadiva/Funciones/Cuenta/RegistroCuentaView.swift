import CadivaCore
import SwiftUI

struct RegistroCuentaView: View {
    @Binding var ruta: [PantallaCuenta]

    @Environment(SesionUsuario.self) private var sesion
    @State private var nombre = ""
    @State private var email = ""
    @State private var contrasena = ""
    @State private var confirmacion = ""
    @State private var error: String?
    @State private var cargando = false
    @State private var correoPorConfirmar: String?
    @State private var mostrarConfirmacion = false

    static let largoMinimo = 8

    private var aviso: String? {
        if !email.isEmpty && !ClienteAuth.esCorreoValido(email) { return "Revisa el correo; parece incompleto." }
        if !contrasena.isEmpty && contrasena.count < Self.largoMinimo { return "La contraseña necesita al menos \(Self.largoMinimo) caracteres." }
        if !confirmacion.isEmpty && confirmacion != contrasena { return "Las contraseñas no coinciden." }
        return nil
    }

    private var esValido: Bool {
        !nombre.recortado.isEmpty && ClienteAuth.esCorreoValido(email)
            && contrasena.count >= Self.largoMinimo && confirmacion == contrasena
    }

    var body: some View {
        FormularioCuenta(titulo: "¡Hola! Regístrate para empezar") {
            CampoCuenta(titulo: "Nombre", texto: $nombre, tipo: .nombre)
            CampoCuenta(titulo: "Correo", texto: $email, tipo: .correo)
            CampoCuenta(titulo: "Contraseña", texto: $contrasena, tipo: .nuevaContrasena)
            CampoCuenta(titulo: "Confirma la contraseña", texto: $confirmacion, tipo: .nuevaContrasena)
                .submitLabel(.join)
                .onSubmit(registrar)
            MensajeError(texto: error ?? aviso)
            BotonPrincipal(titulo: "Crear cuenta", cargando: cargando, accion: registrar)
                .disabled(!esValido)
                .padding(.top, 8)
            SeparadorTexto(texto: "O regístrate con")
                .padding(.top, 12)
            BotonesProveedores(cargando: $cargando, error: $error)
        } pie: {
            PieCuenta(pregunta: "¿Ya tienes cuenta?", accion: "Inicia sesión") { ruta = [] }
        }
        .alert(
            "Revisa tu correo",
            isPresented: $mostrarConfirmacion
        ) {
            Button("Ir a iniciar sesión") { ruta = [] }
        } message: {
            Text("Te enviamos un enlace a \(correoPorConfirmar ?? "tu correo") para confirmar tu cuenta. Después inicia sesión.")
        }
    }

    private func registrar() {
        guard esValido, !cargando else { return }
        error = nil
        cargando = true
        Task {
            defer { cargando = false }
            do {
                let resultado = try await sesion.registrar(nombre: nombre.recortado, email: email, contrasena: contrasena)
                if case let .confirmacionPendiente(correo) = resultado {
                    correoPorConfirmar = correo
                    mostrarConfirmacion = true
                }
            } catch {
                self.error = MensajeError.texto(error)
            }
        }
    }
}
