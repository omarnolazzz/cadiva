import SwiftUI

/// El símbolo de Cadiva se dibuja solo: el punto recorre la "C" trazándola, cruza el hueco
/// dejando una estela de puntos y se queda en su lugar. Inspirado en el avión que orbita el globo.
struct SimboloAnimado: View {
    var lado: CGFloat = 96
    /// Momento en que empieza; todas las fases se calculan desde aquí.
    let inicio: Date

    @Environment(\.colorScheme) private var esquema
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    /// Al terminar se detiene el reloj: si no, redibuja a 120 Hz para siempre (gasta batería y calienta).
    @State private var terminado = false

    var body: some View {
        let dibujo = DibujoSimbolo(
            colorTrazo: esquema == .dark ? .white : Color.cadiva.brand,
            colorPunto: esquema == .dark ? Color.cadiva.mint : Color.cadiva.brand
        )
        let quieto = reducirMovimiento || terminado
        let inicio = inicio
        TimelineView(.animation(paused: quieto)) { contexto in
            let t = quieto ? DibujoSimbolo.total : contexto.date.timeIntervalSince(inicio)
            Canvas { lienzo, tamano in
                dibujo.dibujar(en: &lienzo, tamano: tamano, t: t)
            }
        }
        .frame(width: lado, height: lado)
        .accessibilityHidden(true)
        .task(id: inicio) {
            terminado = false
            let restante = DibujoSimbolo.total - Date.now.timeIntervalSince(inicio)
            if restante > 0 { try? await Task.sleep(for: .seconds(restante + 0.05)) }
            if !Task.isCancelled { terminado = true }
        }
    }
}

/// Cálculo puro de cada cuadro del símbolo animado.
struct DibujoSimbolo: Sendable {
    let colorTrazo: Color
    let colorPunto: Color

    // Fases en segundos.
    static let aparecer = 0.25
    static let trazar = 1.15
    static let cruzar = 0.45
    static let latido = 0.4
    static var total: Double { aparecer + trazar + cruzar + latido }

    func dibujar(en lienzo: inout GraphicsContext, tamano: CGSize, t: Double) {
        // Mismas proporciones que el SVG del logo (caja de 80, radio 30, trazo 14, punto 6.5).
        let escala = min(tamano.width, tamano.height) / 80
        let centro = CGPoint(x: tamano.width / 2, y: tamano.height / 2)
        let radio = 30 * escala
        let grosor = 14 * escala
        let radioPunto = 6.5 * escala

        let pTrazo = progreso(t, desde: Self.aparecer, dura: Self.trazar, curva: Self.suave)
        let pCruce = progreso(t, desde: Self.aparecer + Self.trazar, dura: Self.cruzar, curva: Self.salida)
        let pLatido = progreso(t, desde: Self.aparecer + Self.trazar + Self.cruzar, dura: Self.latido, curva: { $0 })

        // La C va de -45° a -315° en sentido antihorario; el punto termina en 0° (-360°).
        let anguloTrazo = -45 - 270 * pTrazo
        let anguloPunto = pCruce > 0 ? -315 - 45 * pCruce : anguloTrazo

        // Latido final: crece un poco y vuelve.
        let pulso = 1 + 0.06 * sin(.pi * pLatido)
        lienzo.translateBy(x: centro.x, y: centro.y)
        lienzo.scaleBy(x: pulso, y: pulso)
        lienzo.translateBy(x: -centro.x, y: -centro.y)

        if pTrazo > 0 {
            var arco = Path()
            arco.addArc(center: centro, radius: radio, startAngle: .degrees(-45), endAngle: .degrees(anguloTrazo), clockwise: true)
            lienzo.stroke(arco, with: .color(colorTrazo), style: StrokeStyle(lineWidth: grosor, lineCap: .round))
        }

        // Estela de puntos en el hueco: aparece al cruzar y se desvanece en el latido.
        if pCruce > 0 {
            let opacidad = 1 - pLatido
            var angulo = -315.0 - 7
            while angulo > anguloPunto + 7 {
                let punto = posicion(centro: centro, radio: radio, grados: angulo)
                let r = grosor * 0.12
                lienzo.fill(Path(ellipseIn: CGRect(x: punto.x - r, y: punto.y - r, width: r * 2, height: r * 2)), with: .color(colorPunto.opacity(0.55 * opacidad)))
                angulo -= 9
            }
        }

        let pAparecer = progreso(t, desde: 0, dura: Self.aparecer, curva: Self.rebote)
        if pAparecer > 0 {
            let punto = posicion(centro: centro, radio: radio, grados: anguloPunto)
            // Mientras traza, el punto es la "pluma": del ancho del trazo; al cruzar, se encoge a su tamaño.
            let tamanoPluma = grosor / 2
            let r = (pCruce > 0 ? tamanoPluma + (radioPunto - tamanoPluma) * pCruce : tamanoPluma) * pAparecer
            lienzo.fill(Path(ellipseIn: CGRect(x: punto.x - r, y: punto.y - r, width: r * 2, height: r * 2)), with: .color(colorPunto))
        }
    }

    private func posicion(centro: CGPoint, radio: CGFloat, grados: Double) -> CGPoint {
        let radianes = grados * .pi / 180
        return CGPoint(x: centro.x + radio * cos(radianes), y: centro.y + radio * sin(radianes))
    }

    private func progreso(_ t: Double, desde: Double, dura: Double, curva: (Double) -> Double) -> Double {
        curva(min(max((t - desde) / dura, 0), 1))
    }

    private static func suave(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    private static func salida(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private static func rebote(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

#if DEBUG
#Preview("Símbolo") {
    @Previewable @State var inicio = Date.now
    VStack(spacing: 30) {
        SimboloAnimado(lado: 140, inicio: inicio)
        Button("Repetir") { inicio = .now }
    }
}

#Preview("Cargando · oscuro") {
    CargandoSesionView()
        .preferredColorScheme(.dark)
}
#endif
