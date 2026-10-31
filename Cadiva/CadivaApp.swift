import SwiftData
import SwiftUI

@main
struct CadivaApp: App {
    private let contenedor: ModelContainer
    @State private var sesion: SesionUsuario
    @State private var sincronizador = Sincronizador()

    init() {
        contenedor = Self.crearContenedor()
        _sesion = State(initialValue: Self.crearSesion())
    }

    var body: some Scene {
        WindowGroup {
            PuertaView()
                .environment(sesion)
                .environment(sincronizador)
                .environment(\.locale, .cadiva)
                .tint(Color.cadiva.brand)
        }
        .modelContainer(contenedor)
    }

    private static func crearContenedor() -> ModelContainer {
        #if DEBUG
        if Demo.activo { return DatosEjemplo.contenedor }
        #endif
        do {
            return try ModelContainer(for: Producto.self, Compra.self)
        } catch {
            fatalError("No se pudo abrir la base de datos: \(error)")
        }
    }

    private static func crearSesion() -> SesionUsuario {
        #if DEBUG
        if Demo.activo {
            switch Demo.valor("--pantalla") {
            case "arranque": return SesionUsuario(estado: .cargando)
            case "bienvenida", "login", "registro-cuenta", "recuperar": return SesionUsuario(estado: .sinSesion)
            case "bloqueo":
                Seguridad.simulado = true
                return SesionUsuario(estado: .bloqueado(Usuario(id: "demo", email: "gabriel@correo.pe", nombre: "Gabriel Nolazco")))
            case "cargando":
                let sesion = SesionUsuario(estado: .sinSesion)
                sesion.simularIniciando()
                return sesion
            default: return SesionUsuario(estado: .invitado)
            }
        }
        #endif
        return SesionUsuario()
    }
}
