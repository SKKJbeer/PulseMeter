import XCTest
@testable import PulseCore

/// Der Abrechnungszeitraum eines Versorgers beginnt fast nie am 1. Januar.
/// Wer die Jahresabrechnung gegen ein Kalenderjahr prüft, vergleicht zwei
/// verschiedene Zeiträume — dieselbe Fehlerklasse wie überall in diesem Projekt.
final class BillingCycleTests: XCTestCase {

    private let gas = BillingCycle(anchorMonth: 10, anchorDay: 1)!       // Oktober
    private let power = BillingCycle(anchorMonth: 4, anchorDay: 1)!      // April

    func testRejectsImpossibleAnchors() {
        XCTAssertNil(BillingCycle(anchorMonth: 0, anchorDay: 1))
        XCTAssertNil(BillingCycle(anchorMonth: 13, anchorDay: 1))
        XCTAssertNil(BillingCycle(anchorMonth: 1, anchorDay: 0))
        XCTAssertNil(BillingCycle(anchorMonth: 1, anchorDay: 32))
    }

    /// Ein Stichtag am 31. existiert im Februar nicht. Ohne Begrenzung gäbe es
    /// Jahre ganz ohne Stichtag — und damit Zeiträume ohne Anfang.
    func testAnchorIsClampedToMonthLength() {
        let endOfMonth = BillingCycle(anchorMonth: 2, anchorDay: 31)!
        XCTAssertEqual(endOfMonth.anchor(in: 2025), day(2025, 2, 28))
        XCTAssertEqual(endOfMonth.anchor(in: 2024), day(2024, 2, 29), "2024 ist ein Schaltjahr")

        let mid = BillingCycle(anchorMonth: 6, anchorDay: 15)!
        XCTAssertEqual(mid.anchor(in: 2026), day(2026, 6, 15))
    }

    func testPeriodStartLooksBackwards() {
        // Vor dem Stichtag gehört der Tag noch zum Zeitraum des Vorjahres.
        XCTAssertEqual(gas.periodStart(onOrBefore: day(2026, 8, 4)), day(2025, 10, 1))
        // Am Stichtag beginnt der neue Zeitraum.
        XCTAssertEqual(gas.periodStart(onOrBefore: day(2026, 10, 1)), day(2026, 10, 1))
        XCTAssertEqual(gas.periodStart(onOrBefore: day(2026, 11, 15)), day(2026, 10, 1))
    }

    func testPeriodRunsFromAnchorToAnchor() {
        let period = gas.period(containing: day(2026, 8, 4))
        XCTAssertEqual(period.start, day(2025, 10, 1))
        XCTAssertEqual(period.end, day(2026, 10, 1))
        XCTAssertEqual(period.spanInDays, 365)
    }

    /// Der Zählerstand am Stichtag gehört beiden Zeiträumen an — dem alten als
    /// Endstand, dem neuen als Anfangsstand. Sonst fehlt ein Tag Verbrauch.
    func testAdjacentPeriodsShareTheirBoundary() {
        let completed = gas.completedPeriod(before: day(2026, 8, 4))
        let current = gas.period(containing: day(2026, 8, 4))
        XCTAssertEqual(completed.end, current.start)
        XCTAssertEqual(completed.start, day(2024, 10, 1))
        XCTAssertEqual(completed.end, day(2025, 10, 1))
    }

    func testRunningPeriodStopsAtGivenDay() {
        let running = gas.runningPeriod(on: day(2026, 8, 4))
        XCTAssertEqual(running?.start, day(2025, 10, 1))
        XCTAssertEqual(running?.end, day(2026, 8, 4))
        XCTAssertEqual(running?.spanInDays, 307)
    }

    func testRunningPeriodIsEmptyOnTheAnchorItself() {
        XCTAssertNil(gas.runningPeriod(on: day(2026, 10, 1)),
                     "Am Stichtag ist noch kein Tag des neuen Zeitraums vergangen")
    }

    func testLeapDayLengthensTheBillingYear() {
        XCTAssertEqual(power.period(containing: day(2023, 6, 1)).spanInDays, 366, "enthält den 29.02.2024")
        XCTAssertEqual(power.period(containing: day(2024, 6, 1)).spanInDays, 365)
    }

    // MARK: - Zusammenspiel mit dem Rechenkern

    /// Der Fall, für den es das alles gibt: Zwei aufeinanderfolgende
    /// Abrechnungsjahre eines Gaszählers vergleichen — nicht zwei Kalenderjahre.
    func testConsumptionOverBillingYearsIsComparable() {
        let register = Fixture.gasRegister()
        let monthly: [Decimal] = [418, 376, 298, 178, 92, 41, 36, 39, 84, 192, 308, 402]
        var readings: [Reading] = []
        var value = Decimal(1000)
        var sequence = 0
        for year in 2023...2026 {
            for month in 1...12 {
                readings.append(Fixture.reading(register, day(year, month, 1), value, sequence: sequence))
                value += monthly[month - 1]
                sequence += 1
            }
        }

        let point = MeteringPoint(
            propertyID: Fixture.property.id, name: "Gas", kind: .gas,
            registers: [register], billingCycle: gas
        )
        let today = day(2026, 8, 4)

        guard let completed = point.lastCompletedBillingPeriod(before: today),
              let running = point.runningBillingPeriod(on: today)
        else { return XCTFail("Abrechnungszeiträume fehlen") }

        let a = ConsumptionEngine.consumption(register: register, readings: readings, in: completed)
        XCTAssertTrue(a.isComplete)
        // Ein volles Jahr Verbrauch, unabhängig davon, wo es im Kalender liegt.
        XCTAssertEqual(a.quantity.value, monthly.reduce(0, +))

        let b = ConsumptionEngine.consumption(register: register, readings: readings, in: running)
        XCTAssertTrue(b.isComplete)
        XCTAssertLessThan(b.quantity.value, a.quantity.value, "Der laufende Zeitraum ist kürzer")

        // Der laufende Zeitraum darf nur gegen denselben Ausschnitt des
        // Vorjahres gestellt werden, nie gegen ein volles Abrechnungsjahr.
        guard let priorSameWindow = DayRange(start: running.start.oneYearEarlier,
                                             end: running.end.oneYearEarlier) else {
            return XCTFail("Vorjahresfenster fehlt")
        }
        let c = ConsumptionEngine.consumption(register: register, readings: readings, in: priorSameWindow)
        XCTAssertEqual(c.coveredDays, b.coveredDays, "Gleich lange Fenster, sonst ist der Vergleich wertlos")
    }
}
