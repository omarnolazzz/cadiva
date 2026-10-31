import AuthenticationServices
import CadivaCore
import SwiftUI

/// Proveedores disponibles (hoy Google). Cada uno abre su página de inicio de sesión en una hoja segura del sistema.
struct BotonesProveedores: View {
    @Binding var cargando: Bool
    @Binding var error: String?

    @Environment(SesionUsuario.self) private var sesion
    @Environment(\.webAuthenticationSession) private var web
    @ScaledMetric(relativeTo: .body) private var alto: CGFloat = 56

    /// Facebook y Apple necesitan apps de desarrollador propias; se agregan cuando estén configuradas.
    static let disponibles: [ProveedorOAuth] = [.google]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Self.disponibles) { proveedor in
                Button {
                    entrar(con: proveedor)
                } label: {
                    HStack(spacing: 10) {
                        logo(proveedor)
                        Text("Continuar con \(nombre(proveedor))")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.cadiva.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: alto)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cadiva.textSecondary.opacity(0.25), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continuar con \(nombre(proveedor))")
            }
        }
        .disabled(cargando)
    }

    @ViewBuilder
    private func logo(_ proveedor: ProveedorOAuth) -> some View {
        switch proveedor {
        case .facebook:
            Image("LogoFacebook").resizable().scaledToFit().frame(width: 24, height: 24)
        case .google:
            Image("LogoGoogle").resizable().scaledToFit().frame(width: 24, height: 24)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.title2)
                .foregroundStyle(Color.cadiva.textPrimary)
        }
    }

    private func nombre(_ proveedor: ProveedorOAuth) -> String {
        switch proveedor {
        case .facebook: "Facebook"
        case .google: "Google"
        case .apple: "Apple"
        }
    }

    private func entrar(con proveedor: ProveedorOAuth) {
        error = nil
        cargando = true
        Task {
            defer { cargando = false }
            do {
                try await sesion.entrar(con: proveedor, usando: web)
            } catch ErrorAuth.cancelado {
                return
            } catch {
                self.error = MensajeError.texto(error)
            }
        }
    }
}
