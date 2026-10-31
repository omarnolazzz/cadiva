import CadivaCore
import SwiftData
import SwiftUI
import UIKit

extension Decimal {
    /// Redondeo normal a `decimales` cifras.
    func redondeado(_ decimales: Int) -> Decimal {
        var origen = self
        var resultado = Decimal()
        NSDecimalRound(&resultado, &origen, decimales, .plain)
        return resultado
    }
}
