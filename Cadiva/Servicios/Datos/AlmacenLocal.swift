import SwiftData

/// Operaciones sobre todos los datos guardados en este iPhone.
@MainActor
enum AlmacenLocal {
    struct Conteo: Equatable {
        let productos: Int
        let compras: Int
    }

    static func contar(en contexto: ModelContext) -> Conteo {
        Conteo(
            productos: (try? contexto.fetchCount(FetchDescriptor<Producto>())) ?? 0,
            compras: (try? contexto.fetchCount(FetchDescriptor<Compra>())) ?? 0
        )
    }

    /// Borra productos y compras. Con sesión iniciada, la siguiente sincronización lo borra también en la nube.
    static func borrarTodo(en contexto: ModelContext) {
        for compra in (try? contexto.fetch(FetchDescriptor<Compra>())) ?? [] {
            contexto.delete(compra)
        }
        for producto in (try? contexto.fetch(FetchDescriptor<Producto>())) ?? [] {
            contexto.delete(producto)
        }
        try? contexto.save()
    }
}
