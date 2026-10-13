import XCTest
@testable import PulseCore

/// Der Import muss mit dem zurechtkommen, was Menschen wirklich führen. Jeder
/// Test hier ist eine Tabelle, wie sie vorkommt, nicht eine, wie sie sein
/// sollte.
final class TableImportTests: XCTestCase {

    private func result(_ text: String) -> TableImport.Result {
        guard let draft = TableImport.analyse(text) else {
            XCTFail("Keine Tabelle erkannt"); return TableImport.Result(series: [], issues: [])
        }
        return TableImport.series(from: draft)
    }

    // MARK: - Was Zählora selbst ausgibt, liest Zählora wieder ein

    func testOwnExportReadsBack() {
        let register = Register(unit: .kilowattHour, fractionDigits: 2)
        let readings = [
            Reading(registerID: register.id, day: day(2025, 1, 3), value: dec("12345.6")),
            Reading(registerID: register.id, day: day(2025, 2, 3), time: TimeOfDay(hour: 8, minute: 15), value: dec("12601.25"))
        ]
        let text = TableExport.readings(readings, register: register, meterName: "Strom Haus")
        let r = result(text)

        XCTAssertEqual(r.series.count, 1)
        let s = r.series[0]
        XCTAssertEqual(s.meterName, "Strom Haus")
        XCTAssertEqual(s.unit, .kilowattHour)
        XCTAssertEqual(s.kind, .electricity)
        XCTAssertEqual(s.entries.map(\.value), [dec("12345.6"), dec("12601.25")])
        XCTAssertEqual(s.entries.map(\.day), [day(2025, 1, 3), day(2025, 2, 3)])
        XCTAssertEqual(s.entries[1].time, TimeOfDay(hour: 8, minute: 15))
        XCTAssertTrue(r.issues.isEmpty, "Unser eigener Export darf keine Hinweise erzeugen: \(r.issues)")
    }

    func testOwnDualTariffExportKeepsBothRegisters() {
        let ht = Register(label: "HT", unit: .kilowattHour)
        let nt = Register(label: "NT", unit: .kilowattHour)
        let point = MeteringPoint(propertyID: UUID(), name: "Strom", kind: .electricity, registers: [ht, nt])
        let readings = [
            Reading(registerID: ht.id, day: day(2025, 1, 1), value: 1000),
            Reading(registerID: nt.id, day: day(2025, 1, 1), value: 500),
            Reading(registerID: ht.id, day: day(2025, 2, 1), value: 1100),
            Reading(registerID: nt.id, day: day(2025, 2, 1), value: 560)
        ]
        let r = result(TableExport.readings(readings, meteringPoint: point, meterName: "Strom"))
        XCTAssertEqual(r.series.map(\.registerLabel), ["HT", "NT"])
        XCTAssertEqual(r.series.map(\.meterName), ["Strom", "Strom"])
        XCTAssertEqual(r.series[1].entries.map(\.value), [500, 560])
    }

    // MARK: - Eigene Listen

    /// Die häufigste Liste: eine Zeile je Ablesetag, eine Spalte je Zähler,
    /// deutsch geschrieben, aus Excel als CSV gespeichert.
    func testGermanWideTable() {
        let text = """
        Datum;Strom;Gas;Wasser
        01.01.2025;12.345,6;4.567,890;123,456
        01.02.2025;12.601,2;4.689,120;126,001
        03.03.2025;12.850,0;4.790,005;129,370
        """
        let r = result(text)
        XCTAssertEqual(r.series.map(\.meterName), ["Strom", "Gas", "Wasser"])
        XCTAssertEqual(r.series.map(\.kind), [.electricity, .gas, .water])
        XCTAssertEqual(r.series.map(\.unit), [.kilowattHour, .cubicMetre, .cubicMetre])
        XCTAssertEqual(r.series[0].entries.map(\.value), [dec("12345.6"), dec("12601.2"), dec("12850")])
        XCTAssertEqual(r.series[1].entries.first?.value, dec("4567.89"))
        XCTAssertEqual(r.series[1].fractionDigits, 3, "So viele Stellen, wie die Liste zeigt")
        XCTAssertEqual(r.series[2].entries.last?.day, day(2025, 3, 3))
    }

    /// In Numbers oder Excel Zellen markiert und kopiert: Tabulatoren, kurzes
    /// Jahr, keine Zählernamen.
    func testPastedCellsWithTabs() {
        let text = "Datum\tZählerstand\n3.1.25\t1234,5\n2.2.25\t1301\n"
        let r = result(text)
        XCTAssertEqual(r.series.count, 1)
        XCTAssertEqual(r.series[0].meterName, "Zähler", "Ohne Namen fragt die Oberfläche nach")
        XCTAssertEqual(r.series[0].entries.map(\.day), [day(2025, 1, 3), day(2025, 2, 2)])
        XCTAssertEqual(r.series[0].entries.map(\.value), [dec("1234.5"), 1301])
    }

    func testEnglishCommaSeparatedFile() {
        let text = "Date,Electricity (kWh)\n2025-01-03,1234.5\n2025-02-03,\"1,301.25\"\n"
        let r = result(text)
        XCTAssertEqual(r.series.first?.meterName, "Electricity")
        XCTAssertEqual(r.series.first?.unit, .kilowattHour)
        XCTAssertEqual(r.series.first?.entries.map(\.value), [dec("1234.5"), dec("1301.25")])
    }

    func testDualTariffColumnsBecomeOneMeterWithTwoRegisters() {
        let text = "Datum;Strom HT;Strom NT\n01.01.2025;1000;500\n01.02.2025;1100;560\n"
        let r = result(text)
        XCTAssertEqual(r.series.map(\.meterName), ["Strom", "Strom"])
        XCTAssertEqual(r.series.map(\.registerLabel), ["HT", "NT"])
    }

    func testFeedInIsRecognisedAsDirection() {
        let text = "Datum;Bezug;Einspeisung\n01.04.2025;8000;300\n01.05.2025;8150;520\n"
        let r = result(text)
        XCTAssertEqual(r.series.map(\.direction), [.consumption, .feedIn])
    }

    func testConsumptionAndCostColumnsAreNotReadings() {
        let text = "Datum;Zählerstand;Verbrauch;Kosten in €\n01.01.2025;1000;;\n01.02.2025;1120;120;38,40\n"
        let draft = TableImport.analyse(text)!
        XCTAssertEqual(draft.columns.map(\.role), [.date, .reading, .ignored, .ignored])
        let r = TableImport.series(from: draft)
        XCTAssertEqual(r.series.count, 1)
        XCTAssertTrue(r.issues.contains { $0.kind == .ignoredColumn && $0.text.contains("Verbrauch") })
    }

    func testLongTableWithMeterColumnAndNotes() {
        let text = """
        Zähler;Datum;Stand;Bemerkung
        Strom;01.01.2025;1000;
        Wasser;01.01.2025;50,5;
        Strom;01.02.2025;1100;nach dem Urlaub
        Wasser;01.02.2025;53,1;
        """
        let r = result(text)
        XCTAssertEqual(r.series.map(\.meterName), ["Strom", "Wasser"])
        XCTAssertEqual(r.series[0].entries.last?.note, "nach dem Urlaub")
        XCTAssertEqual(r.series[1].entries.map(\.value), [dec("50.5"), dec("53.1")])
    }

    func testFileWithoutHeader() {
        let r = result("01.01.2025;1000\n01.02.2025;1100\n")
        XCTAssertEqual(r.series.first?.entries.count, 2)
    }

    func testMonthNamesAndSpacesLikeANoteOnThePhone() {
        // Mit Leerzeichen getrennt geht nur „Datum Stand“ ohne Leerzeichen im Datum.
        let r2 = result("03.04.2025 1234\n03.05.2025 1301\n")
        XCTAssertEqual(r2.series.first?.entries.map(\.value), [1234, 1301])
        let r3 = result("Datum;Stand\n3. April 2025;1234\n3. Mai 2025;1301\n")
        XCTAssertEqual(r3.series.first?.entries.map(\.day), [day(2025, 4, 3), day(2025, 5, 3)])
    }

    func testAmericanSlashDatesAreRecognisedByTheirValues() {
        let r = result("Date,Reading\n01/13/2025,1000\n02/13/2025,1100\n")
        XCTAssertEqual(r.series.first?.entries.map(\.day), [day(2025, 1, 13), day(2025, 2, 13)])
        let de = result("Datum;Stand\n13/01/2025;1000\n13/02/2025;1100\n")
        XCTAssertEqual(de.series.first?.entries.map(\.day), [day(2025, 1, 13), day(2025, 2, 13)])
    }

    func testDateWithTime() {
        let r = result("Datum;Stand\n03.01.2025 08:15;1000\n2025-02-03T19:40;1100\n")
        XCTAssertEqual(r.series.first?.entries.map(\.time), [TimeOfDay(hour: 8, minute: 15), TimeOfDay(hour: 19, minute: 40)])
    }

    func testQuotedFieldsMayContainTheSeparator() {
        let r = result("Zähler;Datum;Stand\n\"Wasser; Garten\";01.05.2025;12,5\n\"Wasser; Garten\";01.06.2025;14\n")
        XCTAssertEqual(r.series.first?.meterName, "Wasser; Garten")
        XCTAssertEqual(r.series.first?.entries.count, 2)
    }

    // MARK: - Zeichensatz

    func testWindowsEncodingFromExcel() {
        let bytes: [UInt8] = Array("Datum;Z".utf8) + [0xE4] + Array("hlerstand\n01.01.2025;1000\n".utf8)
        let text = TableImport.text(from: Data(bytes))
        XCTAssertEqual(text?.hasPrefix("Datum;Zählerstand"), true)
        let bom = Data([0xEF, 0xBB, 0xBF] + Array("Datum;Stand\n".utf8))
        XCTAssertEqual(TableImport.text(from: bom), "Datum;Stand\n")
    }

    // MARK: - Prüfen

    func testDecreasingValueIsLeftOutAndNamed() {
        let r = result("Datum;Strom\n01.01.2025;1000\n01.02.2025;1100\n01.03.2025;110\n01.04.2025;1290\n")
        let s = r.series[0]
        XCTAssertEqual(s.entries.map(\.value), [1000, 1100, 1290])
        let hinweis = s.issues.first { $0.kind == .decreasing }
        XCTAssertEqual(hinweis?.line, 4, "Die Zeilennummer passt zur Datei, Kopfzeile mitgezählt")
        XCTAssertEqual(hinweis?.text.contains("110 am 01.03.2025 ist kleiner als der Stand davor (1.100)"), true,
                       "Zahlen im Hinweis deutsch geschrieben: \(hinweis?.text ?? "")")
        XCTAssertFalse(s.issues.contains { $0.kind == .looksLikeConsumption },
                       "Ein einzelner Tippfehler ist kein Hinweis auf Verbräuche")
    }

    func testDuplicatesAreMergedAndSameDayDifferentIsNamed() {
        let r = result("Datum;Strom\n01.01.2025;1000\n01.01.2025;1000\n01.02.2025;1100\n01.02.2025;1101\n")
        XCTAssertEqual(r.series[0].entries.map(\.value), [1000, 1100])
        XCTAssertEqual(Set(r.series[0].issues.map(\.kind)), [.duplicate, .sameDayDifferent])
    }

    func testUnsortedRowsAreSorted() {
        let r = result("Datum;Gas\n01.03.2025;30\n01.01.2025;10\n01.02.2025;20\n")
        XCTAssertEqual(r.series[0].entries.map(\.value), [10, 20, 30])
    }

    func testUnreadableRowsAreReportedWithTheirLine() {
        let r = result("Datum;Strom\n01.01.2025;1000\nim Urlaub;\n01.03.2025;abc\n01.04.2025;1200\n")
        XCTAssertEqual(r.series[0].entries.count, 2)
        XCTAssertEqual(r.issues.compactMap(\.line).sorted(), [3, 4])
    }

    func testConsumptionInsteadOfReadingsIsSuspected() {
        let r = result("Monat;Strom\n01.01.2025;310\n01.02.2025;280\n01.03.2025;260\n01.04.2025;220\n01.05.2025;240\n")
        XCTAssertTrue(r.series[0].issues.contains { $0.kind == .looksLikeConsumption })
    }

    func testNotATable() {
        XCTAssertNil(TableImport.analyse("Hallo, wie geht es?"))
        XCTAssertNil(TableImport.analyse(""))
        XCTAssertFalse(TableImport.analyse("Name;Ort\nAnna;Köln\nBen;Bonn\n")?.isUsable ?? false)
    }

    // MARK: - Zahlen

    func testNumberFormats() {
        func n(_ s: String, comma: Bool = true) -> Decimal? { TableImport.parseNumber(s, decimalComma: comma)?.0 }
        XCTAssertEqual(n("12.345,6"), dec("12345.6"))
        XCTAssertEqual(n("12345,6"), dec("12345.6"))
        XCTAssertEqual(n("12.345"), 12345, "Deutsch: Punkt trennt Tausender")
        XCTAssertEqual(n("12,345"), dec("12.345"), "Deutsch: Komma ist das Dezimalzeichen")
        XCTAssertEqual(n("1234.5"), dec("1234.5"), "Ein Punkt vor einer Ziffer ist ein Dezimalpunkt")
        XCTAssertEqual(n("12,345.6", comma: false), dec("12345.6"))
        XCTAssertEqual(n("12 345,6 kWh"), dec("12345.6"))
        XCTAssertEqual(n("1.234,5 m³"), dec("1234.5"))
        XCTAssertNil(n("08:15"))
        XCTAssertNil(n("abc"))
    }

    /// Zehn Jahre täglich, vier Zähler: 14.600 Stände. Wer so viel geführt
    /// hat, soll nicht warten. Grenze großzügig, weil die Läufer verschieden
    /// schnell sind.
    func testALargeListIsQuick() {
        var zeilen = ["Datum;Strom;Gas;Wasser;Wärmepumpe"]
        var tag = day(2016, 1, 1)
        for i in 0..<3650 {
            zeilen.append("\(TableImport.deutsch(tag));\(10000 + i * 8),5;\(2000 + i * 3),125;\(100 + i / 3),25;\(5000 + i * 12)")
            tag = tag.adding(days: 1)
        }
        let text = zeilen.joined(separator: "\n")
        let start = Date()
        let r = result(text)
        let dauer = Date().timeIntervalSince(start)
        XCTAssertEqual(r.entryCount, 14_600)
        XCTAssertLessThan(dauer, 3.0, "Einlesen von 14.600 Ständen dauerte \(dauer) s")
        print("  ⏱  Einlesen von 14.600 Ständen: \(String(format: "%.3f", dauer)) s (Grenze 3.0 s)")
    }

    /// Tausend eingelesene gegen tausend vorhandene: Die Vorschau rechnet das
    /// bei jeder Änderung, also muss es schnell gehen.
    func testMergingAgainstALongHistoryIsQuick() {
        let register = Register(unit: .kilowattHour)
        var vorhanden: [Reading] = []
        var tag = day(2020, 1, 1)
        for i in 0..<1500 { vorhanden.append(Reading(registerID: register.id, day: tag, value: Decimal(i * 10))); tag = tag.adding(days: 1) }
        var zeilen = ["Datum;Strom"]
        tag = day(2020, 1, 1)
        for i in 0..<1500 { zeilen.append("\(TableImport.deutsch(tag));\(i * 10 + (i % 2))"); tag = tag.adding(days: 1) }
        let s = result(zeilen.joined(separator: "\n")).series[0]
        let start = Date()
        let merge = TableImport.readings(from: s, register: register.id, existing: vorhanden)
        let dauer = Date().timeIntervalSince(start)
        XCTAssertEqual(merge.alreadyThere, 750)
        XCTAssertEqual(merge.conflicts.count, 750)
        XCTAssertLessThan(dauer, 0.5, "Abgleich dauerte \(dauer) s")
    }

    // MARK: - Abgleich

    func testMergeSkipsWhatIsAlreadyThereAndKeepsTheExistingOnConflict() {
        let register = Register(unit: .kilowattHour)
        let vorhanden = [
            Reading(registerID: register.id, day: day(2025, 1, 1), value: 1000),
            Reading(registerID: register.id, day: day(2025, 2, 1), value: 1099)
        ]
        let s = result("Datum;Strom\n01.01.2025;1000\n01.02.2025;1100\n01.03.2025;1200\n").series[0]
        let merge = TableImport.readings(from: s, register: register.id, existing: vorhanden)
        XCTAssertEqual(merge.readings.map(\.value), [1200])
        XCTAssertEqual(merge.readings.first?.origin, .imported)
        XCTAssertEqual(merge.alreadyThere, 1)
        XCTAssertEqual(merge.conflicts.count, 1)
    }

    /// Eine Liste, die zu einem anderen Zähler gehört, darf nicht in diesen
    /// laufen, nur weil der Name gleich ist.
    func testReadingsThatDoNotFitBetweenExistingOnesAreLeftOut() {
        let register = Register(unit: .kilowattHour)
        let vorhanden = [
            Reading(registerID: register.id, day: day(2025, 1, 1), value: 49_000),
            Reading(registerID: register.id, day: day(2025, 6, 1), value: 50_000)
        ]
        // Unter dem Stand davor
        let s = result("Datum;Strom\n01.03.2025;12000\n01.04.2025;49500\n01.08.2025;50300\n").series[0]
        let merge = TableImport.readings(from: s, register: register.id, existing: vorhanden)
        XCTAssertEqual(merge.readings.map(\.value), [49_500, 50_300])
        XCTAssertEqual(merge.misfits, 1)
        // Über dem Stand danach
        let hoch = result("Datum;Strom\n01.03.2025;55000\n").series[0]
        let merge2 = TableImport.readings(from: hoch, register: register.id, existing: vorhanden)
        XCTAssertTrue(merge2.readings.isEmpty)
        XCTAssertEqual(merge2.conflicts.first?.kind, .doesNotFit)
    }
}
