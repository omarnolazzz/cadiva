import CadivaCore
import SwiftData
import SwiftUI
import UIKit

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
                Group {
                    if let usuario {
                        AvatarUsuario(usuario: usuario, lado: 80)
                    } else {
                        SimboloAnimado(lado: 72, inicio: inicioSimbolo)
                    }
                }
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
        AlmacenLocal.borrarTodo(en: contexto)
        sesion.entrarConCuenta()
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
