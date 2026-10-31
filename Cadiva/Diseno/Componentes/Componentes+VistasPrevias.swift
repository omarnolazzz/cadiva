import SwiftUI
import UIKit

#if DEBUG
#Preview("Componentes · claro") {
    List {
        HStack {
            IndicadorCambio(cambio: 0.12)
            IndicadorCambio(cambio: -0.05)
            IndicadorCambio(cambio: 0)
            Chip(texto: "Higiene personal", simbolo: "hands.and.sparkles.fill")
        }
        BotonFlotante(titulo: "Registrar compra", simbolo: "cart.badge.plus") {}
    }
}

#Preview("Componentes · oscuro") {
    EstadoVacio(titulo: "Sin productos", mensaje: "Agrega tu primer producto.", tituloAccion: "Nuevo producto") {}
        .preferredColorScheme(.dark)
}
#endif
