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

            /// Es gibt eine Zahl, aber sie ruht nicht auf Ablesungen aus diesem
            /// Ausschnitt — sie ist aus einer Geraden herausgeschnitten.
            ///
            /// **Warum das nicht mehr „keine Daten" heißt.** Bis 0.64.1 zeigte
            /// die Karte für so ein Jahr gar nichts, und beim ersten echten
            /// Gebrauch stand dreimal „keine Daten" untereinander — auch beim
            /// laufenden Jahr, dessen Ablesungen einen Monat auseinanderlagen.
            /// Produktprinzip 7 verlangt, geschätzte Werte zu **kennzeichnen**,
            /// nicht sie zu verschweigen. Die Ansicht zeigt sie jetzt mit einem
            /// ≈ davor.
            public var isApproximate: Bool { hasData && !isComparable }

            /// Wie viele Tage dieses Jahr zum Ausschnitt wirklich beiträgt.
            ///
            /// Nicht dasselbe wie ``isComparable``: Ein Jahr kann den ganzen
            /// Ausschnitt formal abdecken und trotzdem aus einer weit
            /// gespannten Geraden geschnitten sein. Umgekehrt kann ein Jahr
            /// echte Ablesungen haben, aber nur für zwei Tage des Ausschnitts.
            /// Diese Zahl beantwortet die zweite Frage.
            public var coveredDays: Int { result.coveredDays }
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

        /// Ob der Ausschnitt zusätzlich gekürzt wurde, damit ein Vorjahr
        /// mitkommt, das nur einen Teil davon abdeckt.
        ///
        /// Die Alternative wäre gewesen, gar nicht zu vergleichen — und genau
        /// das hat der Gründer im ersten Gebrauch als Mangel gemeldet. Die
        /// Beschriftung muss den Ausschnitt dann nennen: Wer „Mai" liest und
        /// „1. bis 12. Mai" bekommt, soll es sehen, nicht erraten.
        public let isNarrowed: Bool

        public init(slot: Int, granularity: Granularity, entries: [Entry],
                    window: DayRange, isPartial: Bool, isNarrowed: Bool = false) {
            self.slot = slot
            self.granularity = granularity
            self.entries = entries
            self.window = window
            self.isPartial = isPartial
            self.isNarrowed = isNarrowed
        }

        /// Veränderung des Bezugsjahres gegenüber dem Jahr davor — nur, wenn
        /// **beide** Seiten auf eigenen Ablesungen ruhen. Die harte Zahl.
        public var relativeChange: Decimal? {
            guard let roh = rawChange else { return nil }
            let current = entries[0], previous = entries[1]
            guard current.isComparable, previous.isComparable else { return nil }
            return roh
        }

        /// Dieselbe Veränderung, auch wenn eine Seite zwischen zwei Ablesungen
        /// gerechnet ist — aber **nur**, wenn beide Seiten den Ausschnitt
        /// ähnlich weit abdecken. Zum Anzeigen mit Kennzeichnung, nie ohne.
        ///
        /// **Warum die zweite Bedingung.** Auf dem Gerät des Gründers stand
        /// „≈ +8.657 % gegenüber Vorjahr": 1.532 kWh aus acht Monaten 2026
        /// gegen ≈ 18 kWh, die aus zwei Dezembertagen 2025 stammen — seine
        /// erste Ablesung überhaupt. Beide Zahlen für sich sind richtig, der
        /// Prozentwert dazwischen ist keine Aussage, sondern die
        /// wiederkehrende Fehlerklasse dieses Projekts: acht Monate gegen zwei
        /// Tage.
        ///
        /// Ein ≈ hilft dagegen nicht. Es kennzeichnet eine Schätzung; hier
        /// steht aber keine Schätzung, sondern ein Vergleich zweier Dinge, die
        /// sich nicht vergleichen lassen. Der wird nicht gekennzeichnet,
        /// sondern weggelassen.
        public var approximateChange: Decimal? {
            guard let roh = rawChange, spansAreComparable else { return nil }
            return roh
        }

        /// Ob beide Seiten den Ausschnitt ähnlich weit abdecken.
        ///
        /// Die Hälfte als Grenze: Wer im Vorjahr zur Monatsmitte statt zum
        /// Ersten abgelesen hat, soll seinen Vergleich behalten. Wer zwei von
        /// zweihundert Tagen abdeckt, hat keinen.
        public var spansAreComparable: Bool {
            guard entries.count >= 2 else { return false }
            let a = entries[0].coveredDays, b = entries[1].coveredDays
            guard a > 0, b > 0 else { return false }
            return Swift.min(a, b) * 2 >= Swift.max(a, b)
        }

        /// Ob eine angezeigte Veränderung eine geschätzte ist.
        public var changeIsApproximate: Bool {
            approximateChange != nil && relativeChange == nil
        }

        private var rawChange: Decimal? {
            guard entries.count >= 2 else { return nil }
            let current = entries[0], previous = entries[1]
            guard current.hasData, previous.hasData, previous.value != 0 else { return nil }
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

    /// Der gemeinsame Kern der drei Fassungen unten.
    ///
    /// **Warum der Ausschnitt gekürzt wird, wenn ein Vorjahr nicht mitkommt.**
    /// Bis 0.64.1 stand bei einem Vorjahr, das den Ausschnitt nur zum Teil
    /// abdeckte, „keine Daten" — und der Vergleich fiel aus. Das ist der
    /// häufigste Fall überhaupt: Wer im Mai anfängt, hat vom Vorjahr nie einen
    /// vollen Monat. Der Gründer beim ersten Gebrauch: „ich will schon auch
    /// einen Vergleich haben, wenn es nur ein angebrochenes vorheriges Jahr
    /// gibt."
    ///
    /// Die Lösung darf die Regel nicht brechen, sondern muss sie **einhalten**:
    /// Beide Seiten müssen denselben Zeitausschnitt beschreiben. Also wird nicht
    /// der halbe Mai gegen den ganzen gestellt, sondern der Ausschnitt auf das
    /// gekürzt, was **beide** Jahre abdecken — und ``SlotComparison/isNarrowed``
    /// sagt es, damit die Beschriftung es sagen kann.
    ///
    /// Ein Jahr, das gar nichts beisteuert, kürzt nichts: Es bekommt weiter
    /// „keine Daten". Und gekürzt wird nur, solange ein Viertel des
    /// ursprünglichen Ausschnitts übrig bleibt — ein Vergleich über drei Tage,
    /// der „Mai" heißt, wäre wieder eine Aussage über einen Zeitraum, den die
    /// Zahlen nicht beschreiben.
    /// - Parameter readingDays: Die Tage, an denen wirklich abgelesen wurde.
    ///   **Nicht** ``ConsumptionResult/coveredRange``: Das sagt nur, dass ein
    ///   Ausschnitt innerhalb der Reihe liegt. Zwischen dem 12. Mai 2025 und dem
    ///   1. Mai 2026 liegt formal alles „innerhalb", und der Ausschnitt bis zum
    ///   31. Mai 2025 wäre damit gedeckt — aus einer Geraden über elf Monate.
    ///   Die Ablesungstage sagen dagegen, wo die Reihe wirklich etwas weiß.
    private static func comparison(
        slot: Int,
        granularity: Granularity,
        referenceYear: Int,
        yearsBack: Int,
        readingDays: [CalendarDay],
        consumption: (DayRange) -> ConsumptionResult
    ) -> SlotComparison? {
        guard let full = range(year: referenceYear, slot: slot, granularity: granularity) else { return nil }
        let probe = consumption(full)
        guard let window = probe.coveredRange, window.spanInDays > 0 else { return nil }

        let steps = 0...Swift.max(0, yearsBack)

        // Was deckt jedes Jahr von diesem Ausschnitt selbst ab — zurückgerechnet
        // in den Rahmen des Bezugsjahres, damit sich die Stücke schneiden lassen.
        var deckung: [Int: DayRange] = [:]
        for step in steps where step > 0 {
            guard let verschoben = shift(window, byYears: -step) else { continue }
            let tage = readingDays.filter { verschoben.contains($0) }.sorted()
            guard let erste = tage.first, let letzte = tage.last, erste < letzte,
                  let eigen = DayRange(start: erste, end: letzte),
                  let zurueck = shift(eigen, byYears: step) else { continue }
            deckung[referenceYear - step] = zurueck
        }

        var gemeinsam = window
        for (_, teil) in deckung.sorted(by: { $0.key > $1.key }) {
            guard let schnitt = gemeinsam.intersection(with: teil) else { continue }
            // Vier Tage von sechzehn sind kein Mai mehr.
            guard schnitt.dayCount * 4 >= window.dayCount else { continue }
            gemeinsam = schnitt
        }

        var entries: [SlotComparison.Entry] = []
        for step in steps {
            guard let verschoben = shift(gemeinsam, byYears: -step) else { continue }
            entries.append(SlotComparison.Entry(year: referenceYear - step,
                                                result: consumption(verschoben)))
        }

        return SlotComparison(
            slot: slot,
            granularity: granularity,
            entries: entries,
            window: gemeinsam,
            isPartial: gemeinsam.start != full.start || gemeinsam.end != full.end,
            isNarrowed: gemeinsam != window
        )
    }

    /// Verschiebt einen ganzen Ausschnitt um volle Jahre — **gleicher Anfang im
    /// Jahr, gleiche Länge in Tagen**.
    ///
    /// **Warum nicht einfach beide Enden verschieben.** Weil dabei verschieden
    /// lange Fenster herauskommen, und zwar immer dann, wenn ein Schalttag in
    /// einem der beiden Jahre liegt oder auf den 29. Februar geschoben wird
    /// (der auf den 28. rutscht). Der Szenarien-Test hat es beim ersten Lauf
    /// gemeldet: „vergleicht verschieden lange Zeiträume: [30, 29]" beim
    /// Februar, „[149, 150]" beim Jahr. Ein Tag von dreißig sind drei Prozent —
    /// mehr als die Veränderungen, die diese App anzeigt.
    ///
    /// Das ist die wiederkehrende Fehlerklasse aus CLAUDE.md im Kleinen: zwei
    /// Zeiträume verglichen, die nicht denselben Ausschnitt beschreiben. Also
    /// bleibt der **Anfang** kalendarisch verankert — sonst verglichen wir bei
    /// einem saisonalen Zähler Januar gegen Februar — und das Ende ergibt sich
    /// aus der Länge.
    static func shift(_ range: DayRange, byYears years: Int) -> DayRange? {
        guard let start = shifted(range.start, byYears: years) else { return nil }
        return DayRange(start: start, end: start.adding(days: range.spanInDays))
    }

    public static func compareAcrossYears(
        series: ConsumptionSeries,
        slot: Int,
        granularity: Granularity,
        referenceYear: Int,
        yearsBack: Int
    ) -> SlotComparison? {
        // Jedes Jahr wird über sein *eigenes* verschobenes Fenster gerechnet,
        // auch das Bezugsjahr. Dadurch bedeutet `isComplete` bei jedem Eintrag
        // dasselbe: „deckt genau diesen Ausschnitt ab". Würde das Bezugsjahr
        // über den vollen Monat gerechnet, wäre es bei einem laufenden Monat
        // unvollständig — und ließe sich nicht mehr von einem Jahr mit
        // fehlenden Ablesungen unterscheiden.
        comparison(slot: slot, granularity: granularity,
                   referenceYear: referenceYear, yearsBack: yearsBack,
                   readingDays: series.points.map(\.day)) { fenster in
            ConsumptionEngine.consumption(series: series, in: fenster)
        }
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
        comparison(slot: slot, granularity: granularity,
                   referenceYear: referenceYear, yearsBack: yearsBack,
                   readingDays: readings.map(\.day)) { fenster in
            ConsumptionEngine.consumption(meteringPoint: meteringPoint, readings: readings, in: fenster)
        }
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
