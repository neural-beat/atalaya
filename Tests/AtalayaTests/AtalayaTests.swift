import XCTest
@testable import Atalaya

final class AtalayaTests: XCTestCase {
    func testReordenaTarjetaEnPosicionExacta() {
        var d = Disposicion.deFabrica
        XCTAssertTrue(d.mueve("servicios", antesDe: "cpu"))
        XCTAssertEqual(d.fichas.first?.id, "servicios")
    }

    func testUnaTarjetaFijadaNoSeMueveNiSeDesplaza() {
        var d = Disposicion.deFabrica
        d.fichas[0].fijada = true
        XCTAssertFalse(d.mueve("cpu", antesDe: "memoria"))
        XCTAssertFalse(d.mueve("memoria", antesDe: "cpu"))
        XCTAssertEqual(d.fichas.prefix(2).map(\.id), ["cpu", "memoria"])
    }

    func testValidaRepositorioSinPermitirComandos() throws {
        XCTAssertEqual(try ValidadorRepositorio.valida("https://github.com/a/b.git"), "https://github.com/a/b.git")
        XCTAssertThrowsError(try ValidadorRepositorio.valida("https://github.com/a/b.git\nrm -rf /"))
        XCTAssertThrowsError(try ValidadorRepositorio.valida("file:///tmp/repo"))
    }
}
