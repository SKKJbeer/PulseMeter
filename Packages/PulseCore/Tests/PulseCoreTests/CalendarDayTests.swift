import XCTest
@testable import PulseCore

final class CalendarDayTests: XCTestCase {

    func testRejectsImpossibleDates() {
        XCTAssertNil(CalendarDay(year: 2026, month: 2, day: 29), "2026 ist kein Schaltjahr")
        XCTAssertNil(CalendarDay(year: 2026, month: 13, day: 1))
        XCTAssertNil(CalendarDay(year: 2026, month: 4, day: 31))
        XCTAssertNil(CalendarDay(year: 2026, month: 1, day: 0))
        XCTAssertNotNil(CalendarDay(year: 2024, month: 2, day: 29), "2024 ist ein Schaltjahr")
    }

    func testRawValueEncoding() {
        let value = day(2026, 8, 4)
        XCTAssertEqual(value.rawValue, 20_260_804)
        XCTAssertEqual(value.year, 2026)
        XCTAssertEqual(value.month, 8)
        XCTAssertEqual(value.day, 4)
        XCTAssertEqual(value.description, "2026-08-04")
    }

    func testSerialNumberRoundTrip() {
        let samples = [
            day(1970, 1, 1), day(1999, 12, 31), day(2000, 3, 1),
            day(2024, 2, 29), day(2026, 8, 4), day(2100, 12, 31)
        ]
        for sample in samples {
            XCTAssertEqual(CalendarDay(serialNumber: sample.serialNumber), sample)
        }
    }

    func testDayArithmeticAcrossBoundaries() {
        XCTAssertEqual(day(2026, 1, 1).days(since: day(2025, 12, 31)), 1)
        XCTAssertEqual(day(2025, 3, 1).days(since: day(2025, 2, 28)), 1, "2025 ohne Schalttag")
        XCTAssertEqual(day(2024, 3, 1).days(since: day(2024, 2, 28)), 2, "2024 mit Schalttag")
        XCTAssertEqual(day(2025, 1, 1).days(since: day(2024, 1, 1)), 366, "Schaltjahr 2024")
        XCTAssertEqual(day(2026, 1, 1).days(since: day(2025, 1, 1)), 365)
    }

    func testAddingDays() {
        XCTAssertEqual(day(2026, 1, 31).adding(days: 1), day(2026, 2, 1))
        XCTAssertEqual(day(2024, 2, 28).adding(days: 1), day(2024, 2, 29))
        XCTAssertEqual(day(2026, 12, 31).adding(days: 1), day(2027, 1, 1))
        XCTAssertEqual(day(2026, 1, 1).adding(days: -1), day(2025, 12, 31))
    }

    func testMonthBoundaries() {
        XCTAssertEqual(day(2024, 2, 15).endOfMonth, day(2024, 2, 29))
        XCTAssertEqual(day(2026, 2, 15).endOfMonth, day(2026, 2, 28))
        XCTAssertEqual(day(2026, 8, 4).startOfMonth, day(2026, 8, 1))
    }

    /// Ohne diese Abbildung liefe der Vorjahresvergleich am 29. Februar ins Leere.
    func testLeapDayMapsToPreviousYear() {
        XCTAssertEqual(day(2024, 2, 29).oneYearEarlier, day(2023, 2, 28))
        XCTAssertEqual(day(2026, 3, 1).oneYearEarlier, day(2025, 3, 1))
    }

    func testDayRangeCountsDaysAndSpans() {
        let single = span(day(2026, 1, 1), day(2026, 1, 1))
        XCTAssertEqual(single.dayCount, 1)
        XCTAssertEqual(single.spanInDays, 0, "Zwischen einem Tag und sich selbst vergeht kein Verbrauch")

        let january = span(day(2026, 1, 1), day(2026, 2, 1))
        XCTAssertEqual(january.spanInDays, 31)
        XCTAssertEqual(january.dayCount, 32)

        XCTAssertNil(DayRange(start: day(2026, 2, 1), end: day(2026, 1, 1)))
    }

    func testDayRangeIntersection() {
        let a = span(day(2026, 1, 1), day(2026, 6, 30))
        let b = span(day(2026, 4, 1), day(2026, 12, 31))
        XCTAssertEqual(a.intersection(with: b), span(day(2026, 4, 1), day(2026, 6, 30)))

        let disjoint = span(day(2027, 1, 1), day(2027, 2, 1))
        XCTAssertNil(a.intersection(with: disjoint))
    }

    func testContainingDateRespectsTimeZone() {
        // 2026-08-04 22:30 UTC ist in Berlin (UTC+2) bereits der 5. August.
        let instant = Date(timeIntervalSince1970: 1_785_882_600)
        let utc = CalendarDay.containing(instant, in: TimeZone(identifier: "UTC")!)
        let berlin = CalendarDay.containing(instant, in: TimeZone(identifier: "Europe/Berlin")!)
        XCTAssertEqual(utc, day(2026, 8, 4))
        XCTAssertEqual(berlin, day(2026, 8, 5))
    }
}
