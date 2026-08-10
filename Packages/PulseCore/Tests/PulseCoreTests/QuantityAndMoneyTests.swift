import XCTest
@testable import PulseCore

final class QuantityAndMoneyTests: XCTestCase {

    func testConvertsWithinDimension() throws {
        let energy = Quantity(1500, .kilowattHour)
        XCTAssertEqual(try energy.converted(to: .megawattHour).value, dec("1.5"))

        let volume = Quantity(2, .cubicMetre)
        XCTAssertEqual(try volume.converted(to: .litre).value, 2000)
    }

    /// Die Fehlerklasse, die dieses Modell strukturell ausschließen soll:
    /// Volumen und Energie dürfen nicht stillschweigend ineinander übergehen.
    func testRefusesCrossDimensionConversion() {
        let volume = Quantity(200, .cubicMetre)
        XCTAssertThrowsError(try volume.converted(to: .kilowattHour)) { error in
            XCTAssertEqual(
                error as? Quantity.ConversionError,
                .incompatibleDimensions(from: .cubicMetre, to: .kilowattHour)
            )
        }
    }

    func testAdditionConvertsAutomatically() throws {
        let sum = try Quantity(1, .megawattHour).adding(Quantity(500, .kilowattHour))
        XCTAssertEqual(try sum.converted(to: .kilowattHour).value, 1500)
        XCTAssertEqual(sum.unit, .megawattHour, "Das Ergebnis trägt die Einheit des linken Operanden")
    }

    /// Der Grund für `Decimal` statt `Double`: Beträge müssen exakt bleiben.
    func testDecimalArithmeticIsExact() {
        let sum = dec("0.1") + dec("0.2")
        XCTAssertEqual(sum, dec("0.3"))
        XCTAssertTrue(sum == dec("0.3"), "Mit Double wäre dieser Vergleich falsch")
    }

    func testMoneyRoundsToCentsCommercially() {
        XCTAssertEqual(Money(dec("2.125"), .eur).roundedToCents.amount, dec("2.12"))
        XCTAssertEqual(Money(dec("2.135"), .eur).roundedToCents.amount, dec("2.14"))
        XCTAssertEqual(Money(dec("-1.005"), .eur).roundedToCents.amount, dec("-1"))
    }

    func testMoneyRefusesMixedCurrencies() {
        XCTAssertThrowsError(try Money(10, .eur).adding(Money(10, .chf)))
    }

    /// Jede Einheit muss vorgelesen werden können.
    ///
    /// Über `allCases`, damit eine neu hinzugefügte Einheit ohne gesprochenen
    /// Namen hier auffällt und nicht erst bei einem Nutzer, dem VoiceOver
    /// „m hoch drei“ vorliest. Geprüft wird auch, dass der gesprochene Name
    /// **nicht** das Kürzel ist — sonst wäre die Zusage erfüllt und die
    /// Wirkung dieselbe wie vorher.
    func testEveryUnitCanBeSpoken() {
        for unit in MeasurementUnit.allCases {
            XCTAssertFalse(unit.spokenName.isEmpty,
                           "\(unit.symbol) hat keinen gesprochenen Namen")
            XCTAssertNotEqual(unit.spokenName, unit.symbol,
                              "\(unit.symbol) wird nur buchstabiert statt gesprochen")
            XCTAssertGreaterThan(unit.spokenName.count, unit.symbol.count,
                                 "\(unit.symbol): der gesprochene Name sieht nach einem Kürzel aus")
        }
    }

    func testGasConversionFollowsGermanBillingFormula() throws {
        let conversion = GasConversion(stateNumber: dec("0.95"), calorificValue: dec("10.5"))
        let energy = try conversion.energy(fromVolume: Quantity(200, .cubicMetre))
        // 200 m³ × 0,95 × 10,5 kWh/m³ = 1995 kWh
        XCTAssertEqual(energy.value, 1995)
        XCTAssertEqual(energy.unit, .kilowattHour)
    }
}
