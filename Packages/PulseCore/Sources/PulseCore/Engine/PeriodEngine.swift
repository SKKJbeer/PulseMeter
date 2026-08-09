import Foundation

/// Zerlegt eine Zeitreihe in Monate, Quartale und Jahre.
///
/// Der Verlauf-Bildschirm zeigt dieselben Daten in mehreren Auflösungen und
/// stellt sie nebeneinander. Genau dabei ist in diesem Projekt bisher jeder
/// Rechenfehler entstanden — ein Zeitraum, den die Daten abdecken, verglichen
/// mit einem, den sie nicht abdecken. Deshalb rechnet die Ansicht nicht selbst,
/// sondern bekommt fertige Abschnitte, die ihren abgedeckten Bereich
/// mitführen (siehe ``ConsumptionResult/coverage``).
public enum PeriodEngine {

    public enum Granularity: Hashable, Sendable, CaseIterable {
        case month, quarter, year

        /// Wie viele Abschnitte ein Jahr enthält.
        public var slotsPerYear: Int {
            switch self {
            case .month: return 12
            case .quarter: return 4
            case .year: return 1
            }
        }
    }

    /// Ein Abschnitt der Zeitreihe.
    public struct Bucket: Hashable, Sendable, Identifiable {
        public let year: Int
        /// 1…12 beim Monat, 1…4 beim Quartal, immer 1 beim Jahr.
        public let slot: Int
        public let granularity: Granularity
        /// Der angefragte Abschnitt, von Anfang bis Anfang des nächsten:
        /// Zwischen zwei Ablesungen liegt eine Spanne, kein Tag mehr.
        public let range: DayRange
        public let result: ConsumptionResult

        public var id: String { "\(year)-\(granularity)-\(slot)" }
        public var value: Decimal { result.quantity.value }
        public var hasData: Bool { result.hasData }
        /// Ob der Abschnitt vollständig durch Ablesungen gedeckt ist.
        public var isComplete: Bool { result.isComplete }
    }

    // MARK: - Abschnitte bilden

    /// Grenzen eines Abschnitts: vom ersten Tag bis zum ersten Tag des nächsten.
    public static func range(year: Int, slot: Int, granularity: Granularity) -> DayRange? {
        let startMonth: Int
        let monthCount: Int
        switch granularity {
        case .month:
            guard (1...12).contains(slot) else { return nil }
            startMonth = slot
            monthCount = 1
        case .quarter:
            guard (1...4).contains(slot) else { return nil }
            startMonth = (slot - 1) * 3 + 1
            monthCount = 3
        case .year:
            startMonth = 1
            monthCount = 12
        }
        var endMonth = startMonth + monthCount
        var endYear = year
        while endMonth > 12 { endMonth -= 12; endYear += 1 }
        guard let start = CalendarDay(year: year, month: startMonth, day: 1),
              let end = CalendarDay(year: endYear, month: endMonth, day: 1)
        else { return nil }
        return DayRange(start: start, end: end)
    }

    /// Alle Abschnitte eines Jahres.
    ///
    /// Auch Abschnitte ohne Daten kommen zurück — eine Lücke ist eine Aussage,
    /// und wer sie auslässt, zeichnet ein Jahr, das nie stattgefunden hat.
    /// Ob Daten vorliegen, steht in ``Bucket/hasData``.
    public static func buckets(
        series: ConsumptionSeries,
        year: Int,
        granularity: Granularity
    ) -> [Bucket] {
        (1...granularity.slotsPerYear).compactMap { slot in
            guard let range = range(year: year, slot: slot, granularity: granularity) else { return nil }
            return Bucket(
                year: year,
                slot: slot,
                granularity: granularity,
                range: range,
                result: ConsumptionEngine.consumption(series: series, in: range)
            )
        }
    }

    public static func buckets(
        register: Register,
        readings: [Reading],
        year: Int,
        granularity: Granularity
    ) -> [Bucket] {
        guard let series = ConsumptionSeries.build(register: register, readings: readings) else { return [] }
        return buckets(series: series, year: year, granularity: granularity)
    }

    /// Abschnitte für einen ganzen Zähler — bei Doppeltarif die Summe beider
    /// Zählwerke, je Abschnitt auf den gemeinsam abgedeckten Ausschnitt
    /// zugeschnitten.
    public static func buckets(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        year: Int,
        granularity: Granularity
    ) -> [Bucket] {
        (1...granularity.slotsPerYear).compactMap { slot in
            guard let range = range(year: year, slot: slot, granularity: granularity) else { return nil }
            return Bucket(
                year: year,
                slot: slot,
                granularity: granularity,
                range: range,
                result: ConsumptionEngine.consumption(meteringPoint: meteringPoint,
                                                      readings: readings, in: range)
            )
        }
    }

    // MARK: - Derselbe Abschnitt über mehrere Jahre

    /// „Februar 2026 gegen Februar 2025" — die Frage, für die es diese App gibt.
    public struct SlotComparison: Hashable, Sendable {
        public struct Entry: Hashable, Sendable, Identifiable {
            public let year: Int
            public let result: ConsumptionResult
            public var id: Int { year }
            public var value: Decimal { result.quantity.value }
            public var hasData: Bool { result.hasData }

            /// Ob dieses Jahr den Ausschnitt **vollständig** abdeckt.
            ///
            /// Nur dann darf die Zahl neben die anderen gestellt werden. Ein
            /// Jahr, das den halben Ausschnitt abdeckt, hätte einen halb so
            /// großen Balken — und sähe aus wie ein sparsames Jahr, statt wie
            /// eines mit fehlenden Ablesungen.
            ///
            /// ``ConsumptionResult/isComplete`` allein genügt nicht: Es sagt
            /// nur, dass der Ausschnitt innerhalb der Reihe liegt. Liegt
            /// zwischen den beiden nächstgelegenen Ablesungen ein ganzes Jahr,
            /// ist der Ausschnitt formal gedeckt und die Zahl trotzdem nur ein
            /// anteilig ausgeschnittener Jahresschnitt.
            public var isComparable: Bool { result.isComplete && result.restsOnOwnReadings }
        }

        public let slot: Int
        public let granularity: Granularity
        /// Neueste zuerst.
        public let entries: [Entry]
        /// Der Ausschnitt im Bezugsjahr, auf den alle Einträge beschnitten sind.
        public let window: DayRange
        /// Ob dieser Ausschnitt kürzer ist als der volle Abschnitt — dann ist
        /// der laufende Monat gemeint und die Beschriftung muss das sagen.
        public let isPartial: Bool

        /// Veränderung des Bezugsjahres gegenüber dem Jahr davor, `nil`, wenn
        /// eines von beiden keine Daten hat.
        public var relativeChange: Decimal? {
            guard entries.count >= 2 else { return nil }
            let current = entries[0], previous = entries[1]
            guard current.isComparable, previous.isComparable, previous.value != 0 else { return nil }
            return (current.value - previous.value) / previous.value
        }
    }

    /// Vergleicht denselben Abschnitt über mehrere Jahre — auf **demselben**
    /// Ausschnitt des Jahres.
    ///
    /// Der Ausschnitt kommt aus dem Bezugsjahr und wird für jedes frühere Jahr
    /// um volle Jahre zurückverschoben. Läuft der Februar noch oder endet die
    /// Reihe mitten im Monat, vergleicht die Funktion also einen halben Februar
    /// mit einem halben Februar — nicht mit einem ganzen. Das ist die
    /// wiederkehrende Fehlerklasse aus CLAUDE.md, und sie wird hier an genau
    /// einer Stelle abgefangen statt in jeder Ansicht erneut.
    ///
    /// - Returns: `nil`, wenn das Bezugsjahr in diesem Abschnitt gar keine
    ///   Daten hat — dann gibt es nichts zu vergleichen.
    public static func compareAcrossYears(
        series: ConsumptionSeries,
        slot: Int,
        granularity: Granularity,
        referenceYear: Int,
        yearsBack: Int
    ) -> SlotComparison? {
        guard let full = range(year: referenceYear, slot: slot, granularity: granularity) else { return nil }
        let probe = ConsumptionEngine.consumption(series: series, in: full)
        guard let window = probe.coveredRange, window.spanInDays > 0 else { return nil }

        // Jedes Jahr wird über sein *eigenes* verschobenes Fenster gerechnet,
        // auch das Bezugsjahr. Dadurch bedeutet `isComplete` bei jedem Eintrag
        // dasselbe: „deckt genau diesen Ausschnitt ab". Würde das Bezugsjahr
        // über den vollen Monat gerechnet, wäre es bei einem laufenden Monat
        // unvollständig — und ließe sich nicht mehr von einem Jahr mit
        // fehlenden Ablesungen unterscheiden.
        var entries: [SlotComparison.Entry] = []
        for step in 0...Swift.max(0, yearsBack) {
            guard let start = shifted(window.start, byYears: -step),
                  let end = shifted(window.end, byYears: -step),
                  let shiftedWindow = DayRange(start: start, end: end)
            else { continue }
            entries.append(
                SlotComparison.Entry(
                    year: referenceYear - step,
                    result: ConsumptionEngine.consumption(series: series, in: shiftedWindow)
                )
            )
        }

        return SlotComparison(
            slot: slot,
            granularity: granularity,
            entries: entries,
            window: window,
            isPartial: window.start != full.start || window.end != full.end
        )
    }

    public static func compareAcrossYears(
        register: Register,
        readings: [Reading],
        slot: Int,
        granularity: Granularity,
        referenceYear: Int,
        yearsBack: Int
    ) -> SlotComparison? {
        guard let series = ConsumptionSeries.build(register: register, readings: readings) else { return nil }
        return compareAcrossYears(series: series, slot: slot, granularity: granularity,
                                  referenceYear: referenceYear, yearsBack: yearsBack)
    }

    /// Derselbe Vergleich für einen ganzen Zähler.
    ///
    /// Bei einem Doppeltarifzähler steht sonst der Hochtarif für den Zähler,
    /// und der Verlauf zeigte etwas anderes als die Karte darüber.
    public static func compareAcrossYears(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        slot: Int,
        granularity: Granularity,
        referenceYear: Int,
        yearsBack: Int
    ) -> SlotComparison? {
        guard let full = range(year: referenceYear, slot: slot, granularity: granularity) else { return nil }
        let probe = ConsumptionEngine.consumption(meteringPoint: meteringPoint, readings: readings, in: full)
        guard let window = probe.coveredRange, window.spanInDays > 0 else { return nil }

        var entries: [SlotComparison.Entry] = []
        for step in 0...Swift.max(0, yearsBack) {
            guard let start = shifted(window.start, byYears: -step),
                  let end = shifted(window.end, byYears: -step),
                  let shiftedWindow = DayRange(start: start, end: end)
            else { continue }
            entries.append(
                SlotComparison.Entry(
                    year: referenceYear - step,
                    result: ConsumptionEngine.consumption(meteringPoint: meteringPoint,
                                                          readings: readings, in: shiftedWindow)
                )
            )
        }

        return SlotComparison(
            slot: slot,
            granularity: granularity,
            entries: entries,
            window: window,
            isPartial: window.start != full.start || window.end != full.end
        )
    }

    /// Verschiebt einen Tag um volle Jahre. Der 29. Februar rutscht auf den
    /// 28. — sonst gäbe es den Tag im Zieljahr nicht, und die Verschiebung
    /// schlüge genau in jedem vierten Jahr fehl.
    static func shifted(_ day: CalendarDay, byYears years: Int) -> CalendarDay? {
        let target = day.year + years
        let clamped = Swift.min(day.day, CalendarDay.daysInMonth(year: target, month: day.month))
        return CalendarDay(year: target, month: day.month, day: clamped)
    }
}
