import Foundation

/// Eine bereinigte, streng monoton steigende Zeitreihe eines Zählwerks.
///
/// Das Kernproblem: Der abgelesene Zählerstand ist *nicht* monoton. Er springt
/// beim Überlauf auf null zurück und beim Gerätewechsel auf den Anfangsstand des
/// neuen Geräts. Rechnet man naiv Differenzen, entstehen negative Verbräuche —
/// der sichtbarste Fehler vergleichbarer Apps.
///
/// `ConsumptionSeries` bildet die Ablesungen auf einen gedachten Zähler ab, der
/// bei null beginnt und nie zurückspringt. Alle weiteren Berechnungen arbeiten
/// ausschließlich auf dieser Reihe.
public struct ConsumptionSeries: Sendable {

    public struct Point: Hashable, Sendable {
        public let day: CalendarDay
        /// Stand des gedachten, lückenlosen Zählers.
        public let cumulative: Decimal
        /// Ob an diesem Punkt eine als Schätzung markierte Ablesung liegt.
        public let isEstimated: Bool
    }

    public let unit: MeasurementUnit
    public let points: [Point]
    public let warnings: [ConsumptionWarning]

    public var firstDay: CalendarDay? { points.first?.day }
    public var lastDay: CalendarDay? { points.last?.day }
    public var totalConsumption: Quantity {
        Quantity(points.last.map { $0.cumulative } ?? 0, unit)
    }

    /// Ab diesem Anteil der Zählwerk-Kapazität gilt ein Rücksprung als Überlauf.
    ///
    /// Ein Zählerstand von 998.500 bei sechsstelligem Werk steht kurz vor dem
    /// Überlauf; ein Stand von 4.200 tut das nicht. Ohne diese Schwelle würde
    /// jeder Tippfehler als Überlauf durchgehen und einen absurd hohen Verbrauch
    /// erzeugen — schlimmer als gar kein Ergebnis.
    static let rolloverThreshold = Decimal(string: "0.9")!

    // MARK: - Aufbau

    /// Baut die Reihe aus den Ablesungen eines Zählwerks auf.
    /// Gibt `nil` zurück, wenn keine Ablesung vorliegt.
    public static func build(register: Register, readings: [Reading]) -> ConsumptionSeries? {
        let relevant = readings.forRegister(register.id).chronological()
        guard !relevant.isEmpty else { return nil }

        switch register.accumulation {
        case .cumulative:
            return buildCumulative(register: register, readings: relevant)
        case .interval:
            return buildInterval(register: register, readings: relevant)
        }
    }

    private static func buildCumulative(register: Register, readings: [Reading]) -> ConsumptionSeries {
        var points: [Point] = [
            Point(day: readings[0].day, cumulative: 0, isEstimated: readings[0].isEstimated)
        ]
        var warnings: [ConsumptionWarning] = []
        var running = Decimal(0)

        for index in 1..<readings.count {
            let previous = readings[index - 1]
            let current = readings[index]
            let step = self.step(from: previous, to: current, register: register)
            running += step.delta
            warnings.append(contentsOf: step.warnings)

            let point = Point(
                day: current.day,
                cumulative: running,
                isEstimated: current.isEstimated
            )
            // Am Tag eines Gerätewechsels liegen zwei Ablesungen. Für die
            // Interpolation zählt der Stand nach beiden — der spätere Punkt
            // ersetzt den früheren desselben Tages.
            if points.last?.day == current.day {
                points[points.count - 1] = point
            } else {
                points.append(point)
            }
        }

        if readings.count == 1 {
            warnings.append(.insufficientReadings)
        }
        return ConsumptionSeries(unit: register.unit, points: points, warnings: warnings)
    }

    /// Zählwerke im Intervallmodus erfassen Mengen statt Ständen (z. B.
    /// Heizöl-Lieferungen). Die Reihe wird durch Aufsummieren gebildet; der
    /// erste Punkt liegt einen Tag vor der ersten Menge, damit diese im
    /// Zeitraum vollständig enthalten ist.
    private static func buildInterval(register: Register, readings: [Reading]) -> ConsumptionSeries {
        var points: [Point] = [
            Point(day: readings[0].day.adding(days: -1), cumulative: 0, isEstimated: false)
        ]
        var running = Decimal(0)

        for reading in readings {
            running += reading.value
            let point = Point(day: reading.day, cumulative: running, isEstimated: reading.isEstimated)
            if points.last?.day == reading.day {
                points[points.count - 1] = point
            } else {
                points.append(point)
            }
        }
        return ConsumptionSeries(unit: register.unit, points: points, warnings: [])
    }

    /// Verbrauch zwischen zwei aufeinanderfolgenden Ablesungen.
    ///
    /// Hier liegen die Randfälle aus docs/02-datenmodell.md, Abschnitt 3.
    private static func step(
        from previous: Reading,
        to current: Reading,
        register: Register
    ) -> (delta: Decimal, warnings: [ConsumptionWarning]) {

        // Gerätewechsel: Der Rücksprung ist erklärt. Zwischen dem Endstand des
        // alten und dem Anfangsstand des neuen Geräts vergeht kein Verbrauch —
        // beide Ablesungen beschreiben denselben Moment.
        if let a = previous.deviceID, let b = current.deviceID, a != b {
            return (0, [.deviceChange(on: current.day)])
        }

        if current.value >= previous.value {
            return (current.value - previous.value, [])
        }

        // Rücksprung ohne Gerätewechsel: Überlauf oder Fehleingabe.
        let capacity = register.capacity
        let isNearCapacity = capacity > 0 && previous.value >= capacity * rolloverThreshold
        if isNearCapacity {
            return (capacity - previous.value + current.value, [.rolloverAssumed(on: current.day)])
        }

        // Nicht raten. Der Abschnitt zählt als null, die Warnung erlaubt der
        // Oberfläche eine gezielte Rückfrage: Gerätewechsel oder Tippfehler?
        return (0, [.unexplainedDecrease(
            on: current.day,
            previous: previous.value,
            current: current.value
        )])
    }

    // MARK: - Auswertung

    /// Stand des gedachten Zählers an einem Tag.
    ///
    /// Zwischen zwei Ablesungen wird linear interpoliert. Außerhalb des
    /// abgedeckten Bereichs wird **nicht** extrapoliert — eine Hochrechnung ist
    /// eine eigene, ausdrücklich als solche gekennzeichnete Operation
    /// (siehe ``ForecastEngine``).
    public func cumulative(at day: CalendarDay) -> (value: Decimal, isExact: Bool)? {
        guard let first = points.first, let last = points.last else { return nil }
        guard day >= first.day, day <= last.day else { return nil }

        var lower = points[0]
        for point in points {
            if point.day == day {
                return (point.cumulative, true)
            }
            if point.day < day {
                lower = point
            } else {
                let span = point.day.days(since: lower.day)
                guard span > 0 else { return (point.cumulative, false) }
                let elapsed = day.days(since: lower.day)
                let fraction = Decimal(elapsed) / Decimal(span)
                let interpolated = lower.cumulative + (point.cumulative - lower.cumulative) * fraction
                return (interpolated, false)
            }
        }
        return (last.cumulative, true)
    }

    /// Ob im Zeitraum eine als Schätzung markierte Ablesung liegt.
    func containsEstimates(in range: DayRange) -> Bool {
        points.contains { $0.isEstimated && range.contains($0.day) }
    }

    /// Warnungen, die einen Tag innerhalb des Zeitraums betreffen.
    func warnings(in range: DayRange) -> [ConsumptionWarning] {
        warnings.filter { warning in
            switch warning {
            case .rolloverAssumed(let day),
                 .deviceChange(let day),
                 .unexplainedDecrease(let day, _, _):
                return range.contains(day)
            case .noDataBeforeStart, .noDataAfterEnd, .insufficientReadings:
                return true
            }
        }
    }
}
