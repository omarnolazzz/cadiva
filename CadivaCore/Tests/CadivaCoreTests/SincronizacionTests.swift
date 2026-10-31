import Foundation
import Testing
@testable import CadivaCore

@Suite("Sincronización")
struct SincronizacionTests {
    static let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    static let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    func producto(_ id: UUID = idA, nombre: String = "Papel", borrado: Bool = false) -> ProductoNube {
        ProductoNube(
            id: id, nombre: nombre, categoria: "Limpieza", simbolo: "scroll.fill",
            notas: nil, archivado: false,
            creado: Date(timeIntervalSince1970: 1_800_000_000), borrado: borrado
        )
    }

    func remota(_ fila: ProductoNube, _ version: String) -> FilaRemota<ProductoNube> {
        FilaRemota(fila: fila, version: version)
    }

    func base(_ fila: ProductoNube, _ version: String) -> [UUID: EstadoSincronizado] {
        [fila.id: EstadoSincronizado(huella: fila.huella, version: version)]
    }

    // MARK: Fusión

    @Test func primeraVezSubeLoLocalYBajaLoRemoto() {
        let local = producto(Self.idA)
        let nube = producto(Self.idB, nombre: "Café")
        let plan = Fusion.planear(locales: [local], remotas: [remota(nube, "v1")], base: [:])
        #expect(plan.subir == [local])
        #expect(plan.aplicar == [nube])
        #expect(plan.borrarLocal.isEmpty)

        let nueva = plan.nuevaBase(versiones: [Self.idA: "v9"])
        #expect(nueva[Self.idA] == EstadoSincronizado(huella: local.huella, version: "v9"))
        #expect(nueva[Self.idB] == EstadoSincronizado(huella: nube.huella, version: "v1"))
    }

    @Test func sinCambiosNoHaceNada() {
        let fila = producto()
        let plan = Fusion.planear(locales: [fila], remotas: [remota(fila, "v1")], base: base(fila, "v1"))
        #expect(!plan.hayCambios)
        #expect(plan.nuevaBase(versiones: [:]) == base(fila, "v1"))
    }

    @Test func cambioLocalSeSube() {
        let antes = producto()
        let ahora = producto(nombre: "Papel grande")
        let plan = Fusion.planear(locales: [ahora], remotas: [remota(antes, "v1")], base: base(antes, "v1"))
        #expect(plan.subir == [ahora])
        #expect(plan.aplicar.isEmpty)
    }

    @Test func cambioRemotoSeAplica() {
        let antes = producto()
        let nube = producto(nombre: "Papel de otro iPhone")
        let plan = Fusion.planear(locales: [antes], remotas: [remota(nube, "v2")], base: base(antes, "v1"))
        #expect(plan.aplicar == [nube])
        #expect(plan.subir.isEmpty)
        #expect(plan.nuevaBase(versiones: [:]) == base(nube, "v2"))
    }

    @Test func siCambianLosDosGanaElIPhone() {
        let antes = producto()
        let local = producto(nombre: "Local")
        let nube = producto(nombre: "Nube")
        let plan = Fusion.planear(locales: [local], remotas: [remota(nube, "v2")], base: base(antes, "v1"))
        #expect(plan.subir == [local])
        #expect(plan.aplicar.isEmpty)
    }

    @Test func borradoLocalSubeLapida() {
        let fila = producto()
        let plan = Fusion.planear(locales: [], remotas: [remota(fila, "v1")], base: base(fila, "v1"))
        #expect(plan.subir == [producto(borrado: true)])
        #expect(plan.nuevaBase(versiones: [Self.idA: "v2"]).isEmpty)
    }

    @Test func borradoLocalPeroEditadoEnOtroLadoSeConserva() {
        let antes = producto()
        let nube = producto(nombre: "Editado")
        let plan = Fusion.planear(locales: [], remotas: [remota(nube, "v2")], base: base(antes, "v1"))
        #expect(plan.aplicar == [nube])
        #expect(plan.subir.isEmpty)
    }

    @Test func borradoRemotoSeBorraAqui() {
        let fila = producto()
        let plan = Fusion.planear(locales: [fila], remotas: [remota(producto(borrado: true), "v2")], base: base(fila, "v1"))
        #expect(plan.borrarLocal == [Self.idA])
        #expect(plan.nuevaBase(versiones: [:]).isEmpty)
    }

    @Test func lapidaRemotaSinFilaLocalSeIgnora() {
        let plan = Fusion.planear(locales: [ProductoNube](), remotas: [remota(producto(borrado: true), "v1")], base: [:])
        #expect(!plan.hayCambios)
    }

    @Test func filaQueDesaparecioDeLaNubeSeVuelveASubir() {
        let fila = producto()
        let plan = Fusion.planear(locales: [fila], remotas: [], base: base(fila, "v1"))
        #expect(plan.subir == [fila])
    }

    // MARK: Formato

    @Test(arguments: [
        ("2026-10-30T23:38:07.123456+00:00", 1_793_403_487.123),
        ("2026-10-30T23:38:07+00:00", 1_793_403_487.0),
        ("2026-10-30T23:38:07.5Z", 1_793_403_487.5),
        ("2026-10-30 18:38:07.25-05:00", 1_793_403_487.25),
    ])
    func fechasDePostgres(texto: String, segundos: Double) throws {
        let fecha = try #require(FormatoNube.fecha(de: texto))
        #expect(abs(fecha.timeIntervalSince1970 - segundos) < 0.0005)
    }

    @Test func compraIdaYVueltaConservaDecimales() throws {
        let compra = CompraNube(
            id: Self.idA, productoId: Self.idB, fecha: Date(timeIntervalSince1970: 1_800_000_000.1234),
            precioTotal: Decimal(string: "189.90")!, cantidad: Decimal(string: "0.333")!,
            tienda: "Súper", fechaAgotado: nil
        )
        let datos = try FormatoNube.codificador.encode(compra)
        let json = try #require(String(data: datos, encoding: .utf8))
        #expect(json.contains(#""precio_total":"189.9""#))
        #expect(json.contains(#""cantidad":"0.333""#))
        #expect(json.contains(#""producto_id":"00000000-0000-0000-0000-00000000000B""#))
        #expect(try FormatoNube.decodificador.decode(CompraNube.self, from: datos) == compra)
    }

    @Test func compraRemotaConNumerosComoTexto() throws {
        let json = """
        [{"id":"00000000-0000-0000-0000-00000000000A","producto_id":null,"fecha":"2026-10-30T23:38:07.123+00:00",
          "precio_total":"15.90","cantidad":"12","tienda":null,"fecha_agotado":null,"borrado":false,
          "modificado":"2026-10-30T23:40:00.000001+00:00"}]
        """
        let filas = try FormatoNube.decodificador.decode([FilaRemota<CompraNube>].self, from: Data(json.utf8))
        let fila = try #require(filas.first)
        #expect(fila.version == "2026-10-30T23:40:00.000001+00:00")
        #expect(fila.fila.precioTotal == Decimal(string: "15.9"))
        #expect(fila.fila.cantidad == 12)
        #expect(fila.fila.productoId == nil)
    }

    @Test func huellaEsEstableYDetectaCambios() {
        #expect(producto().huella == producto().huella)
        #expect(producto().huella != producto(nombre: "Otro").huella)
    }

    // MARK: Cliente

    let configuracion = ConfiguracionAuth(url: URL(string: "https://demo.supabase.co")!, claveAnonima: "anon-123")

    @Test func descargarPideLasColumnasConElToken() async throws {
        let falso = TransporteFalso()
        falso.responder(200, "[]")
        let filas = try await ClienteDatos(configuracion: configuracion, transporte: falso.transporte)
            .descargar(CompraNube.self, token: "tok")
        #expect(filas.isEmpty)
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.httpMethod == "GET")
        #expect(solicitud.url?.absoluteString.hasPrefix("https://demo.supabase.co/rest/v1/compras?select=id,producto_id,fecha,precio_total::text") == true)
        #expect(solicitud.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(solicitud.value(forHTTPHeaderField: "apikey") == "anon-123")
    }

    @Test func subirHaceUpsertYDevuelveVersiones() async throws {
        let falso = TransporteFalso()
        falso.responder(201, #"[{"id":"00000000-0000-0000-0000-00000000000A","modificado":"v7"}]"#)
        let versiones = try await ClienteDatos(configuracion: configuracion, transporte: falso.transporte)
            .subir([producto()], token: "tok")
        #expect(versiones == [Self.idA: "v7"])
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.httpMethod == "POST")
        #expect(solicitud.url?.query?.contains("on_conflict=id") == true)
        #expect(solicitud.value(forHTTPHeaderField: "Prefer") == "resolution=merge-duplicates,return=representation")
    }

    @Test func productoMandaNullEnCamposVacios() throws {
        let json = try #require(String(data: FormatoNube.codificador.encode(producto()), encoding: .utf8))
        #expect(json.contains(#""notas":null"#))
        #expect(json.contains(#""foto":null"#))
        #expect(!json.contains("unidad"))
    }

    @Test func huellaFotoCambiaConLaImagen() {
        let a = FormatoNube.huellaFoto(Data([1, 2, 3]))
        #expect(a.count == 24)
        #expect(a == FormatoNube.huellaFoto(Data([1, 2, 3])))
        #expect(a != FormatoNube.huellaFoto(Data([1, 2, 4])))
    }

    @Test func subirFotoVaASuCarpetaConUpsert() async throws {
        let falso = TransporteFalso()
        falso.responder(200, #"{"Key":"fotos/u/p.jpg"}"#)
        let ruta = ClienteDatos.rutaFoto(usuario: "ABC-123", producto: Self.idA)
        #expect(ruta == "abc-123/00000000-0000-0000-0000-00000000000a.jpg")
        try await ClienteDatos(configuracion: configuracion, transporte: falso.transporte)
            .subirFoto(Data([0xFF, 0xD8]), ruta: ruta, token: "tok")
        let solicitud = try #require(falso.solicitudes.first)
        #expect(solicitud.url?.absoluteString == "https://demo.supabase.co/storage/v1/object/fotos/abc-123/00000000-0000-0000-0000-00000000000a.jpg")
        #expect(solicitud.value(forHTTPHeaderField: "x-upsert") == "true")
        #expect(solicitud.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(solicitud.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
    }

    @Test func errorDelServidorSeReporta() async {
        let falso = TransporteFalso()
        falso.responder(403, #"{"code":"42501","message":"new row violates row-level security policy"}"#)
        await #expect(throws: ErrorNube.servidor("new row violates row-level security policy")) {
            _ = try await ClienteDatos(configuracion: configuracion, transporte: falso.transporte)
                .subir([producto()], token: "tok")
        }
    }
}
