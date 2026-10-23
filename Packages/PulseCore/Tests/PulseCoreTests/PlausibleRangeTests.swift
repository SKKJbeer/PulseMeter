import XCTest
@testable import PulseCore

/// Der Bereich, in dem die Kamera einen Stand vorschlagen darf, und die Prüfung im
/// Ziffernblock müssen **dieselbe Grenze** ziehen.
final class PlausibleRangeTests: XCTestCase {

    private func setup() -> (Register, [Reading]) {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]
        return (register, readings)
    }

    func testFirstReadingHasNoRange() {
        let register = Fixture.electricityRegister()
        XCTAssertNil(ConsumptionEngine.plausibleReadingRange(register: register, readings: [], today: day(2026, 3, 1)))
    }

    func testRangeStartsAtTheLastReading() throws {
        let (register, readings) = setup()
        let range = try XCTUnwrap(ConsumptionEngine.plausibleReadingRange(register: register, readings: readings, today: day(2026, 3, 1)))
        XCTAssertEqual(range.lowerBound, 1300)
        XCTAssertGreaterThan(range.upperBound, 1300)
    }

    /// Die obere Grenze ist genau die, an der `plausibility` zu „auffällig" wechselt.
    func testUpperBoundIsWhereThePlausibilityCheckStartsToDoubt() throws {
        let (register, readings) = setup()
        let today = day(2026, 3, 1)
        let range = try XCTUnwrap(ConsumptionEngine.plausibleReadingRange(register: register, readings: readings, today: today))

        func verdict(_ v: Decimal) -> ConsumptionEngine.Plausibility {
            ConsumptionEngine.plausibility(of: v, on: today, register: register, readings: readings, today: today)
        }
        guard case .normal = verdict(range.upperBound - 1) else { return XCTFail("knapp darunter muss normal sein") }
        guard case .unusual = verdict(range.upperBound + 1) else { return XCTFail("knapp darüber muss auffällig sein") }
    }

    func testWithoutUsualConsumptionATenthOfTheRegisterIsTheCeiling() throws {
        let register = Fixture.electricityRegister()
        let readings = [Fixture.reading(register, day(2026, 1, 1), 1000)]
        let range = try XCTUnwrap(ConsumptionEngine.plausibleReadingRange(register: register, readings: readings, today: day(2026, 1, 10)))
        XCTAssertEqual(range.upperBound, 1000 + register.capacity / 10)
    }
}
