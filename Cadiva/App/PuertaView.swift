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
                LoginView()
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
