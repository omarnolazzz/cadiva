import AuthenticationServices
import CadivaCore
import SwiftUI

/// Rutas dentro del flujo de cuenta.
enum PantallaCuenta: Hashable {
    case registro
    case recuperar
}

/// Botón principal relleno, con indicador de carga.
struct BotonPrincipal: View {
    let titulo: String
    var cargando = false
    let accion: () -> Void

    @Environment(\.isEnabled) private var habilitado

    var body: some View {
        Button(action: accion) {
            ZStack {
                Text(titulo).opacity(cargando ? 0 : 1)
                if cargando {
                    ProgressView().tint(.white)
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.cadiva.brandDeep.opacity(habilitado ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(cargando)
    }
}

/// Botón secundario con contorno.
struct BotonSecundario: View {
    let titulo: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(titulo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.cadiva.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cadiva.textPrimary, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

/// Campo de texto con fondo suave y borde, como en el diseño de referencia.
struct CampoCuenta: View {
    enum Tipo { case nombre, correo, contrasena, nuevaContrasena }

    let titulo: String
    @Binding var texto: String
    let tipo: Tipo

    @State private var visible = false

    private var esSecreto: Bool { tipo == .contrasena || tipo == .nuevaContrasena }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if esSecreto && !visible {
                    SecureField(titulo, text: $texto)
                } else {
                    TextField(titulo, text: $texto)
                }
            }
            .textContentType(tipoContenido)
            .keyboardType(tipo == .correo ? .emailAddress : .default)
            .textInputAutocapitalization(tipo == .nombre ? .words : .never)
            .autocorrectionDisabled()
            .foregroundStyle(Color.cadiva.textPrimary)

            if esSecreto {
                Button {
                    visible.toggle()
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(visible ? "Ocultar contraseña" : "Mostrar contraseña")
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 56)
        .background(Color.cadiva.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cadiva.textSecondary.opacity(0.25), lineWidth: 1))
    }

    private var tipoContenido: UITextContentType {
        switch tipo {
        case .nombre: .name
        case .correo: .username
        case .contrasena: .password
        case .nuevaContrasena: .newPassword
        }
    }
}

/// Línea con texto al centro: "O inicia sesión con".
struct SeparadorTexto: View {
    let texto: String

    var body: some View {
        HStack(spacing: 12) {
            linea
            Text(texto)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.cadiva.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .layoutPriority(1)
            linea
        }
        .padding(.vertical, 6)
    }

    private var linea: some View {
        Rectangle().fill(Color.cadiva.textSecondary.opacity(0.25)).frame(minWidth: 24, maxWidth: .infinity, maxHeight: 1)
    }
}

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

/// Foto de perfil de la cuenta (la de Google) en un círculo. Mientras carga o si no hay, las iniciales.
struct AvatarUsuario: View {
    let usuario: Usuario
    var lado: CGFloat = 44

    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    private var tamano: CGFloat { lado * min(escala, 1.5) }

    var body: some View {
        ZStack {
            iniciales
            if let foto = usuario.foto {
                AsyncImage(url: foto, transaction: Transaction(animation: .easeOut(duration: 0.35))) { fase in
                    if let imagen = fase.image {
                        imagen
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.cadiva.surface, lineWidth: 2))
        .accessibilityHidden(true)
    }

    private var iniciales: some View {
        let base = usuario.nombre ?? usuario.email ?? "?"
        let letras = String(base.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
        return Text(letras)
            .font(.system(size: tamano * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.cadiva.brand)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cadiva.tint)
    }
}

/// Mensaje de error en línea.
struct MensajeError: View {
    let texto: String?

    static func texto(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    var body: some View {
        if let texto {
            Label(texto, systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.cadiva.priceUp)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// Estructura común de Iniciar sesión, Registro y Recuperar: atrás, título, contenido y pie.
struct FormularioCuenta<Contenido: View, Pie: View>: View {
    let titulo: String
    var subtitulo: String?
    @ViewBuilder let contenido: Contenido
    @ViewBuilder let pie: Pie

    @Environment(SesionUsuario.self) private var sesion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(titulo)
                        .font(.title.bold())
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitulo {
                        Text(subtitulo)
                            .font(.callout)
                            .foregroundStyle(Color.cadiva.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 12)

                if !sesion.cuentasDisponibles {
                    Label("Las cuentas todavía no están configuradas en esta versión. Puedes usar Cadiva como invitado.", systemImage: "info.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.cadiva.brand)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cadiva.tint, in: RoundedRectangle(cornerRadius: 10))
                }

                contenido
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            pie
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.cadiva.surface)
        }
        .background(Color.cadiva.surface)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .frame(width: 41, height: 41)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cadiva.textSecondary.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Atrás")
            }
        }
        .toolbarBackground(Color.cadiva.surface, for: .navigationBar)
    }
}

/// "¿No tienes cuenta? Regístrate".
struct PieCuenta: View {
    let pregunta: String
    let accion: String
    let alTocar: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { contenido }
            VStack(spacing: 4) { contenido }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var contenido: some View {
        Text(pregunta).foregroundStyle(Color.cadiva.textPrimary)
        Button(accion, action: alTocar)
            .fontWeight(.bold)
            .foregroundStyle(Color.cadiva.brand)
    }
}
