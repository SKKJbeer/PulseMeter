import Foundation

/// Vorher und nachher: der Winter mit Gas oder Öl gegen den mit Wärmepumpe (1.9).
///
/// **Derselbe Ausschnitt des Jahres** (wiederkehrende Fehlerklasse,
/// CLAUDE.md). Verglichen werden nur ganze Monate, die nach dem Wechsel voll
/// gemessen sind, gegen dieselben Monate ein Jahr früher. Ein halber Winter
/// gegen einen ganzen wäre die bekannteste Art, sich eine Wärmepumpe
/// schönzurechnen. Höchstens ein Jahr, das jüngste: Fünfzehn Monate gegen
/// fünfzehn zählten drei Wintermonate doppelt. Ein ganzes Jahr steht gegen
/// die zwölf Monate vor dem Wechsel.
///
/// Das Wetter ist **nicht** ausgeglichen. Die App hat keine Wetterdaten und
/// soll ohne Netz auskommen; die Oberfläche sagt das, statt still etwas zu
/// rechnen, was sie nicht weiß (Produktprinzip 7).
public enum HeatingComparison {

    public struct Side: Hashable, Sendable {
        /// Halboffen, vom Ersten eines Monats bis zum Ersten nach dem letzten.
        public let range: DayRange
        /// Was der Zähler gemessen hat, in seiner Einheit (m³, l, kWh).
        public let quantity: Quantity
        /// Dieselbe Menge in kWh. Bei Gas und Öl nur mit Umrechnung im Tarif.
        public let kilowattHours: Quantity?
        /// Kosten mit den Tarifen, die dort galten, Grundpreis eingeschlossen.
        public let cost: Money?
    }

    public struct Result: Hashable, Sendable {
        public let before: Side
        public let after: Side
        public let monthCount: Int
        public let boilerEfficiency: Decimal
        /// Brennstoff × Wirkungsgrad. Die Wärme der Wärmepumpe bleibt ohne
        /// Wärmemengenzähler unbekannt und steht deshalb nirgends.
        public var heatBefore: Quantity? {
            before.kilowattHours.map { Quantity($0.value * boilerEfficiency, .kilowattHour) }
        }
        /// Nachher minus vorher. Negativ heißt: Die Wärmepumpe war billiger.
        public var costDifference: Money? {
            guard let a = before.cost, let b = after.cost, a.currency == b.currency else { return nil }
            return Money(b.amount - a.amount, a.currency)
        }
        /// Gekaufte kWh nachher minus vorher.
        public var energyDifference: Quantity? {
            guard let a = before.kilowattHours, let b = after.kilowattHours else { return nil }
            return Quantity(b.value - a.value, .kilowattHour)
        }
    }

    public enum Outcome: Hashable, Sendable {
        /// Noch kein ganzer Monat gemessen. Ab dem genannten Tag kann eine
        /// Zahl dastehen, wenn bis dahin abgelesen ist.
        case waiting(firstNumberOn: CalendarDay)
        /// Vom alten Zähler fehlt derselbe Ausschnitt ein Jahr früher.
        case earlierYearMissing(DayRange)
        case compared(Result)
    }

    public enum Eligibility: Hashable, Sendable {
        case eligible
        case notElectricity
        /// Der Zähler wurde schon lange vor dem Wechsel abgelesen. Er hat
        /// vorher also etwas anderes gemessen, meist das Haus.
        case measuredBefore(firstReading: CalendarDay)
    }

    /// Spielraum vor dem Wechsel: Der Zähler wird oft ein paar Tage vor der
    /// Inbetriebnahme gesetzt und einmal abgelesen.
    public static let toleranceDays = 31

    /// Ob ein Zähler als Zähler der Wärmepumpe gelten darf.
    ///
    /// Ein Zähler für Haus und Wärmepumpe zusammen stellte den Haushaltsstrom
    /// auf die Seite der Wärmepumpe, und der Vergleich würde um genau diesen
    /// Betrag schlechter. Erkennbar ist er daran, dass er lange vor dem
    /// Wechsel schon Ablesungen hat.
    public static func eligibility(
        of meter: MeteringPoint,
        readings: [Reading],
        changeDay: CalendarDay
    ) -> Eligibility {
        guard meter.kind == .electricity else { return .notElectricity }
        let ids = Set(meter.registers.filter { $0.direction == .consumption }.map(\.id))
        guard let first = readings.filter({ ids.contains($0.registerID) }).map(\.day).min() else {
            return .eligible
        }
        return changeDay.days(since: first) > toleranceDays ? .measuredBefore(firstReading: first) : .eligible
    }

    public static func compare(
        change: HeatingChange,
        old: MeteringPoint,
        new: MeteringPoint,
        readings: [Reading],
        tariffs: [Tariff],
        today: CalendarDay
    ) -> Outcome {
        let newDraws = new.registers.filter { $0.direction == .consumption }
        let oldDraws = old.registers.filter { $0.direction == .consumption }

        // Der erste ganze Monat beginnt am Ersten nach dem Wechsel und nach
        // der ersten Ablesung des neuen Zählers. Liegt die erste Ablesung am
        // 5. Oktober, ist der Oktober nicht gemessen, sondern geschätzt.
        let newSeries = newDraws.compactMap { ConsumptionSeries.build(register: $0, readings: readings) }
        var start = firstOfMonth(onOrAfter: change.day)
        if let firstNew = newSeries.compactMap(\.firstDay).max() {
            start = Swift.max(start, firstOfMonth(onOrAfter: firstNew))
        }
        // Das Ende: der letzte Monatserste, bis zu dem **alle** Zählwerke
        // reichen, und nie nach heute.
        guard newSeries.count == newDraws.count, !newDraws.isEmpty,
              let lastNew = newSeries.compactMap(\.lastDay).min() else {
            return .waiting(firstNumberOn: addingMonths(1, to: start))
        }
        let end = Swift.min(lastNew.startOfMonth, today.startOfMonth)
        let months = monthsBetween(start, end)
        guard months >= 1, let afterRange = DayRange(start: start, end: end) else {
            return .waiting(firstNumberOn: addingMonths(1, to: start))
        }
        let after: DayRange = months > 12
            ? DayRange(start: addingMonths(-12, to: end), end: end)!
            : afterRange
        let count = Swift.min(months, 12)
        // Unter einem Jahr: dieselben Monate ein Jahr früher. Ab einem ganzen
        // Jahr läge „ein Jahr früher" teils schon nach dem Wechsel, wo der
        // alte Zähler nichts mehr misst. Ein ganzes Jahr enthält jeden Monat
        // einmal; dann zählen die zwölf Monate direkt vor dem Wechsel.
        let changeMonth = change.day.startOfMonth
        let before: DayRange
        if count == 12 {
            before = DayRange(start: addingMonths(-12, to: changeMonth), end: changeMonth)!
        } else {
            guard let shifted = DayRange(start: after.start.oneYearEarlier, end: after.end.oneYearEarlier) else {
                return .waiting(firstNumberOn: addingMonths(1, to: start))
            }
            before = shifted
        }

        guard let beforeSide = side(of: old, draws: oldDraws, readings: readings,
                                    tariffs: tariffs, in: before) else {
            return .earlierYearMissing(before)
        }
        guard let afterSide = side(of: new, draws: newDraws, readings: readings,
                                   tariffs: tariffs, in: after) else {
            return .waiting(firstNumberOn: addingMonths(1, to: after.end))
        }
        return .compared(Result(before: beforeSide, after: afterSide, monthCount: count,
                                boilerEfficiency: change.boilerEfficiency))
    }

    // MARK: - Intern

    /// Eine Seite, nur wenn **jedes** Bezugszählwerk den ganzen Ausschnitt
    /// abdeckt. Eine Summe aus verschieden langen Zeiträumen wäre keine.
    private static func side(
        of meter: MeteringPoint,
        draws: [Register],
        readings: [Reading],
        tariffs: [Tariff],
        in range: DayRange
    ) -> Side? {
        guard let unit = draws.first?.unit else { return nil }
        var total = Decimal(0)
        var kwh: Decimal? = 0
        for register in draws {
            let consumed = ConsumptionEngine.consumption(register: register, readings: readings, in: range)
            guard consumed.isComplete,
                  let inUnit = try? consumed.quantity.converted(to: unit) else { return nil }
            total += inUnit.value
            if consumed.quantity.unit == .kilowattHour {
                kwh = kwh.map { $0 + consumed.quantity.value }
            } else if let energy = EnergyDisplay.kilowattHours(
                register: register, readings: readings,
                tariffs: tariffs.filter { $0.meteringPointID == meter.id }, in: range) {
                kwh = kwh.map { $0 + energy.value }
            } else {
                kwh = nil
            }
        }
        let cost = (try? CostEngine.cost(meteringPoint: meter, readings: readings,
                                         tariffs: tariffs, in: range)).flatMap { $0 }
        return Side(range: range, quantity: Quantity(total, unit),
                    kilowattHours: kwh.map { Quantity($0, .kilowattHour) },
                    cost: cost?.total)
    }

    static func firstOfMonth(onOrAfter day: CalendarDay) -> CalendarDay {
        day.day == 1 ? day : addingMonths(1, to: day.startOfMonth)
    }

    static func addingMonths(_ n: Int, to day: CalendarDay) -> CalendarDay {
        let index = day.year * 12 + (day.month - 1) + n
        let y = index >= 0 ? index / 12 : (index - 11) / 12
        return CalendarDay(year: y, month: index - y * 12 + 1, day: 1)!
    }

    static func monthsBetween(_ a: CalendarDay, _ b: CalendarDay) -> Int {
        (b.year * 12 + b.month) - (a.year * 12 + a.month)
    }
}
