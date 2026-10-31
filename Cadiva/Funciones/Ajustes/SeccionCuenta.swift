import SwiftData
import SwiftUI
import UIKit

/// Quién usa la app, la sincronización y cerrar sesión. Como invitado, invita a iniciar sesión.
struct SeccionCuenta: View {
    @Environment(\.modelContext) private var contexto
    @Environment(SesionUsuario.self) private var sesion
    @Environment(Sincronizador.self) private var sincronizador

    @State private var confirmarSalida = false

    var body: some View {
        Section {
            if let usuario = sesion.usuario {
                HStack(spacing: 14) {
                    AvatarUsuario(usuario: usuario, lado: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(usuario.nombre ?? "Tu cuenta")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.cadiva.textPrimary)
                        if let email = usuario.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(Color.cadiva.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                Button {
                    Task { await sincronizador.sincronizar(contexto: contexto, sesion: sesion) }
                } label: {
                    HStack {
                        Label("Sincronizar ahora", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if sincronizador.estado == .sincronizando {
                            ProgressView()
                        }
                    }
                }
                .disabled(sincronizador.estado == .sincronizando)
                Button("Cerrar sesión", role: .destructive) { confirmarSalida = true }
            } else {
                Button {
                    sesion.irABienvenida()
                } label: {
                    Label("Iniciar sesión o crear cuenta", systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text("Cuenta")
        } footer: {
            Text(sesion.usuario == nil
                 ? "Estás usando Cadiva como invitado. Tus compras se guardan solo en este iPhone. Inicia sesión para guardarlas en tu cuenta."
                 : textoSincronizacion)
        }
        .celdaCadiva()
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Cerrar sesión y borrar del iPhone", role: .destructive) { salir(borrandoDatos: true) }
            Button("Cerrar sesión y conservar en el iPhone") { salir(borrandoDatos: false) }
        } message: {
            Text("Tus compras siguen guardadas en tu cuenta. Si las conservas en el iPhone y entras con otra cuenta, se agregarán a esa cuenta.")
        }
    }

    private var textoSincronizacion: String {
        switch sincronizador.estado {
        case .sincronizando:
            return "Sincronizando con tu cuenta…"
        case let .error(mensaje):
            return "No se pudo sincronizar. \(mensaje)"
        case .inactivo, .listo:
            guard let ultima = sincronizador.ultima else {
                return "Tus compras se guardan en tu cuenta y en este iPhone."
            }
            return "Sincronizado con tu cuenta \(ultima.formatted(.relative(presentation: .named).locale(.cadiva)))."
        }
    }

    private func salir(borrandoDatos: Bool) {
        let usuario = sesion.usuario?.id
        Task {
            // Último intento de subir lo pendiente antes de salir.
            await sincronizador.sincronizar(contexto: contexto, sesion: sesion)
            // Primero se cierra la sesión: así borrar aquí no se toma como borrar en la nube.
            await sesion.cerrarSesion()
            if borrandoDatos {
                AlmacenLocal.borrarTodo(en: contexto)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                if let usuario { sincronizador.olvidar(usuario: usuario) }
            }
        }
    }
}
