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
