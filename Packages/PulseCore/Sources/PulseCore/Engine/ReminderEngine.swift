import Foundation

/// Wann an eine Ablesung erinnert werden soll.
///
/// Ohne Erinnerung kommt niemand nach drei Monaten zurück, und dann sind alle
/// anderen Funktionen wertlos — der Verlauf bleibt leer, der Vorjahresvergleich
/// entsteht nie, die Abschlagsvorschau rechnet ins Blaue
/// (docs/00-produktstrategie.md).
///
/// Die Regel ist bewusst **dieselbe** wie in
/// ``ConsumptionEngine/isReadingDue(meteringPoint:readings:today:)``: Eine
/// Mitteilung, die kommt, während auf dem Schirm nichts fällig ist — oder
/// umgekehrt —, macht beide unglaubwürdig. Deshalb rechnet diese Datei den
/// Fälligkeitstag aus, und die Fälligkeit selbst leitet sich davon ab.
public enum ReminderEngine {

    /// Der Tag, an dem ein Zähler wieder abgelesen werden sollte.
    ///
    /// - Returns: `nil`, wenn der Zähler keinen Rhythmus hat oder archiviert
    ///   ist — dann gibt es nichts zu erinnern.
    public static func dueDay(
        meteringPoint: MeteringPoint,
        readings: [Reading]
    ) -> CalendarDay? {
        guard !meteringPoint.isArchived,
              let expected = meteringPoint.readingInterval.approximateDays
        else { return nil }

        let relevantIDs = Set(meteringPoint.registers.map(\.id))
        guard let last = readings.filter({ relevantIDs.contains($0.registerID) })
            .map(\.day).max()
        else { return nil }

        return last.adding(days: expected)
    }

    /// Der Tag, an dem die nächste Mitteilung fällig ist — nie in der
    /// Vergangenheit.
    ///
    /// Ein überfälliger Zähler wird **heute** erinnert, nicht rückwirkend:
    /// Eine Mitteilung für einen vergangenen Tag lässt sich nicht mehr
    /// zustellen, und der Zähler bliebe für immer stumm. Genau so verschwinden
    /// Erinnerungen in Apps, die den Fall nicht bedenken.
    public static func nextNotificationDay(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        today: CalendarDay
    ) -> CalendarDay? {
        guard let due = dueDay(meteringPoint: meteringPoint, readings: readings) else {
            // Ohne Ablesung gibt es keinen Bezugspunkt. Erinnert wird trotzdem,
            // und zwar heute — ein Zähler ohne jede Ablesung ist der
            // dringendste Fall, nicht der unwichtigste.
            guard !meteringPoint.isArchived,
                  meteringPoint.readingInterval.approximateDays != nil
            else { return nil }
            return today
        }
        return Swift.max(due, today)
    }

    /// Alle anstehenden Erinnerungen, früheste zuerst.
    ///
    /// - Parameter limit: iOS stellt höchstens 64 lokale Mitteilungen in die
    ///   Warteschlange. Wer zwanzig Zähler führt, bekäme sonst irgendwann
    ///   keine mehr — welche wegfallen, entschiede dann das System.
    /// Ein Eintrag im Erinnerungsplan.
    public struct Entry: Hashable, Sendable {
        public let meteringPoint: MeteringPoint
        public let day: CalendarDay
    }

    /// Schrittweise statt als verkettete Ausdrucksfolge: Der Typprüfer brauchte
    /// für die Kette aus `compactMap`, `sorted` und `prefix` über zwei Minuten
    /// und gab dann auf. Mit benannten Zwischenschritten übersetzt dasselbe in
    /// Sekunden — und liest sich obendrein.
    public static func schedule(
        meteringPoints: [MeteringPoint],
        readings: [MeteringPoint.ID: [Reading]],
        today: CalendarDay,
        limit: Int = 32
    ) -> [Entry] {
        var entries: [Entry] = []
        for point in meteringPoints {
            let own = readings[point.id] ?? []
            guard let day = nextNotificationDay(meteringPoint: point, readings: own, today: today)
            else { continue }
            entries.append(Entry(meteringPoint: point, day: day))
        }

        entries.sort { left, right in
            if left.day == right.day { return left.meteringPoint.name < right.meteringPoint.name }
            return left.day < right.day
        }
        return Array(entries.prefix(Swift.max(0, limit)))
    }
}
