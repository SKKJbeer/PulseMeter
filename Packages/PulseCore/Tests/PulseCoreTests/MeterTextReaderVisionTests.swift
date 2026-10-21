import XCTest
@testable import PulseCore

/// Der Leser an dem, was **Apples Vision** auf den 15 Zählerfotos wirklich
/// gelesen hat (`docs/kamera/vision-gelesen.json`, gemessen auf dem macOS-Läufer am
/// 21. Oktober 2026 mit `kamera-messen`), nicht an nachgebildeten Texten.
///
/// Gehalten wird eine einzige Regel: **kein falscher Vorschlag.** Wie viele
/// richtige es sind, ist eine Zahl, die sich bessern darf; ein falscher Vorschlag
/// ist ein Fehler. Ändert sich die Aufnahme (neues macOS, neuer Rahmen), läuft
/// `kamera-messen` neu und die Datei wird ersetzt, auf dem Mac-Läufer, nicht von Hand.
final class MeterTextReaderVisionTests: XCTestCase {

    private struct Foto: Decodable {
        let datei: String
        let stand: String?
        let vorkommastellen: Int
        let nachkommastellen: Int
        var name: String { String(datei.split(separator: "/").last!.dropLast(4)) }
    }

    private func laden() throws -> (fotos: [Foto], gelesen: [String: [RecognizedLine]]) {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        struct Sammlung: Decodable { let fotos: [Foto] }
        let fotos = try JSONDecoder().decode(Sammlung.self, from: Data(contentsOf: root.appendingPathComponent("docs/kamera/fotos.json"))).fotos
        let roh = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("docs/kamera/vision-gelesen.json"))) as! [String: [[Any]]]
        let gelesen = roh.mapValues { $0.map { RecognizedLine($0[0] as! String, confidence: ($0[1] as! NSNumber).doubleValue) } }
        return (fotos, gelesen)
    }

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    /// Wie `kamera-messen`: einmal ohne Bereich (erste Ablesung), einmal mit
    /// einem engen um den Soll-Stand (zweite), bei Fotos ohne Stand um 12.345.
    private func ergebnisse(_ foto: Foto, _ texte: [RecognizedLine]) -> [(String, MeterTextReader.Outcome)] {
        let format = MeterFormat(integerDigits: foto.vorkommastellen, fractionDigits: foto.nachkommastellen)
        let soll = foto.stand.map(dec)
        let bereich = soll.map { max(0, $0 - 100)...($0 + 100) } ?? dec("12345")...dec("13845")
        return [("erste Ablesung", MeterTextReader.propose(from: texte, format: format)),
                ("zweite Ablesung", MeterTextReader.propose(from: texte, format: format, plausible: bereich))]
    }

    func testVisionOutputNeverYieldsAWrongProposal() throws {
        let (fotos, gelesen) = try laden()
        XCTAssertEqual(fotos.count, 15)
        for foto in fotos {
            let texte = try XCTUnwrap(gelesen[foto.name], "\(foto.name): keine Aufnahme von Vision")
            for (modus, ergebnis) in ergebnisse(foto, texte) {
                guard case .proposal(let p) = ergebnis else { continue }
                guard let stand = foto.stand else {
                    XCTFail("\(foto.name), \(modus): Vorschlag \(p.value), obwohl auf dem Foto kein Stand steht")
                    continue
                }
                let soll = dec(stand)
                var ganz = Decimal(); var kopie = soll
                NSDecimalRound(&ganz, &kopie, 0, .down)
                let richtig = p.value == soll
                let teilweise = p.fractionMissing && p.value == ganz
                XCTAssertTrue(richtig || teilweise, "\(foto.name), \(modus): Vorschlag \(p.value) statt \(soll)")
            }
        }
    }

    /// Was Vision gut liest, wird auch vorgeschlagen: das Rollenzählwerk mit
    /// Sicherheit 1,0. Fällt das weg, hat jemand den Leser stumm geschaltet.
    func testWhatVisionReadsConfidentlyIsStillProposed() throws {
        let (fotos, gelesen) = try laden()
        let openway = try XCTUnwrap(fotos.first { $0.name.hasPrefix("28-") })
        let erste = ergebnisse(openway, gelesen[openway.name]!)[0].1
        guard case .proposal(let p) = erste else { return XCTFail("OpenWay: \(erste)") }
        XCTAssertEqual(p.value, 0)

        // Foto 07: Vision liest „65521" mit 1,0 und die rote 9 als eigenes Stück mit 0,3.
        // Vorgeschlagen wird die Vorkommazahl, mit dem Kennzeichen, dass die rote Stelle fehlt.
        let siemens = try XCTUnwrap(fotos.first { $0.name.hasPrefix("07-") })
        guard case .proposal(let s) = ergebnisse(siemens, gelesen[siemens.name]!)[1].1 else { return XCTFail("Siemens: kein Vorschlag") }
        XCTAssertEqual(s.value, 65521)
        XCTAssertTrue(s.fractionMissing)
    }

    /// Das Datum im Display (Foto 01) liest Vision als „270822" mit 0,5: ohne
    /// Doppelpunkte und ohne Einheit. Das darf nie ein Stand werden.
    func testDateOnDisplayReadWithoutColonsIsNotProposed() throws {
        let (fotos, gelesen) = try laden()
        let datum = try XCTUnwrap(fotos.first { $0.name.hasPrefix("01-") })
        for (modus, ergebnis) in ergebnisse(datum, gelesen[datum.name]!) {
            if case .proposal(let p) = ergebnis { XCTFail("Datum als Stand gelesen (\(modus)): \(p.value)") }
        }
    }
}
