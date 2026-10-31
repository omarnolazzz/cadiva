import SwiftUI
import UIKit

/// Flecha con el % de cambio del precio unitario.
struct IndicadorCambio: View {
    let cambio: Decimal?

    var body: some View {
        if let cambio {
            let porcentaje = Formato.porcentaje(cambio.magnitude)
            HStack(spacing: 2) {
                Image(systemName: cambio > 0 ? "arrow.up" : cambio < 0 ? "arrow.down" : "equal")
                    .imageScale(.small)
                Text(porcentaje)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(cambio > 0 ? Color.cadiva.priceUp : cambio < 0 ? Color.cadiva.priceDown : Color.cadiva.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (cambio > 0 ? Color.cadiva.priceUp : cambio < 0 ? Color.cadiva.priceDown : Color.cadiva.textSecondary).opacity(0.12),
                in: Capsule()
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cambio > 0 ? "Subió \(porcentaje)" : cambio < 0 ? "Bajó \(porcentaje)" : "Mismo precio")
        }
    }
}

/// Etiqueta con fondo `tint`.
struct Chip: View {
    let texto: String
    var simbolo: String?

    var body: some View {
        HStack(spacing: 4) {
            if let simbolo {
                Image(systemName: simbolo)
                    .accessibilityHidden(true)
            }
            Text(texto)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.cadiva.brand)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.cadiva.tint, in: Capsule())
    }
}

/// Foto del producto o, si no tiene, su símbolo sobre fondo `tint`.
struct MiniaturaProducto: View {
    let producto: Producto
    var tamano: CGFloat = 48

    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    private var lado: CGFloat { tamano * min(escala, 1.6) }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: lado * 0.26, style: .continuous)
        Group {
            if let imagen = CacheMiniaturas.imagen(de: producto, lado: lado) {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: producto.simbolo)
                    .font(.system(size: lado * 0.42, weight: .semibold))
                    .foregroundStyle(producto.archivado ? Color.cadiva.textSecondary : Color.cadiva.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cadiva.tint)
            }
        }
        .frame(width: lado, height: lado)
        .clipShape(forma)
        .accessibilityHidden(true)
    }
}

/// Las fotos se reducen una vez y se guardan en memoria para que las listas vayan fluidas.
@MainActor
enum CacheMiniaturas {
    private static let cache = NSCache<NSString, UIImage>()

    static func imagen(de producto: Producto, lado: CGFloat) -> UIImage? {
        guard let datos = producto.foto else { return nil }
        let pixeles = lado * 3
        let clave = "\(producto.persistentModelID.hashValue)-\(datos.count)-\(Int(pixeles))" as NSString
        if let guardada = cache.object(forKey: clave) { return guardada }
        guard let original = UIImage(data: datos) else { return nil }
        let reducida = original.preparingThumbnail(of: CGSize(width: pixeles, height: pixeles)) ?? original
        cache.setObject(reducida, forKey: clave)
        return reducida
    }
}

/// Botón principal flotante sobre el contenido. En iOS 26 es de Liquid Glass.
struct BotonFlotante: View {
    let titulo: String
    let simbolo: String
    let accion: () -> Void

    @State private var toques = 0

    var body: some View {
        Button {
            toques += 1
            accion()
        } label: {
            Label(titulo, systemImage: simbolo)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .symbolEffect(.bounce, value: toques)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
        }
        .modifier(EstiloFlotante())
        // Flota sobre el contenido: en tamaños enormes taparía demasiado.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.impact(weight: .light), trigger: toques)
    }
}

private struct EstiloFlotante: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(Color.cadiva.brandDeep).interactive(), in: .capsule)
                .buttonStyle(.plain)
        } else {
            content
                .foregroundStyle(.white)
                .background(Color.cadiva.brandDeep, in: Capsule())
                .buttonStyle(.plain)
        }
    }
}

/// Estado vacío con el símbolo de Cadiva.
struct EstadoVacio: View {
    let titulo: String
    let mensaje: String
    var tituloAccion: String?
    var simboloAccion: String?
    var accion: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 72
    @State private var visible = false

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 16) {
                Image("CadivaSimbolo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: lado, height: lado)
                    .scaleEffect(visible ? 1 : 0.6)
                    .opacity(visible ? 1 : 0)
                    .accessibilityHidden(true)
                Text(titulo)
                    .font(.title2.bold())
                    .foregroundStyle(Color.cadiva.textPrimary)
            }
        } description: {
            Text(mensaje)
                .foregroundStyle(Color.cadiva.textSecondary)
        } actions: {
            if let tituloAccion, let accion {
                Button(action: accion) {
                    Label(tituloAccion, systemImage: simboloAccion ?? "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cadiva.brandDeep)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { visible = true }
        }
    }
}

/// Cuadrícula para elegir el SF Symbol de un producto.
struct SelectorSimbolo: View {
    @Binding var seleccion: String

    @ScaledMetric(relativeTo: .body) private var celda: CGFloat = 44

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: celda), spacing: 8)], spacing: 8) {
            ForEach(SimbolosProducto.todos, id: \.self) { simbolo in
                let elegido = simbolo == seleccion
                Button {
                    withAnimation(.snappy) { seleccion = simbolo }
                } label: {
                    Image(systemName: simbolo)
                        .font(.title3)
                        .frame(width: celda, height: celda)
                        .foregroundStyle(elegido ? Color.white : Color.cadiva.brand)
                        .background(elegido ? Color.cadiva.brand : Color.cadiva.tint, in: Circle())
                        .scaleEffect(elegido ? 1.08 : 1)
                        .symbolEffect(.bounce, value: elegido)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(simbolo.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                .accessibilityAddTraits(elegido ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

extension View {
    /// Entra con un leve desplazamiento hacia arriba y fundido. Respeta "Reducir movimiento".
    func entrada(retraso: Double = 0) -> some View {
        modifier(Entrada(retraso: retraso))
    }
}

private struct Entrada: ViewModifier {
    let retraso: Double

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reducirMovimiento ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(retraso)) { visible = true }
            }
    }
}

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
