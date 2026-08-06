import XCTest
@testable import PulseCore

/// Das Widget zeigt drei Zahlen auf einem Sperrbildschirm — und genau deshalb
/// darf keine davon falsch sein. Wer im Vorbeigehen liest, prüft nichts nach.
final class WidgetSummaryTests: XCTestCase {

    private let year2026 = span(day(2026, 1, 1), day(2027, 1, 1))

    private func point(_ name: String, register: Register,
                       interval: ReadingInterval = .monthly) -> MeteringPoint {
        MeteringPoint(propertyID: Fixture.property.id, name: name,
                      kind: .electricity, registers: [register],
                      readingInterval: interval)
    }

    func testSummaryCarriesQuantityAndDueState() {
        let register = Fixture.electricityRegister()
        let meter = point("Strom", register: register)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 4, 1), 1900)
        ]

        let summary = WidgetSummary.build(
            meteringPoints: [meter], readings: [meter.id: readings],
            range: year2026, today: day(2026, 4, 1), caption: { _ in "Seit Jahresbeginn" })

        XCTAssertEqual(summary.version, WidgetSummary.currentVersion)
        XCTAssertEqual(summary.meters.count, 1)
        XCTAssertEqual(summary.meters[0].quantity, 900)
        XCTAssertEqual(summary.meters[0].unit, "kWh")
        XCTAssertEqual(summary.meters[0].daysSinceReading, 0)
        XCTAssertFalse(summary.meters[0].isDue)
    }

    /// Ohne Verbrauch steht `nil` und nicht null.
    ///
    /// Eine Null auf dem Sperrbildschirm liest sich als „nichts verbraucht" —
    /// eine Aussage, die niemand gemacht hat (Produktprinzip 7).
    func testUnknownConsumptionIsNilAndNotZero() {
        let register = Fixture.electricityRegister()
        let meter = point("Neu", register: register)

        let summary = WidgetSummary.build(
            meteringPoints: [meter], readings: [:],
            range: year2026, today: day(2026, 4, 1), caption: { _ in "Noch keine Ablesung" })

        XCTAssertNil(summary.meters[0].quantity)
        XCTAssertTrue(summary.meters[0].isDue, "Ohne jede Ablesung ist immer eine fällig")
        XCTAssertNil(summary.meters[0].daysSinceReading)
    }

    /// Der nie abgelesene Zähler steht vorn.
    ///
    /// Dieselbe Regel wie in `ReminderEngine`: Er ist der dringendste Fall,
    /// nicht der unwichtigste. Stünde er hinten, verschwände er aus einem
    /// Widget, das nur einen Zähler zeigt — und zwar dauerhaft.
    func testNeverReadMeterLeadsTheDueList() {
        let a = Fixture.electricityRegister()
        let b = Fixture.electricityRegister()
        let stale = point("Alt", register: a)
        let never = point("Nie", register: b)
        let readings = [Fixture.reading(a, day(2025, 1, 1), 500)]

        let summary = WidgetSummary.build(
            meteringPoints: [stale, never],
            readings: [stale.id: readings],
            range: year2026, today: day(2026, 4, 1), caption: { _ in "" })

        XCTAssertEqual(summary.due.map(\.name), ["Nie", "Alt"])
        XCTAssertEqual(summary.headline?.name, "Nie")
    }

    /// Archivierte Zähler tauchen nicht auf.
    func testArchivedMetersAreLeftOut() {
        let register = Fixture.electricityRegister()
        var meter = point("Weg", register: register)
        meter.isArchived = true

        let summary = WidgetSummary.build(
            meteringPoints: [meter], readings: [:],
            range: year2026, today: day(2026, 4, 1), caption: { _ in "" })

        XCTAssertTrue(summary.meters.isEmpty)
        XCTAssertNil(summary.headline)
    }

    /// Die Datei muss über Prozessgrenzen hinweg lesbar sein — App schreibt,
    /// Widget liest. Ein Kodierungsfehler fiele sonst erst auf dem Gerät auf,
    /// und dort als leeres Widget ohne Meldung.
    func testSummarySurvivesEncodingRoundTrip() throws {
        let register = Fixture.electricityRegister()
        let meter = point("Strom", register: register)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 4, 1), 1900)
        ]
        let summary = WidgetSummary.build(
            meteringPoints: [meter], readings: [meter.id: readings],
            range: year2026, today: day(2026, 4, 1), caption: { _ in "Seit Jahresbeginn" })

        let data = try JSONEncoder().encode(summary)
        let restored = try JSONDecoder().decode(WidgetSummary.self, from: data)

        XCTAssertEqual(restored, summary)
        XCTAssertEqual(restored.meters[0].quantity, 900,
                       "Der Betrag muss exakt zurückkommen, nicht als Fließkommazahl")
    }

    /// Ein Widget, das eine neuere Fassung nicht versteht, muss das erkennen
    /// können. Es läuft weiter, während die App schon aktualisiert ist.
    func testVersionIsCarriedSoAnOldWidgetCanRefuse() throws {
        var summary = WidgetSummary()
        summary.version = WidgetSummary.currentVersion + 1
        let data = try JSONEncoder().encode(summary)
        let restored = try JSONDecoder().decode(WidgetSummary.self, from: data)
        XCTAssertGreaterThan(restored.version, WidgetSummary.currentVersion)
    }
}
