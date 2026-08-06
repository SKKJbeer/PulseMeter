import XCTest
@testable import PulseCore

final class ForecastEngineTests: XCTestCase {

    // Halboffen bis zum 1. Januar des Folgejahres — so, wie `BillingCycle`
    // einen Abrechnungszeitraum liefert und wie jede Verbrauchsrechnung im
    // Projekt einen Zeitraum versteht.
    private let year2026 = span(day(2026, 1, 1), day(2027, 1, 1))

    func testLinearProjectionWithoutHistory() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900)     // 90 Tage, 10 kWh je Tag
        ]

        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2026, 4, 1)
        )

        XCTAssertEqual(forecast?.method, .linear)
        XCTAssertEqual(forecast?.daysElapsed, 90)
        XCTAssertEqual(forecast?.daysRemaining, 275)
        assertClose(forecast?.projected.value ?? 0, 3650)   // 365 Tage × 10 kWh
        XCTAssertEqual(forecast?.confidence, .estimated, "Eine Hochrechnung ist nie gemessen")
    }

    /// Bei Gas und Heizung ist die lineare Hochrechnung im Winter grob falsch.
    /// Liegt das Vorjahr vollständig vor, wird dessen Verlauf als Muster genutzt.
    func testSeasonalProjectionUsesPreviousYearShape() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 1, 1), 0),
            Fixture.reading(register, day(2025, 4, 1), 1200),   // 40 % des Vorjahres
            Fixture.reading(register, day(2025, 12, 31), 3000),
            Fixture.reading(register, day(2026, 1, 1), 3000),
            Fixture.reading(register, day(2026, 4, 1), 4000)    // 1000 kWh bisher
        ]

        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2026, 4, 1)
        )

        XCTAssertEqual(forecast?.method, .seasonal)
        // 1000 kWh entsprechen 40 % → 2500 kWh erwartet,
        // deutlich unter der linearen Schätzung von rund 4040 kWh.
        assertClose(forecast?.projected.value ?? 0, 2500, accuracy: 0.01)
    }

    /// Ein veralteter Zählerstand darf die Prognose nicht drücken: Die Tage
    /// zwischen letzter Ablesung und heute gehören zur Restzeit, nicht zum
    /// gemessenen Zeitraum. Sonst sagt die App ausgerechnet dem Nutzer, der
    /// länger nicht abgelesen hat, einen zu niedrigen Verbrauch voraus.
    func testStaleReadingDoesNotDepressProjection() {
        let register = Fixture.electricityRegister()
        let upToDate = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900)      // 90 Tage, 10 kWh/Tag
        ]
        let stale = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 3, 1), 590)      // 59 Tage, 10 kWh/Tag
        ]

        let fresh = ForecastEngine.forecast(register: register, readings: upToDate,
                                            period: year2026, today: day(2026, 4, 1))
        let old = ForecastEngine.forecast(register: register, readings: stale,
                                          period: year2026, today: day(2026, 4, 1))

        XCTAssertEqual(old?.daysElapsed, 59)
        XCTAssertEqual(old?.daysRemaining, 306, "Die 31 Tage seit der letzten Ablesung zählen zur Restzeit")
        assertClose(old?.projected.value ?? 0, 3650)   // 365 Tage × 10 kWh
        XCTAssertEqual(approx(old?.projected.value ?? 0), approx(fresh?.projected.value ?? 0),
                       accuracy: 0.01, "Gleicher Tagesverbrauch, gleiche Prognose")
    }

    func testCompletedPeriodIsNotProjected() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            // Auf der Grenze, nicht einen Tag davor: Die Jahresablesung
            // gehört auf den Stichtag, sonst bleibt ein Tag ungedeckt und die
            // Reihe rechnet ihn zu Recht hoch.
            Fixture.reading(register, day(2027, 1, 1), 3000)
        ]

        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2027, 1, 15)
        )

        XCTAssertEqual(forecast?.daysRemaining, 0)
        XCTAssertEqual(forecast?.projected.value, 3000)
    }

    func testNoForecastWithoutReadings() {
        let register = Fixture.electricityRegister()
        XCTAssertNil(ForecastEngine.forecast(
            register: register, readings: [], period: year2026, today: day(2026, 4, 1)))
    }

    // MARK: - Abschlagsvergleich

    /// Die Aussage, für die das Produkt existiert.
    func testPrepaymentOutlookPredictsRefund() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 100)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 4, 1)
        )

        XCTAssertNotNil(outlook)
        // Hochrechnung 3650 kWh × 0,30 € = 1095 €, Abschläge 12 × 100 € = 1200 €
        assertClose(outlook?.totalPrepayment.amount ?? 0, 1200, accuracy: 0.01)
        assertClose(outlook?.projectedCost.amount ?? 0, 1095, accuracy: 0.01)
        assertClose(outlook?.balance.amount ?? 0, 105, accuracy: 0.01)
        XCTAssertEqual(outlook?.expectsRefund, true)
    }

    func testPrepaymentOutlookPredictsAdditionalPayment() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 1800)   // doppelter Verbrauch
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 100)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 4, 1)
        )

        XCTAssertEqual(outlook?.expectsRefund, false)
        assertClose(outlook?.balance.amount ?? 0, -990, accuracy: 0.01)   // 2 × 3650 × 0,30 = 2190
    }

    func testNoOutlookWithoutPrepayment() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026)

        XCTAssertNil(try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: [], tariffs: [tariff],
            period: period, today: day(2026, 4, 1)
        ))
    }

    func testBillingPeriodLengthIsFractional() {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let full = BillingPeriod(meteringPointID: point.id, range: year2026)
        assertClose(full.lengthInMonths, 12, accuracy: 0.01)

        let half = BillingPeriod(
            meteringPointID: point.id,
            range: span(day(2026, 1, 1), day(2026, 7, 1))
        )
        assertClose(half.lengthInMonths, 5.95, accuracy: 0.05)
    }
}
