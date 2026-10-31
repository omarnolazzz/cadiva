import SwiftData
import SwiftUI
import UIKit

// MARK: Piezas del PIN

/// Cuatro puntos que se llenan con cada dígito. Tiemblan en rojo si el PIN es incorrecto.
struct PuntosPIN: View {
    enum Estado: Equatable { case normal, error, exito }

    let llenos: Int
    var estado: Estado = .normal
    var intentoFallido = 0

    var body: some View {
        HStack(spacing: 22) {
            ForEach(0..<Seguridad.largoPIN, id: \.self) { indice in
                let lleno = indice < llenos
                Circle()
                    .fill(lleno ? color : Color.clear)
                    .overlay(Circle().stroke(lleno ? color : Color.cadiva.textSecondary.opacity(0.5), lineWidth: 1.5))
                    .frame(width: 15, height: 15)
                    .scaleEffect(lleno ? 1.15 : 1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.5), value: lleno)
            }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: intentoFallido) { vista, desplazamiento in
            vista.offset(x: desplazamiento)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(-14, duration: 0.06)
                SpringKeyframe(12, duration: 0.065)
                SpringKeyframe(-9, duration: 0.07)
                SpringKeyframe(6, duration: 0.075)
                SpringKeyframe(-3, duration: 0.08)
                SpringKeyframe(0, duration: 0.085)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(llenos) de \(Seguridad.largoPIN) dígitos")
    }

    private var color: Color {
        switch estado {
        case .normal: Color.cadiva.brand
        case .error: Color.cadiva.priceUp
        case .exito: Color.cadiva.priceDown
        }
    }
}

/// Teclado numérico de botones redondos. En iOS 26 los botones son de Liquid Glass.
struct TecladoPIN: View {
    /// Símbolo de la tecla de abajo a la izquierda (Face ID), si hay.
    var simboloExtra: String?
    var etiquetaExtra = ""
    let alPulsar: (String) -> Void
    let alBorrar: () -> Void
    var alExtra: () -> Void = {}

    @ScaledMetric(relativeTo: .title) private var lado: CGFloat = 76

    private let filas = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(filas, id: \.self) { fila in
                HStack(spacing: 26) {
                    ForEach(fila, id: \.self) { digito in
                        tecla { Text(digito).font(.system(size: lado * 0.4, weight: .medium, design: .rounded)) } accion: { alPulsar(digito) }
                            .accessibilityLabel(digito)
                    }
                }
            }
            HStack(spacing: 26) {
                if let simboloExtra {
                    tecla(conFondo: false) { Image(systemName: simboloExtra).font(.system(size: lado * 0.36)) } accion: { alExtra() }
                        .accessibilityLabel(etiquetaExtra)
                } else {
                    Color.clear.frame(width: lado, height: lado)
                }
                tecla { Text("0").font(.system(size: lado * 0.4, weight: .medium, design: .rounded)) } accion: { alPulsar("0") }
                    .accessibilityLabel("0")
                tecla(conFondo: false) { Image(systemName: "delete.left").font(.system(size: lado * 0.3)) } accion: { alBorrar() }
                    .accessibilityLabel("Borrar")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func tecla<Contenido: View>(conFondo: Bool = true, @ViewBuilder _ contenido: () -> Contenido, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            contenido()
                .foregroundStyle(Color.cadiva.textPrimary)
                .frame(width: lado, height: lado)
                .contentShape(Circle())
        }
        .buttonStyle(TeclaEstilo(conFondo: conFondo))
    }
}

private struct TeclaEstilo: ButtonStyle {
    let conFondo: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if conFondo {
                    if #available(iOS 26.0, *) {
                        Circle().fill(.clear).glassEffect(.regular.interactive(), in: .circle)
                    } else {
                        Circle().fill(Color.cadiva.surface.opacity(0.85))
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed && !conFondo ? 0.5 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed) { _, pulsado in pulsado }
    }
}

/// Fondo de las pantallas de PIN: la imagen de bienvenida muy desenfocada.
struct FondoBloqueo: View {
    var body: some View {
        ZStack {
            Color.cadiva.background
            Image("BienvenidaFoto")
                .resizable()
                .scaledToFill()
                .blur(radius: 40)
                .opacity(0.55)
            Rectangle().fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: Pantalla de bloqueo

/// Se muestra al abrir la app (o al volver tras un rato) cuando hay PIN o Face ID.
struct BloqueoView: View {
    @Environment(SesionUsuario.self) private var sesion
    @Environment(\.modelContext) private var contexto

    @State private var pin = ""
    @State private var estado: PuntosPIN.Estado = .normal
    @State private var fallos = 0
    @State private var mensaje: String?
    @State private var visible = false
    @State private var inicioSimbolo = Date.now
    @State private var confirmarOlvido = false
    @State private var autenticando = false

    private var usuario: Usuario? { sesion.usuarioBloqueado }
    private var tienePIN: Bool { Seguridad.tienePIN }
    private var biometria: Seguridad.Biometria? { Seguridad.biometriaActiva || !tienePIN ? Seguridad.biometria : nil }

    var body: some View {
        ZStack {
            FondoBloqueo()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                encabezado
                Spacer(minLength: 24)
                if tienePIN {
                    PuntosPIN(llenos: pin.count, estado: estado, intentoFallido: fallos)
                        .padding(.bottom, 14)
                    Text(mensaje ?? " ")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(estado == .error ? Color.cadiva.priceUp : Color.cadiva.textSecondary)
                        .contentTransition(.opacity)
                        .padding(.bottom, 22)
                    TecladoPIN(
                        simboloExtra: biometria?.simbolo,
                        etiquetaExtra: "Usar \(biometria?.nombre ?? "")",
                        alPulsar: pulsar,
                        alBorrar: { if !pin.isEmpty { pin.removeLast() } },
                        alExtra: { Task { await usarBiometria() } }
                    )
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 40)
                } else if let biometria {
                    BotonPrincipal(titulo: "Desbloquear con \(biometria.nombre)") { Task { await usarBiometria() } }
                        .padding(.horizontal, 32)
                        .opacity(visible ? 1 : 0)
                }
                Spacer(minLength: 20)
                Button(usuario == nil ? "¿Olvidaste tu PIN?" : "Entrar con mi cuenta") {
                    if usuario == nil { confirmarOlvido = true } else { sesion.entrarConCuenta() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cadiva.brand)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            inicioSimbolo = .now
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.15)) { visible = true }
        }
        .task {
            // Face ID se ofrece solo, como en las apps de bancos.
            try? await Task.sleep(for: .milliseconds(650))
            if biometria != nil { await usarBiometria() }
        }
        .alert("¿Olvidaste tu PIN?", isPresented: $confirmarOlvido) {
            Button("Borrar datos y quitar PIN", role: .destructive, action: reiniciarInvitado)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Como invitado, tus datos solo viven en este iPhone. Para quitar el PIN hay que borrarlos.")
        }
    }

    private var encabezado: some View {
        VStack(spacing: 14) {
            ZStack {
                SimboloAnimado(lado: 72, inicio: inicioSimbolo)
                    .opacity(estado == .exito ? 0 : 1)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.cadiva.priceDown)
                    .scaleEffect(estado == .exito ? 1 : 0.3)
                    .opacity(estado == .exito ? 1 : 0)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: estado)
            VStack(spacing: 6) {
                Text(saludo)
                    .font(.title2.bold())
                    .foregroundStyle(Color.cadiva.textPrimary)
                Text(tienePIN ? "Ingresa tu PIN para continuar" : "Desbloquea Cadiva para continuar")
                    .font(.subheadline)
                    .foregroundStyle(Color.cadiva.textSecondary)
            }
            .multilineTextAlignment(.center)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
        }
    }

    private var saludo: String {
        let nombre = usuario?.nombre?.split(separator: " ").first.map(String.init)
        return nombre.map { "Hola, \($0)" } ?? "Hola de nuevo"
    }

    // MARK: Acciones

    private func pulsar(_ digito: String) {
        guard pin.count < Seguridad.largoPIN, estado != .exito else { return }
        if estado == .error {
            estado = .normal
            mensaje = nil
        }
        pin.append(digito)
        if pin.count == Seguridad.largoPIN { comprobar() }
    }

    private func comprobar() {
        if Seguridad.verificar(pin) {
            exito()
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        fallos += 1
        estado = .error
        let restantes = Seguridad.intentosRestantes
        if restantes == 0 {
            if usuario != nil {
                mensaje = "Demasiados intentos. Inicia sesión con tu cuenta."
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    sesion.entrarConCuenta()
                }
            } else {
                mensaje = "Demasiados intentos. Espera un momento."
                Task {
                    try? await Task.sleep(for: .seconds(30))
                    Seguridad.reiniciarIntentos()
                    mensaje = nil
                }
            }
        } else {
            mensaje = restantes == 1 ? "PIN incorrecto. Te queda 1 intento." : "PIN incorrecto. Te quedan \(restantes) intentos."
        }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) { pin = "" }
        }
    }

    private func usarBiometria() async {
        guard !autenticando, estado != .exito, let biometria else { return }
        autenticando = true
        defer { autenticando = false }
        if await Seguridad.autenticarConBiometria(motivo: "Desbloquea Cadiva con \(biometria.nombre)") {
            pin = String(repeating: "•", count: tienePIN ? Seguridad.largoPIN : 0)
            exito()
        }
    }

    private func exito() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        estado = .exito
        mensaje = nil
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            sesion.desbloquear()
        }
    }

    private func reiniciarInvitado() {
        for compra in (try? contexto.fetch(FetchDescriptor<Compra>())) ?? [] { contexto.delete(compra) }
        for producto in (try? contexto.fetch(FetchDescriptor<Producto>())) ?? [] { contexto.delete(producto) }
        try? contexto.save()
        sesion.entrarConCuenta()
    }
}

// MARK: Crear PIN

/// Dos pasos: escribir y confirmar. Si no coinciden, tiembla y vuelve a empezar.
struct CrearPINView: View {
    var alTerminar: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var primero: String?
    @State private var pin = ""
    @State private var estado: PuntosPIN.Estado = .normal
    @State private var fallos = 0
    @State private var mensaje: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FondoBloqueo()
                VStack(spacing: 0) {
                    Spacer(minLength: 16)
                    Image(systemName: estado == .exito ? "checkmark.shield.fill" : "lock.shield.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(estado == .exito ? Color.cadiva.priceDown : Color.cadiva.brand)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: primero != nil)
                        .padding(.bottom, 16)
                    Text(titulo)
                        .font(.title2.bold())
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .contentTransition(.opacity)
                        .id(titulo)
                        .transition(.push(from: .trailing).combined(with: .opacity))
                    Text(mensaje ?? "Lo usarás para abrir Cadiva.")
                        .font(.subheadline)
                        .foregroundStyle(estado == .error ? Color.cadiva.priceUp : Color.cadiva.textSecondary)
                        .padding(.top, 6)
                    Spacer(minLength: 24)
                    PuntosPIN(llenos: pin.count, estado: estado, intentoFallido: fallos)
                        .padding(.bottom, 36)
                    TecladoPIN(
                        alPulsar: pulsar,
                        alBorrar: { if !pin.isEmpty { pin.removeLast() } }
                    )
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: titulo)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private var titulo: String {
        if estado == .exito { return "PIN guardado" }
        return primero == nil ? "Crea tu PIN" : "Confirma tu PIN"
    }

    private func pulsar(_ digito: String) {
        guard pin.count < Seguridad.largoPIN, estado != .exito else { return }
        if estado == .error { estado = .normal }
        pin.append(digito)
        guard pin.count == Seguridad.largoPIN else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(200))
            if let primero {
                if primero == pin {
                    Seguridad.guardarPIN(pin)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    estado = .exito
                    try? await Task.sleep(for: .milliseconds(900))
                    alTerminar()
                    dismiss()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    fallos += 1
                    estado = .error
                    mensaje = "No coinciden. Vuelve a crearlo."
                    try? await Task.sleep(for: .milliseconds(450))
                    self.primero = nil
                    pin = ""
                }
            } else {
                primero = pin
                mensaje = nil
                pin = ""
            }
        }
    }
}

// MARK: Oferta tras iniciar sesión

/// Tras iniciar sesión sin PIN ni Face ID: así no habrá que escribir la contraseña cada vez.
struct OfertaBloqueoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var creandoPIN = false
    @State private var aparecer = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: Seguridad.biometria?.simbolo ?? "lock.shield.fill")
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(Color.cadiva.brand)
                .symbolEffect(.bounce, value: aparecer)
                .padding(.top, 28)
            VStack(spacing: 8) {
                Text("Entra más rápido")
                    .font(.title2.bold())
                    .foregroundStyle(Color.cadiva.textPrimary)
                Text("Cada vez que abras Cadiva te pediremos tu contraseña. Con \(Seguridad.biometria.map { "\($0.nombre) o " } ?? "")un PIN entras en un segundo.")
                    .font(.callout)
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 12) {
                if let biometria = Seguridad.biometria {
                    BotonPrincipal(titulo: "Usar \(biometria.nombre)") {
                        Task {
                            if await Seguridad.autenticarConBiometria(motivo: "Activa \(biometria.nombre) para abrir Cadiva") {
                                Seguridad.biometriaActiva = true
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    }
                }
                BotonSecundario(titulo: "Crear un PIN") { creandoPIN = true }
                Button("Ahora no") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { aparecer = true }
        .sheet(isPresented: $creandoPIN) {
            CrearPINView { dismiss() }
        }
    }
}

#if DEBUG
#Preview("Bloqueo") {
    BloqueoView()
        .environment(SesionUsuario(estado: .bloqueado(Usuario(id: "1", email: "gabriel@correo.pe", nombre: "Gabriel Nolazco")), cliente: nil))
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Crear PIN · oscuro") {
    CrearPINView()
        .preferredColorScheme(.dark)
}

#Preview("Oferta") {
    Color.clear.sheet(isPresented: .constant(true)) { OfertaBloqueoView() }
}
#endif
