import XCTest
@testable import PulseCore

/// Jeder Test hier ist ein Foto aus `docs/kamera/fotos.json`: derselbe Zähler,
/// derselbe Stand, und als Text das, was eine Erkennung dort liest — inklusive
/// des Typenschilds, das sie zuerst und am zuverlässigsten findet. Die Texte
/// sind von Hand nachgebildet (Tesseract auf den Fotos, Vision auf dem Mac
/// liest anders); was auf dem Telefon wirklich herauskommt, misst
/// `docs/kamera/README.md` an denselben Fotos.
///
/// Die Regel, an der alles hängt: **lieber kein Vorschlag als ein falscher.**
final class MeterTextReaderTests: XCTestCase {

    private let electric = MeterFormat(integerDigits: 6, fractionDigits: 2)
    private let electricNoDecimals = MeterFormat(integerDigits: 6, fractionDigits: 0)
    private let gas = MeterFormat(integerDigits: 5, fractionDigits: 2)

    private func texts(_ items: String...) -> [RecognizedLine] { items.map { RecognizedLine($0) } }

    private func value(_ outcome: MeterTextReader.Outcome, file: StaticString = #filePath, line: UInt = #line) -> Decimal? {
        if case .proposal(let p) = outcome { return p.value }
        return nil
    }

    private func dec(_ s: String) -> Decimal { Decimal(string: s)! }

    // MARK: - Was gelesen werden soll

    /// Foto 07: Siemens, Rollenzählwerk 65521 mit roter 9.
    func testSiemensRollerCounterReadsRedDigitAsFraction() {
        let format = MeterFormat(integerDigits: 5, fractionDigits: 1)
        let items = texts("655219", "SIEMENS", "kWh", "Wechselstromzähler", "220 V", "10(60) A", "50 Hz", "375 U/kWh", "6.047.178")
        let outcome = MeterTextReader.propose(from: items, format: format, plausible: dec("65000")...dec("66000"))
        XCTAssertEqual(value(outcome), dec("65521.9"))
    }

    /// Dasselbe Foto bei der ersten Ablesung: „655219" hat weder Einheit noch Komma
    /// noch führende Null und sieht damit aus wie eine Seriennummer.
    func testBareRollerNumberIsNotProposedOnFirstReading() {
        let format = MeterFormat(integerDigits: 5, fractionDigits: 1)
        let outcome = MeterTextReader.propose(from: texts("655219", "SIEMENS", "kWh"), format: format)
        XCTAssertEqual(outcome, .none(.noCandidate))
    }

    /// Foto 02: „P 424501" auf dem Typenschild ist sechsstellig und damit so breit wie das Zählwerk.
    func testSixDigitSerialNumberIsNotProposedOnFirstReading() {
        XCTAssertNil(value(MeterTextReader.propose(from: texts("424501", "5530", "2008"), format: electricNoDecimals)))
        // Mit einem Bereich, in dem der Zähler liegen kann, ist die Seriennummer draußen.
        let outcome = MeterTextReader.propose(from: texts("424501", "9023 kWh"), format: electricNoDecimals,
                                              plausible: dec("9000")...dec("9200"))
        XCTAssertEqual(value(outcome), 9023)
    }

    /// Foto 31: Landis+Gyr E320, „1.8.0" und „002423 kWh".
    func testLandisDisplayWithObisPrefixAndUnit() {
        let outcome = MeterTextReader.propose(
            from: texts("1.8.0", "002423 kWh", "E320", "5000 Imp/kWh", "DE-M24", "2024", "230V/400V", "0,25-5(100)A"),
            format: electricNoDecimals)
        XCTAssertEqual(value(outcome), 2423)
    }

    /// Foto 11: Metrix G4, Rollen „00047" und rote „36", dazu die Zählernummer 113457.
    func testGasMeterRollersWithRedDigitsAsSeparateGroup() {
        let outcome = MeterTextReader.propose(
            from: texts("0 0 0 4 7 3 6 m³", "113457", "G4", "6G4L", "2007"),
            format: gas)
        XCTAssertEqual(value(outcome), dec("47.36"))
    }

    func testGasMeterWithDecimalCommaAndUnit() {
        let outcome = MeterTextReader.propose(from: texts("00047,36 m³", "G4"), format: gas)
        XCTAssertEqual(value(outcome), dec("47.36"))
    }

    /// Foto 29: Kamstrup, sieben Stellen „0014426" auf einem sechsstelligen Zählwerk.
    func testSevenDigitsWithLeadingZerosFitSixDigitRegister() {
        let outcome = MeterTextReader.propose(from: texts("1.8.0", "0014426", "2008W38", "1000 imp/kWh"), format: electricNoDecimals)
        XCTAssertEqual(value(outcome), 14426)
        if case .proposal(let p) = outcome { XCTAssertFalse(p.fractionMissing) }
    }

    /// Foto 04: ein neuer Zähler zeigt lauter Nullen. „000000" ist ein Stand, kein Fehler.
    func testAllZerosIsAReading() {
        let outcome = MeterTextReader.propose(
            from: texts("180", "000000 kWh", "1 LOG00 8612 2566", "Nr. 86122566", "500 Imp/kWh"),
            format: electricNoDecimals)
        XCTAssertEqual(value(outcome), 0)
    }

    func testSegmentDisplayLookalikesAreRepaired() {
        // Siebensegment-Null und Eins als Buchstaben.
        let outcome = MeterTextReader.propose(from: texts("O02423 kWh"), format: electricNoDecimals)
        XCTAssertEqual(value(outcome), 2423)
        let outcome2 = MeterTextReader.propose(from: texts("OO2I23 kWh"), format: electricNoDecimals)
        XCTAssertEqual(value(outcome2), 2123)
    }

    /// Ein repariertes Wort ist ein geratenes Wort und zählt nur mit Einheit.
    /// `kamera-messen` hat das an Foto 06 gefunden: Die Materialnummer
    /// „B11538" auf dem Typenschild wurde zu 811538, und ein Kürzel wie
    /// „D12345" wäre über die führende Null zu 12345 geworden.
    func testRepairedWordNeverBecomesAReadingWithoutUnit() {
        for plate in ["B11538", "D12345", "Q10006", "O02423", "OO2I23"] {
            XCTAssertNil(value(MeterTextReader.propose(from: texts(plate), format: electricNoDecimals)), plate)
        }
        XCTAssertEqual(value(MeterTextReader.propose(from: texts("O02423 kWh"), format: electricNoDecimals)), 2423)
    }

    /// Eine Zahl ohne Einheit und ohne führende Nullen ist nur im erwarteten Bereich glaubwürdig.
    func testWeakNumberNeedsExpectedRange() {
        // Foto 32: „1936" auf dem grünen Display, davor stand 1900.
        let items = texts("1936")
        XCTAssertEqual(MeterTextReader.propose(from: items, format: electricNoDecimals), .none(.noCandidate),
                       "Ohne Vorwissen kann „1936“ alles sein, auch ein Baujahr")
        XCTAssertEqual(value(MeterTextReader.propose(from: items, format: electricNoDecimals, plausible: dec("1900")...dec("2100"))), 1936)
    }

    // MARK: - Was nie vorgeschlagen werden darf

    /// Das Typenschild allein, in allen Abwandlungen, die auf den Fotos vorkamen.
    func testTypePlateAloneProposesNothing() {
        let plates = texts(
            "2566", "5000", "2024", "230V", "50Hz", "63A", "424501", "5530", "2008",
            "500imp/KWh", "375U/kWh", "10(60)A", "7AA50 61", "50470-3", "04972G072",
            "6.047.178", "Nr 50 752 788", "86122566", "1 LOG00 8612 2566", "LK11BE803617",
            "0A-01-4C-4F-47-00-05-22-20-46", "7350028676767257", "1.8.0", "0,25-5(60)A",
            "10.000 Imp/kWh", "221/12-5004", "2812689", "306 495 056")
        for format in [electric, electricNoDecimals, gas, MeterFormat(integerDigits: 7, fractionDigits: 0)] {
            let outcome = MeterTextReader.propose(from: plates, format: format)
            XCTAssertNil(value(outcome), "Typenschild als Stand gelesen bei \(format): \(outcome)")
        }
    }

    /// Foto 06: das Display ist leer, auf dem Typenschild stehen nur Kennzahlen.
    func testBlankDisplayProposesNothing() {
        let outcome = MeterTextReader.propose(
            from: texts("Wechselstromzähler", "1 LOG00 8612 2566", "Mat. B11538", "230V", "50Hz", "2023", "1383"),
            format: electricNoDecimals)
        XCTAssertNil(value(outcome))
    }

    /// Foto 43: eine halb gedrehte Ziffer. Die Erkennung liefert zwei Lesarten;
    /// welche stimmt, weiß nur, wer hinsieht.
    func testHalfRolledDigitWithTwoReadingsIsAmbiguous() {
        let outcome = MeterTextReader.propose(from: texts("006100", "006700", "11272121"),
                                              format: electricNoDecimals)
        XCTAssertEqual(outcome, .none(.ambiguous))
    }

    func testSameNumberReadTwiceIsNotAmbiguous() {
        let outcome = MeterTextReader.propose(from: [RecognizedLine("002423", confidence: 0.6), RecognizedLine("002423 kWh", confidence: 0.9)],
                                              format: electricNoDecimals)
        XCTAssertEqual(value(outcome), 2423)
        if case .proposal(let p) = outcome { XCTAssertEqual(p.confidence, 0.9) }
    }

    /// Das Zählwerk steht auf den Voreinstellungen (6 + 2), der Zähler ist aber
    /// ein Siemens mit 5 + 1: „655219" würde als 655.219 gelesen — ein Stand,
    /// den der Zähler nicht erreicht haben kann.
    func testWrongRegisterFormatIsCaughtByRange() {
        let outcome = MeterTextReader.propose(from: texts("655219"), format: electric,
                                              plausible: dec("65500")...dec("66500"))
        XCTAssertEqual(outcome, .none(.outsideRange))
    }

    /// Eine passende Zahl außerhalb des Bereichs darf nicht von einer
    /// Kennzahl ersetzt werden, die zufällig im Bereich liegt.
    func testObisCodeDoesNotStandInForReadingOutsideRange() {
        let outcome = MeterTextReader.propose(from: texts("180", "002423 kWh"), format: electricNoDecimals,
                                              plausible: dec("100")...dec("300"))
        XCTAssertEqual(outcome, .none(.outsideRange))
    }

    func testLowRecognitionConfidenceProposesNothing() {
        let outcome = MeterTextReader.propose(from: [RecognizedLine("002423 kWh", confidence: 0.3)],
                                              format: electricNoDecimals)
        XCTAssertEqual(outcome, .none(.lowConfidence))
        let weak = MeterTextReader.propose(from: [RecognizedLine("1936", confidence: 0.7)], format: electricNoDecimals,
                                           plausible: dec("1900")...dec("2100"))
        XCTAssertEqual(weak, .none(.lowConfidence), "Eine schwache Zahl braucht mehr Sicherheit als eine starke")
    }

    func testMoreFractionDigitsThanTheRegisterHasIsNotAReading() {
        // „10.000" ist bei zwei Nachkommastellen ein Tausenderpunkt oder eine Impulskonstante.
        XCTAssertNil(value(MeterTextReader.propose(from: texts("10.000"), format: electric)))
        // Bei einem Wasserzähler mit drei Nachkommastellen ist es 10,000.
        let water = MeterFormat(integerDigits: 5, fractionDigits: 3)
        XCTAssertNil(value(MeterTextReader.propose(from: texts("10.000"), format: water)),
                     "Ohne Vorwissen bleibt es schwach")
        XCTAssertEqual(value(MeterTextReader.propose(from: texts("00010,000 m³"), format: water)), 10)
    }

    func testEmptyAndGibberishProposeNothing() {
        XCTAssertEqual(MeterTextReader.propose(from: [], format: electric), .none(.noCandidate))
        XCTAssertEqual(MeterTextReader.propose(from: texts("", "   ", "Zähler", "kWh"), format: electric), .none(.noCandidate))
    }

    /// Eine Ziffer im Text bleibt Text, wenn Buchstaben mittendrin stehen.
    func testLookalikeRepairOnlyAppliesToNumbers() {
        XCTAssertEqual(MeterTextReader.fixLookalikes("SB2"), "SB2")
        XCTAssertEqual(MeterTextReader.fixLookalikes("OO2I23"), "002123")
        XCTAssertEqual(MeterTextReader.fixLookalikes("Wechselstromzähler 220"), "Wechselstromzähler 220")
    }

    // MARK: - Dieselben Fälle wie im Klick-Dummy

    /// `docs/kamera/vektoren.json` ist die eine Liste von Fällen, die auch
    /// `scripts/check-kamera-js.mjs` gegen die Fassung im Klick-Dummy laufen
    /// lässt. Weichen beide voneinander ab, ist das ein Fehler (CLAUDE.md, Regel 2).
    func testSharedVectorsMatchPrototype() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/kamera/vektoren.json"))
        let file = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let cases = file["faelle"] as! [[String: Any]]
        XCTAssertGreaterThan(cases.count, 20)

        for c in cases {
            let name = c["name"] as! String
            let items = (c["texte"] as! [[Any]]).map {
                RecognizedLine($0[0] as! String, confidence: ($0[1] as! NSNumber).doubleValue)
            }
            let f = c["format"] as! [Int]
            let range = (c["bereich"] as? [String]).map { dec($0[0])...dec($0[1]) }
            let outcome = MeterTextReader.propose(from: items, format: MeterFormat(integerDigits: f[0], fractionDigits: f[1]), plausible: range)

            let expected = c["erwartet"] as! [String: String]
            if let want = expected["wert"] {
                XCTAssertEqual(value(outcome), dec(want), "\(name): \(outcome)")
            } else {
                let reason: MeterTextReader.Reason = ["noCandidate": .noCandidate, "ambiguous": .ambiguous,
                                                       "outsideRange": .outsideRange, "lowConfidence": .lowConfidence][expected["keine"]!]!
                XCTAssertEqual(outcome, .none(reason), name)
            }
        }
    }

    /// Foto 01: Das Display zeigt ein Datum. Mit Doppelpunkten ist es kein Stand;
    /// ohne sie sähe es aus wie 270.822 und trüge kein Merkmal.
    func testDateOnDisplayIsNotAReading() {
        XCTAssertEqual(MeterTextReader.propose(from: texts("27:08:22", "DATE"), format: electricNoDecimals), .none(.noCandidate))
        XCTAssertEqual(MeterTextReader.propose(from: texts("270822"), format: electricNoDecimals), .none(.noCandidate))
    }
}
