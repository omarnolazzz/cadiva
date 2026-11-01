import CadivaCore
import PhotosUI
import SwiftUI
import UIKit

/// Datos de un producto mientras se edita, antes de guardarlo.
struct BorradorProducto {
    var nombre = ""
    var categoria: Categoria = .despensa
    var simbolo = Categoria.despensa.simbolo
    var foto: Data?
    /// nil mientras la persona no elija: se usa lo sugerido.
    var seguimientoElegido: Seguimiento?

    init() {}

    init(_ producto: Producto) {
        nombre = producto.nombre
        categoria = producto.categoria
        simbolo = producto.simbolo
        foto = producto.foto
        seguimientoElegido = producto.seguimientoRaw.flatMap(Seguimiento.init(rawValue:))
    }

    var seguimientoSugerido: Seguimiento {
        ClasificadorSeguimiento.sugerir(nombre: nombre, categoria: categoria.rawValue)
    }

    var seguimiento: Seguimiento { seguimientoElegido ?? seguimientoSugerido }

    func crear() -> Producto {
        let producto = Producto(nombre: nombre.recortado, categoria: categoria, simbolo: simbolo)
        producto.asignarFoto(foto)
        producto.seguimientoRaw = seguimientoElegido?.rawValue
        return producto
    }

    func aplicar(a producto: Producto) {
        producto.nombre = nombre.recortado
        producto.categoria = categoria
        producto.simbolo = simbolo
        producto.asignarFoto(foto)
        producto.seguimientoRaw = seguimientoElegido?.rawValue
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
        SelectorFoto(foto: $borrador.foto, simbolo: borrador.simbolo, consulta: borrador.nombre)
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
