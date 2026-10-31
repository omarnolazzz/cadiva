import CadivaCore
import SwiftData
import SwiftUI
import UIKit

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
