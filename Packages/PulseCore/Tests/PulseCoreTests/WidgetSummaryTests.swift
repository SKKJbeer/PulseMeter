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

    // MARK: - Was VoiceOver hört

    /// Das Widget zeigt Name, Zeile, Zahl und Einheit als vier Bausteine. Für
    /// das Auge ist das eine Karte; vorgelesen waren es vier Fundstücke, und
    /// „kWh" allein sagt nichts.
    func testSpokenSummaryIsOneSentence() {
        let meter = WidgetSummary.Meter(
            id: UUID(), name: "Strom", symbolName: "bolt", colorToken: "amber",
            unit: "kWh", quantity: 1607, isApproximate: false,
            periodCaption: "Seit Jahresbeginn", isDue: false, daysSinceReading: 4)

        XCTAssertEqual(meter.spokenSummary { "\($0)" },
                       "Strom. Seit Jahresbeginn. 1607 Kilowattstunden.")
    }

    /// Produktprinzip 7: Eine geschätzte Zahl ist als solche gekennzeichnet —
    /// sichtbar durch „≈", hörbar durch ein Wort. Das Zeichen wird je nach
    /// Stimme als „Ungefähr gleich" oder gar nicht gelesen.
    func testAnEstimateSaysSoOutLoud() {
        let meter = WidgetSummary.Meter(
            id: UUID(), name: "Gas", symbolName: "flame", colorToken: "orange",
            unit: "m³", quantity: 1181, isApproximate: true,
            periodCaption: "1. Januar bis 1. Mai", isDue: false, daysSinceReading: 96)

        let spoken = meter.spokenSummary { "\($0)" }
        XCTAssertTrue(spoken.contains("ungefähr"), "Die Schätzung muss mitgesprochen werden")
        XCTAssertFalse(spoken.contains("≈"), "Das Zeichen taugt nicht zum Vorlesen")
        XCTAssertTrue(spoken.contains("Kubikmeter"), "m³ ist kein Wort")
    }

    /// Unbekannt ist nicht null. Auf dem Schirm steht dafür ein Strich — und
    /// ein Strich liest sich nicht vor.
    func testNoNumberIsSaidAsSuchAndNotAsZero() {
        let meter = WidgetSummary.Meter(
            id: UUID(), name: "Wasser", symbolName: "drop", colorToken: "blue",
            unit: "m³", quantity: nil, isApproximate: false,
            periodCaption: "Noch keine Ablesung", isDue: false, daysSinceReading: nil)

        let spoken = meter.spokenSummary { "\($0)" }
        XCTAssertTrue(spoken.contains("Noch keine Zahl"))
        XCTAssertFalse(spoken.contains("0 "), "Eine Null wäre eine Aussage, die niemand gemacht hat")
    }

    /// Fälligkeit hat Vorrang vor dem Zeitraum — in der sichtbaren Zeile wie
    /// in der gesprochenen. Zwei Fassungen hätten hier auseinanderlaufen
    /// können, und die gesprochene sieht niemand nach.
    func testDueBeatsThePeriodInBothLines() {
        let meter = WidgetSummary.Meter(
            id: UUID(), name: "Gas", symbolName: "flame", colorToken: "orange",
            unit: "m³", quantity: 1181, isApproximate: false,
            periodCaption: "1. Januar bis 1. Mai", isDue: true, daysSinceReading: 96)

        XCTAssertEqual(meter.statusText, "Seit 96 Tagen fällig")
        XCTAssertTrue(meter.spokenSummary { "\($0)" }.contains("Seit 96 Tagen fällig"))
        XCTAssertFalse(meter.spokenSummary { "\($0)" }.contains("1. Januar"))
    }

    /// Ein nie abgelesener Zähler ist der dringendste Fall, nicht der
    /// unwichtigste — und er hat kein Datum, auf das sich „seit" beziehen ließe.
    func testNeverReadSaysSoInsteadOfCountingFromNothing() {
        let meter = WidgetSummary.Meter(
            id: UUID(), name: "Garage", symbolName: "bolt", colorToken: "amber",
            unit: "kWh", quantity: nil, isApproximate: false,
            periodCaption: "Noch keine Ablesung", isDue: true, daysSinceReading: nil)

        XCTAssertEqual(meter.statusText, "Noch nie abgelesen")
    }

    /// Jede Einheit, die ein Zähler tragen kann, muss sich auch vorlesen
    /// lassen. Fällt eine durch, stünde dort das Zeichen — „m hoch drei" oder
    /// gar nichts.
    func testEveryUnitFindsItsSpokenForm() {
        for unit in MeasurementUnit.allCases {
            let meter = WidgetSummary.Meter(
                id: UUID(), name: "Prüf", symbolName: "bolt", colorToken: "amber",
                unit: unit.symbol, quantity: 1, isApproximate: false,
                periodCaption: "Seit Jahresbeginn", isDue: false, daysSinceReading: 1)
            XCTAssertEqual(meter.spokenUnit, unit.spokenName,
                           "\(unit.symbol) findet seine gesprochene Form nicht")
        }
    }
}
