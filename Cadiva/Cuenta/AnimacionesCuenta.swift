import SwiftUI

/// El símbolo de Cadiva se dibuja solo: el punto recorre la "C" trazándola, cruza el hueco
/// dejando una estela de puntos y se queda en su lugar. Inspirado en el avión que orbita el globo.
struct SimboloAnimado: View {
    var lado: CGFloat = 96
    /// Momento en que empieza; todas las fases se calculan desde aquí.
    let inicio: Date

    @Environment(\.colorScheme) private var esquema
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        let dibujo = DibujoSimbolo(
            colorTrazo: esquema == .dark ? .white : Color.cadiva.brand,
            colorPunto: esquema == .dark ? Color.cadiva.mint : Color.cadiva.brand
        )
        let reducir = reducirMovimiento
        let inicio = inicio
        TimelineView(.animation(paused: reducir)) { contexto in
            let t = reducir ? DibujoSimbolo.total : contexto.date.timeIntervalSince(inicio)
            Canvas { lienzo, tamano in
                dibujo.dibujar(en: &lienzo, tamano: tamano, t: t)
            }
        }
        .frame(width: lado, height: lado)
        .accessibilityHidden(true)
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

/// Encima de todo mientras se inicia sesión: desenfoca la pantalla y muestra la órbita.
struct CargandoSesionView: View {
    var titulo = "Iniciando sesión"
    var detalle = "Preparando tus productos"

    @State private var visible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.cadiva.background.opacity(0.35))
                .ignoresSafeArea()
            VStack(spacing: 18) {
                OrbitaCarga()
                    .scaleEffect(visible ? 1 : 0.6)
                VStack(spacing: 4) {
                    Text(titulo)
                        .font(.headline)
                        .foregroundStyle(Color.cadiva.textPrimary)
                    Text(detalle)
                        .font(.subheadline)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { visible = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titulo). \(detalle)")
    }
}

/// Transición con desenfoque: lo que entra pasa de borroso y algo más grande a nítido.
struct Desenfoque: ViewModifier {
    let radio: CGFloat
    let escala: CGFloat
    let opacidad: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radio)
            .scaleEffect(escala)
            .opacity(opacidad)
    }
}

extension AnyTransition {
    static var desenfoque: AnyTransition {
        .modifier(
            active: Desenfoque(radio: 24, escala: 1.06, opacidad: 0),
            identity: Desenfoque(radio: 0, escala: 1, opacidad: 1)
        )
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
