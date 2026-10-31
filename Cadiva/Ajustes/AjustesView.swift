import CadivaCore
import SwiftData
import SwiftUI
import UIKit

struct AjustesView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Compra.fecha) private var compras: [Compra]

    @AppStorage(Preferencias.moneda) private var moneda = Preferencias.monedaPorDefecto
    @AppStorage(Preferencias.avisosActivos) private var avisosActivos = false
    @AppStorage(Preferencias.diasAviso) private var diasAviso = Preferencias.diasAvisoPorDefecto

    @State private var permisoDenegado = false
    @State private var confirmarBorrado = false
    @State private var archivoCSV: URL?
    @State private var confirmarSalida = false
    @State private var borrado: EstadoBorrado?
    @State private var creandoPIN = false
    /// El estado de Seguridad no es observable; esto obliga a redibujar tras cambiarlo.
    @State private var versionSeguridad = 0

    @Environment(SesionUsuario.self) private var sesion
    @Environment(Sincronizador.self) private var sincronizador

    var body: some View {
        NavigationStack {
            Form {
                seccionCuenta
                seccionSeguridad

                Section("Moneda") {
                    Picker("Moneda", selection: $moneda) {
                        ForEach(Preferencias.monedas, id: \.self) { codigo in
                            Text("\(codigo) · \(Locale.cadiva.localizedString(forCurrencyCode: codigo) ?? codigo)")
                                .tag(codigo)
                        }
                    }
                }
                .celdaCadiva()

                Section {
                    Toggle("Aviso de recompra", isOn: $avisosActivos)
                    if avisosActivos {
                        Stepper(value: $diasAviso, in: 0...7) {
                            Text(diasAviso == 0 ? "El mismo día" : "\(Formato.dias(diasAviso)) antes")
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Avisos")
                } footer: {
                    if permisoDenegado {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Las notificaciones de Cadiva están desactivadas en Configuración.")
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("Abrir Configuración", destination: url)
                            }
                        }
                    } else {
                        Text("Te avisamos a las 10:00 cuando un producto esté por acabarse, según su fecha de recompra.")
                    }
                }
                .celdaCadiva()

                Section {
                    if let archivoCSV {
                        ShareLink(item: archivoCSV, preview: SharePreview("Compras de Cadiva")) {
                            Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(compras.isEmpty)
                    }
                    Button(role: .destructive) {
                        confirmarBorrado = true
                    } label: {
                        Label("Borrar todos los datos", systemImage: "trash")
                            .foregroundStyle(Color.cadiva.priceUp)
                    }
                } header: {
                    Text("Datos")
                } footer: {
                    Text("El CSV incluye una fila por compra.")
                }
                .celdaCadiva()

                Section {
                    LabeledContent("Versión", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                }
                .celdaCadiva()
            }
            .fondoCadiva()
            .navigationTitle("Ajustes")
            .sheet(isPresented: $creandoPIN, onDismiss: { versionSeguridad += 1 }) {
                CrearPINView()
            }
            .overlay {
                if let borrado {
                    PantallaBorrado(estado: borrado)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: borrado)
            #if DEBUG
            .onAppear {
                if Demo.valor("--pantalla") == "borrado" { borrado = .listo(productos: 6, compras: 24) }
                creandoPIN = Demo.valor("--pantalla") == "crear-pin"
            }
            #endif
            .onChange(of: avisosActivos) { _, activos in
                guard activos else { return }
                Task {
                    let permitido = await ProgramadorAvisos.pedirPermiso()
                    permisoDenegado = !permitido
                    if !permitido { avisosActivos = false }
                }
            }
            .task(id: compras.count) { archivoCSV = try? exportarCSV() }
            .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { Task { await borrarConAnimacion() } }
            } message: {
                Text(sesion.usuario == nil
                     ? "Se eliminarán todos tus productos y compras de este iPhone. No se puede deshacer."
                     : "Se eliminarán todos tus productos y compras de este iPhone y de tu cuenta. No se puede deshacer.")
            }
        }
    }

    private var seccionSeguridad: some View {
        let _ = versionSeguridad
        let tienePIN = Seguridad.tienePIN
        return Section {
            if tienePIN {
                Button {
                    creandoPIN = true
                } label: {
                    Label("Cambiar PIN", systemImage: "lock.rotation")
                }
                Button(role: .destructive) {
                    withAnimation {
                        Seguridad.quitarPIN()
                        versionSeguridad += 1
                    }
                } label: {
                    Label("Quitar PIN", systemImage: "lock.open")
                        .foregroundStyle(Color.cadiva.priceUp)
                }
            } else {
                Button {
                    creandoPIN = true
                } label: {
                    Label("Crear PIN", systemImage: "lock.fill")
                }
            }
            if let biometria = Seguridad.biometria {
                Toggle(isOn: Binding(
                    get: { Seguridad.biometriaActiva },
                    set: { activar in
                        Task {
                            let permitido = activar
                                ? await Seguridad.autenticarConBiometria(motivo: "Activa \(biometria.nombre) para abrir Cadiva")
                                : true
                            if permitido {
                                withAnimation {
                                    Seguridad.biometriaActiva = activar
                                    versionSeguridad += 1
                                }
                            }
                        }
                    }
                )) {
                    Label("Desbloquear con \(biometria.nombre)", systemImage: biometria.simbolo)
                }
            }
        } header: {
            Text("Seguridad")
        } footer: {
            Text(Seguridad.bloqueoConfigurado
                 ? "Cadiva te pedirá tu \(textoBloqueo) al abrirla y cuando vuelvas después de un minuto."
                 : "Sin PIN ni \(Seguridad.biometria?.nombre ?? "Face ID") tendrás que iniciar sesión cada vez que abras Cadiva.")
        }
        .celdaCadiva()
    }

    private var textoBloqueo: String {
        switch (Seguridad.tienePIN, Seguridad.biometriaActiva ? Seguridad.biometria : nil) {
        case let (true, biometria?): "PIN o \(biometria.nombre)"
        case let (false, biometria?): biometria.nombre
        default: "PIN"
        }
    }

    @ViewBuilder
    private var seccionCuenta: some View {
        Section {
            if let usuario = sesion.usuario {
                HStack(spacing: 14) {
                    AvatarUsuario(usuario: usuario, lado: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(usuario.nombre ?? "Tu cuenta")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.cadiva.textPrimary)
                        if let email = usuario.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(Color.cadiva.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                Button {
                    Task { await sincronizador.sincronizar(contexto: contexto, sesion: sesion) }
                } label: {
                    HStack {
                        Label("Sincronizar ahora", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if sincronizador.estado == .sincronizando {
                            ProgressView()
                        }
                    }
                }
                .disabled(sincronizador.estado == .sincronizando)
                Button("Cerrar sesión", role: .destructive) { confirmarSalida = true }
            } else {
                Button {
                    sesion.irABienvenida()
                } label: {
                    Label("Iniciar sesión o crear cuenta", systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text("Cuenta")
        } footer: {
            Text(sesion.usuario == nil
                 ? "Estás usando Cadiva como invitado. Tus compras se guardan solo en este iPhone. Inicia sesión para guardarlas en tu cuenta."
                 : textoSincronizacion)
        }
        .celdaCadiva()
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Cerrar sesión y borrar del iPhone", role: .destructive) { salir(borrandoDatos: true) }
            Button("Cerrar sesión y conservar en el iPhone") { salir(borrandoDatos: false) }
        } message: {
            Text("Tus compras siguen guardadas en tu cuenta. Si las conservas en el iPhone y entras con otra cuenta, se agregarán a esa cuenta.")
        }
    }

    private var textoSincronizacion: String {
        switch sincronizador.estado {
        case .sincronizando:
            return "Sincronizando con tu cuenta…"
        case let .error(mensaje):
            return "No se pudo sincronizar. \(mensaje)"
        case .inactivo, .listo:
            guard let ultima = sincronizador.ultima else {
                return "Tus compras se guardan en tu cuenta y en este iPhone."
            }
            return "Sincronizado con tu cuenta \(ultima.formatted(.relative(presentation: .named).locale(.cadiva)))."
        }
    }

    private func salir(borrandoDatos: Bool) {
        let usuario = sesion.usuario?.id
        Task {
            // Último intento de subir lo pendiente antes de salir.
            await sincronizador.sincronizar(contexto: contexto, sesion: sesion)
            // Primero se cierra la sesión: así borrar aquí no se toma como borrar en la nube.
            await sesion.cerrarSesion()
            if borrandoDatos {
                borrarTodo()
                if let usuario { sincronizador.olvidar(usuario: usuario) }
            }
        }
    }

    private func exportarCSV() throws -> URL {
        let filas = compras.compactMap { compra -> FilaCSV? in
            guard let producto = compra.producto else { return nil }
            return FilaCSV(
                producto: producto.nombre, categoria: producto.categoria.nombre, unidad: producto.unidad.rawValue,
                fecha: compra.fecha, precioTotal: compra.precioTotal, cantidad: compra.cantidad,
                tienda: compra.tienda, fechaAgotado: compra.fechaAgotado, duracionRealDias: compra.duracionReal
            )
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "cadiva-compras.csv")
        try ExportadorCSV.csv(filas, calendar: .cadiva).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Muestra "Eliminando…", borra y confirma con el resultado.
    private func borrarConAnimacion() async {
        let productos = (try? contexto.fetchCount(FetchDescriptor<Producto>())) ?? 0
        let cantidadCompras = (try? contexto.fetchCount(FetchDescriptor<Compra>())) ?? 0
        borrado = .borrando
        // Una pausa breve para que la animación se alcance a ver aunque haya pocos datos.
        try? await Task.sleep(for: .milliseconds(1300))
        borrarTodo()
        borrado = .listo(productos: productos, compras: cantidadCompras)
        try? await Task.sleep(for: .seconds(2.2))
        borrado = nil
    }

    private func borrarTodo() {
        for compra in (try? contexto.fetch(FetchDescriptor<Compra>())) ?? [] {
            contexto.delete(compra)
        }
        for producto in (try? contexto.fetch(FetchDescriptor<Producto>())) ?? [] {
            contexto.delete(producto)
        }
        try? contexto.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

enum EstadoBorrado: Equatable {
    case borrando
    case listo(productos: Int, compras: Int)
}

/// Tarjeta sobre el contenido mientras se borran los datos y al terminar.
private struct PantallaBorrado: View {
    let estado: EstadoBorrado

    @State private var pulso = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 112, height: 112)
                        .scaleEffect(pulso && estado == .borrando ? 1.12 : 1)
                    Image(systemName: estado == .borrando ? "trash.fill" : "checkmark.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(color)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: estado)
                }
                VStack(spacing: 6) {
                    Text(titulo)
                        .font(.title3.bold())
                        .foregroundStyle(Color.cadiva.textPrimary)
                        .contentTransition(.opacity)
                    Text(detalle)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.cadiva.textSecondary)
                }
                if estado == .borrando {
                    ProgressView()
                        .tint(color)
                        .transition(.opacity)
                }
            }
            .padding(32)
            .frame(maxWidth: 320)
            .background(Color.cadiva.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
        .sensoryFeedback(trigger: estado) { _, nuevo in
            nuevo == .borrando ? .impact(weight: .medium) : .success
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulso = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var color: Color { estado == .borrando ? Color.cadiva.priceUp : Color.cadiva.priceDown }

    private var titulo: String { estado == .borrando ? "Eliminando tus datos…" : "Datos eliminados" }

    private var detalle: String {
        switch estado {
        case .borrando:
            return "Esto toma solo un momento."
        case let .listo(productos, compras):
            let p = productos == 1 ? "1 producto" : "\(productos) productos"
            let c = compras == 1 ? "1 compra" : "\(compras) compras"
            return "Se borraron \(p) y \(c) correctamente."
        }
    }
}

#if DEBUG
#Preview("Borrando") {
    PantallaBorrado(estado: .borrando)
}

#Preview("Borrado · oscuro") {
    PantallaBorrado(estado: .listo(productos: 6, compras: 24))
        .preferredColorScheme(.dark)
}

#Preview("Claro") {
    AjustesView()
        .environment(SesionUsuario(estado: .invitado, cliente: nil))
        .environment(Sincronizador())
        .modelContainer(DatosEjemplo.contenedor)
}

#Preview("Oscuro") {
    AjustesView()
        .environment(SesionUsuario(estado: .invitado, cliente: nil))
        .environment(Sincronizador())
        .modelContainer(DatosEjemplo.contenedor)
        .preferredColorScheme(.dark)
}
#endif
