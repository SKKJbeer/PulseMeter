import Foundation

/// Was auf Sperr- und Startbildschirm passt.
///
/// **Warum eine eigene Zusammenfassung und nicht der Speicher.** Ein Widget
/// ist ein eigener Prozess mit eigenem Speicherbudget und wenigen
/// Millisekunden Zeit. Zöge es SwiftData samt CloudKit auf, um drei Zahlen
/// anzuzeigen, wäre es das langsamste und fehleranfälligste Stück der App —
/// und der häufigste Grund für ein leeres Widget ist genau das. Die App
/// schreibt stattdessen nach jeder Änderung eine kleine Datei; das Widget
/// liest sie und rechnet nichts.
///
/// **Warum in `PulseCore`.** Damit die Zusammenfassung dieselbe Rechnung
/// benutzt wie die Übersicht. Entstünde sie in der App und würde in der
/// Erweiterung noch einmal formuliert, liefen die beiden auseinander — und
/// dann zeigte das Widget eine andere Zahl als der Bildschirm daneben. Hier
/// ist sie außerdem ohne Simulator prüfbar.
public struct WidgetSummary: Codable, Hashable, Sendable {

    /// Steigt nur, wenn die Struktur so bricht, dass ein altes Widget sie
    /// nicht mehr lesen kann. Ein Widget läuft weiter, während die App schon
    /// aktualisiert ist — es muss erkennen können, dass es die Datei nicht
    /// versteht, statt Unsinn anzuzeigen.
    public static let currentVersion = 1

    public var version: Int
    public var createdAt: Date
    public var meters: [Meter]

    public struct Meter: Codable, Hashable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var symbolName: String
        public var colorToken: String
        public var unit: String
        /// Verbrauch im laufenden Jahr. `nil`, solange keiner feststeht —
        /// und ausdrücklich nicht null: Unbekannt ist nicht dasselbe wie
        /// nichts verbraucht (Produktprinzip 7).
        public var quantity: Decimal?
        /// Ob die Zahl auf Schätzung beruht. Das Widget setzt dann ein „≈".
        public var isApproximate: Bool
        /// Der Zeitraum, den die Zahl **abdeckt** — nicht der angefragte.
        public var periodCaption: String
        public var isDue: Bool
        public var daysSinceReading: Int?

        public init(id: UUID, name: String, symbolName: String, colorToken: String,
                    unit: String, quantity: Decimal?, isApproximate: Bool,
                    periodCaption: String, isDue: Bool, daysSinceReading: Int?) {
            self.id = id
            self.name = name
            self.symbolName = symbolName
            self.colorToken = colorToken
            self.unit = unit
            self.quantity = quantity
            self.isApproximate = isApproximate
            self.periodCaption = periodCaption
            self.isDue = isDue
            self.daysSinceReading = daysSinceReading
        }
    }

    public init(version: Int = WidgetSummary.currentVersion,
                createdAt: Date = Date(),
                meters: [Meter] = []) {
        self.version = version
        self.createdAt = createdAt
        self.meters = meters
    }

    /// Fällige Zähler, dringendste zuerst.
    ///
    /// Ein nie abgelesener Zähler steht vorn: Er ist der dringendste Fall,
    /// nicht der unwichtigste — dieselbe Regel wie in ``ReminderEngine``.
    public var due: [Meter] {
        meters.filter(\.isDue).sorted { left, right in
            switch (left.daysSinceReading, right.daysSinceReading) {
            case (nil, nil): return left.name < right.name
            case (nil, _):   return true
            case (_, nil):   return false
            case let (a?, b?): return a == b ? left.name < right.name : a > b
            }
        }
    }

    /// Der Zähler, den das kleine Widget zeigt: der dringendste, sonst der
    /// erste. Ein leeres Widget wäre die schlechteste aller Antworten.
    public var headline: Meter? { due.first ?? meters.first }
}

extension WidgetSummary {

    /// Baut die Zusammenfassung aus dem Bestand.
    ///
    /// - Parameter caption: Die Beschriftung des Zeitraums. Wird
    ///   hineingereicht statt hier gebildet, weil sie Datumsangaben in der
    ///   Sprache des Nutzers enthält und die Sprachformatierung nicht in den
    ///   Rechenkern gehört. Die **Auswahl** des Zeitraums trifft aber diese
    ///   Funktion, damit Widget und Übersicht nicht auseinanderlaufen können.
    public static func build(
        meteringPoints: [MeteringPoint],
        readings: [MeteringPoint.ID: [Reading]],
        range: DayRange,
        today: CalendarDay,
        caption: (ConsumptionResult?) -> String
    ) -> WidgetSummary {

        var meters: [Meter] = []
        for point in meteringPoints where !point.isArchived {
            guard let register = point.primaryRegister else { continue }
            let own = readings[point.id] ?? []
            // Auf Zählerebene, damit im Widget dieselbe Zahl steht wie auf der
            // Karte darunter. Bei Doppeltarif wäre das sonst der Hochtarif
            // allein — und ein Widget, das etwas anderes zeigt als der
            // Bildschirm daneben, ist schlimmer als keines.
            let result = ConsumptionEngine.consumption(meteringPoint: point,
                                                       readings: own, in: range)
            let last = own.filter { $0.registerID == register.id }.map(\.day).max()

            meters.append(Meter(
                id: point.id,
                name: point.name,
                symbolName: point.appearance.symbolName,
                colorToken: point.appearance.colorToken,
                unit: register.unit.symbol,
                quantity: result.hasData ? result.quantity.value : nil,
                isApproximate: result.hasData && result.confidence != .measured,
                periodCaption: caption(result.hasData ? result : nil),
                isDue: ConsumptionEngine.isReadingDue(meteringPoint: point,
                                                      readings: own, today: today),
                daysSinceReading: last.map { today.days(since: $0) }
            ))
        }
        return WidgetSummary(meters: meters)
    }
}
