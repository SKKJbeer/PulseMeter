import Foundation

/// Ein Kalendertag ohne Uhrzeit und ohne Zeitzone.
///
/// Eine Ablesung findet „am 3. August" statt, nicht „am 3. August um 14:22 Uhr UTC".
/// Würden wir `Date` speichern, entstünden bei Zeitzonenwechseln, Sommerzeit und
/// Gerätereisen Off-by-one-Fehler, die Verbräuche verfälschen.
///
/// Persistiert wird `rawValue` im Format `yyyyMMdd` — sortierbar, vergleichbar,
/// migrationssicher. Siehe docs/01-architektur.md, ADR-004.
public struct CalendarDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {

    /// Tag im Format `yyyyMMdd`, z. B. `20260804`.
    public let rawValue: Int

    public var year: Int { rawValue / 10_000 }
    public var month: Int { (rawValue / 100) % 100 }
    public var day: Int { rawValue % 100 }

    // MARK: - Erzeugung

    /// Erzeugt einen Tag; gibt `nil` zurück, wenn das Datum nicht existiert
    /// (z. B. 30. Februar oder 29. Februar in einem Nicht-Schaltjahr).
    public init?(year: Int, month: Int, day: Int) {
        guard month >= 1, month <= 12 else { return nil }
        guard day >= 1, day <= Self.daysInMonth(year: year, month: month) else { return nil }
        self.rawValue = year * 10_000 + month * 100 + day
    }

    /// Erzeugt einen Tag aus der `yyyyMMdd`-Darstellung; validiert den Wert.
    public init?(rawValue: Int) {
        let year = rawValue / 10_000
        let month = (rawValue / 100) % 100
        let day = rawValue % 100
        self.init(year: year, month: month, day: day)
    }

    /// Der Kalendertag, auf den ein Zeitpunkt in einer gegebenen Zeitzone fällt.
    ///
    /// Die Zeitzone ist ein Pflichtparameter: Der Aufrufer soll bewusst entscheiden,
    /// in welcher Zone ein Zeitpunkt interpretiert wird.
    public static func containing(_ date: Date, in timeZone: TimeZone) -> CalendarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        // Der Gregorianische Kalender liefert hier immer gültige Komponenten.
        return CalendarDay(year: parts.year!, month: parts.month!, day: parts.day!)!
    }

    // MARK: - Rechnen

    /// Fortlaufende Tagesnummer (Julian Day Number).
    ///
    /// Rein arithmetisch, ohne `Calendar` — dadurch deterministisch, schnell und
    /// unabhängig von Zeitzonen- und Locale-Einstellungen des Geräts.
    public var serialNumber: Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045
    }

    /// Umkehrung von ``serialNumber``.
    public init(serialNumber: Int) {
        let a = serialNumber + 32_044
        let b = (4 * a + 3) / 146_097
        let c = a - 146_097 * b / 4
        let d = (4 * c + 3) / 1_461
        let e = c - 1_461 * d / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4_800 + m / 10
        self.rawValue = year * 10_000 + month * 100 + day
    }

    public func adding(days: Int) -> CalendarDay {
        CalendarDay(serialNumber: serialNumber + days)
    }

    /// Anzahl der Tage von `other` bis zu diesem Tag. Positiv, wenn dieser Tag später liegt.
    public func days(since other: CalendarDay) -> Int {
        serialNumber - other.serialNumber
    }

    // MARK: - Kalenderwissen

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    public static func daysInYear(_ year: Int) -> Int {
        isLeapYear(year) ? 366 : 365
    }

    /// Erster Tag des Monats, in dem dieser Tag liegt.
    public var startOfMonth: CalendarDay {
        CalendarDay(year: year, month: month, day: 1)!
    }

    /// Letzter Tag des Monats, in dem dieser Tag liegt.
    public var endOfMonth: CalendarDay {
        CalendarDay(year: year, month: month, day: Self.daysInMonth(year: year, month: month))!
    }

    /// Derselbe Tag im Vorjahr. Der 29. Februar wird auf den 28. Februar abgebildet,
    /// damit Vorjahresvergleiche in Schaltjahren nicht ins Leere laufen.
    public var oneYearEarlier: CalendarDay {
        if month == 2 && day == 29 {
            return CalendarDay(year: year - 1, month: 2, day: 28)!
        }
        return CalendarDay(year: year - 1, month: month, day: day)!
    }

    // MARK: - Protokolle

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Ein geschlossener Zeitraum von Kalendertagen. Start und Ende sind eingeschlossen.
public struct DayRange: Hashable, Codable, Sendable, CustomStringConvertible {

    public let start: CalendarDay
    public let end: CalendarDay

    /// Gibt `nil` zurück, wenn `end` vor `start` liegt.
    public init?(start: CalendarDay, end: CalendarDay) {
        guard start <= end else { return nil }
        self.start = start
        self.end = end
    }

    /// Anzahl der enthaltenen Tage. Ein Zeitraum vom 1. bis 1. umfasst einen Tag.
    public var dayCount: Int { end.days(since: start) + 1 }

    /// Länge des Zeitraums als Differenz, wie sie für Verbrauchsberechnungen gilt:
    /// Zwischen zwei aufeinanderfolgenden Ablesungen liegt eine Spanne, kein Tag mehr.
    public var spanInDays: Int { end.days(since: start) }

    public func contains(_ day: CalendarDay) -> Bool {
        day >= start && day <= end
    }

    /// Schnittmenge zweier Zeiträume, `nil` bei Überschneidungsfreiheit.
    public func intersection(with other: DayRange) -> DayRange? {
        DayRange(start: Swift.max(start, other.start), end: Swift.min(end, other.end))
    }

    public var description: String { "\(start) … \(end)" }
}
