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
}
