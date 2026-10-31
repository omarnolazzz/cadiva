import CadivaCore
import SwiftUI

struct RecuperarView: View {
    @Binding var ruta: [PantallaCuenta]

    @Environment(SesionUsuario.self) private var sesion
    @State private var email = ""
    @State private var error: String?
    @State private var cargando = false
    @State private var enviado = false

    var body: some View {
        FormularioCuenta(
            titulo: "¿Olvidaste tu contraseña?",
            subtitulo: "No te preocupes. Escribe el correo de tu cuenta y te mandamos un enlace para crear una nueva."
        ) {
            CampoCuenta(titulo: "Escribe tu correo", texto: $email, tipo: .correo)
                .submitLabel(.send)
                .onSubmit(enviar)
            MensajeError(texto: error)
            if enviado {
                Label("Listo. Si existe una cuenta con ese correo, te llegará el enlace en unos minutos.", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.cadiva.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BotonPrincipal(titulo: enviado ? "Enviar de nuevo" : "Enviar enlace", cargando: cargando, accion: enviar)
                .disabled(!ClienteAuth.esCorreoValido(email))
                .padding(.top, 8)
        } pie: {
            PieCuenta(pregunta: "¿Recordaste tu contraseña?", accion: "Inicia sesión") { ruta = [] }
        }
    }

    private func enviar() {
        guard ClienteAuth.esCorreoValido(email), !cargando else { return }
        error = nil
        cargando = true
        Task {
            defer { cargando = false }
            do {
                try await sesion.recuperarContrasena(email: email)
                enviado = true
            } catch {
                self.error = MensajeError.texto(error)
            }
        }
    }
}
