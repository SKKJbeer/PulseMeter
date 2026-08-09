import Foundation

/// Stellt den Verbrauchsbericht zusammen — die Zahlen, nicht das Papier.
///
/// **Warum das hier steht und nicht in der App.** Ein Bericht ist das
/// Dokument, das der Nutzer neben die Jahresabrechnung seines Versorgers legt.
/// Steht darin eine falsche Zahl, ist der Schaden größer als bei jeder
/// Bildschirmanzeige — er hat sie ausgedruckt und weitergereicht. Der Rechenteil
/// gehört deshalb dorthin, wo er ohne Xcode und ohne Simulator prüfbar ist.
///
/// Die App setzt daraus Seiten. Diese Trennung ist dieselbe wie bei
/// ``WidgetSummary``: Wer die Zahlen woanders zeigt, holt sie hier ab, statt
/// sie ein zweites Mal zu rechnen.
public enum ReportBuilder {

    // MARK: - Zeitraum

    /// Ein Zeitraum, über den berichtet werden kann.
    ///
    /// Das Abrechnungsjahr des Versorgers beginnt selten am 1. Januar — bei
    /// Strom oft im April, bei Gas im Oktober. Genau deshalb steht es als
    /// eigene Wahl da und nicht als Kalenderjahr getarnt: Wer seine Rechnung
    /// prüfen will, braucht *ihren* Zeitraum.
    public struct Period: Hashable, Sendable, Identifiable {
        public let id: String
        public let label: String
        public let range: DayRange
        /// Ob der Zeitraum noch läuft. Bei abgeschlossenen Zeiträumen ist das
        /// Ende der Stichtag danach; angezeigt wird dann der letzte enthaltene
        /// Tag, weil „bis 1. Januar" für ein Kalenderjahr schlicht verwirrt.
        public let isRunning: Bool

        public init(id: String, label: String, range: DayRange, isRunning: Bool) {
            self.id = id
            self.label = label
            self.range = range
            self.isRunning = isRunning
        }

        /// Der letzte Tag, der noch dazugehört.
        public var lastIncludedDay: CalendarDay {
            isRunning ? range.end : range.end.adding(days: -1)
        }
    }

    /// Die Zeiträume, die zur Wahl stehen.
    ///
    /// - Parameter billingCycle: Der Abrechnungsrhythmus eines **einzelnen**
    ///   Zählers. Für einen gemeinsamen Bericht über mehrere Zähler gibt es
    ///   keinen: Strom rechnet im April ab, Gas im Oktober, und ein Zeitraum,
    ///   der für beide gilt, existiert nicht.
    public static func periods(today: CalendarDay, billingCycle: BillingCycle? = nil) -> [Period] {
        var list: [Period] = []

        if let cycle = billingCycle {
            let start = cycle.periodStart(onOrBefore: today)
            let previous = cycle.completedPeriod(before: today)
            let short = { (year: Int) in String(String(year).suffix(2)) }
            if let running = DayRange(start: start, end: today), running.spanInDays > 0 {
                list.append(Period(
                    id: "billing-current",
                    label: "Laufendes Abrechnungsjahr \(start.year)/\(short(start.year + 1))",
                    range: running, isRunning: true))
            }
            list.append(Period(
                id: "billing-last",
                label: "Abrechnungsjahr \(previous.start.year)/\(short(previous.end.year)) · abgeschlossen",
                range: previous, isRunning: false))
        }

        if let yearStart = CalendarDay(year: today.year, month: 1, day: 1),
           let ytd = DayRange(start: yearStart, end: today), ytd.spanInDays > 0 {
            list.append(Period(id: "ytd", label: "Laufendes Jahr", range: ytd, isRunning: true))
        }
        if let twelve = DayRange(start: today.oneYearEarlier, end: today) {
            list.append(Period(id: "last12", label: "Letzte 12 Monate", range: twelve, isRunning: true))
        }
        for year in [today.year - 1, today.year - 2] {
            guard let from = CalendarDay(year: year, month: 1, day: 1),
                  let to = CalendarDay(year: year + 1, month: 1, day: 1),
                  let range = DayRange(start: from, end: to) else { continue }
            list.append(Period(id: "year-\(year)", label: "Kalenderjahr \(year)",
                               range: range, isRunning: false))
        }
        return list
    }

    // MARK: - Ergebnis

    /// Eine Zeile je Zählwerk: Was es gezählt hat und was das kostet.
    public struct RegisterLine: Hashable, Sendable, Identifiable {
        public let id: Register.ID
        /// Name in der Sprache des Nutzers — „Hochtarif", „Einspeisung".
        /// `nil` bei einem Zähler mit nur einer Zahl.
        public let label: String?
        public let quantity: Quantity
        /// Der Stand am Anfang und am Ende — die Zahl, die am Tag auf dem Gerät
        /// stand, nicht der aufgelaufene Verbrauch. Ein Bericht wird gegen das
        /// Gerät gehalten.
        public let startValue: Decimal?
        public let endValue: Decimal?
        public let fractionDigits: Int
        public let isFeedIn: Bool
        /// Arbeitspreis je abgerechneter Einheit. `nil` ohne hinterlegten Tarif.
        public let pricePerUnit: Decimal?
        /// Betrag dieses Zählwerks. Bei der Einspeisung eine Gutschrift und
        /// deshalb im Gesamtbetrag abgezogen.
        public let amount: Money?
    }

    public struct MonthLine: Hashable, Sendable, Identifiable {
        public let year: Int
        public let month: Int
        public let value: Decimal
        /// Derselbe Monat des Vorjahres. `nil`, wenn er nicht vollständig
        /// abgedeckt ist — eine halbe Vergleichszahl wäre schlimmer als keine.
        public let previousValue: Decimal?
        public var id: String { "\(year)-\(month)" }

        public var relativeChange: Decimal? {
            guard let previous = previousValue, previous != 0 else { return nil }
            return (value - previous) / previous
        }
    }

    /// Ein Zähler im Bericht.
    public struct MeterSection: Hashable, Sendable, Identifiable {
        public let id: MeteringPoint.ID
        public let name: String
        public let serialNumber: String?
        /// Menge über den Zeitraum, den **alle** Bezugs-Zählwerke abdecken.
        public let consumption: ConsumptionResult
        /// Derselbe Ausschnitt im Vorjahr. `nil` ohne belastbare Daten.
        public let previous: ConsumptionResult?
        public let relativeChange: Decimal?
        public let registers: [RegisterLine]
        public let months: [MonthLine]
        public let energyAmount: Money?
        public let feedInAmount: Money?
        public let baseAmount: Money?
        public let total: Money?
        public let monthlyPrepayment: Decimal?

        /// Ob die Zahlen den angefragten Zeitraum ganz abdecken.
        public var isComplete: Bool { consumption.isComplete }
    }

    /// Der fertige Bericht.
    public struct Report: Hashable, Sendable {
        public let period: Period
        public let createdOn: CalendarDay
        public let propertyName: String
        public let sections: [MeterSection]
        public let totalCost: Money?
        /// Summe der Abschläge — nur von Zählern, für die einer hinterlegt ist.
        public let prepaymentTotal: Money?
        /// Kosten **derselben** Zähler. Alles andere gegenzurechnen erzeugte
        /// eine Nachzahlung in Höhe der übrigen Zähler.
        public let costOnAccount: Money?
        public let namesOnAccount: [String]
        /// Guthaben (positiv) oder Nachzahlung (negativ).
        public let balance: Money?
        public let hasIncompleteData: Bool
        public let hasEstimatedReadings: Bool

        public var isEmpty: Bool { sections.isEmpty }
    }

    // MARK: - Bauen

    public static func build(
        meteringPoints: [MeteringPoint],
        readings: [MeteringPoint.ID: [Reading]],
        tariffs: [MeteringPoint.ID: [Tariff]],
        prepayments: [MeteringPoint.ID: Decimal],
        period: Period,
        propertyName: String,
        today: CalendarDay
    ) -> Report {

        var sections: [MeterSection] = []
        for point in meteringPoints where !point.isArchived {
            let own = readings[point.id] ?? []
            let result = ConsumptionEngine.consumption(meteringPoint: point, readings: own,
                                                       in: period.range)
            // Ein Zähler ohne Ablesungen im Zeitraum steht nicht im Bericht.
            // Eine Zeile mit Strichen sagt nichts und macht das Dokument länger.
            guard result.hasData, let covered = result.coveredRange else { continue }

            sections.append(section(
                point: point, readings: own, tariffs: tariffs[point.id] ?? [],
                prepayment: prepayments[point.id],
                result: result, covered: covered, period: period))
        }

        let currency = sections.compactMap(\.total).first?.currency ?? .eur
        let totals = sections.compactMap(\.total)
        let totalCost = totals.isEmpty ? nil : Money(totals.reduce(Decimal(0)) { $0 + $1.amount }, currency)

        let onAccount = sections.filter { $0.monthlyPrepayment != nil && $0.total != nil }
        var prepaymentTotal: Money?
        var costOnAccount: Money?
        var balance: Money?
        if !onAccount.isEmpty {
            // Anteilige Monate des Zeitraums, tagesgenau — wie
            // ``BillingPeriod/lengthInMonths``. Zwölf Abschläge zu 160 € sind
            // 1.920 €, nicht 1.925,26 €.
            let days = Decimal(period.range.spanInDays)
            let months = days / (Decimal(CalendarDay.daysInYear(period.range.start.year)) / 12)
            let paid = onAccount.reduce(Decimal(0)) { $0 + ($1.monthlyPrepayment ?? 0) * months }
            let cost = onAccount.reduce(Decimal(0)) { $0 + ($1.total?.amount ?? 0) }
            prepaymentTotal = Money(paid, currency)
            costOnAccount = Money(cost, currency)
            balance = Money(paid - cost, currency)
        }

        return Report(
            period: period,
            createdOn: today,
            propertyName: propertyName,
            sections: sections,
            totalCost: totalCost,
            prepaymentTotal: prepaymentTotal,
            costOnAccount: costOnAccount,
            namesOnAccount: onAccount.map(\.name),
            balance: balance,
            hasIncompleteData: sections.contains { !$0.isComplete },
            hasEstimatedReadings: sections.contains { $0.consumption.confidence == .estimated }
        )
    }

    private static func section(
        point: MeteringPoint,
        readings: [Reading],
        tariffs: [Tariff],
        prepayment: Decimal?,
        result: ConsumptionResult,
        covered: DayRange,
        period: Period
    ) -> MeterSection {

        // Der Vorjahresvergleich läuft über den **abgedeckten** Ausschnitt,
        // nicht über den angefragten: Reichen die Ablesungen nur bis Mai,
        // verglichen wir sonst fünf Monate mit einem vollen Jahr.
        var previous: ConsumptionResult?
        var change: Decimal?
        if let previousRange = DayRange(start: covered.start.oneYearEarlier,
                                        end: covered.end.oneYearEarlier) {
            let earlier = ConsumptionEngine.consumption(meteringPoint: point, readings: readings,
                                                        in: previousRange)
            if earlier.hasData {
                previous = earlier
                if earlier.quantity.value != 0, earlier.coveredDays > 0, result.coveredDays > 0 {
                    let now = result.quantity.value / Decimal(result.coveredDays)
                    let then = earlier.quantity.value / Decimal(earlier.coveredDays)
                    if then != 0 { change = (now - then) / then }
                }
            }
        }

        let many = point.registers.count > 1
        var lines: [RegisterLine] = []
        for register in point.registers {
            let part = ConsumptionEngine.consumption(register: register, readings: readings, in: covered)
            let cost = try? CostEngine.cost(register: register, readings: readings,
                                            tariffs: tariffs, in: covered)
            let tariff = (try? CostEngine.segmentsOfValidity(for: register, tariffs: tariffs,
                                                             in: covered))?.first?.1
            lines.append(RegisterLine(
                id: register.id,
                label: many ? (register.label ?? TableExport.name(of: register)) : nil,
                quantity: part.quantity,
                startValue: rawReading(readings, register: register, on: covered.start),
                endValue: rawReading(readings, register: register, on: covered.end),
                fractionDigits: register.fractionDigits,
                isFeedIn: register.direction == .feedIn,
                pricePerUnit: tariff.map { CostEngine.price(for: register, tariff: $0) },
                amount: cost.map(\.energyAmount)
            ))
        }

        // Ausdrücklich mit `do`/`catch` statt `try?`: Die Rechnung über die
        // ganze Messstelle gibt `CostResult?` zurück **und** wirft. Ein `try?`
        // darauf ergibt je nach Lesart ein einfach oder doppelt verpacktes
        // Ergebnis — und genau daran entstehen die Fehler, die erst der
        // Compiler und dann niemand mehr sieht.
        let total: CostEngine.CostResult?
        do {
            total = try CostEngine.cost(meteringPoint: point, readings: readings,
                                        tariffs: tariffs, in: covered)
        } catch {
            total = nil
        }

        let feedIn = lines.filter(\.isFeedIn).compactMap(\.amount)
        let currency = total?.total.currency ?? .eur

        return MeterSection(
            id: point.id,
            name: point.name,
            serialNumber: point.devices.first(where: \.isActive)?.serialNumber,
            consumption: result,
            previous: previous,
            relativeChange: change,
            registers: lines,
            months: monthLines(point: point, readings: readings, covered: covered),
            energyAmount: total?.energyAmount,
            feedInAmount: feedIn.isEmpty ? nil : Money(feedIn.reduce(Decimal(0)) { $0 + $1.amount }, currency),
            baseAmount: total?.baseAmount,
            total: total?.total,
            monthlyPrepayment: prepayment
        )
    }

    /// Der Stand, der an einem Tag auf dem Gerät stand.
    ///
    /// Nicht der aufgelaufene Verbrauch aus ``ConsumptionSeries``: Ein Bericht
    /// wird neben den Zähler gehalten, und dort steht eine sechsstellige Zahl,
    /// keine Differenz.
    ///
    /// Zwischen zwei Ablesungen wird linear eingesetzt — aber **nicht** über
    /// einen Rücksprung hinweg. Nach einem Gerätewechsel oder einem Überlauf
    /// ergäbe die Gerade eine Zahl, die auf keinem der beiden Geräte je stand.
    static func rawReading(_ readings: [Reading], register: Register, on day: CalendarDay) -> Decimal? {
        let own = readings.forRegister(register.id).chronological()
        guard !own.isEmpty else { return nil }
        if let exact = own.last(where: { $0.day == day }) { return exact.value }
        guard let before = own.last(where: { $0.day < day }) else { return own.first?.value }
        guard let after = own.first(where: { $0.day > day }), after.value >= before.value else {
            return before.value
        }
        let span = Decimal(after.day.days(since: before.day))
        guard span > 0 else { return before.value }
        let offset = Decimal(day.days(since: before.day))
        return before.value + (after.value - before.value) * offset / span
    }

    /// Monatstabelle über den abgedeckten Ausschnitt, jeder Monat gegen
    /// denselben Monat des Vorjahres.
    ///
    /// Nur **vollständige** Monate: Ein angefangener Monat neben elf ganzen
    /// sieht in einer Tabelle aus wie ein sparsamer Monat. Das ist wieder die
    /// wiederkehrende Fehlerklasse, nur in Tabellenform.
    private static func monthLines(
        point: MeteringPoint,
        readings: [Reading],
        covered: DayRange
    ) -> [MonthLine] {

        var lines: [MonthLine] = []
        var year = covered.start.year
        var month = covered.start.month
        while let start = CalendarDay(year: year, month: month, day: 1), start < covered.end {
            let nextMonth = month == 12 ? 1 : month + 1
            let nextYear = month == 12 ? year + 1 : year
            if let end = CalendarDay(year: nextYear, month: nextMonth, day: 1),
               let range = DayRange(start: start, end: end) {
                let now = ConsumptionEngine.consumption(meteringPoint: point, readings: readings, in: range)
                if now.isComplete {
                    var earlier: Decimal?
                    if let previousRange = DayRange(start: start.oneYearEarlier, end: end.oneYearEarlier) {
                        let result = ConsumptionEngine.consumption(meteringPoint: point,
                                                                   readings: readings, in: previousRange)
                        if result.isComplete { earlier = result.quantity.value }
                    }
                    lines.append(MonthLine(year: year, month: month,
                                           value: now.quantity.value, previousValue: earlier))
                }
            }
            year = nextYear
            month = nextMonth
        }
        return lines
    }
}
