import CadivaCore
import SwiftData
import SwiftUI

extension View {
    /// En iOS 18 la pantalla de detalle crece desde la fila.
    @ViewBuilder
    func transicionZoom(id: some Hashable, en espacio: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: espacio))
        } else {
            self
        }
    }

    @ViewBuilder
    func origenZoom(id: some Hashable, en espacio: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: espacio)
        } else {
            self
        }
    }
}
