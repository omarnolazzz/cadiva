import CadivaCore
import SwiftUI

/// Login como el del video: imagen arriba y una tarjeta que sube con el formulario.
struct LoginView: View {
    @Environment(SesionUsuario.self) private var sesion
    @State private var ruta: [PantallaCuenta] = []
    @State private var email = ""
    @State private var contrasena = ""
    @State private var error: String?
    @State private var cargando = false
    @State private var entrada = false
    @FocusState private var foco: Campo?

    private enum Campo: Hashable { case email, contrasena }

    private var esValido: Bool { ClienteAuth.esCorreoValido(email) && !contrasena.isEmpty }

    var body: some View {
        NavigationStack(path: $ruta) {
            GeometryReader { geometria in
                ScrollView {
                    VStack(spacing: 0) {
                        Image("BienvenidaFoto")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometria.size.width, height: geometria.size.height * 0.4)
                            .clipped()
                            .scaleEffect(entrada ? 1 : 1.12, anchor: .top)
                            .opacity(entrada ? 1 : 0)
                            .accessibilityHidden(true)

                        tarjeta
                            .frame(minHeight: geometria.size.height * 0.6 + 32, alignment: .top)
                            .padding(.top, -32)
                            .offset(y: entrada ? 0 : 160)
                            .opacity(entrada ? 1 : 0)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea(edges: .top)
            .background(Color.cadiva.surface)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PantallaCuenta.self) { pantalla in
                switch pantalla {
                case .registro: RegistroCuentaView(ruta: $ruta)
                case .recuperar: RecuperarView(ruta: $ruta)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.88).delay(0.05)) { entrada = true }
        }
        #if DEBUG
        .onAppear {
            switch Demo.valor("--pantalla") {
            case "registro-cuenta": ruta = [.registro]
            case "recuperar": ruta = [.recuperar]
            default: break
            }
        }
        #endif
    }

    private var tarjeta: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.cadiva.textSecondary.opacity(0.25))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            VStack(spacing: 2) {
                Text("Lleva el control de")
                    .foregroundStyle(Color.cadiva.textPrimary)
                Text("tus precios")
                    .foregroundStyle(Color.cadiva.brand)
            }
            .font(.title.bold())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .entrada(retraso: 0.25)

            if !sesion.cuentasDisponibles {
                Label("Las cuentas todavía no están configuradas en esta versión. Puedes usar Cadiva como invitado.", systemImage: "info.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.cadiva.brand)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cadiva.tint, in: RoundedRectangle(cornerRadius: 10))
            }

            Group {
                CampoCuenta(titulo: "Escribe tu correo", texto: $email, tipo: .correo)
                    .focused($foco, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { foco = .contrasena }
                    .entrada(retraso: 0.32)
                CampoCuenta(titulo: "Escribe tu contraseña", texto: $contrasena, tipo: .contrasena)
                    .focused($foco, equals: .contrasena)
                    .submitLabel(.go)
                    .onSubmit(entrar)
                    .entrada(retraso: 0.38)
                HStack {
                    Spacer()
                    Button("¿Olvidaste tu contraseña?") { ruta.append(.recuperar) }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.cadiva.brand)
                }
                .entrada(retraso: 0.42)
                MensajeError(texto: error)
                BotonPrincipal(titulo: "Iniciar sesión", cargando: cargando, accion: entrar)
                    .disabled(!esValido)
                    .entrada(retraso: 0.46)
                SeparadorTexto(texto: "O continúa con")
                    .entrada(retraso: 0.5)
                BotonesProveedores(cargando: $cargando, error: $error)
                    .entrada(retraso: 0.54)
            }

            VStack(spacing: 14) {
                PieCuenta(pregunta: "¿No tienes cuenta?", accion: "Crear una cuenta") { ruta.append(.registro) }
                Button("Continuar como invitado") { sesion.continuarComoInvitado() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .entrada(retraso: 0.6)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(Color.cadiva.surface)
        )
    }

    private func entrar() {
        guard esValido, !cargando else { return }
        foco = nil
        error = nil
        cargando = true
        Task {
            defer { cargando = false }
            do {
                try await sesion.iniciarSesion(email: email, contrasena: contrasena)
            } catch {
                withAnimation { self.error = MensajeError.texto(error) }
            }
        }
    }
}

#if DEBUG

private extension SesionUsuario {
    static var vistaPrevia: SesionUsuario { SesionUsuario(estado: .sinSesion, cliente: nil) }
}

#Preview("Login · claro") {
    LoginView()
        .environment(SesionUsuario.vistaPrevia)
        .environment(Sincronizador())
}

#Preview("Login · oscuro") {
    LoginView()
        .environment(SesionUsuario.vistaPrevia)
        .environment(Sincronizador())
        .preferredColorScheme(.dark)
}

#Preview("Registro · oscuro") {
    @Previewable @State var ruta: [PantallaCuenta] = []
    NavigationStack { RegistroCuentaView(ruta: $ruta) }
        .environment(SesionUsuario.vistaPrevia)
        .environment(Sincronizador())
        .preferredColorScheme(.dark)
}

#Preview("Recuperar · claro") {
    @Previewable @State var ruta: [PantallaCuenta] = []
    NavigationStack { RecuperarView(ruta: $ruta) }
        .environment(SesionUsuario.vistaPrevia)
        .environment(Sincronizador())
}

#Preview("Arranque · oscuro") {
    ArranqueView()
        .preferredColorScheme(.dark)
}
#endif
