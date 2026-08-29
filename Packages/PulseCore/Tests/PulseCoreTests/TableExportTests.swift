import XCTest
@testable import PulseCore

final class TableExportTests: XCTestCase {

    func testReadingsCarryDateValueAndOrigin() {
        let register = Fixture.gasRegister()
        let readings = [
            Fixture.reading(register, day(2026, 2, 1), dec("8100.5"), sequence: 0),
            Fixture.reading(register, day(2026, 1, 1), dec("8000.25"), origin: .estimated, sequence: 1)
        ]

        let csv = TableExport.readings(readings, register: register, meterName: "Gas")
        let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true).map(String.init)

        XCTAssertEqual(lines[0], "Zähler;Datum;Stand;Einheit;Art")
        XCTAssertEqual(lines[1], "Gas;2026-01-01;8000,250;m³;geschätzt",
                       "Älteste zuerst, Dezimalkomma, Nachkommastellen des Zählwerks")
        XCTAssertEqual(lines[2], "Gas;2026-02-01;8100,500;m³;abgelesen")
    }

    /// Die Spalte „Vollständig" muss mit: Ohne sie steht ein laufender Monat
    /// in der Tabelle neben abgeschlossenen und die Summe wirkt wie ein Jahr.
    func testBreakdownMarksIncompletePeriods() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2026, 2, 1), 1300, sequence: 1),
            Fixture.reading(register, day(2026, 2, 15), 1440, sequence: 2)
        ]
        let buckets = PeriodEngine.buckets(register: register, readings: readings,
                                           year: 2026, granularity: .month)

        let csv = TableExport.breakdown(buckets, unit: .kilowattHour, meterName: "Strom")
        let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true).map(String.init)

        XCTAssertEqual(lines[0],
                       "Zähler;Zeitraum;Von;Bis;Verbrauch;Einheit;Tage;Vollständig")
        XCTAssertEqual(lines[1], "Strom;Januar 2026;2026-01-01;2026-02-01;300;kWh;31;ja")
        XCTAssertEqual(lines[2], "Strom;Februar 2026;2026-02-01;2026-02-15;140;kWh;14;nein",
                       "Der laufende Februar endet am 15. und ist unvollständig")
        XCTAssertEqual(lines[3], "Strom;März 2026;;;;kWh;0;keine Daten")
    }

    func testQuarterAndYearLabels() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2027, 1, 1), 4650, sequence: 1)
        ]

        let quarters = PeriodEngine.buckets(register: register, readings: readings,
                                            year: 2026, granularity: .quarter)
        XCTAssertEqual(TableExport.label(for: quarters[2]), "Q3 2026")

        let years = PeriodEngine.buckets(register: register, readings: readings,
                                         year: 2026, granularity: .year)
        XCTAssertEqual(TableExport.label(for: years[0]), "2026")
    }

    /// Ein Zählername darf alles enthalten, was jemand eintippt.
    func testFieldsContainingTheSeparatorAreQuoted() {
        let register = Fixture.electricityRegister()
        let readings = [Fixture.reading(register, day(2026, 1, 1), 1000, sequence: 0)]

        let csv = TableExport.readings(readings, register: register,
                                       meterName: "Wohnung 2; \"oben\"")
        XCTAssertTrue(csv.contains("\"Wohnung 2; \"\"oben\"\"\""),
                      "Trennzeichen und Anführungszeichen müssen eingefasst werden")
    }

    func testDecimalsUseACommaAndTheRequestedPrecision() {
        XCTAssertEqual(TableExport.decimal(dec("1234.567"), digits: 1), "1234,6")
        XCTAssertEqual(TableExport.decimal(dec("-3.25"), digits: 2), "-3,25")
    }

    /// Nachgestellte Nullen bleiben stehen: Der Export eines Zählerstands ist
    /// ein Beleg und soll die Genauigkeit des Geräts zeigen.
    func testTrailingZerosArePreserved() {
        XCTAssertEqual(TableExport.decimal(dec("8000.25"), digits: 3), "8000,250")
        XCTAssertEqual(TableExport.decimal(dec("7"), digits: 2), "7,00")
        XCTAssertEqual(TableExport.decimal(dec("0.5"), digits: 3), "0,500")
    }

    /// Gerundet wird zur geraden Ziffer — dieselbe Regel wie im ganzen
    /// Rechenkern (siehe `StorageTests.testRoundsHalfToEvenLikeMoney`). Über
    /// viele Zeilen hinweg vermeidet das eine systematische Verzerrung nach
    /// oben; für einen Export über zwölf Monate ist genau das der Punkt.
    func testHalvesRoundToTheEvenDigitLikeEverywhereElse() {
        XCTAssertEqual(TableExport.decimal(dec("1234.5"), digits: 0), "1234")
        XCTAssertEqual(TableExport.decimal(dec("1235.5"), digits: 0), "1236")
    }

    /// Der Export eines Doppeltarifzählers enthält **beide** Zahlen.
    ///
    /// Ohne diese Prüfung verschwände beim Export die Hälfte der Daten, und die
    /// Datei sähe trotzdem vollständig aus — der teuerste Fehler, den ein
    /// Export machen kann.
    func testDualTariffExportCarriesBothRegisters() {
        let high = Register(label: "Hochtarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let low = Register(label: "Niedertarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [high, low])
        let readings = [
            Fixture.reading(low, day(2026, 1, 1), 29_479.8),
            Fixture.reading(high, day(2026, 1, 1), 24_739.5),
            Fixture.reading(high, day(2026, 6, 1), 25_971.5),
            Fixture.reading(low, day(2026, 6, 1), 30_788.8)
        ]

        let csv = TableExport.readings(readings, meteringPoint: point, meterName: "Wärmepumpe")
        let lines = csv.split(separator: "\r\n").map(String.init)

        XCTAssertEqual(lines.count, 5, "Kopfzeile und vier Ablesungen")
        XCTAssertTrue(lines[0].contains("Bezeichnung"))
        XCTAssertTrue(lines[1].contains("Hochtarif") && lines[1].contains("24739,5"),
                      "Am selben Tag steht das erste Zählwerk oben — gelesen: \(lines[1])")
        XCTAssertTrue(lines[2].contains("Niedertarif") && lines[2].contains("29479,8"))
        XCTAssertTrue(lines[3].contains("Hochtarif") && lines[3].contains("25971,5"))
        XCTAssertTrue(lines[4].contains("Niedertarif") && lines[4].contains("30788,8"))
    }

    /// Ein gewöhnlicher Zähler behält die alte Form — ohne leere Spalte.
    func testSingleRegisterExportKeepsItsShape() {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [Fixture.reading(register, day(2026, 1, 1), 1_000)]

        let viaMeter = TableExport.readings(readings, meteringPoint: point, meterName: "Strom")
        let viaRegister = TableExport.readings(readings, register: register, meterName: "Strom")

        XCTAssertEqual(viaMeter, viaRegister)
        XCTAssertFalse(viaMeter.contains("Bezeichnung"))
    }

    // MARK: - Formeln in der Tabelle

    /// **Ein Zählername darf keine Formel werden.**
    ///
    /// Der Export ist zum Weitergeben gedacht. Öffnet der Vermieter die Datei,
    /// ist der Name für ihn fremde Eingabe — und `=HYPERLINK(…)` läuft in
    /// Excel, sobald die Tabelle auf dem Schirm steht. Einfassen allein hilft
    /// nicht: Auch ein Feld in Anführungszeichen wird ausgewertet.
    func testAMeterNameNeverBecomesAFormula() {
        for gefaehrlich in ["=1+1", "+1", "-1+2", "@SUM(A1)", "\tTabulator"] {
            let zelle = TableExport.escape(gefaehrlich)
            XCTAssertTrue(zelle.hasPrefix("'") || zelle.hasPrefix("\"'"),
                          "Der Wert \(gefaehrlich) ist ungeschützt: \(zelle)")
        }
    }

    /// Und ein gewöhnlicher Name bleibt unangetastet.
    ///
    /// Sonst stünde vor jedem „Strom" ein Apostroph — die Heilung wäre
    /// schlimmer als die Krankheit.
    func testAnOrdinaryNameIsLeftAlone() {
        XCTAssertEqual(TableExport.escape("Strom"), "Strom")
        XCTAssertEqual(TableExport.escape("Wärmepumpe (Garage)"), "Wärmepumpe (Garage)")
        // Semikolon bleibt der Grund fürs Einfassen, ohne Apostroph davor.
        XCTAssertEqual(TableExport.escape("Garage; hinten"), "\"Garage; hinten\"")
    }

}
