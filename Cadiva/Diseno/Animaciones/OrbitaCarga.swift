import SwiftUI

/// Punto que orbita dejando una estela de puntos, como el avión del video al iniciar sesión.
struct OrbitaCarga: View {
    var lado: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        let reducir = reducirMovimiento
        TimelineView(.animation) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            Canvas { lienzo, tamano in
                let centro = CGPoint(x: tamano.width / 2, y: tamano.height / 2)
                let radio = min(tamano.width, tamano.height) / 2 - 8
                // Una vuelta cada 1.4 s, con aceleración suave para que se sienta viva.
                let vuelta = (t / 1.4).truncatingRemainder(dividingBy: 1)
                let base = reducir ? 0 : (vuelta + 0.08 * sin(vuelta * 2 * .pi)) * 360 - 90
                let estela = 14
                for i in stride(from: estela, through: 0, by: -1) {
                    let angulo = (base - Double(i) * 11) * .pi / 180
                    let punto = CGPoint(x: centro.x + radio * cos(angulo), y: centro.y + radio * sin(angulo))
                    let fraccion = 1 - Double(i) / Double(estela)
                    let r = i == 0 ? 7.0 : 1.6 + 2.6 * fraccion
                    let color = Color.cadiva.brand.opacity(i == 0 ? 1 : 0.15 + 0.7 * fraccion)
                    lienzo.fill(Path(ellipseIn: CGRect(x: punto.x - r, y: punto.y - r, width: r * 2, height: r * 2)), with: .color(color))
                }
            }
        }
        .frame(width: lado, height: lado)
        .accessibilityHidden(true)
    }
}
