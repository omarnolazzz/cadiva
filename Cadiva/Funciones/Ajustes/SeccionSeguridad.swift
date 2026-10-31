import SwiftUI

/// PIN y Face ID / Touch ID para abrir la app.
struct SeccionSeguridad: View {
    /// La hoja de crear PIN vive en `AjustesView`: dentro de un `Form` no se presenta.
    @Binding var creandoPIN: Bool
    /// El estado de `Seguridad` no es observable; cambiar este número obliga a redibujar.
    @Binding var version: Int

    var body: some View {
        let _ = version
        Section {
            if Seguridad.tienePIN {
                Button {
                    creandoPIN = true
                } label: {
                    Label("Cambiar PIN", systemImage: "lock.rotation")
                }
                Button(role: .destructive) {
                    withAnimation {
                        Seguridad.quitarPIN()
                        version += 1
                    }
                } label: {
                    Label("Quitar PIN", systemImage: "lock.open")
                        .foregroundStyle(Color.cadiva.priceUp)
                }
            } else {
                Button {
                    creandoPIN = true
                } label: {
                    Label("Crear PIN", systemImage: "lock.fill")
                }
            }
            if let biometria = Seguridad.biometria {
                Toggle(isOn: Binding(
                    get: { Seguridad.biometriaActiva },
                    set: { activar in
                        Task {
                            let permitido = activar
                                ? await Seguridad.autenticarConBiometria(motivo: "Activa \(biometria.nombre) para abrir Cadiva")
                                : true
                            if permitido {
                                withAnimation {
                                    Seguridad.biometriaActiva = activar
                                    version += 1
                                }
                            }
                        }
                    }
                )) {
                    Label("Desbloquear con \(biometria.nombre)", systemImage: biometria.simbolo)
                }
            }
        } header: {
            Text("Seguridad")
        } footer: {
            Text(Seguridad.bloqueoConfigurado
                 ? "Cadiva te pedirá tu \(textoBloqueo) al abrirla y cuando vuelvas después de un minuto."
                 : "Sin PIN ni \(Seguridad.biometria?.nombre ?? "Face ID") tendrás que iniciar sesión cada vez que abras Cadiva.")
        }
        .celdaCadiva()
    }

    private var textoBloqueo: String {
        switch (Seguridad.tienePIN, Seguridad.biometriaActiva ? Seguridad.biometria : nil) {
        case let (true, biometria?): "PIN o \(biometria.nombre)"
        case let (false, biometria?): biometria.nombre
        default: "PIN"
        }
    }
}
