import XCTest
@testable import PulseCore

/// 1.7: neuer Preis ab einem Tag, Gas und Heizöl in kWh.
///
/// Die Fälle aus dem Testplan in `docs/konzepte/1.7-preis-ab-tag-und-kwh.md`.
/// Dieselben Wege prüft der Klick-Dummy im Abschnitt „1.7“ von
/// `check-prototype.mjs`; weichen beide ab, ist das ein Fehler (Regel 2).
final class TariffHistoryTests: XCTestCase {

    private let year2026 = span(day(2026, 1, 1), day(2027, 1, 1))

    private func firstTariff(_ point: MeteringPoint, price: String = "0.30",
                             base: Decimal = 12) -> Tariff {
        Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
               pricePerUnit: dec(price), monthlyBasePrice: base, billingUnit: .kilowattHour)
    }

    // MARK: - Neuer Preis

    func testNewPriceClosesOldOneOnPreviousDay() throws {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let old = firstTariff(point)

        let result = try TariffHistory.startingNewPrice(
            on: day(2026, 9, 1), tariffs: [old], meteringPointID: point.id
        ) { $0.pricePerUnit = dec("0.40") }

        XCTAssertEqual(result.count, 2, "Kein Tarif wird überschrieben")
        let closed = try XCTUnwrap(result.first { $0.id == old.id })
        XCTAssertEqual(closed.validTo, day(2026, 8, 31))
        XCTAssertEqual(closed.pricePerUnit, dec("0.30"), "Der alte Preis bleibt")
        let fresh = try XCTUnwrap(result.first { $0.id != old.id })
        XCTAssertEqual(fresh.validFrom, day(2026, 9, 1))
        XCTAssertNil(fresh.validTo)
        XCTAssertEqual(fresh.pricePerUnit, dec("0.40"))
        XCTAssertEqual(fresh.monthlyBasePrice, 12, "Was nicht geändert wird, kommt mit")
    }

    /// Beim Doppeltarif schließt ein neuer Preis beide, und jeder neue Tarif
    /// behält sein Zählwerk und den Grundpreis nur am ersten.
    func testDoubleTariffClosesBoth() throws {
        let high = Fixture.electricityRegister(), low = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [high, low])
        let tHigh = Tariff(meteringPointID: point.id, registerID: high.id, validFrom: day(2026, 1, 1),
                           pricePerUnit: dec("0.31"), monthlyBasePrice: dec("8.90"),
                           billingUnit: .kilowattHour)
        let tLow = Tariff(meteringPointID: point.id, registerID: low.id, validFrom: day(2026, 1, 1),
                          pricePerUnit: dec("0.21"), billingUnit: .kilowattHour)

        let result = try TariffHistory.startingNewPrice(
            on: day(2026, 6, 1), tariffs: [tHigh, tLow], meteringPointID: point.id
        ) { tariff in
            if tariff.registerID == low.id { tariff.pricePerUnit = dec("0.24") }
            tariff.registerID = nil   // darf der Aufrufer nicht ändern
        }

        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.filter { $0.validTo == day(2026, 5, 31) }.count, 2)
        let generations = TariffHistory.generations(of: result, meteringPointID: point.id)
        XCTAssertEqual(generations.count, 2)
        XCTAssertEqual(generations[0].validFrom, day(2026, 6, 1))
        XCTAssertNil(generations[0].validTo)
        XCTAssertEqual(generations[1].validTo, day(2026, 5, 31))
        XCTAssertEqual(generations[0].tariff(for: low.id)?.pricePerUnit, dec("0.24"))
        XCTAssertEqual(generations[0].tariff(for: high.id)?.pricePerUnit, dec("0.31"))
        XCTAssertEqual(generations[0].tariff(for: high.id)?.monthlyBasePrice, dec("8.90"))
        XCTAssertEqual(generations[0].tariff(for: low.id)?.monthlyBasePrice, 0)
    }

    func testDayNotAfterNewestStartIsRejected() throws {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let tariffs = try TariffHistory.startingNewPrice(
            on: day(2026, 3, 1), tariffs: [firstTariff(point)], meteringPointID: point.id)

        XCTAssertThrowsError(try TariffHistory.startingNewPrice(
            on: day(2026, 3, 1), tariffs: tariffs, meteringPointID: point.id)) { error in
            XCTAssertEqual(error as? TariffHistory.HistoryError, .notAfterNewestStart(day(2026, 3, 1)))
        }
        XCTAssertThrowsError(try TariffHistory.startingNewPrice(
            on: day(2026, 2, 1), tariffs: tariffs, meteringPointID: point.id))
        XCTAssertThrowsError(try TariffHistory.startingNewPrice(
            on: day(2026, 3, 1), tariffs: [], meteringPointID: point.id)) { error in
            XCTAssertEqual(error as? TariffHistory.HistoryError, .noTariff)
        }
    }

    /// Die angekündigte Erhöhung zum 1. Januar ist der häufigste Fall.
    func testFutureDayIsAllowed() throws {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let result = try TariffHistory.startingNewPrice(
            on: day(2027, 1, 1), tariffs: [firstTariff(point)], meteringPointID: point.id)
        XCTAssertEqual(TariffHistory.generations(of: result, meteringPointID: point.id)
            .map(\.validFrom), [day(2027, 1, 1), day(2026, 1, 1)])
    }

    /// Tarife anderer Zähler kommen unverändert mit zurück.
    func testOtherMetersAreUntouched() throws {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let other = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let foreign = firstTariff(other)
        let result = try TariffHistory.startingNewPrice(
            on: day(2026, 5, 1), tariffs: [firstTariff(point), foreign], meteringPointID: point.id)
        XCTAssertEqual(result.first { $0.id == foreign.id }, foreign)
    }

    // MARK: - Jüngsten löschen

    func testRemovingNewestReopensPrevious() throws {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let first = firstTariff(point)
        let two = try TariffHistory.startingNewPrice(
            on: day(2026, 9, 1), tariffs: [first], meteringPointID: point.id)
        let three = try TariffHistory.startingNewPrice(
            on: day(2027, 1, 1), tariffs: two, meteringPointID: point.id)

        let back = try TariffHistory.removingNewest(tariffs: three, meteringPointID: point.id)
        let generations = TariffHistory.generations(of: back, meteringPointID: point.id)
        XCTAssertEqual(generations.map(\.validFrom), [day(2026, 9, 1), day(2026, 1, 1)])
        XCTAssertNil(generations[0].validTo, "Der vorige gilt wieder offen")
        XCTAssertEqual(generations[1].validTo, day(2026, 8, 31), "Ältere bleiben, wie sie sind")

        let one = try TariffHistory.removingNewest(tariffs: back, meteringPointID: point.id)
        XCTAssertEqual(one, [first])
        XCTAssertThrowsError(try TariffHistory.removingNewest(tariffs: one, meteringPointID: point.id)) {
            XCTAssertEqual($0 as? TariffHistory.HistoryError, .onlyOnePrice)
        }
    }

    // MARK: - Kosten über die Grenze

    /// Abschnitt alt plus Abschnitt neu, Grundpreis tagesgenau. Die Kosten vor
    /// dem neuen Preis bleiben genau, wie sie waren.
    func testCostAcrossBoundary() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 3, 1), 590),    // 10 kWh je Tag
            Fixture.reading(register, day(2026, 5, 1), 1200)
        ]
        let before = try CostEngine.cost(meteringPoint: point, readings: readings,
                                         tariffs: [firstTariff(point)],
                                         in: span(day(2026, 1, 1), day(2026, 3, 1)))
        let tariffs = try TariffHistory.startingNewPrice(
            on: day(2026, 3, 1), tariffs: [firstTariff(point)], meteringPointID: point.id
        ) { $0.pricePerUnit = dec("0.40") }

        let earlier = try XCTUnwrap(CostEngine.cost(meteringPoint: point, readings: readings,
                                                    tariffs: tariffs,
                                                    in: span(day(2026, 1, 1), day(2026, 3, 1))))
        // Gleicher Betrag, nicht nur ähnlich: Wer den Preis ändert, ändert die
        // Vergangenheit nicht mehr.
        XCTAssertEqual(earlier.total.amount, try XCTUnwrap(before).total.amount)

        let whole = try XCTUnwrap(CostEngine.cost(meteringPoint: point, readings: readings,
                                                  tariffs: tariffs,
                                                  in: span(day(2026, 1, 1), day(2026, 5, 1))))
        // 590 kWh × 0,30 + 610 kWh × 0,40 + 12 € × 12 / 365 × 120 Tage
        let expected: Double = 590 * 0.30 + 610 * 0.40 + 144.0 / 365.0 * 120.0
        assertClose(whole.total.amount, expected, accuracy: 0.001)
        XCTAssertEqual(whole.segments.count, 2)
    }

    // MARK: - Hochrechnung

    /// Eine angekündigte Erhöhung steckt in der Hochrechnung, bevor der erste
    /// Tag mit dem neuen Preis gemessen ist. Bis 0.146 skalierte die App die
    /// bisherigen Kosten hoch und rechnete das ganze Jahr zum alten Preis.
    func testPrepaymentOutlookPricesRemainderWithFuturePrice() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .water)  // ohne Jahresform: nach Tagen
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 7, 1), 1810)    // 181 Tage, 10 kWh je Tag
        ]
        let period = BillingPeriod(meteringPointID: point.id, range: year2026, monthlyPrepayment: 100)
        let one = firstTariff(point, base: 0)
        let two = try TariffHistory.startingNewPrice(
            on: day(2026, 10, 1), tariffs: [one], meteringPointID: point.id
        ) { $0.pricePerUnit = dec("0.50") }

        let plain = try XCTUnwrap(ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [one], period: period, today: day(2026, 7, 1)))
        let split = try XCTUnwrap(ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: two, period: period, today: day(2026, 7, 1)))

        // Mit einem Preis unverändert: 3650 kWh × 0,30 €.
        assertClose(plain.projectedCost.amount, 1095, accuracy: 0.01)
        // Mit zweien: 1810 gemessen × 0,30, dann 92 Tage Juli bis September
        // × 10 × 0,30, dann 92 Tage Oktober bis Dezember × 10 × 0,50.
        let expected: Double = 1810 * 0.30 + 920 * 0.30 + 920 * 0.50
        assertClose(split.projectedCost.amount, expected, accuracy: 0.01)
    }

    /// Ein Grundpreis, der sich mit dem neuen Preis ändert, zählt je Abschnitt.
    func testPrepaymentOutlookSplitsBasePrice() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .water)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 7, 1), 1810)
        ]
        let period = BillingPeriod(meteringPointID: point.id, range: year2026, monthlyPrepayment: 100)
        let tariffs = try TariffHistory.startingNewPrice(
            on: day(2026, 10, 1), tariffs: [firstTariff(point, base: 10)], meteringPointID: point.id
        ) { $0.monthlyBasePrice = 20 }

        let outlook = try XCTUnwrap(ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: tariffs, period: period, today: day(2026, 7, 1)))
        // 273 Tage × 120 € / 365 + 92 Tage × 240 € / 365
        let expected: Double = 273.0 * 120.0 / 365.0 + 92.0 * 240.0 / 365.0
        assertClose(outlook.breakdown.standingCost.amount, expected, accuracy: 0.01)
    }

    // MARK: - kWh

    func testGasCubicMetresInKilowattHours() throws {
        let register = Fixture.gasRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .gas)
        let conversion = GasConversion(stateNumber: dec("0.95"), calorificValue: dec("11"))
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1), pricePerUnit: dec("0.11"),
                            billingUnit: .kilowattHour, gasConversion: conversion)
        let readings = [Fixture.reading(register, day(2026, 1, 1), 100),
                        Fixture.reading(register, day(2026, 3, 1), 350)]

        let kwh = EnergyDisplay.kilowattHours(register: register, readings: readings, tariffs: [tariff],
                                              in: span(day(2026, 1, 1), day(2026, 3, 1)))
        assertClose(try XCTUnwrap(kwh).value, 250 * 0.95 * 11)
        XCTAssertFalse(EnergyDisplay.isEstimate(unit: .cubicMetre))
    }

    /// Ändert sich der Brennwert mit einem neuen Preis, rechnet jeder
    /// Abschnitt mit seinem.
    func testGasUsesConversionOfEachSegment() throws {
        let register = Fixture.gasRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .gas)
        let first = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1), pricePerUnit: dec("0.11"),
                           billingUnit: .kilowattHour,
                           gasConversion: GasConversion(stateNumber: 1, calorificValue: 10))
        let tariffs = try TariffHistory.startingNewPrice(
            on: day(2026, 2, 1), tariffs: [first], meteringPointID: point.id
        ) { $0.gasConversion = GasConversion(stateNumber: 1, calorificValue: 12) }
        let readings = [Fixture.reading(register, day(2026, 1, 1), 0),
                        Fixture.reading(register, day(2026, 2, 1), 100),
                        Fixture.reading(register, day(2026, 3, 1), 300)]

        let kwh = EnergyDisplay.kilowattHours(register: register, readings: readings, tariffs: tariffs,
                                              in: span(day(2026, 1, 1), day(2026, 3, 1)))
        assertClose(try XCTUnwrap(kwh).value, 100 * 10 + 200 * 12)
    }

    func testHeatingOilLitresInKilowattHoursWithoutChangingCost() throws {
        let register = Register(unit: .litre, integerDigits: 6, fractionDigits: 0)
        let point = Fixture.meteringPoint(registers: [register], kind: .heatingOil)
        let conversion = EnergyDisplay.heatingOilConversion(
            kWhPerLitre: EnergyDisplay.typicalHeatingOilKWhPerLitre)
        XCTAssertEqual(EnergyDisplay.kWhPerLitre(conversion), 10)
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1), pricePerUnit: dec("1.05"),
                            billingUnit: .litre, gasConversion: conversion)
        let readings = [Fixture.reading(register, day(2026, 1, 2), 12000),
                        Fixture.reading(register, day(2026, 7, 1), 13450)]
        let range = span(day(2026, 1, 2), day(2026, 7, 1))

        let kwh = EnergyDisplay.kilowattHours(register: register, readings: readings, tariffs: [tariff], in: range)
        assertClose(try XCTUnwrap(kwh).value, 14500)
        XCTAssertTrue(EnergyDisplay.isEstimate(unit: .litre))

        // Abgerechnet wird weiter in Litern: Die Umrechnung greift nur über
        // Dimensionen hinweg, und Liter gegen Liter ist dieselbe.
        let cost = try CostEngine.cost(register: register, readings: readings, tariffs: [tariff], in: range)
        assertClose(cost.total.amount, 1450 * 1.05)
    }

    func testNoConversionGivesNil() {
        let register = Fixture.gasRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .gas)
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1), pricePerUnit: dec("1"),
                            billingUnit: .cubicMetre)
        let readings = [Fixture.reading(register, day(2026, 1, 1), 0),
                        Fixture.reading(register, day(2026, 2, 1), 10)]
        XCTAssertNil(EnergyDisplay.kilowattHours(register: register, readings: readings, tariffs: [tariff],
                                                 in: span(day(2026, 1, 1), day(2026, 2, 1))))
        XCTAssertNil(EnergyDisplay.kilowattHours(for: Quantity(10, .kilowattHour), tariff: tariff),
                     "Strom ist schon kWh")
    }
}
