import XCTest
@testable import PulseCore

final class ReminderEngineTests: XCTestCase {

    private func monthlyMeter(archived: Bool = false,
                              interval: ReadingInterval = .monthly) -> (MeteringPoint, Register) {
        let register = Fixture.electricityRegister()
        var point = Fixture.meteringPoint(registers: [register])
        point.readingInterval = interval
        point.isArchived = archived
        return (point, register)
    }

    // MARK: - Fälligkeitstag

    func testDueDayIsTheIntervalAfterTheLastReading() {
        let (point, register) = monthlyMeter()
        let readings = [Fixture.reading(register, day(2026, 6, 10), 1000)]

        XCTAssertEqual(ReminderEngine.dueDay(meteringPoint: point, readings: readings),
                       day(2026, 7, 10), "Monatlich sind 30 Tage")
    }

    func testArchivedMetersAreNotReminded() {
        let (point, register) = monthlyMeter(archived: true)
        let readings = [Fixture.reading(register, day(2026, 6, 10), 1000)]

        XCTAssertNil(ReminderEngine.dueDay(meteringPoint: point, readings: readings))
        XCTAssertNil(ReminderEngine.nextNotificationDay(meteringPoint: point, readings: readings,
                                                       today: day(2026, 8, 1)))
    }

    func testMetersWithoutRhythmAreNotReminded() {
        let (point, register) = monthlyMeter(interval: .never)
        let readings = [Fixture.reading(register, day(2026, 6, 10), 1000)]

        XCTAssertNil(ReminderEngine.dueDay(meteringPoint: point, readings: readings))
    }

    // MARK: - Nächste Mitteilung

    func testUpcomingReminderKeepsItsDay() {
        let (point, register) = monthlyMeter()
        let readings = [Fixture.reading(register, day(2026, 7, 20), 1000)]

        XCTAssertEqual(
            ReminderEngine.nextNotificationDay(meteringPoint: point, readings: readings,
                                               today: day(2026, 8, 1)),
            day(2026, 8, 19)
        )
    }

    /// Ein überfälliger Zähler wird heute erinnert, nicht rückwirkend.
    ///
    /// Eine Mitteilung für einen vergangenen Tag lässt sich nicht zustellen —
    /// der Zähler bliebe für immer stumm, und zwar genau der, der die
    /// Erinnerung am nötigsten hat.
    func testOverdueMeterIsRemindedTodayRatherThanInThePast() {
        let (point, register) = monthlyMeter()
        let readings = [Fixture.reading(register, day(2026, 1, 1), 1000)]

        XCTAssertEqual(
            ReminderEngine.nextNotificationDay(meteringPoint: point, readings: readings,
                                               today: day(2026, 8, 6)),
            day(2026, 8, 6)
        )
    }

    /// Ein Zähler ohne jede Ablesung ist der dringendste Fall.
    func testMeterWithoutAnyReadingIsRemindedToday() {
        let (point, _) = monthlyMeter()

        XCTAssertEqual(
            ReminderEngine.nextNotificationDay(meteringPoint: point, readings: [],
                                               today: day(2026, 8, 6)),
            day(2026, 8, 6)
        )
    }

    // MARK: - Der Plan

    func testScheduleIsSortedByDayAndCappedAtTheLimit() {
        let (soon, soonRegister) = monthlyMeter()
        var (later, laterRegister) = monthlyMeter()
        later.name = "Später"

        let schedule = ReminderEngine.schedule(
            meteringPoints: [later, soon],
            readings: [
                soon.id: [Fixture.reading(soonRegister, day(2026, 7, 20), 1000)],
                later.id: [Fixture.reading(laterRegister, day(2026, 7, 25), 1000)]
            ],
            today: day(2026, 8, 1)
        )

        XCTAssertEqual(schedule.count, 2)
        XCTAssertEqual(schedule[0].day, day(2026, 8, 19), "Der frühere zuerst")
        XCTAssertEqual(schedule[1].day, day(2026, 8, 24))
    }

    /// iOS stellt höchstens 64 lokale Mitteilungen in die Warteschlange. Wer
    /// sehr viele Zähler führt, bekäme sonst irgendwann keine mehr — und
    /// welche wegfallen, entschiede das System.
    func testScheduleRespectsTheLimit() {
        var points: [MeteringPoint] = []
        var readings: [MeteringPoint.ID: [Reading]] = [:]
        for index in 0..<10 {
            let (point, register) = monthlyMeter()
            points.append(point)
            readings[point.id] = [Fixture.reading(register, day(2026, 7, 1 + index), 1000)]
        }

        let schedule = ReminderEngine.schedule(meteringPoints: points, readings: readings,
                                               today: day(2026, 8, 1), limit: 3)
        XCTAssertEqual(schedule.count, 3)
    }

    // MARK: - Gleichlauf mit der Fälligkeit auf dem Schirm

    /// Mitteilung und „Fällig"-Marke müssen dieselbe Antwort geben. Sonst
    /// kommt eine Erinnerung, während auf dem Schirm nichts fällig ist.
    func testDueBadgeAndReminderAgreeOnEveryDayAroundTheBoundary() {
        let (point, register) = monthlyMeter()
        let readings = [Fixture.reading(register, day(2026, 6, 10), 1000)]
        let due = ReminderEngine.dueDay(meteringPoint: point, readings: readings)

        for offset in -3...3 {
            let today = day(2026, 7, 10).adding(days: offset)
            let isDue = ConsumptionEngine.isReadingDue(meteringPoint: point,
                                                       readings: readings, today: today)
            XCTAssertEqual(isDue, today >= due!,
                           "Am \(today) sind Marke und Erinnerung uneins")
        }
    }
}
