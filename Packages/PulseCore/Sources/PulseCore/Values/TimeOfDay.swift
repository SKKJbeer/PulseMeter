import Foundation

/// Eine Uhrzeit am Tag — Stunde und Minute, ohne Sekunden und ohne Zeitzone.
///
/// **Warum getrennt von ``CalendarDay`` und nicht als `Date`.** Der Tag bleibt
/// die Grundlage jeder Berechnung (ADR-004): Verbräuche entstehen zwischen
/// Tagen, und ein `Date` würde bei Sommerzeit und Gerätereisen genau die
/// Off-by-one-Fehler zurückbringen, die `CalendarDay` verhindert. Die Uhrzeit
/// beantwortet eine andere Frage — **welche von zwei Ablesungen desselben Tages
/// die spätere ist** — und sie beantwortet sie ohne Zeitzone, weil beide am
/// selben Ort abgelesen wurden.
///
/// Gespeichert wird ``minuteOfDay``: 0 bis 1439, sortierbar und vergleichbar.
///
/// Sekunden fehlen mit Absicht. Niemand liest einen Zähler sekundengenau ab,
/// und ein Feld, das genauer aussieht als die Sache, die es beschreibt, ist eine
/// stille Behauptung (Produktprinzip 7).
public struct TimeOfDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {

    /// Minuten seit Mitternacht, 0 bis 1439.
    public let minuteOfDay: Int

    public var hour: Int { minuteOfDay / 60 }
    public var minute: Int { minuteOfDay % 60 }

    // MARK: - Erzeugung

    /// Gibt `nil` zurück, wenn es die Uhrzeit nicht gibt. 24:00 ist keine
    /// Uhrzeit dieses Tages, sondern Mitternacht des nächsten — und wer das
    /// meint, soll den Tag ändern, nicht die Stunde.
    public init?(hour: Int, minute: Int) {
        guard hour >= 0, hour <= 23, minute >= 0, minute <= 59 else { return nil }
        self.minuteOfDay = hour * 60 + minute
    }

    public init?(minuteOfDay: Int) {
        guard minuteOfDay >= 0, minuteOfDay < 24 * 60 else { return nil }
        self.minuteOfDay = minuteOfDay
    }

    /// Die Uhrzeit, die ein Zeitpunkt in einer gegebenen Zeitzone trägt.
    ///
    /// Die Zeitzone ist Pflicht, aus demselben Grund wie bei
    /// ``CalendarDay/containing(_:in:)``: Der Aufrufer soll entscheiden, in
    /// welcher Zone ein Zeitpunkt gelesen wird — nicht die Voreinstellung.
    public static func containing(_ date: Date, in timeZone: TimeZone) -> TimeOfDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        // Der Gregorianische Kalender liefert hier immer gültige Komponenten.
        return TimeOfDay(hour: parts.hour!, minute: parts.minute!)!
    }

    // MARK: - Darstellung

    /// `14:05` — vierundzwanzig Stunden, führende Null, wie eine deutsche Uhr.
    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minuteOfDay < rhs.minuteOfDay
    }
}
