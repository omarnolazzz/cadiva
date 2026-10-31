import CadivaCore
import SwiftData
import SwiftUI
import UIKit

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
