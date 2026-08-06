import Foundation

/// Berechnet Verbräuche aus Ablesungen.
///
/// Reine Funktionen über Wertetypen: keine Persistenz, keine Nebenwirkungen,
/// kein Zustand. Dadurch vollständig testbar — und weil dieses Paket nur
/// Foundation importiert, auch ohne Xcode und ohne Simulator.
public enum ConsumptionEngine {

    // MARK: - Verbrauch

    public static func consumption(
        register: Register,
        readings: [Reading],
        in range: DayRange
    ) -> ConsumptionResult {
        guard let series = ConsumptionSeries.build(register: register, readings: readings) else {
            return .empty(unit: register.unit, range: range, warnings: [.insufficientReadings])
        }
        return consumption(series: series, in: range)
    }

    public static func consumption(
        series: ConsumptionSeries,
        in range: DayRange
    ) -> ConsumptionResult {
        guard let first = series.firstDay, let last = series.lastDay else {
            return .empty(unit: series.unit, range: range, warnings: [.insufficientReadings])
        }

        var warnings = series.warnings(in: range)
        if range.start < first { warnings.append(.noDataBeforeStart(firstReading: first)) }
        if range.end > last { warnings.append(.noDataAfterEnd(lastReading: last)) }

        guard let covered = DayRange(start: Swift.max(range.start, first),
                                     end: Swift.min(range.end, last)),
              covered.spanInDays > 0,
              let start = series.cumulative(at: covered.start),
              let end = series.cumulative(at: covered.end)
        else {
            return .empty(unit: series.unit, range: range, warnings: warnings)
        }

        var confidence: Confidence = (start.isExact && end.isExact) ? .measured : .interpolated
        if series.containsEstimates(in: covered) {
            confidence = confidence.degraded(to: .estimated)
        }

        return ConsumptionResult(
            quantity: Quantity(end.value - start.value, series.unit),
            confidence: confidence,
            requestedRange: range,
            coveredRange: covered,
            warnings: warnings,
            longestGapInDays: series.longestGap(in: covered)
        )
    }

    // MARK: - Vergleiche

    /// Vergleich eines Zeitraums mit demselben Zeitraum im Vorjahr.
    public struct YearComparison: Hashable, Sendable {
        public let current: ConsumptionResult
        public let previous: ConsumptionResult
        /// Relative Veränderung, z. B. `-0.07` für sieben Prozent weniger.
        /// `nil`, wenn im Vorjahr keine belastbaren Daten vorliegen.
        public let relativeChange: Decimal?

        public var isImprovement: Bool? {
            relativeChange.map { $0 < 0 }
        }
    }

    public static func yearOverYear(
        register: Register,
        readings: [Reading],
        in range: DayRange
    ) -> YearComparison? {
        guard let series = ConsumptionSeries.build(register: register, readings: readings) else {
            return nil
        }

        let current = consumption(series: series, in: range)

        // Das Vorjahresfenster folgt dem *abgedeckten* Zeitraum, nicht dem
        // angefragten. Reicht die Historie bis August, die aktuellen Daten aber
        // nur bis Mai, verglichen wir sonst eine halbe Heizperiode mit einem
        // vollen Jahr inklusive Sommer — eine Zahl, die nichts bedeutet.
        guard let covered = current.coveredRange,
              let previousRange = DayRange(start: covered.start.oneYearEarlier,
                                           end: covered.end.oneYearEarlier)
        else { return nil }

        let previous = consumption(series: series, in: previousRange)

        var change: Decimal?
        if previous.hasData, current.hasData, previous.quantity.value != 0 {
            // Auf Tagesbasis normalisieren: Zeiträume unterschiedlicher Länge —
            // etwa durch ein Schaltjahr — wären sonst nicht vergleichbar.
            let currentPerDay = current.quantity.value / Decimal(current.coveredDays)
            let previousPerDay = previous.quantity.value / Decimal(previous.coveredDays)
            if previousPerDay != 0 {
                change = (currentPerDay - previousPerDay) / previousPerDay
            }
        }

        return YearComparison(current: current, previous: previous, relativeChange: change)
    }

    // MARK: - Plausibilität bei der Eingabe

    /// Einschätzung eines eingetippten Wertes, noch während der Nutzer tippt.
    ///
    /// Der häufigste Datenfehler ist der Tippfehler, und er fällt erst Monate
    /// später auf — dann, wenn ein Diagramm absurd aussieht und der Nutzer der
    /// App nicht mehr traut. Die Prüfung im Moment der Eingabe ist der billigste
    /// Ort, das zu verhindern. Siehe docs/03-ux-konzept.md, Abschnitt 3.
    public enum Plausibility: Hashable, Sendable {
        /// Kein Vergleichswert vorhanden — die erste Ablesung ist immer gültig.
        case noReference
        /// Im gewohnten Rahmen.
        case normal(consumption: Quantity, days: Int)
        /// Auffällig, aber möglich. Ein ruhiger Hinweis, keine Blockade.
        case unusual(consumption: Quantity, days: Int, factorOfUsual: Decimal)
        /// Der Wert liegt unter dem letzten Stand.
        case belowPrevious(previous: Decimal)
        /// Das Datum liegt in der Zukunft.
        case futureDate
    }

    /// Ab welchem Vielfachen des gewohnten Tagesverbrauchs ein Wert als
    /// auffällig gilt. Bewusst großzügig: Ein Heizmonat kann das Dreifache eines
    /// Sommermonats betragen, ohne falsch zu sein. Wir warnen vor Tippfehlern —
    /// typischerweise Faktor 10 — nicht vor kalten Wintern.
    static let unusualFactor = Decimal(4)

    public static func plausibility(
        of value: Decimal,
        on day: CalendarDay,
        register: Register,
        readings: [Reading],
        today: CalendarDay
    ) -> Plausibility {
        if day > today { return .futureDate }

        let history = readings.forRegister(register.id).chronological()
        guard let previous = history.last(where: { $0.day <= day }) else {
            return .noReference
        }

        let days = day.days(since: previous.day)
        guard days > 0 else { return .noReference }

        if value < previous.value {
            let isNearCapacity = register.capacity > 0
                && previous.value >= register.capacity * ConsumptionSeries.rolloverThreshold
            if !isNearCapacity {
                return .belowPrevious(previous: previous.value)
            }
        }

        let delta = value >= previous.value
            ? value - previous.value
            : register.capacity - previous.value + value
        let quantity = Quantity(delta, register.unit)

        guard let series = ConsumptionSeries.build(register: register, readings: history) else {
            return .normal(consumption: quantity, days: days)
        }
        guard let usualPerDay = referenceRate(series: series, from: previous.day, to: day),
              usualPerDay > 0
        else {
            return .normal(consumption: quantity, days: days)
        }
        let candidatePerDay = delta / Decimal(days)

        let factor = candidatePerDay / usualPerDay
        if factor >= unusualFactor || factor <= 1 / unusualFactor {
            return .unusual(consumption: quantity, days: days, factorOfUsual: factor)
        }
        return .normal(consumption: quantity, days: days)
    }

    /// Der Tagesverbrauch, an dem ein neuer Wert gemessen wird.
    ///
    /// Zuerst derselbe Zeitraum im Vorjahr, erst danach der Gesamtdurchschnitt.
    /// Der Unterschied ist bei Heizung und Gas entscheidend: Im Juli liegt der
    /// Gasverbrauch weit unter dem Jahresmittel. Gegen den Jahresschnitt geprüft
    /// würde jede korrekte Sommerablesung als unplausibel gemeldet — und ein um
    /// eine Stelle zu hoher Wert liefe glatt durch. Genau verkehrt herum.
    static func referenceRate(
        series: ConsumptionSeries,
        from previousDay: CalendarDay,
        to day: CalendarDay
    ) -> Decimal? {
        if let priorRange = DayRange(start: previousDay.oneYearEarlier, end: day.oneYearEarlier) {
            let prior = consumption(series: series, in: priorRange)
            if prior.isComplete, prior.coveredDays > 0, prior.quantity.value > 0 {
                return prior.quantity.value / Decimal(prior.coveredDays)
            }
        }
        // Kein Vorjahr vorhanden — dann der bisherige Durchschnitt.
        guard let firstDay = series.firstDay,
              let range = DayRange(start: firstDay, end: previousDay),
              range.spanInDays > 0
        else { return nil }

        let past = consumption(series: series, in: range)
        guard past.hasData, past.quantity.value > 0, past.coveredDays > 0 else { return nil }
        return past.quantity.value / Decimal(past.coveredDays)
    }

    // MARK: - Datenlücken

    /// Ob für eine Messstelle eine Ablesung fällig ist.
    public static func isReadingDue(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        today: CalendarDay
    ) -> Bool {
        guard let expected = meteringPoint.readingInterval.approximateDays else { return false }
        guard !meteringPoint.isArchived else { return false }

        let relevantIDs = Set(meteringPoint.registers.map(\.id))
        let last = readings
            .filter { relevantIDs.contains($0.registerID) }
            .map(\.day)
            .max()

        guard let last else { return true }
        return today.days(since: last) >= expected
    }
}
