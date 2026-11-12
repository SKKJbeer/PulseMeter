import XCTest
@testable import PulseCore

/// 1.9: vorher und nachher. Gegenstück im Klick-Dummy: Block „1.9" in
/// `scripts/check-prototype.mjs` (Regel 2).
final class HeatingComparisonTests: XCTestCase {

    // Gas eines Jahres, m³ je Monat, Januar zuerst.
    private let gasMonate: [Decimal] = [400, 360, 290, 170, 90, 40, 35, 38, 85, 190, 300, 390]
    // Strom der Wärmepumpe, kWh je Monat.
    private let wpMonate: [Decimal] = [1300, 1150, 900, 520, 260, 120, 110, 115, 250, 560, 900, 1250]

    private let gasRegister = Fixture.gasRegister()
    private let wpRegister = Fixture.electricityRegister()
    private lazy var gas = Fixture.meteringPoint(registers: [gasRegister], kind: .gas)
    private lazy var wp: MeteringPoint = {
        var m = Fixture.meteringPoint(registers: [wpRegister], kind: .electricity)
        m.measuresHeatPump = true
        return m
    }()

    /// Stände am Monatsersten, von `start` an, `months` Monate lang.
    private func monthly(_ register: Register, from start: CalendarDay, months: Int,
                         shape: [Decimal], startValue: Decimal = 1000) -> [Reading] {
        var value = startValue
        var day = start
        var out = [Fixture.reading(register, day, value)]
        for _ in 0..<months {
            value += shape[day.month - 1]
            day = HeatingComparison.addingMonths(1, to: day)
            out.append(Fixture.reading(register, day, value))
        }
        return out
    }

    private func gasTariffs(price: String = "0.11", base: String = "0", from: CalendarDay = day(2020, 1, 1)) -> [Tariff] {
        [Tariff(meteringPointID: gas.id, validFrom: from, pricePerUnit: dec(price),
                monthlyBasePrice: dec(base), billingUnit: .kilowattHour,
                gasConversion: GasConversion(stateNumber: dec("0.95"), calorificValue: dec("11")))]
    }
    private func wpTariffs(base: String = "0") -> [Tariff] {
        [Tariff(meteringPointID: wp.id, validFrom: day(2020, 1, 1), pricePerUnit: dec("0.27"),
                monthlyBasePrice: dec(base), billingUnit: .kilowattHour)]
    }

    private func compared(_ outcome: HeatingComparison.Outcome,
                          file: StaticString = #filePath, line: UInt = #line) throws -> HeatingComparison.Result {
        guard case .compared(let r) = outcome else {
            XCTFail("Kein Vergleich, sondern \(outcome)", file: file, line: line)
            throw XCTSkip()
        }
        return r
    }

    /// **Der Fall „halber Winter gegen ganzen".** Gewechselt am 1. Oktober
    /// 2025, gemessen bis 1. Februar 2026: Oktober bis Januar gegen Oktober
    /// bis Januar ein Jahr früher. Nicht gegen das ganze Vorjahr und nicht
    /// gegen den ganzen Winter davor.
    func testBothSidesDescribeTheSameMonthsOfTheYear() throws {
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2024, 1, 1), months: 21, shape: gasMonate)
            + monthly(wpRegister, from: day(2025, 10, 1), months: 4, shape: wpMonate)
        let r = try compared(HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                       tariffs: gasTariffs() + wpTariffs(), today: day(2026, 2, 3)))

        XCTAssertEqual(r.monthCount, 4)
        XCTAssertEqual(r.after.range, span(day(2025, 10, 1), day(2026, 2, 1)))
        XCTAssertEqual(r.before.range, span(day(2024, 10, 1), day(2025, 2, 1)))
        // Oktober bis Dezember 2024 und Januar 2025: 190 + 300 + 390 + 400.
        assertClose(r.before.quantity.value, 1280)
        assertClose(r.after.quantity.value, 560 + 900 + 1250 + 1300)
    }

    /// Mehr als ein Jahr nach dem Wechsel: das jüngste Jahr, nicht alles, und
    /// gegen die zwölf Monate vor dem Wechsel. „Ein Jahr früher" läge hier
    /// teils schon in der Zeit der Wärmepumpe.
    func testMoreThanAYearKeepsTheLatestTwelveMonths() throws {
        let change = HeatingChange(day: day(2024, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2023, 1, 1), months: 21, shape: gasMonate)
            + monthly(wpRegister, from: day(2024, 10, 1), months: 16, shape: wpMonate)
        let r = try compared(HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                       tariffs: gasTariffs() + wpTariffs(), today: day(2026, 2, 3)))
        XCTAssertEqual(r.monthCount, 12)
        XCTAssertEqual(r.after.range, span(day(2025, 2, 1), day(2026, 2, 1)))
        XCTAssertEqual(r.before.range, span(day(2023, 10, 1), day(2024, 10, 1)))
        assertClose(r.before.quantity.value, approx(gasMonate.reduce(0, +)))
        assertClose(r.after.quantity.value, approx(wpMonate.reduce(0, +)))
    }

    func testNoFullMonthYetSaysWhenThereWillBeANumber() {
        let change = HeatingChange(day: day(2026, 1, 15), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2025, 1, 1), months: 12, shape: gasMonate)
            + [Fixture.reading(wpRegister, day(2026, 1, 15), 100), Fixture.reading(wpRegister, day(2026, 2, 10), 900)]
        let outcome = HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                tariffs: gasTariffs() + wpTariffs(), today: day(2026, 2, 11))
        XCTAssertEqual(outcome, .waiting(firstNumberOn: day(2026, 3, 1)))
    }

    /// Erste Ablesung am 5. Oktober: Der Oktober ist nicht gemessen.
    func testAMonthWithoutAReadingAtItsStartDoesNotCount() throws {
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2024, 1, 1), months: 21, shape: gasMonate)
            + [Fixture.reading(wpRegister, day(2025, 10, 5), 100)]
            + monthly(wpRegister, from: day(2025, 11, 1), months: 2, shape: wpMonate, startValue: 600)
        let r = try compared(HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                       tariffs: gasTariffs() + wpTariffs(), today: day(2026, 1, 2)))
        XCTAssertEqual(r.after.range, span(day(2025, 11, 1), day(2026, 1, 1)))
        XCTAssertEqual(r.before.range, span(day(2024, 11, 1), day(2025, 1, 1)))
    }

    func testHeatIsFuelTimesBoilerEfficiency() throws {
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2024, 1, 1), months: 21, shape: gasMonate)
            + monthly(wpRegister, from: day(2025, 10, 1), months: 4, shape: wpMonate)
        let r = try compared(HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                       tariffs: gasTariffs() + wpTariffs(), today: day(2026, 2, 3)))
        let kwh = 1280 * 0.95 * 11.0
        assertClose(try XCTUnwrap(r.before.kilowattHours).value, kwh, accuracy: 0.01)
        assertClose(try XCTUnwrap(r.heatBefore).value, kwh * 0.9, accuracy: 0.01)
        assertClose(try XCTUnwrap(r.energyDifference).value, 4010 - kwh, accuracy: 0.01)
    }

    /// Ein neuer Gaspreis mitten im Ausschnitt: Jeder Abschnitt kostet, was
    /// dort galt.
    func testAPriceChangeInsideTheWindowIsHonoured() throws {
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2024, 1, 1), months: 21, shape: gasMonate)
            + monthly(wpRegister, from: day(2025, 10, 1), months: 4, shape: wpMonate)
        let tariffs = try TariffHistory.startingNewPrice(on: day(2024, 12, 1), tariffs: gasTariffs(),
                                                         meteringPointID: gas.id) { $0.pricePerUnit = dec("0.15") }
        let r = try compared(HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                       tariffs: tariffs + wpTariffs(), today: day(2026, 2, 3)))
        // Oktober und November zu 0,11, Dezember und Januar zu 0,15 je kWh.
        let erwartet = (190 + 300) * 0.95 * 11 * 0.11 + (390 + 400) * 0.95 * 11 * 0.15
        assertClose(try XCTUnwrap(r.before.cost).amount, erwartet, accuracy: 0.01)
    }

    func testTheBasePriceCountsOnBothSides() throws {
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        let readings = monthly(gasRegister, from: day(2024, 1, 1), months: 21, shape: gasMonate)
            + monthly(wpRegister, from: day(2025, 10, 1), months: 4, shape: wpMonate)
        func run(_ base: String) throws -> HeatingComparison.Result {
            try compared(HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                   tariffs: gasTariffs(base: base) + wpTariffs(base: base),
                                                   today: day(2026, 2, 3)))
        }
        let ohne = try run("0"), mit = try run("12")
        // Vier Monate zu 12 € je Seite, nach Tagen gerechnet.
        assertClose(try XCTUnwrap(mit.before.cost).amount - XCTUnwrap(ohne.before.cost).amount, 48, accuracy: 0.6)
        assertClose(try XCTUnwrap(mit.after.cost).amount - XCTUnwrap(ohne.after.cost).amount, 48, accuracy: 0.6)
        assertClose(try XCTUnwrap(mit.costDifference).amount,
                    approx(try XCTUnwrap(mit.after.cost).amount - XCTUnwrap(mit.before.cost).amount))
    }

    func testHeatingOilInLitres() throws {
        let oelRegister = Register(unit: .litre, integerDigits: 5, fractionDigits: 0)
        let oel = Fixture.meteringPoint(registers: [oelRegister], kind: .heatingOil)
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: oel.id, newMeterID: wp.id,
                                   boilerEfficiency: HeatingChange.defaultEfficiency(for: .heatingOil))
        let readings = monthly(oelRegister, from: day(2024, 1, 1), months: 21, shape: gasMonate)
            + monthly(wpRegister, from: day(2025, 10, 1), months: 4, shape: wpMonate)
        let tarif = Tariff(meteringPointID: oel.id, validFrom: day(2020, 1, 1), pricePerUnit: dec("1.05"),
                           billingUnit: .litre, gasConversion: EnergyDisplay.heatingOilConversion(kWhPerLitre: 10))
        let r = try compared(HeatingComparison.compare(change: change, old: oel, new: wp, readings: readings,
                                                       tariffs: [tarif] + wpTariffs(), today: day(2026, 2, 3)))
        assertClose(r.before.quantity.value, 1280)
        assertClose(try XCTUnwrap(r.before.kilowattHours).value, 12_800, accuracy: 0.01)
        assertClose(try XCTUnwrap(r.heatBefore).value, 12_800 * 0.85, accuracy: 0.01)
        assertClose(try XCTUnwrap(r.before.cost).amount, 1280 * 1.05, accuracy: 0.01)
    }

    func testWithoutThatEarlierYearThereIsNoComparison() {
        let change = HeatingChange(day: day(2025, 10, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                   boilerEfficiency: dec("0.9"))
        // Gas erst seit Dezember 2024 erfasst.
        let readings = monthly(gasRegister, from: day(2024, 12, 1), months: 10, shape: gasMonate)
            + monthly(wpRegister, from: day(2025, 10, 1), months: 4, shape: wpMonate)
        let outcome = HeatingComparison.compare(change: change, old: gas, new: wp, readings: readings,
                                                tariffs: gasTariffs() + wpTariffs(), today: day(2026, 2, 3))
        XCTAssertEqual(outcome, .earlierYearMissing(span(day(2024, 10, 1), day(2025, 2, 1))))
    }

    /// Der Hausstromzähler mit Ablesungen lange vor dem Wechsel darf nicht
    /// als Zähler der Wärmepumpe gelten.
    func testAHouseMeterReadLongBeforeTheChangeIsNotEligible() {
        let readings = [Fixture.reading(wpRegister, day(2024, 1, 1), 100)]
        XCTAssertEqual(HeatingComparison.eligibility(of: wp, readings: readings, changeDay: day(2025, 10, 1)),
                       .measuredBefore(firstReading: day(2024, 1, 1)))
        let kurzVorher = [Fixture.reading(wpRegister, day(2025, 9, 20), 0)]
        XCTAssertEqual(HeatingComparison.eligibility(of: wp, readings: kurzVorher, changeDay: day(2025, 10, 1)),
                       .eligible)
        XCTAssertEqual(HeatingComparison.eligibility(of: wp, readings: [], changeDay: day(2025, 10, 1)), .eligible)
        XCTAssertEqual(HeatingComparison.eligibility(of: gas, readings: [], changeDay: day(2025, 10, 1)),
                       .notElectricity)
    }

    func testEfficiencyStaysBetweenZeroAndOne() {
        XCTAssertEqual(HeatingChange(day: day(2025, 1, 1), oldMeterID: gas.id, newMeterID: wp.id,
                                     boilerEfficiency: 3).boilerEfficiency, 1)
        XCTAssertEqual(HeatingChange.defaultEfficiency(for: .gas), dec("0.9"))
    }
}
