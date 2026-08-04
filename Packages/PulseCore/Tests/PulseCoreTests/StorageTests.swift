import XCTest
@testable import PulseCore

/// Diese Tests sichern die Grenze zur Persistenzschicht ab. Sie laufen ohne
/// SwiftData und ohne Xcode — genau deshalb liegt die Umrechnung hier und
/// nicht in `PulseData`.
final class StorageTests: XCTestCase {

    // MARK: - ScaledDecimal

    func testReadingRoundTripsExactly() {
        let register = Register(unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let stored = ScaledDecimal(reading: dec("49157.4"), register: register)
        XCTAssertEqual(stored.scaled, 491_574)
        XCTAssertEqual(stored.value, dec("49157.4"))
    }

    func testCubicMetresKeepThreeDecimals() {
        let register = Register(unit: .cubicMetre, integerDigits: 5, fractionDigits: 3)
        let stored = ScaledDecimal(reading: dec("10057.106"), register: register)
        XCTAssertEqual(stored.scaled, 10_057_106)
        XCTAssertEqual(stored.value, dec("10057.106"))
    }

    /// Der eigentliche Grund für diesen Typ: Über CloudKit würde ein `Decimal`
    /// zu `Double`, und 0,1 + 0,2 wäre nicht mehr 0,3.
    func testPricesSurviveArithmeticAfterStorage() {
        let price = ScaledDecimal(money: dec("0.112")).value
        let feedIn = ScaledDecimal(money: dec("0.082")).value
        XCTAssertEqual(price + feedIn, dec("0.194"))
        XCTAssertEqual(price * 1995, dec("223.44"), "1995 kWh Gas zum Arbeitspreis")
    }

    func testNegativeValuesRoundTrip() {
        let stored = ScaledDecimal(dec("-84.35"), scale: 2)
        XCTAssertEqual(stored.scaled, -8_435)
        XCTAssertEqual(stored.value, dec("-84.35"))
    }

    func testZeroAndWholeNumbers() {
        XCTAssertEqual(ScaledDecimal(0, scale: 3).value, 0)
        XCTAssertEqual(ScaledDecimal(dec("1000"), scale: 0).scaled, 1000)
        XCTAssertEqual(ScaledDecimal(dec("1000"), scale: 0).value, 1000)
    }

    /// Mehr Nachkommastellen als das Zählwerk hat, werden kaufmännisch gerundet —
    /// dieselbe Regel wie bei Geldbeträgen, damit nirgends anders gerundet wird.
    func testRoundsHalfToEvenLikeMoney() {
        XCTAssertEqual(ScaledDecimal(dec("2.125"), scale: 2).value, dec("2.12"))
        XCTAssertEqual(ScaledDecimal(dec("2.135"), scale: 2).value, dec("2.14"))
    }

    func testLargeReadingStaysExact() {
        // Sechsstelliges Werk kurz vor dem Überlauf, mit einer Nachkommastelle.
        let stored = ScaledDecimal(dec("999999.9"), scale: 1)
        XCTAssertEqual(stored.scaled, 9_999_999)
        XCTAssertEqual(stored.value, dec("999999.9"))
    }

    func testScaleIsCarriedWithTheValue() {
        // Ändert der Nutzer später die Nachkommastellen des Zählwerks, bleiben
        // alte Ablesungen unverschoben, weil ihr Faktor mitgespeichert ist.
        let old = ScaledDecimal(scaled: 491_574, scale: 1)
        let new = ScaledDecimal(scaled: 491_574_000, scale: 4)
        XCTAssertEqual(old.value, new.value)
    }

    func testCodableRoundTrip() throws {
        let stored = ScaledDecimal(dec("10057.106"), scale: 3)
        let data = try JSONEncoder().encode(stored)
        XCTAssertEqual(try JSONDecoder().decode(ScaledDecimal.self, from: data), stored)
    }

    // MARK: - ResourceKind

    func testEveryKindHasADistinctStorageID() {
        let kinds: [ResourceKind] = [
            .electricity, .water, .hotWater, .gas, .districtHeating, .heatingOil,
            .solarProduction, .wallbox, .batteryStorage, .operatingHours, .rainwater
        ]
        XCTAssertEqual(Set(kinds.map(\.storageID)).count, kinds.count)
        for kind in kinds {
            XCTAssertEqual(ResourceKind.restore(storageID: kind.storageID), kind)
        }
    }

    func testCustomKindRoundTrips() {
        let kind = ResourceKind.custom(name: "Poolpumpe", unit: .hour)
        let restored = ResourceKind.restore(
            storageID: kind.storageID,
            customName: kind.customName,
            customUnit: kind.customUnit
        )
        XCTAssertEqual(restored, kind)
    }

    /// Eine Zählerart aus einer neueren App-Version darf nichts kaputt machen.
    /// Der Nutzer verliert die Vorbelegung, nie seine Ablesungen.
    func testUnknownKindDegradesToCustom() {
        let restored = ResourceKind.restore(storageID: "hydrogen", customUnit: .kilowattHour)
        guard case .custom(let name, let unit) = restored else {
            return XCTFail("Erwartet: frei definierter Zähler, erhalten: \(restored)")
        }
        XCTAssertEqual(name, "hydrogen")
        XCTAssertEqual(unit, .kilowattHour)
    }
}
