import Foundation
import UserNotifications

/// Una notificación lista para programarse, sin referencias a SwiftData.
struct PlanAviso: Sendable, Equatable {
    let identificador: String
    let cuerpo: String
    let disparo: DateComponents
}

/// Avisos locales de recompra. Se reprograman completos cada vez que cambian las compras.
enum ProgramadorAvisos {
    /// iOS solo conserva 64 notificaciones pendientes por app.
    static let limite = 64
    static let horaDelAviso = 10

    @MainActor
    static func planes(productos: [Producto], diasAntes: Int, hoy: Date = .now) -> [PlanAviso] {
        let calendario = Calendar.cadiva
        let candidatos: [(Date, PlanAviso)] = productos.filter { !$0.archivado }.compactMap { producto in
            guard let recompra = producto.resumen(hoy: hoy).fechaRecompra,
                  let dia = calendario.date(byAdding: .day, value: -diasAntes, to: recompra),
                  let disparo = calendario.date(bySettingHour: horaDelAviso, minute: 0, second: 0, of: dia),
                  disparo > hoy else { return nil }
            let plan = PlanAviso(
                identificador: "recompra-\(producto.creado.timeIntervalSince1970)-\(producto.nombre)",
                cuerpo: cuerpo(nombre: producto.nombre, dias: diasAntes),
                disparo: calendario.dateComponents([.year, .month, .day, .hour, .minute], from: disparo)
            )
            return (disparo, plan)
        }
        return candidatos.sorted { $0.0 < $1.0 }.prefix(limite).map(\.1)
    }

    static func cuerpo(nombre: String, dias: Int) -> String {
        let producto = nombre.lowercased(with: .cadiva)
        switch dias {
        case 0: return "Tu \(producto) se acaba hoy"
        case 1: return "Tu \(producto) se acaba en ~1 día"
        default: return "Tu \(producto) se acaba en ~\(dias) días"
        }
    }

    static func reprogramar(_ planes: [PlanAviso], activos: Bool) async {
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()
        guard activos else { return }
        let estado = await centro.notificationSettings().authorizationStatus
        guard estado == .authorized || estado == .provisional else { return }
        for plan in planes {
            let contenido = UNMutableNotificationContent()
            contenido.title = "Hora de recomprar"
            contenido.body = plan.cuerpo
            contenido.sound = .default
            let disparador = UNCalendarNotificationTrigger(dateMatching: plan.disparo, repeats: false)
            let solicitud = UNNotificationRequest(identifier: plan.identificador, content: contenido, trigger: disparador)
            try? await centro.add(solicitud)
        }
    }

    /// Pide permiso la primera vez; después solo devuelve la decisión que ya se tomó.
    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
