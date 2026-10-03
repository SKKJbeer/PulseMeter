import XCTest
@testable import PulseCore

/// Der Rundgang führt durch die fälligen Zähler, in der Reihenfolge der
/// Übersicht, und endet, wenn keiner mehr wartet.
final class ReadingRoundTests: XCTestCase {

    private let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    func testFollowsTheOrderOfTheOverviewFromTheStart() {
        let runde = ReadingRound(start: b, order: [a, b, c, d], due: [a, c, d])
        XCTAssertEqual(runde.remaining, [c, d, a], "ab dem Start und im Kreis weiter")
    }

    func testLeavesOutWhatIsNotDue() {
        let runde = ReadingRound(start: a, order: [a, b, c, d], due: [a, c])
        XCTAssertEqual(runde.remaining, [c])
    }

    /// Der Zähler, mit dem es anfing, kommt nie ein zweites Mal, auch wenn er
    /// selbst fällig war.
    func testNeverReturnsToTheStart() {
        let runde = ReadingRound(start: a, order: [a, b], due: [a, b])
        XCTAssertEqual(runde.remaining, [b])
    }

    /// Ohne weiteren fälligen Zähler gibt es keinen Rundgang, und das Blatt
    /// schließt wie bisher.
    func testNoRoundWhenNothingElseIsDue() {
        let runde = ReadingRound(start: a, order: [a, b, c], due: [a])
        XCTAssertNil(runde.next)
    }

    /// Wer auf einem nicht fälligen Zähler anfängt, kommt trotzdem zu den
    /// fälligen. Genau das ist der Fall, in dem jemand ohnehin am Zähler steht.
    func testStartingOnAMeterThatIsNotDue() {
        let runde = ReadingRound(start: b, order: [a, b, c], due: [a, c])
        XCTAssertEqual(runde.remaining, [c, a])
    }

    func testAdvanceWalksThroughAndEnds() {
        var runde = ReadingRound(start: a, order: [a, b, c], due: [b, c])
        XCTAssertEqual(runde.advance(), b)
        XCTAssertEqual(runde.next, c)
        XCTAssertEqual(runde.advance(), c)
        XCTAssertNil(runde.next)
        XCTAssertNil(runde.advance(), "über das Ende hinaus passiert nichts")
    }

    /// Ein unbekannter Start, etwa ein eben gelöschter Zähler: Dann gilt die
    /// Reihenfolge von vorn, ohne Absturz und ohne Doppelte.
    func testUnknownStartUsesTheOrderFromTheTop() {
        let runde = ReadingRound(start: UUID(), order: [a, b, a], due: [a, b])
        XCTAssertEqual(runde.remaining, [a, b])
    }

    /// Fällig heißt dasselbe wie auf der Karte: nie abgelesen ist fällig,
    /// eben abgelesen nicht, archiviert nie.
    func testUsesTheSameDueRuleAsTheCard() throws {
        let heute = try XCTUnwrap(CalendarDay(year: 2026, month: 10, day: 3))
        let gestern = try XCTUnwrap(CalendarDay(year: 2026, month: 10, day: 2))
        let vorZweiMonaten = try XCTUnwrap(CalendarDay(year: 2026, month: 8, day: 1))
        let haus = UUID()
        let strom = MeteringPoint(propertyID: haus, name: "Strom", kind: .electricity)
        let wasser = MeteringPoint(propertyID: haus, name: "Wasser", kind: .water)
        let gas = MeteringPoint(propertyID: haus, name: "Gas", kind: .gas)
        var alt = MeteringPoint(propertyID: haus, name: "Alter Zähler", kind: .water)
        alt.isArchived = true
        let neu = MeteringPoint(propertyID: haus, name: "Garten", kind: .water)

        func stand(_ punkt: MeteringPoint, _ tag: CalendarDay) throws -> [Reading] {
            [Reading(registerID: try XCTUnwrap(punkt.primaryRegister).id, day: tag, value: 100)]
        }
        let runde = ReadingRound(
            start: strom.id,
            meteringPoints: [strom, wasser, gas, alt, neu],
            primaryReadings: [strom.id: try stand(strom, vorZweiMonaten),
                              wasser.id: try stand(wasser, gestern),
                              gas.id: try stand(gas, vorZweiMonaten),
                              alt.id: try stand(alt, vorZweiMonaten)],
            today: heute)
        XCTAssertEqual(runde.remaining, [gas.id, neu.id],
                       "Wasser ist eben abgelesen, der alte Zähler archiviert")
    }
}
