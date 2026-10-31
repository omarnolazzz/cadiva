import AuthenticationServices
import CadivaCore
import SwiftUI

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
