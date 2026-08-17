import XCTest
@testable import PulseCore

final class TimeOfDayTests: XCTestCase {

    func testRejectsImpossibleTimes() {
        XCTAssertNil(TimeOfDay(hour: 24, minute: 0), "24:00 ist Mitternacht des nächsten Tages")
        XCTAssertNil(TimeOfDay(hour: -1, minute: 0))
        XCTAssertNil(TimeOfDay(hour: 12, minute: 60))
        XCTAssertNil(TimeOfDay(hour: 12, minute: -1))
        XCTAssertNotNil(TimeOfDay(hour: 0, minute: 0))
        XCTAssertNotNil(TimeOfDay(hour: 23, minute: 59))
    }

    func testMinuteOfDayRoundTrip() {
        let zeit = TimeOfDay(hour: 14, minute: 5)!
        XCTAssertEqual(zeit.minuteOfDay, 845)
        XCTAssertEqual(TimeOfDay(minuteOfDay: 845), zeit)
        XCTAssertEqual(zeit.hour, 14)
        XCTAssertEqual(zeit.minute, 5)
        XCTAssertEqual(zeit.description, "14:05")
        XCTAssertNil(TimeOfDay(minuteOfDay: 1_440), "Ein Tag hat 1440 Minuten, 0 bis 1439")
        XCTAssertNil(TimeOfDay(minuteOfDay: -1))
    }

    func testOrdering() {
        XCTAssertTrue(TimeOfDay(hour: 7, minute: 30)! < TimeOfDay(hour: 19, minute: 30)!)
        XCTAssertTrue(TimeOfDay(hour: 7, minute: 30)! < TimeOfDay(hour: 7, minute: 31)!)
        XCTAssertEqual(TimeOfDay(hour: 0, minute: 0)!.minuteOfDay, 0)
    }

    /// Zeitzone als Pflichtparameter, aus demselben Grund wie bei
    /// ``CalendarDay``: 22:30 UTC ist in Berlin schon der nächste Tag, 0:30.
    func testContainingRespectsTimeZone() {
        let moment = Date(timeIntervalSince1970: 1_785_882_600)  // 2026-08-04 22:30 UTC
        let utc = TimeOfDay.containing(moment, in: TimeZone(identifier: "UTC")!)
        let berlin = TimeOfDay.containing(moment, in: TimeZone(identifier: "Europe/Berlin")!)
        XCTAssertEqual(utc.description, "22:30")
        XCTAssertEqual(berlin.description, "00:30")
        XCTAssertEqual(CalendarDay.containing(moment, in: TimeZone(identifier: "UTC")!).day, 4)
        XCTAssertEqual(CalendarDay.containing(moment, in: TimeZone(identifier: "Europe/Berlin")!).day, 5,
                       "In Berlin ist es dann schon der 5.")
    }

    // MARK: - Reihenfolge der Ablesungen

    func testTimeDecidesWithinTheSameDay() {
        let register = Fixture.electricityRegister()
        let heute = day(2026, 8, 4)
        // Absichtlich gegenläufig: Die abends abgelesene Zahl wurde zuerst
        // erfasst. Ohne Uhrzeit entschiede diese Reihenfolge — mit Uhrzeit nicht.
        let abends = Fixture.reading(register, heute, dec("1200"), sequence: 1,
                                     time: TimeOfDay(hour: 19, minute: 0))
        let morgens = Fixture.reading(register, heute, dec("1100"), sequence: 2,
                                      time: TimeOfDay(hour: 7, minute: 0))
        let sortiert = [abends, morgens].chronological()
        XCTAssertEqual(sortiert.map(\.value), [dec("1100"), dec("1200")],
                       "Die frühere Uhrzeit steht vorn, nicht die frühere Erfassung")
    }

    func testCreatedAtStillDecidesWithoutTimes() {
        let register = Fixture.electricityRegister()
        let heute = day(2026, 8, 4)
        // Der Tag eines Zählerwechsels: zwei Ablesungen, keine mit Uhrzeit.
        let erste = Fixture.reading(register, heute, dec("9990"), sequence: 1)
        let zweite = Fixture.reading(register, heute, dec("0"), sequence: 2)
        XCTAssertEqual([zweite, erste].chronological().map(\.value), [dec("9990"), dec("0")],
                       "Ohne Uhrzeit bleibt es beim Erfassungszeitpunkt")
    }

    func testMixedTimesFallBackToCreatedAt() {
        let register = Fixture.electricityRegister()
        let heute = day(2026, 8, 4)
        // Eine mit, eine ohne Uhrzeit: Die Uhrzeit der einen gegen die Erfassung
        // der anderen zu stellen wäre ein Vergleich zweier verschiedener Dinge.
        let ohne = Fixture.reading(register, heute, dec("1100"), sequence: 1)
        let mit = Fixture.reading(register, heute, dec("1200"), sequence: 2,
                                  time: TimeOfDay(hour: 3, minute: 0))
        XCTAssertEqual([mit, ohne].chronological().map(\.value), [dec("1100"), dec("1200")],
                       "Der Erfassungszeitpunkt ist das Einzige, was beide haben")
    }

    func testDayBeatsTime() {
        let register = Fixture.electricityRegister()
        let spaetAmVortag = Fixture.reading(register, day(2026, 8, 3), dec("1000"), sequence: 2,
                                           time: TimeOfDay(hour: 23, minute: 30))
        let fruehHeute = Fixture.reading(register, day(2026, 8, 4), dec("1010"), sequence: 1,
                                        time: TimeOfDay(hour: 6, minute: 0))
        XCTAssertEqual([fruehHeute, spaetAmVortag].chronological().map(\.value),
                       [dec("1000"), dec("1010")],
                       "Der Tag entscheidet vor der Uhrzeit")
    }

    /// Die Spalte steht nur da, wenn sie etwas zu sagen hat — und dann in der
    /// richtigen Reihenfolge.
    func testExportShowsTheTimeOnlyWhenThereIsOne() {
        let register = Fixture.electricityRegister()
        let ohne = [Fixture.reading(register, day(2026, 8, 3), dec("1000"))]
        let ohneKopf = TableExport.readings(ohne, register: register, meterName: "Strom")
            .split(separator: "\r\n")[0]
        XCTAssertFalse(ohneKopf.contains("Uhrzeit"),
                       "Ohne eine einzige Uhrzeit bleibt die Spalte weg")

        let mit = [
            Fixture.reading(register, day(2026, 8, 4), dec("1025"), sequence: 1,
                            time: TimeOfDay(hour: 19, minute: 0)),
            Fixture.reading(register, day(2026, 8, 4), dec("1010"), sequence: 2,
                            time: TimeOfDay(hour: 7, minute: 0))
        ]
        let zeilen = TableExport.readings(mit, register: register, meterName: "Strom")
            .split(separator: "\r\n").map(String.init)
        XCTAssertTrue(zeilen[0].contains("Datum;Uhrzeit;Stand"))
        XCTAssertTrue(zeilen[1].contains(";07:00;"), "Die frühere Uhrzeit steht in der ersten Zeile")
        XCTAssertTrue(zeilen[2].contains(";19:00;"))
    }

    /// Zwei Ablesungen an einem Tag tragen **beide** zum Verbrauch bei — die
    /// Uhrzeit ordnet sie, sie verwirft nichts. Genau das war die Frage hinter
    /// dem Wunsch nach mehreren Einträgen am Tag.
    func testBothReadingsOfADayCount() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 8, 3), dec("1000"), sequence: 0),
            Fixture.reading(register, day(2026, 8, 4), dec("1010"), sequence: 1,
                            time: TimeOfDay(hour: 7, minute: 0)),
            Fixture.reading(register, day(2026, 8, 4), dec("1025"), sequence: 2,
                            time: TimeOfDay(hour: 19, minute: 0))
        ]
        let series = ConsumptionSeries.build(register: register, readings: readings)
        XCTAssertEqual(series?.totalConsumption.value, dec("25"),
                       "10 kWh morgens und 15 kWh abends sind 25 kWh, nicht 10 oder 15")
    }
}
