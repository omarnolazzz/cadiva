import PhotosUI
import SwiftUI
import UIKit

/// Datos de un producto mientras se edita, antes de guardarlo.
struct BorradorProducto {
    var nombre = ""
    var categoria: Categoria = .despensa
    var simbolo = Categoria.despensa.simbolo
    var foto: Data?

    init() {}

    init(_ producto: Producto) {
        nombre = producto.nombre
        categoria = producto.categoria
        simbolo = producto.simbolo
        foto = producto.foto
    }

    func crear() -> Producto {
        let producto = Producto(nombre: nombre.recortado, categoria: categoria, unidad: .piezas, simbolo: simbolo)
        producto.foto = foto
        return producto
    }

    func aplicar(a producto: Producto) {
        producto.nombre = nombre.recortado
        producto.categoria = categoria
        producto.simbolo = simbolo
        if producto.foto != foto { producto.foto = foto }
    }
}

/// Foto grande arriba del formulario, con opciones de galería y cámara.
struct SelectorFoto: View {
    @Binding var foto: Data?
    let simbolo: String

    @State private var elementoGaleria: PhotosPickerItem?
    @State private var mostrandoGaleria = false
    @State private var mostrandoCamara = false
    @State private var cargando = false

    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 120

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.cadiva.tint)
                if let foto, let imagen = UIImage(data: foto) {
                    Image(uiImage: imagen)
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
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: foto)
            .accessibilityHidden(true)

            Menu {
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
        .photosPicker(isPresented: $mostrandoGaleria, selection: $elementoGaleria, matching: .images)
        .fullScreenCover(isPresented: $mostrandoCamara) {
            CamaraView { imagen in
                foto = FotoProducto.comprimir(imagen)
            }
            .ignoresSafeArea()
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

enum FotoProducto {
    /// Lado mayor de 1024 px en JPEG: buena calidad y poco peso para sincronizar.
    static func comprimir(_ imagen: UIImage) -> Data? {
        let maximo: CGFloat = 1024
        let escala = min(1, maximo / max(imagen.size.width, imagen.size.height))
        let tamano = CGSize(width: (imagen.size.width * escala).rounded(), height: (imagen.size.height * escala).rounded())
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let reducida = UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }
        return reducida.jpegData(compressionQuality: 0.75)
    }
}

/// Cámara del sistema.
struct CamaraView: UIViewControllerRepresentable {
    let alTomar: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controlador = UIImagePickerController()
        controlador.sourceType = .camera
        controlador.delegate = context.coordinator
        return controlador
    }

    func updateUIViewController(_ controlador: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(self) }

    @MainActor
    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let padre: CamaraView

        init(_ padre: CamaraView) { self.padre = padre }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let imagen = info[.originalImage] as? UIImage { padre.alTomar(imagen) }
            padre.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            padre.dismiss()
        }
    }
}

/// Categoría y símbolo. Cada pantalla pone su propio campo de nombre para manejar el foco.
struct CamposProducto: View {
    @Binding var borrador: BorradorProducto

    var body: some View {
        Picker("Categoría", selection: $borrador.categoria) {
            ForEach(Categoria.allCases) { categoria in
                Label(categoria.nombre, systemImage: categoria.simbolo).tag(categoria)
            }
        }
        .onChange(of: borrador.categoria) { anterior, nueva in
            // Si el símbolo seguía el de la categoría, que la siga.
            if borrador.simbolo == anterior.simbolo { borrador.simbolo = nueva.simbolo }
        }
        DisclosureGroup {
            SelectorSimbolo(seleccion: $borrador.simbolo)
        } label: {
            LabeledContent("Símbolo") {
                Image(systemName: borrador.simbolo)
                    .foregroundStyle(Color.cadiva.brand)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
        }
    }
}

#if DEBUG
#Preview("Claro") {
    @Previewable @State var borrador = BorradorProducto()
    Form {
        SelectorFoto(foto: $borrador.foto, simbolo: borrador.simbolo)
        TextField("Nombre del producto", text: $borrador.nombre)
        CamposProducto(borrador: $borrador)
    }
}

#Preview("Oscuro") {
    @Previewable @State var borrador = BorradorProducto()
    Form { CamposProducto(borrador: $borrador) }
        .preferredColorScheme(.dark)
}
#endif
