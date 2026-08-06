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

    /// Bei einem Zweirichtungszähler bekommt jedes Zählwerk seine eigene
    /// Hochrechnung.
    ///
    /// Der Fall, der die Fehlerklasse aus CLAUDE.md in neuem Gewand zeigt:
    /// Vorher wurde der Arbeitspreis der ganzen Messstelle — Bezug **minus**
    /// Einspeisevergütung — mit dem Faktor des ersten Zählwerks skaliert. Das
    /// ist nur richtig, wenn beide Zählwerke denselben Ausschnitt abdecken.
    ///
    /// Hier reicht der Bezug bis zum 1. Juli, die Einspeisung nur bis zum
    /// 1. April — jemand hat die zweite Zahl einmal vergessen. Der Bezug
    /// rechnet sich also mit 365/181 hoch, die Einspeisung mit 365/90.
    ///
    /// - Bezug: 900 kWh in 181 Tagen → 1814,92 kWh im Jahr × 0,30 € = 544,48 €
    /// - Einspeisung: 300 kWh in 90 Tagen → 1216,67 kWh im Jahr × 0,10 € = 121,67 €
    /// - Erwartet: 544,48 − 121,67 = **422,81 €**
    ///
    /// Die alte Rechnung kam auf 483,98 € — sie nahm die 240 € Nettokosten
    /// bis Juli und multiplizierte sie mit dem Faktor des Bezugs. Einundsechzig
    /// Euro daneben, und im Winter wäre der Abstand größer: Dann steht die
    /// Einspeisung des ganzen Sommers noch aus.
    func testOutlookProjectsEachRegisterWithItsOwnShape() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [draw, feedIn])
        let readings = [
            Fixture.reading(draw, day(2026, 1, 1), 0),
            Fixture.reading(draw, day(2026, 7, 1), 900),
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2026, 4, 1), 300)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour,
                            feedInPricePerUnit: dec("0.10"))
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 50)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 7, 1)
        )

        assertClose(outlook?.projectedCost.amount ?? 0, 422.81, accuracy: 0.02)
        assertClose(outlook?.totalPrepayment.amount ?? 0, 600, accuracy: 0.01)
        assertClose(outlook?.balance.amount ?? 0, 177.19, accuracy: 0.02)
        XCTAssertEqual(outlook?.expectsRefund, true)
    }

    /// Die Einspeisung mindert die Vorschau tatsächlich.
    ///
    /// Ohne diese Prüfung könnte die Gegenrichtung stillschweigend wegfallen —
    /// die Zahl sähe plausibel aus und wäre um die ganze Vergütung zu hoch.
    func testFeedInLowersTheOutlook() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let readings = [
            Fixture.reading(draw, day(2026, 1, 1), 0),
            Fixture.reading(draw, day(2026, 7, 1), 900),
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2026, 7, 1), 600)
        ]

        func projected(_ registers: [Register], feedInPrice: Decimal?) throws -> Decimal {
            let point = Fixture.meteringPoint(registers: registers)
            let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                                pricePerUnit: dec("0.30"), billingUnit: .kilowattHour,
                                feedInPricePerUnit: feedInPrice)
            let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                       monthlyPrepayment: 50)
            let outlook = try ForecastEngine.prepaymentOutlook(
                meteringPoint: point, readings: readings, tariffs: [tariff],
                period: period, today: day(2026, 7, 1))
            return outlook?.projectedCost.amount ?? 0
        }

        let withoutFeedIn = try projected([draw], feedInPrice: nil)
        let withFeedIn = try projected([draw, feedIn], feedInPrice: dec("0.10"))
        XCTAssertLessThan(withFeedIn, withoutFeedIn,
                          "Die Einspeisung muss die erwarteten Kosten senken")
        // 600 kWh in 181 Tagen → 1209,94 kWh × 0,10 € = 120,99 € Gutschrift.
        assertClose(withoutFeedIn - withFeedIn, 120.99, accuracy: 0.02)
    }
}
