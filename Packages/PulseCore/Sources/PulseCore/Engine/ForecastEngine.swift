import Foundation

/// Rechnet einen laufenden Abrechnungszeitraum auf sein Ende hoch und vergleicht
/// das Ergebnis mit den geleisteten Abschlägen.
///
/// Das ist die Aussage, für die das Produkt existiert:
/// „Bei diesem Verbrauch liegst du am Jahresende 84 € im Plus."
public enum ForecastEngine {

    /// Wie hochgerechnet wurde. Die Methode gehört zum Ergebnis, weil der Nutzer
    /// jede Zahl nachvollziehen können muss (Produktprinzip 4) und weil eine
    /// Zahl, die auf fremden Daten beruht, als solche gekennzeichnet sein muss
    /// (Produktprinzip 7).
    ///
    /// Die Reihenfolge ist die Rangfolge: Was weiter unten steht, wird nur
    /// genommen, wenn das darüber nicht geht.
    public enum Method: String, Hashable, Codable, Sendable, CaseIterable {

        /// **Mehrere eigene Jahre.** Die Form wird über alle vollständigen
        /// Vorjahre gemittelt. Ein einzelner Ausreißer — ein Winter mit
        /// Umbau, ein Sommer im Ausland — verzerrt dann nicht mehr das ganze
        /// Bild.
        case ownHistory

        /// **Das eigene Vorjahr.** Ein vollständiges Jahr liegt vor, mehr
        /// nicht.
        case previousYear

        /// **Ein veröffentlichtes Referenzprofil** für diese Zählerart, weil
        /// noch kein eigenes Jahr vorliegt. Fremde Daten, und deshalb
        /// kennzeichnungspflichtig — siehe ``SeasonalProfile``.
        case reference

        /// **Gleichmäßig fortgeschrieben.** Der letzte Ausweg: keine eigene
        /// Historie und kein Profil für diese Art. Bei allem, was mit der
        /// Jahreszeit schwankt, ist das grob — für Wasser und Betriebsstunden
        /// dagegen die richtige Annahme.
        case linear

        /// Worauf die Zahl beruht, in einem Satzteil für den Schirm.
        ///
        /// Im Rechenkern und nicht in der Ansicht, weil dieselben Wörter in
        /// der App, im Bericht und im Klick-Dummy stehen — drei Fassungen
        /// liefen auseinander.
        public var explanation: String {
            switch self {
            case .ownHistory:   return "nach dem Verlauf deiner Vorjahre"
            case .previousYear: return "nach dem Verlauf deines Vorjahres"
            case .reference:    return "nach einem typischen Jahresverlauf, weil noch kein eigenes Jahr vorliegt"
            case .linear:       return "gleichmäßig aus dem bisherigen Tagesschnitt"
            }
        }

        /// Ob die Hochrechnung auf den Daten des Nutzers selbst beruht.
        ///
        /// Der Unterschied, auf den es ankommt: Alles andere ist eine
        /// Annahme über ihn, keine Beobachtung an ihm.
        public var usesOwnHistory: Bool {
            self == .ownHistory || self == .previousYear
        }

        /// Je kleiner, desto schwächer die Grundlage. Für den Fall, dass ein
        /// Zähler mehrere Zählwerke hat und sie verschieden gerechnet werden:
        /// Genannt wird dann die schwächste, denn sie bestimmt, wie sehr man
        /// der Gesamtzahl trauen darf.
        var rank: Int {
            switch self {
            case .linear: return 0
            case .reference: return 1
            case .previousYear: return 2
            case .ownHistory: return 3
            }
        }
    }

    public struct Forecast: Hashable, Sendable {
        /// Verbrauch, der im Zeitraum bereits gemessen wurde.
        public let actual: ConsumptionResult
        /// Hochgerechneter Verbrauch für den gesamten Zeitraum.
        public let projected: Quantity
        public let method: Method
        public let daysElapsed: Int
        public let daysRemaining: Int
        /// Immer ``Confidence/estimated`` — eine Hochrechnung ist nie gemessen.
        public let confidence: Confidence = .estimated

        public var progress: Decimal {
            let total = daysElapsed + daysRemaining
            guard total > 0 else { return 0 }
            return Decimal(daysElapsed) / Decimal(total)
        }
    }

    // MARK: - Verbrauchsprognose

    /// - Parameter kind: Die Zählerart. Wird nur gebraucht, um ein
    ///   veröffentlichtes Referenzprofil zu wählen, wenn noch kein eigenes
    ///   Jahr vorliegt. Ohne Angabe bleibt es beim linearen Rückfall — das ist
    ///   die alte Vorgabe und für Aufrufer gedacht, die keine Art kennen.
    public static func forecast(
        register: Register,
        readings: [Reading],
        period: DayRange,
        today: CalendarDay,
        kind: ResourceKind? = nil
    ) -> Forecast? {

        guard let series = ConsumptionSeries.build(register: register, readings: readings) else {
            return nil
        }

        let elapsedEnd = Swift.min(today, period.end)
        guard let elapsedRange = DayRange(start: period.start, end: elapsedEnd),
              elapsedRange.spanInDays > 0
        else { return nil }

        let actual = ConsumptionEngine.consumption(series: series, in: elapsedRange)
        guard actual.hasData, let covered = actual.coveredRange, covered.spanInDays > 0 else {
            return nil
        }

        // Maßgeblich ist der Zeitraum, den die Daten tatsächlich abdecken — nicht
        // der, den der Nutzer angefragt hat. Liegt die letzte Ablesung zwei Monate
        // zurück, gehören diese zwei Monate zur Restzeit und nicht zum Gemessenen.
        // Sonst würde ein veralteter Zählerstand die Prognose systematisch drücken.
        let daysElapsed = covered.spanInDays
        let daysRemaining = Swift.max(0, period.spanInDays - daysElapsed)

        // Der Zeitraum ist abgeschlossen — nichts hochzurechnen.
        guard daysRemaining > 0 else {
            return Forecast(
                actual: actual,
                projected: actual.quantity,
                method: .linear,
                daysElapsed: daysElapsed,
                daysRemaining: 0
            )
        }

        // **Die Rangfolge.** Eigene Jahre schlagen ein fremdes Profil, ein
        // fremdes Profil schlägt die gleichmäßige Fortschreibung. Jede Stufe
        // gibt auf, sobald ihre Grundlage nicht trägt — und der Nutzer erfährt
        // hinterher, welche gegriffen hat.
        if let own = ownHistoryProjection(series: series, period: period,
                                          covered: covered, actual: actual) {
            return Forecast(
                actual: actual,
                projected: own.value,
                method: own.method,
                daysElapsed: daysElapsed,
                daysRemaining: daysRemaining
            )
        }

        if let kind,
           let profile = SeasonalProfile.reference(for: kind, direction: register.direction),
           let share = profile.share(of: covered, within: period),
           share > 0 {
            // Dieselbe Rechnung wie beim eigenen Vorjahr, nur mit fremdem
            // Muster: Deckt der gemessene Ausschnitt 32 % eines typischen
            // Jahres ab, entspricht das Gemessene 32 % des Jahres.
            return Forecast(
                actual: actual,
                projected: Quantity(actual.quantity.value / share, actual.quantity.unit),
                method: .reference,
                daysElapsed: daysElapsed,
                daysRemaining: daysRemaining
            )
        }

        let perDay = actual.quantity.value / Decimal(daysElapsed)
        let projected = actual.quantity.value + perDay * Decimal(daysRemaining)
        return Forecast(
            actual: actual,
            projected: Quantity(projected, actual.quantity.unit),
            method: .linear,
            daysElapsed: daysElapsed,
            daysRemaining: daysRemaining
        )
    }

    /// Wie viele eigene Jahre höchstens herangezogen werden.
    ///
    /// Drei. Mehr brächte wenig und würde eine echte Verhaltensänderung —
    /// neue Heizung, Kind aus dem Haus — jahrelang mitschleppen.
    private static let maximumHistoryYears = 3

    /// Hochrechnung anhand des eigenen Verlaufs, über bis zu drei Vorjahre.
    ///
    /// **Die Idee.** Waren im Vorjahr bis zum selben Tag 40 % des Jahres
    /// angefallen, dann entsprechen die diesjährigen Werte vermutlich
    /// ebenfalls etwa 40 %. Das trägt die Saisonalität des Heizens mit, ohne
    /// ein Modell zu brauchen, das niemand erklären kann.
    ///
    /// **Warum mehrere Jahre.** Ein einzelnes Vorjahr ist eine Stichprobe von
    /// eins. Ein Winter mit Umbau oder ein Sommer im Ausland verzerrt dann die
    /// Form des ganzen kommenden Jahres. Über mehrere Jahre gemittelt fällt
    /// ein Ausreißer nicht mehr ins Gewicht — und es ist dieselbe Rechnung,
    /// nur mit einem stabileren Anteil.
    ///
    /// Gemittelt werden die **Anteile**, nicht die Mengen: Wer vor zwei Jahren
    /// doppelt so viel verbraucht hat, soll die Form beisteuern und nicht das
    /// Niveau. Das Niveau kommt ausschließlich aus dem, was heuer gemessen
    /// wurde.
    private static func ownHistoryProjection(
        series: ConsumptionSeries,
        period: DayRange,
        covered: DayRange,
        actual: ConsumptionResult
    ) -> (value: Quantity, method: Method)? {

        var shares: [Decimal] = []
        var periodStart = period.start
        var periodEnd = period.end
        var coveredStart = covered.start
        var coveredEnd = covered.end

        for _ in 0..<maximumHistoryYears {
            periodStart = periodStart.oneYearEarlier
            periodEnd = periodEnd.oneYearEarlier
            coveredStart = coveredStart.oneYearEarlier
            coveredEnd = coveredEnd.oneYearEarlier

            // Das Vorjahresfenster muss denselben Ausschnitt abbilden wie die
            // vorliegenden Daten, sonst vergleicht man ungleiche Zeiträume —
            // die wiederkehrende Fehlerklasse aus CLAUDE.md.
            guard let priorPeriod = DayRange(start: periodStart, end: periodEnd),
                  let priorElapsed = DayRange(start: coveredStart, end: coveredEnd)
            else { break }

            let priorTotal = ConsumptionEngine.consumption(series: series, in: priorPeriod)
            let priorSoFar = ConsumptionEngine.consumption(series: series, in: priorElapsed)

            // Nur verwenden, wenn das Jahr den Zeitraum wirklich abdeckt. Eine
            // Hochrechnung auf Lückendaten wäre schlechter als die ehrliche
            // lineare Variante. Ein unvollständiges Jahr beendet die Reihe:
            // Was davor liegt, ist noch älter und wäre erst recht lückenhaft.
            guard priorTotal.isComplete, priorSoFar.isComplete,
                  priorSoFar.quantity.value > 0, priorTotal.quantity.value > 0
            else { break }

            let share = priorSoFar.quantity.value / priorTotal.quantity.value
            guard share > 0, share <= 1 else { break }
            shares.append(share)
        }

        guard !shares.isEmpty else { return nil }
        let mittel = shares.reduce(0, +) / Decimal(shares.count)
        guard mittel > 0 else { return nil }

        return (Quantity(actual.quantity.value / mittel, actual.quantity.unit),
                shares.count > 1 ? .ownHistory : .previousYear)
    }

    // MARK: - Abschlagsvergleich

    public struct PrepaymentOutlook: Hashable, Sendable {
        /// Erwartete Gesamtkosten des Zeitraums.
        public let projectedCost: Money
        /// Summe der Abschläge über den Zeitraum.
        public let totalPrepayment: Money
        /// Positiv = voraussichtliches Guthaben, negativ = voraussichtliche Nachzahlung.
        public let balance: Money

        /// Worauf die Hochrechnung beruht.
        ///
        /// **Warum das mitkommen muss.** Bis 0.38.0 stand auf der Karte
        /// „≈ 71,63 € Guthaben" und sonst nichts. Ob dahinter das eigene
        /// Vorjahr steckte oder eine gleichmäßige Fortschreibung, die bei Gas
        /// im Februar um 100 % danebenliegt, war der Zahl nicht anzusehen.
        /// Produktprinzip 7 verlangt genau hier eine Kennzeichnung — es ist
        /// die folgenreichste Zahl der App.
        ///
        /// Hat ein Zähler mehrere Zählwerke, steht hier die **schwächste**
        /// Grundlage: Sie bestimmt, wie sehr man dem Ganzen trauen darf.
        public let method: Method

        public var expectsRefund: Bool { balance.amount > 0 }
    }

    /// Rechnet den laufenden Abrechnungszeitraum hoch und stellt ihm die
    /// Abschläge gegenüber.
    ///
    /// Die Kosten werden aus dem hochgerechneten Verbrauch bestimmt, indem der
    /// bisher gemessene Verbrauch im selben Verhältnis skaliert wird. So bleibt
    /// die abschnittsweise Tarifrechnung (Preiswechsel im Zeitraum) erhalten.
    public static func prepaymentOutlook(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        tariffs: [Tariff],
        period: BillingPeriod,
        today: CalendarDay
    ) throws -> PrepaymentOutlook? {

        guard let prepayment = period.totalPrepayment else { return nil }
        guard let costSoFar = try cost(meteringPoint: meteringPoint, readings: readings,
                                       tariffs: tariffs, upTo: today, in: period.range)
        else { return nil }
        guard let elapsedRange = DayRange(start: period.range.start,
                                          end: Swift.min(today, period.range.end))
        else { return nil }

        // **Jedes Zählwerk mit seiner eigenen Jahresform.**
        //
        // Vorher wurde der Arbeitspreis der ganzen Messstelle mit dem
        // Hochrechnungsfaktor des ersten Zählwerks skaliert. Bei einem
        // Zweirichtungszähler ist das falsch, und zwar systematisch: Bezug und
        // Einspeisung laufen gegenläufig durchs Jahr. Im August ist der Bezug
        // fast durch, die Einspeisung noch lange nicht — einen Betrag, in dem
        // beides steckt, mit der Form nur eines der beiden fortzuschreiben,
        // ist die wiederkehrende Fehlerklasse aus CLAUDE.md.
        let relevant = tariffs.filter { $0.meteringPointID == meteringPoint.id }
        var projectedEnergy = Decimal(0)
        var sawRegister = false
        var weakest: Method = .ownHistory

        for register in meteringPoint.registers {
            guard let partial = try? CostEngine.cost(register: register, readings: readings,
                                                     tariffs: relevant, in: elapsedRange)
            else { continue }
            sawRegister = true
            let energy = partial.energyAmount.amount
            guard let forecast = forecast(register: register, readings: readings,
                                          period: period.range, today: today,
                                          kind: meteringPoint.kind) else {
                // Ohne Hochrechnung bleibt der gemessene Betrag stehen. Ihn
                // wegzulassen wäre schlimmer: Der Wert wäre dann kleiner als
                // das, was schon feststeht. Und weil dann gar nicht
                // fortgeschrieben wurde, ist die Grundlage die schwächste.
                projectedEnergy += energy
                weakest = .linear
                continue
            }
            if forecast.method.rank < weakest.rank { weakest = forecast.method }
            let measured = forecast.actual.quantity.value
            let scale: Decimal = measured > 0 ? forecast.projected.value / measured : 1
            projectedEnergy += energy * scale
        }
        guard sawRegister else { return nil }

        // Der Arbeitspreis skaliert mit dem Verbrauch, der Grundpreis nicht —
        // er fällt für den gesamten Zeitraum an, unabhängig vom Verbrauch.
        // Hochgerechnet wird er über die abgerechneten Tage, nicht über die
        // gemessenen: Der Grundpreis läuft auch weiter, wenn niemand abliest.
        let elapsedDays = Swift.min(today, period.range.end).days(since: period.range.start)
        let fullBase = costSoFar.baseAmount.amount
            * Decimal(period.range.spanInDays)
            / Decimal(Swift.max(1, elapsedDays))
        let projectedTotal = projectedEnergy + fullBase
        let projectedCost = Money(projectedTotal, costSoFar.total.currency)

        return PrepaymentOutlook(
            projectedCost: projectedCost.roundedToCents,
            totalPrepayment: prepayment.roundedToCents,
            balance: try prepayment.subtracting(projectedCost).roundedToCents,
            method: weakest
        )
    }

    private static func cost(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        tariffs: [Tariff],
        upTo today: CalendarDay,
        in period: DayRange
    ) throws -> CostEngine.CostResult? {
        guard let elapsed = DayRange(start: period.start, end: Swift.min(today, period.end)) else {
            return nil
        }
        return try CostEngine.cost(meteringPoint: meteringPoint, readings: readings,
                                   tariffs: tariffs, in: elapsed)
    }
}
