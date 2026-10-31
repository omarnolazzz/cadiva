import CadivaCore
import SwiftUI

/// Decide qué se ve: arranque, login, bloqueo o la app. Todas las entradas son animadas.
struct PuertaView: View {
    @Environment(SesionUsuario.self) private var sesion
    @Environment(\.scenePhase) private var fase

    @State private var salioEn: Date?

    /// Si la app pasa más de este tiempo en segundo plano, se vuelve a bloquear.
    private let graciaSegundoPlano: TimeInterval = 60

    var body: some View {
        ZStack {
            switch sesion.estado {
            case .cargando:
                ArranqueView()
                    .transition(.opacity)
            case .sinSesion:
                BienvenidaView()
                    .transition(.opacity)
            case .bloqueado:
                BloqueoView()
                    .transition(.desenfoque)
            case .invitado, .conectado:
                RaizView()
                    .transition(.desenfoque)
            }

            if sesion.iniciando {
                CargandoSesionView()
                    .transition(.opacity)
                    .zIndex(10)
            }

            // En el selector de apps no se ven los datos si hay bloqueo.
            if fase != .active, Seguridad.bloqueoConfigurado, !sesion.estaBloqueado, sesion.estado != .cargando {
                ZStack {
                    FondoBloqueo()
                    Image("CadivaSimbolo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: sesion.estado)
        .animation(.easeInOut(duration: 0.35), value: sesion.iniciando)
        .animation(.easeInOut(duration: 0.2), value: fase)
        .task {
            #if DEBUG
            if Demo.valor("--pantalla") == "arranque" { return }
            #endif
            if sesion.estado == .cargando { await sesion.cargar() }
        }
        .onChange(of: fase) { _, nueva in
            switch nueva {
            case .background:
                salioEn = .now
            case .active:
                if let salioEn, Date.now.timeIntervalSince(salioEn) > graciaSegundoPlano { sesion.bloquear() }
                salioEn = nil
            default:
                break
            }
        }
    }
}

/// El símbolo se dibuja solo; luego aparecen el nombre y el lema.
struct ArranqueView: View {
    @State private var inicio = Date.now
    @State private var mostrarNombre = false
    @State private var mostrarLema = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 104

    var body: some View {
        ZStack {
            Color.cadiva.background.ignoresSafeArea()
            VStack(spacing: 18) {
                SimboloAnimado(lado: lado, inicio: inicio)
                VStack(spacing: 8) {
                    Image("CadivaLogotipo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: lado * 0.34)
                        .opacity(mostrarNombre ? 1 : 0)
                        .offset(y: mostrarNombre ? 0 : 10)
                        .blur(radius: mostrarNombre ? 0 : 6)
                    Text("Tus precios, bajo control")
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                        .opacity(mostrarLema ? 1 : 0)
                        .offset(y: mostrarLema ? 0 : 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cadiva. Tus precios, bajo control")
        }
        .task {
            inicio = .now
            let nombre = reducirMovimiento ? 0 : DibujoSimbolo.aparecer + DibujoSimbolo.trazar
            try? await Task.sleep(for: .seconds(nombre))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { mostrarNombre = true }
            try? await Task.sleep(for: .milliseconds(reducirMovimiento ? 0 : 280))
            withAnimation(.easeOut(duration: 0.5)) { mostrarLema = true }
        }
    }
}

/// Login como el del video: imagen arriba y una tarjeta que sube con el formulario.
struct BienvenidaView: View {
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
                case .registro: RegistroView(ruta: $ruta)
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

struct RegistroView: View {
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

#if DEBUG
private extension SesionUsuario {
    static var vistaPrevia: SesionUsuario { SesionUsuario(estado: .sinSesion, cliente: nil) }
}

#Preview("Login · claro") {
    BienvenidaView()
        .environment(SesionUsuario.vistaPrevia)
        .environment(Sincronizador())
}

#Preview("Login · oscuro") {
    BienvenidaView()
        .environment(SesionUsuario.vistaPrevia)
        .environment(Sincronizador())
        .preferredColorScheme(.dark)
}

#Preview("Registro · oscuro") {
    @Previewable @State var ruta: [PantallaCuenta] = []
    NavigationStack { RegistroView(ruta: $ruta) }
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
