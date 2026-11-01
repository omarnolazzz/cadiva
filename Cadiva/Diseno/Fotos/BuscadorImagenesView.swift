import SwiftUI
import UIKit
import WebKit

/// Google Imágenes dentro de la app, con el nombre del producto ya buscado.
/// Al tocar una imagen aparece abajo una vista previa; "Usar" la descarga y la deja como foto del producto.
struct BuscadorImagenesView: View {
    let consultaInicial: String
    let alElegir: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var consulta: String
    @State private var direccion: URL
    @State private var seleccionada: UIImage?
    @State private var descargando = false
    @State private var error: String?
    @State private var mostrarAyuda = true

    init(consultaInicial: String, alElegir: @escaping (Data) -> Void) {
        self.consultaInicial = consultaInicial
        self.alElegir = alElegir
        let texto = consultaInicial.recortado
        _consulta = State(initialValue: texto)
        _direccion = State(initialValue: Self.urlBusqueda(texto))
    }

    var body: some View {
        NavigationStack {
            NavegadorImagenes(direccion: direccion) { origen in
                Task { await previsualizar(origen) }
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                if mostrarAyuda {
                    Label("Toca una imagen para usarla. Si la abres y la tocas otra vez, se descarga en mejor calidad.", systemImage: "hand.tap")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation(.snappy) { mostrarAyuda = false } }
                }
            }
            .overlay(alignment: .bottom) {
                if seleccionada != nil || descargando || error != nil {
                    barraSeleccion
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: seleccionada)
            .animation(.snappy, value: descargando)
            .navigationTitle("Buscar imagen")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $consulta, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar en Google")
            .onSubmit(of: .search) {
                let texto = consulta.recortado
                guard !texto.isEmpty else { return }
                seleccionada = nil
                direccion = Self.urlBusqueda(texto)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.snappy) { mostrarAyuda = false }
            }
        }
    }

    private var barraSeleccion: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cadiva.tint)
                if let seleccionada {
                    Image(uiImage: seleccionada)
                        .resizable()
                        .scaledToFill()
                } else if descargando {
                    ProgressView()
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.cadiva.priceUp)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(error ?? (descargando ? "Descargando…" : "¿Usar esta imagen?"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cadiva.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let seleccionada, error == nil {
                    Text("\(Int(seleccionada.size.width * seleccionada.scale)) × \(Int(seleccionada.size.height * seleccionada.scale)) px")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Button(action: usar) {
                Text("Usar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.cadiva.brandDeep, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(seleccionada == nil)
            .opacity(seleccionada == nil ? 0.4 : 1)
        }
        .padding(12)
        .modifier(FondoVidrio())
    }

    // MARK: Acciones

    /// Baja (o decodifica) la imagen tocada para mostrarla antes de usarla.
    private func previsualizar(_ origen: String) async {
        withAnimation(.snappy) { mostrarAyuda = false }
        error = nil
        descargando = true
        defer { descargando = false }
        guard let datos = await Self.datos(de: origen), let imagen = UIImage(data: datos) else {
            seleccionada = nil
            error = "No se pudo abrir esa imagen. Prueba con otra."
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        seleccionada = imagen
    }

    private func usar() {
        guard let seleccionada, let datos = FotoProducto.comprimir(seleccionada) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        alElegir(datos)
        dismiss()
    }

    static func urlBusqueda(_ texto: String) -> URL {
        var partes = URLComponents(string: "https://www.google.com/search")!
        partes.queryItems = [
            URLQueryItem(name: "q", value: texto.isEmpty ? "producto" : texto),
            URLQueryItem(name: "udm", value: "2"), // pestaña Imágenes
            URLQueryItem(name: "hl", value: "es-419"),
        ]
        return partes.url!
    }

    /// Las miniaturas de Google vienen como `data:image/...;base64,`; las vistas previas, como URL.
    static func datos(de origen: String) async -> Data? {
        if origen.hasPrefix("data:image") {
            guard let coma = origen.firstIndex(of: ",") else { return nil }
            return Data(base64Encoded: String(origen[origen.index(after: coma)...]))
        }
        guard let url = URL(string: origen), url.scheme == "https" || url.scheme == "http" else { return nil }
        var solicitud = URLRequest(url: url, timeoutInterval: 20)
        solicitud.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let resultado = try? await URLSession.shared.data(for: solicitud) else { return nil }
        let (datos, respuesta) = resultado
        if let http = respuesta as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return datos
    }
}

private struct FondoVidrio: ViewModifier {
    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: forma)
        } else {
            content
                .background(.regularMaterial, in: forma)
                .overlay(forma.stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
    }
}

/// WKWebView con un script que avisa qué imagen se tocó, sin estorbar la navegación de Google.
struct NavegadorImagenes: UIViewRepresentable {
    let direccion: URL
    let alTocarImagen: @MainActor (String) -> Void

    static let nombreMensaje = "cadivaImagen"

    /// Escucha los toques en fase de captura: Google sigue abriendo su vista previa
    /// y Cadiva recibe la imagen tocada (la miniatura o, en la vista previa, la grande).
    static let script = """
    (function() {
      if (window.__cadiva) return; window.__cadiva = true;
      document.addEventListener('click', function(evento) {
        var objetivo = evento.target;
        var imagen = objetivo && objetivo.closest ? objetivo.closest('img') : null;
        if (!imagen && objetivo && objetivo.querySelector) imagen = objetivo.querySelector('img');
        if (!imagen) return;
        var origen = imagen.currentSrc || imagen.src || imagen.getAttribute('data-src') || '';
        if (!origen || origen.indexOf('data:image/gif') === 0) return;
        if (imagen.naturalWidth && imagen.naturalWidth < 48) return;
        window.webkit.messageHandlers.\(nombreMensaje).postMessage(origen);
      }, true);
    })();
    """

    func makeCoordinator() -> Coordinador { Coordinador(alTocarImagen: alTocarImagen) }

    func makeUIView(context: Context) -> WKWebView {
        let configuracion = WKWebViewConfiguration()
        // Sin cookies ni historial guardados: cada búsqueda empieza limpia.
        configuracion.websiteDataStore = .nonPersistent()
        configuracion.userContentController.addUserScript(
            WKUserScript(source: Self.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        configuracion.userContentController.add(context.coordinator, name: Self.nombreMensaje)
        let navegador = WKWebView(frame: .zero, configuration: configuracion)
        navegador.allowsBackForwardNavigationGestures = true
        navegador.load(URLRequest(url: direccion))
        context.coordinator.cargada = direccion
        return navegador
    }

    func updateUIView(_ navegador: WKWebView, context: Context) {
        context.coordinator.alTocarImagen = alTocarImagen
        if context.coordinator.cargada != direccion {
            context.coordinator.cargada = direccion
            navegador.load(URLRequest(url: direccion))
        }
    }

    static func dismantleUIView(_ navegador: WKWebView, coordinator: Coordinador) {
        navegador.configuration.userContentController.removeScriptMessageHandler(forName: nombreMensaje)
    }

    @MainActor
    final class Coordinador: NSObject, WKScriptMessageHandler {
        var alTocarImagen: @MainActor (String) -> Void
        var cargada: URL?

        init(alTocarImagen: @escaping @MainActor (String) -> Void) {
            self.alTocarImagen = alTocarImagen
        }

        func userContentController(_ controlador: WKUserContentController, didReceive mensaje: WKScriptMessage) {
            guard let origen = mensaje.body as? String else { return }
            alTocarImagen(origen)
        }
    }
}

#if DEBUG
#Preview("Buscar imagen") {
    BuscadorImagenesView(consultaInicial: "Papas Lay's 42 g") { _ in }
}
#endif
