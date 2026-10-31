import PhotosUI
import SwiftUI
import UIKit

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
