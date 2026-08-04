import Foundation

/// Rechnet einen laufenden Abrechnungszeitraum auf sein Ende hoch und vergleicht
/// das Ergebnis mit den geleisteten Abschlägen.
///
/// Das ist die Aussage, für die das Produkt existiert:
/// „Bei diesem Verbrauch liegst du am Jahresende 84 € im Plus."
public enum ForecastEngine {

    /// Wie hochgerechnet wurde. Die Methode gehört zum Ergebnis, weil der Nutzer
    /// jede Zahl nachvollziehen können muss (Produktprinzip 4).
    public enum Method: String, Hashable, Codable, Sendable {
        /// Bisheriger Tagesdurchschnitt auf die Restzeit fortgeschrieben.
        case linear
        /// Verlauf des Vorjahres als Muster genutzt. Deutlich genauer bei
        /// Heizung und Gas, wo der Verbrauch stark saisonal schwankt: Wer im
        /// Februar linear hochrechnet, sagt einem Gaskunden einen viel zu hohen
        /// Jahresverbrauch voraus.
        case seasonal
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

    public static func forecast(
        register: Register,
        readings: [Reading],
        period: DayRange,
        today: CalendarDay
    ) -> Forecast? {

        guard let series = ConsumptionSeries.build(register: register, readings: readings) else {
            return nil
        }

        let elapsedEnd = Swift.min(today, period.end)
        guard let elapsedRange = DayRange(start: period.start, end: elapsedEnd),
              elapsedRange.spanInDays > 0
        else { return nil }

        let actual = ConsumptionEngine.consumption(series: series, in: elapsedRange)
        guard actual.hasData, actual.coveredDays > 0 else { return nil }

        let daysElapsed = actual.coveredDays
        let daysRemaining = Swift.max(0, period.spanInDays - elapsedRange.spanInDays)

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

        if let seasonal = seasonalProjection(series: series, period: period,
                                             elapsedRange: elapsedRange, actual: actual) {
            return Forecast(
                actual: actual,
                projected: seasonal,
                method: .seasonal,
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

    /// Hochrechnung anhand des Vorjahresverlaufs.
    ///
    /// Idee: Wenn im Vorjahr zum selben Zeitpunkt 40 % des Jahresverbrauchs
    /// angefallen waren, dann entsprechen die diesjährigen Werte vermutlich
    /// ebenfalls etwa 40 %. Das trägt die Saisonalität des Heizens mit, ohne
    /// ein Modell zu benötigen, das niemand erklären kann.
    private static func seasonalProjection(
        series: ConsumptionSeries,
        period: DayRange,
        elapsedRange: DayRange,
        actual: ConsumptionResult
    ) -> Quantity? {

        guard let priorPeriod = DayRange(start: period.start.oneYearEarlier,
                                         end: period.end.oneYearEarlier),
              let priorElapsed = DayRange(start: elapsedRange.start.oneYearEarlier,
                                          end: elapsedRange.end.oneYearEarlier)
        else { return nil }

        let priorTotal = ConsumptionEngine.consumption(series: series, in: priorPeriod)
        let priorSoFar = ConsumptionEngine.consumption(series: series, in: priorElapsed)

        // Nur verwenden, wenn das Vorjahr den Zeitraum wirklich abdeckt.
        // Eine Hochrechnung auf Basis von Lückendaten wäre schlechter als die
        // ehrliche lineare Variante.
        guard priorTotal.isComplete, priorSoFar.isComplete else { return nil }
        guard priorSoFar.quantity.value > 0, priorTotal.quantity.value > 0 else { return nil }

        let shareElapsed = priorSoFar.quantity.value / priorTotal.quantity.value
        guard shareElapsed > 0, shareElapsed <= 1 else { return nil }

        return Quantity(actual.quantity.value / shareElapsed, actual.quantity.unit)
    }

    // MARK: - Abschlagsvergleich

    public struct PrepaymentOutlook: Hashable, Sendable {
        /// Erwartete Gesamtkosten des Zeitraums.
        public let projectedCost: Money
        /// Summe der Abschläge über den Zeitraum.
        public let totalPrepayment: Money
        /// Positiv = voraussichtliches Guthaben, negativ = voraussichtliche Nachzahlung.
        public let balance: Money

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
        guard let register = meteringPoint.primaryRegister else { return nil }
        guard let forecast = forecast(register: register, readings: readings,
                                      period: period.range, today: today) else { return nil }
        guard let costSoFar = try cost(meteringPoint: meteringPoint, readings: readings,
                                       tariffs: tariffs, upTo: today, in: period.range)
        else { return nil }

        let measured = forecast.actual.quantity.value
        let scale: Decimal = measured > 0 ? forecast.projected.value / measured : 1

        // Der Arbeitspreis skaliert mit dem Verbrauch, der Grundpreis nicht —
        // er fällt für den gesamten Zeitraum an, unabhängig vom Verbrauch.
        let fullBase = costSoFar.baseAmount.amount
            * Decimal(period.range.spanInDays)
            / Decimal(Swift.max(1, forecast.daysElapsed))
        let projectedTotal = costSoFar.energyAmount.amount * scale + fullBase
        let projectedCost = Money(projectedTotal, costSoFar.total.currency)

        return PrepaymentOutlook(
            projectedCost: projectedCost.roundedToCents,
            totalPrepayment: prepayment.roundedToCents,
            balance: try prepayment.subtracting(projectedCost).roundedToCents
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
