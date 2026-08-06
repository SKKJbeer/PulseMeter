import XCTest
@testable import PulseCore

final class PulseSnapshotTests: XCTestCase {

    private func sample() -> PulseSnapshot {
        let property = Property(name: "Zuhause")
        let register = Fixture.electricityRegister()
        let point = MeteringPoint(propertyID: property.id, name: "Strom",
                                  kind: .electricity, registers: [register])
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.34"), monthlyBasePrice: dec("12.90"),
                            billingUnit: .kilowattHour)
        return PulseSnapshot(
            properties: [property],
            meteringPoints: [point],
            readings: [
                Fixture.reading(register, day(2026, 1, 1), 1000, sequence: 1),
                Fixture.reading(register, day(2026, 2, 1), 1300, sequence: 2)
            ],
            tariffs: [tariff]
        )
    }

    func testRoundTripsThroughJSON() throws {
        let snapshot = sample()
        let restored = try PulseSnapshot.decode(from: snapshot.encoded())
        XCTAssertEqual(restored.properties, snapshot.properties)
        XCTAssertEqual(restored.meteringPoints, snapshot.meteringPoints)
        XCTAssertEqual(restored.readings, snapshot.readings)
        XCTAssertEqual(restored.tariffs, snapshot.tariffs)
    }

    func testSnapshotCarriesEveryEntityNotJustReadings() throws {
        // Ein Abzug, aus dem sich der Zustand nicht rekonstruieren lässt,
        // ist keine Sicherung.
        let restored = try PulseSnapshot.decode(from: sample().encoded())
        XCTAssertFalse(restored.properties.isEmpty)
        XCTAssertFalse(restored.meteringPoints.isEmpty)
        XCTAssertFalse(restored.tariffs.isEmpty)
        XCTAssertEqual(restored.meteringPoints[0].registers.count, 1,
                       "Zählwerke müssen den Abzug überstehen, sonst hängen die Ablesungen in der Luft")
    }

    /// Ohne diese Eigenschaft traut sich niemand, eine Sicherung einzuspielen,
    /// wenn er nicht mehr weiß, ob er es schon getan hat.
    func testImportIsIdempotent() {
        let snapshot = sample()
        let once = snapshot.merged(into: PulseSnapshot())
        let twice = snapshot.merged(into: once)

        XCTAssertEqual(once.readings.count, 2)
        XCTAssertEqual(twice.readings.count, 2, "Zweimal eingelesen darf keine Dubletten erzeugen")
        XCTAssertEqual(twice.meteringPoints.count, 1)
        XCTAssertEqual(twice.properties.count, 1)
    }

    func testMergeAddsNewAndReplacesKnown() {
        let base = sample()
        var updated = base
        // Derselbe Zähler, umbenannt — und eine zusätzliche Ablesung.
        updated.meteringPoints[0].name = "Strom Haupthaus"
        updated.readings.append(
            Fixture.reading(base.meteringPoints[0].registers[0], day(2026, 3, 1), 1580, sequence: 3)
        )

        let result = updated.merged(into: base)
        XCTAssertEqual(result.meteringPoints.count, 1, "Gleiche Kennung, kein zweiter Zähler")
        XCTAssertEqual(result.meteringPoints[0].name, "Strom Haupthaus", "Der eingelesene Wert gewinnt")
        XCTAssertEqual(result.readings.count, 3)
    }

    func testMergeKeepsExistingEntriesUntouched() {
        let base = sample()
        let other = PulseSnapshot(properties: [Property(name: "Ferienhaus")])
        let result = other.merged(into: base)
        XCTAssertEqual(result.properties.count, 2)
        XCTAssertEqual(result.readings.count, 2, "Bestehende Ablesungen bleiben erhalten")
    }

    func testRejectsNewerFormat() throws {
        var snapshot = sample()
        snapshot.version = PulseSnapshot.currentVersion + 1
        XCTAssertThrowsError(try PulseSnapshot.decode(from: snapshot.encoded())) { error in
            XCTAssertEqual(error as? PulseSnapshot.DecodingProblem,
                           .unsupportedVersion(found: PulseSnapshot.currentVersion + 1,
                                               supported: PulseSnapshot.currentVersion))
        }
    }

    func testDetectsOrphanedReadings() {
        var snapshot = sample()
        let stranger = Register(unit: .cubicMetre)
        snapshot.readings.append(Fixture.reading(stranger, day(2026, 4, 1), 42, sequence: 9))

        let problems = snapshot.danglingReferences()
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems[0].contains("ohne zugehörigen Zähler"))
    }

    func testCleanSnapshotHasNoProblems() {
        XCTAssertTrue(sample().danglingReferences().isEmpty)
    }
}
