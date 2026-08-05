import Foundation

/// Wie belastbar ein berechneter Wert ist.
///
/// Jedes Ergebnis des Rechenkerns führt seine Verlässlichkeit mit sich. Dadurch
/// *kann* die Oberfläche eine interpolierte Zahl nicht wie eine gemessene
/// darstellen — Produktprinzip 7 ist damit technisch erzwungen statt nur
/// vorgenommen. Siehe docs/00-produktstrategie.md, Abschnitt 5.
public enum Confidence: Int, Hashable, Codable, Sendable, Comparable, CaseIterable {
    /// Beide Grenzen des Zeitraums liegen auf tatsächlichen Ablesetagen.
    case measured = 0
    /// Mindestens eine Grenze wurde zwischen zwei Ablesungen interpoliert.
    case interpolated = 1
    /// Es fließen vom Nutzer als Schätzung markierte Werte ein.
    case estimated = 2

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Die schlechtere der beiden Einstufungen.
    public func degraded(to other: Confidence) -> Confidence {
        Swift.max(self, other)
    }
}

/// Auffälligkeiten, die bei der Berechnung erkannt wurden.
///
/// Warnungen werden nie stillschweigend verworfen. Die Oberfläche entscheidet,
/// welche sie zeigt — der Rechenkern verschweigt keine.
public enum ConsumptionWarning: Hashable, Codable, Sendable {
    /// Der Zählerstand ist gesunken und ein Überlauf war plausibel; es wurde
    /// über den Überlaufpunkt hinweg gerechnet.
    case rolloverAssumed(on: CalendarDay)
    /// Zwischen zwei Ablesungen wurde das Gerät gewechselt. Über die Lücke
    /// hinweg wird kein Verbrauch angerechnet.
    case deviceChange(on: CalendarDay)
    /// Der Zählerstand ist gesunken, ohne dass Überlauf oder Gerätewechsel das
    /// erklären. Es wird nicht geraten — dieser Abschnitt zählt als null.
    case unexplainedDecrease(on: CalendarDay, previous: Decimal, current: Decimal)
    /// Der angefragte Zeitraum beginnt vor der ersten Ablesung.
    case noDataBeforeStart(firstReading: CalendarDay)
    /// Der angefragte Zeitraum endet nach der letzten Ablesung.
    case noDataAfterEnd(lastReading: CalendarDay)
    /// Weniger als zwei Ablesungen — ein Verbrauch ist nicht bestimmbar.
    case insufficientReadings
}

/// Ergebnis einer Verbrauchsberechnung.
///
/// Enthält nie nur eine Zahl, sondern immer auch deren Qualität.
public struct ConsumptionResult: Hashable, Sendable {

    public let quantity: Quantity
    public let confidence: Confidence
    /// Der angefragte Zeitraum.
    public let requestedRange: DayRange
    /// Der Teil des Zeitraums, für den Daten vorliegen. `nil`, wenn keine.
    public let coveredRange: DayRange?
    public let warnings: [ConsumptionWarning]
    /// Größter Abstand zwischen zwei Ablesungen, über den für dieses Ergebnis
    /// interpoliert wurde.
    public let longestGapInDays: Int

    public init(
        quantity: Quantity,
        confidence: Confidence,
        requestedRange: DayRange,
        coveredRange: DayRange?,
        warnings: [ConsumptionWarning],
        longestGapInDays: Int = 0
    ) {
        self.quantity = quantity
        self.confidence = confidence
        self.requestedRange = requestedRange
        self.coveredRange = coveredRange
        self.warnings = warnings
        self.longestGapInDays = longestGapInDays
    }

    /// Ob die Zahl auf Ablesungen aus diesem Zeitraum beruht — und nicht auf
    /// einer Geraden, die weit darüber hinweggelegt wurde.
    ///
    /// Die Grenze liegt beim Doppelten der Zeitraumlänge. Sie ist großzügig
    /// gewählt: Wer monatlich abliest, trifft den Monatsersten selten genau,
    /// und ein Abstand von 31 Tagen für einen 28-Tage-Monat ist völlig normal.
    /// Ein Abstand von einem Jahr für einen Monat ist es nicht — dann steht da
    /// ein anteiliger Jahresschnitt und keine Aussage über den Monat.
    public var restsOnOwnReadings: Bool {
        longestGapInDays <= 2 * Swift.max(1, requestedRange.spanInDays)
    }

    /// Anzahl der Tage, über die tatsächlich gerechnet werden konnte.
    public var coveredDays: Int { coveredRange?.spanInDays ?? 0 }

    /// Ob für den gesamten angefragten Zeitraum Daten vorlagen.
    public var isComplete: Bool {
        guard let covered = coveredRange else { return false }
        return covered.start == requestedRange.start && covered.end == requestedRange.end
    }

    public var hasData: Bool { coveredDays > 0 }

    /// Durchschnittlicher Verbrauch je Tag im abgedeckten Zeitraum.
    public var dailyAverage: Quantity? {
        guard coveredDays > 0 else { return nil }
        return Quantity(quantity.value / Decimal(coveredDays), quantity.unit)
    }

    /// Wie weit die Zahl den angefragten Zeitraum tatsächlich abdeckt.
    ///
    /// Der Grund für diesen Typ steht in CLAUDE.md unter „Wiederkehrende
    /// Fehlerklasse": Bisher entstand *jeder* gefundene Rechenfehler daraus,
    /// dass ein Zeitraum, den die Daten abdecken, wie einer behandelt wurde,
    /// den sie nicht abdecken. Zuletzt auf der Übersicht selbst — dort stand
    /// „1.181 m³" für ein Jahr, dessen Daten im Mai enden.
    ///
    /// Als Aufzählung statt als Menge von Merkmalen, weil ein vollständiger
    /// `switch` den Aufrufer zwingt, den unvollständigen Fall zu beschriften.
    /// Ein `if result.isComplete` lässt sich vergessen, ein fehlender Fall
    /// nicht — er übersetzt nicht.
    public enum Coverage: Hashable, Sendable {
        /// Keine Daten im angefragten Zeitraum.
        case none
        /// Deckt den angefragten Zeitraum vollständig ab.
        case full
        /// Beginnt erst später — davor gibt es keine Ablesungen.
        case startsLate(firstDay: CalendarDay)
        /// Endet früher — der Zähler wurde seitdem nicht abgelesen.
        case endsEarly(lastDay: CalendarDay)
        /// An beiden Enden verkürzt.
        case partial(firstDay: CalendarDay, lastDay: CalendarDay)
    }

    public var coverage: Coverage {
        guard let covered = coveredRange, coveredDays > 0 else { return .none }
        let late = covered.start > requestedRange.start
        let early = covered.end < requestedRange.end
        switch (late, early) {
        case (false, false): return .full
        case (true, false): return .startsLate(firstDay: covered.start)
        case (false, true): return .endsEarly(lastDay: covered.end)
        case (true, true): return .partial(firstDay: covered.start, lastDay: covered.end)
        }
    }

    static func empty(unit: MeasurementUnit, range: DayRange, warnings: [ConsumptionWarning]) -> ConsumptionResult {
        ConsumptionResult(
            quantity: .zero(unit),
            confidence: .estimated,
            requestedRange: range,
            coveredRange: nil,
            warnings: warnings
        )
    }
}
