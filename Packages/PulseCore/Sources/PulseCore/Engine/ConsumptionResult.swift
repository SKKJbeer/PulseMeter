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

    public init(
        quantity: Quantity,
        confidence: Confidence,
        requestedRange: DayRange,
        coveredRange: DayRange?,
        warnings: [ConsumptionWarning]
    ) {
        self.quantity = quantity
        self.confidence = confidence
        self.requestedRange = requestedRange
        self.coveredRange = coveredRange
        self.warnings = warnings
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
