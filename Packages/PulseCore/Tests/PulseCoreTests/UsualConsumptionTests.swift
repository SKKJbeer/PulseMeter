import XCTest
@testable import PulseCore

/// Die Zahl, an der ein auffälliger Stand im Ziffernblock gemessen wird.
///
/// Bis 0.148 stand dort ein Faktor („rund 0,2× dein üblicher Verbrauch“, beim
/// unveränderten Stand „rund 0×“). Seit 0.149.0 stehen zwei Mengen
/// nebeneinander; diese Tests halten fest, dass die zweite stimmt und dass es
/// sie beim unveränderten Stand nicht gibt.
final class UsualConsumptionTests: XCTestCase {

    /// 300 kWh im Januar (31 Tage), also gut 9,7 kWh am Tag. Ein Stand mit
    /// einer Stelle zu viel bringt im Februar 3000 kWh in 28 Tagen.
    func testATenfoldTypoNamesTheUsualAmountForTheSameDays() throws {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]
        let verdict = ConsumptionEngine.plausibility(
            of: 4300, on: day(2026, 3, 1), register: register,
            readings: readings, today: day(2026, 3, 1))

        let usual = try XCTUnwrap(verdict.usualConsumption, "Erwartet eine übliche Menge: \(verdict)")
        // 300 / 31 × 28 = 270,97 — dieselben 28 Tage wie die eingetippte Menge.
        XCTAssertEqual(NSDecimalNumber(decimal: usual.value).doubleValue, 300.0 / 31 * 28, accuracy: 0.01)
        XCTAssertEqual(usual.unit, .kilowattHour)
    }

    /// Der Fall, der „rund 0×“ ergab: Der Stand wird unverändert übernommen.
    func testAnUnchangedReadingHasNoUsualAmount() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]
        let verdict = ConsumptionEngine.plausibility(
            of: 1300, on: day(2026, 3, 1), register: register,
            readings: readings, today: day(2026, 3, 1))

        guard case .unusual(let consumption, _, _) = verdict else {
            return XCTFail("Ein unveränderter Stand nach vier Wochen muss nachfragen: \(verdict)")
        }
        XCTAssertEqual(consumption.value, 0)
        XCTAssertNil(verdict.usualConsumption)
    }

    func testOnlyAnUnusualValueHasAUsualAmount() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]
        for wert: Decimal in [1600, 900] {
            let verdict = ConsumptionEngine.plausibility(
                of: wert, on: day(2026, 3, 1), register: register,
                readings: readings, today: day(2026, 3, 1))
            XCTAssertNil(verdict.usualConsumption, "\(wert): \(verdict)")
        }
    }
}
