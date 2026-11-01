import PhotosUI
import SwiftUI
import UIKit

/// Foto grande arriba del formulario, con opciones de galería, cámara y búsqueda en Google.
struct SelectorFoto: View {
    @Binding var foto: Data?
    let simbolo: String
    /// Lo que se busca en Google: el nombre del producto.
    var consulta = ""

    @State private var elementoGaleria: PhotosPickerItem?
    @State private var mostrandoGaleria = false
    @State private var mostrandoCamara = false
    @State private var buscandoEnGoogle = false
    @State private var cargando = false
    /// La foto ya decodificada: decodificarla en cada redibujado trababa el formulario al escribir.
    @State private var vista: UIImage?

    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 120

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.cadiva.tint)
                if let vista, foto != nil {
                    Image(uiImage: vista)
                        .resizable()
                        .scaledToFill()
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    Image(systemName: simbolo)
                        .font(.system(size: lado * 0.38, weight: .semibold))
                        .foregroundStyle(Color.cadiva.brand)
                        .contentTransition(.symbolEffect(.replace))
                }
                if cargando {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .frame(width: lado, height: lado)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vista)
            .accessibilityHidden(true)

            Menu {
                Button {
                    buscandoEnGoogle = true
                } label: {
                    Label("Buscar en Google", systemImage: "magnifyingglass")
                }
                Button {
                    mostrandoGaleria = true
                } label: {
                    Label("Elegir de la galería", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        mostrandoCamara = true
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                }
                if foto != nil {
                    Button(role: .destructive) {
                        foto = nil
                    } label: {
                        Label("Quitar foto", systemImage: "trash")
                    }
                }
            } label: {
                Label(foto == nil ? "Agregar foto" : "Cambiar foto", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .task(id: foto?.count) {
            guard let foto else {
                vista = nil
                return
            }
            vista = await CacheMiniaturas.reducir(foto, pixeles: 480)
        }
        #if DEBUG
        .onAppear { buscandoEnGoogle = Demo.valor("--pantalla") == "buscar-imagen" }
        #endif
        .photosPicker(isPresented: $mostrandoGaleria, selection: $elementoGaleria, matching: .images)
        .fullScreenCover(isPresented: $mostrandoCamara) {
            CamaraView { imagen in
                foto = FotoProducto.comprimir(imagen)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $buscandoEnGoogle) {
            BuscadorImagenesView(consultaInicial: consulta) { datos in
                foto = datos
            }
        }
        .onChange(of: elementoGaleria) { _, elemento in
            guard let elemento else { return }
            cargando = true
            Task {
                defer {
                    cargando = false
                    elementoGaleria = nil
                }
                if let datos = try? await elemento.loadTransferable(type: Data.self), let imagen = UIImage(data: datos) {
                    foto = FotoProducto.comprimir(imagen)
                }
            }
        }
    }
}
