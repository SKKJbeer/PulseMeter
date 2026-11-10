import XCTest
@testable import PulseData

/// Hält `cloudkit/schema.ckdb` und das Datenmodell zusammen.
///
/// Die Datei lädt `.github/workflows/cloudkit-schema.yml` in die
/// Entwicklungsumgebung von CloudKit. Weicht sie vom Modell ab, fehlt in der
/// Produktion ein Feld, und CloudKit lehnt jedes Hochladen damit ab, still.
/// Bei einer Abweichung steht der richtige Inhalt in der Meldung.
final class CloudKitSchemaTests: XCTestCase {

    func testSchemaFileMatchesTheModel() throws {
        let erzeugt = try PulseStore.cloudKitSchemaText()
        let datei = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PulseDataTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // PulseData
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // Wurzel
            .appendingPathComponent("cloudkit/schema.ckdb")
        let abgelegt = try String(contentsOf: datei, encoding: .utf8)
        XCTAssertEqual(abgelegt, erzeugt,
                       "cloudkit/schema.ckdb weicht vom Modell ab. Richtig wäre:\n\(erzeugt)")
    }

    func testEveryModelTypeHasARecordType() throws {
        let text = try PulseStore.cloudKitSchemaText()
        for typ in PulseStore.modelTypes {
            XCTAssertTrue(text.contains("RECORD TYPE CD_\(typ) ("), "\(typ) fehlt im Schema")
        }
    }
}
