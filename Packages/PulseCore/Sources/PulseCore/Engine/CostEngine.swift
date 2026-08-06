import Foundation

/// Berechnet Kosten aus Verbrauch und Tarifen.
public enum CostEngine {

    public enum CostError: Error, Equatable, Sendable {
        /// Zählwerk und Tarif rechnen in verschiedenen Dimensionen und es ist
        /// keine Umrechnung hinterlegt — der klassische Fall: Gaszähler misst m³,
        /// der Tarif rechnet in kWh, aber Zustandszahl und Brennwert fehlen.
        case missingConversion(from: MeasurementUnit, to: MeasurementUnit)
        /// Für den Zeitraum ist kein Tarif hinterlegt.
        case noTariff(DayRange)
        /// Tarife des Zeitraums verwenden verschiedene Währungen.
        case mixedCurrencies
    }

    /// Ein Abschnitt konstanter Tarifbedingungen.
    public struct Segment: Hashable, Sendable {
        public let range: DayRange
        public let tariffID: Tariff.ID
        public let billedQuantity: Quantity
        public let energyAmount: Money
        public let baseAmount: Money

        public var total: Money {
            Money(energyAmount.amount + baseAmount.amount, energyAmount.currency)
        }
    }

    /// Ergebnis einer Kostenberechnung.
    ///
    /// Für Zählwerke der Richtung ``FlowDirection/feedIn`` ist der Betrag
    /// **negativ** — eine Einspeisung ist eine Gutschrift. Dadurch ergibt die
    /// Summe über alle Zählwerke eines Zweirichtungszählers unmittelbar das,
    /// was ein PV-Besitzer wissen will: Netzbezug minus Einspeisevergütung.
    public struct CostResult: Hashable, Sendable {
        public let total: Money
        public let energyAmount: Money
        public let baseAmount: Money
        public let confidence: Confidence
        public let segments: [Segment]
        public let warnings: [ConsumptionWarning]

        public var isCredit: Bool { total.amount < 0 }
    }

    // MARK: - Ein Zählwerk

    public static func cost(
        register: Register,
        readings: [Reading],
        tariffs: [Tariff],
        in range: DayRange
    ) throws -> CostResult {

        let applicable = try segmentsOfValidity(for: register, tariffs: tariffs, in: range)
        guard !applicable.isEmpty else { throw CostError.noTariff(range) }

        let currency = applicable[0].1.currency
        guard applicable.allSatisfy({ $0.1.currency == currency }) else {
            throw CostError.mixedCurrencies
        }

        let series = ConsumptionSeries.build(register: register, readings: readings)
        var segments: [Segment] = []
        var energyTotal = Decimal(0)
        var baseTotal = Decimal(0)
        var confidence = Confidence.measured
        var warnings: [ConsumptionWarning] = []

        for (segmentRange, tariff) in applicable {
            let consumed: ConsumptionResult
            if let series {
                consumed = ConsumptionEngine.consumption(series: series, in: segmentRange)
            } else {
                consumed = .empty(unit: register.unit, range: segmentRange,
                                  warnings: [.insufficientReadings])
            }
            confidence = confidence.degraded(to: consumed.confidence)
            warnings.append(contentsOf: consumed.warnings)

            let billed = try billedQuantity(consumed.quantity, register: register, tariff: tariff)
            let unitPrice = price(for: register, tariff: tariff)
            let sign: Decimal = register.direction == .feedIn ? -1 : 1

            let energy = billed.value * unitPrice * sign
            let base = dailyBasePrice(tariff, in: segmentRange) * Decimal(segmentRange.spanInDays)

            energyTotal += energy
            baseTotal += base

            segments.append(Segment(
                range: segmentRange,
                tariffID: tariff.id,
                billedQuantity: billed,
                energyAmount: Money(energy, currency),
                baseAmount: Money(base, currency)
            ))
        }

        return CostResult(
            total: Money(energyTotal + baseTotal, currency),
            energyAmount: Money(energyTotal, currency),
            baseAmount: Money(baseTotal, currency),
            confidence: confidence,
            segments: segments,
            warnings: warnings
        )
    }

    // MARK: - Ganze Messstelle

    /// Summiert die Kosten aller Zählwerke einer Messstelle.
    ///
    /// Zählwerke ohne passenden Tarif werden übersprungen statt den ganzen
    /// Vorgang scheitern zu lassen: Ein Nutzer, der nur für den Bezug einen
    /// Preis hinterlegt hat, soll trotzdem seine Bezugskosten sehen.
    public static func cost(
        meteringPoint: MeteringPoint,
        readings: [Reading],
        tariffs: [Tariff],
        in range: DayRange
    ) throws -> CostResult? {

        let relevant = tariffs.filter { $0.meteringPointID == meteringPoint.id }
        var results: [CostResult] = []

        for register in meteringPoint.registers {
            do {
                results.append(try cost(register: register, readings: readings,
                                        tariffs: relevant, in: range))
            } catch CostError.noTariff {
                continue
            }
        }

        guard let first = results.first else { return nil }
        let currency = first.total.currency
        guard results.allSatisfy({ $0.total.currency == currency }) else {
            throw CostError.mixedCurrencies
        }

        // **Der Grundpreis gehört zum Anschluss, nicht zum Zählwerk.**
        //
        // Vorher wurden die Grundpreise der Zählwerke summiert. Bei einem
        // Zweirichtungszähler zahlte der Nutzer ihn dadurch doppelt — für ein
        // Gerät, das eine Rechnung bekommt. Auf dem Bildschirmfoto stand
        // deshalb ein Betrag, der neunzig Euro zu hoch war, und die
        // Einspeisevergütung sah um denselben Betrag zu klein aus.
        //
        // Gezählt wird je Tarifabschnitt: Dieselbe Kennung im selben Zeitraum
        // ist derselbe Grundpreis. Zwei Zählwerke mit *eigenen* Tarifen
        // behalten dagegen jeder seinen — dann sind es zwei Anschlüsse.
        struct BaseKey: Hashable {
            let tariffID: Tariff.ID
            let range: DayRange
        }
        var counted: Set<BaseKey> = []
        var baseTotal = Decimal(0)
        for segment in results.flatMap(\.segments) {
            guard counted.insert(BaseKey(tariffID: segment.tariffID,
                                         range: segment.range)).inserted else { continue }
            baseTotal += segment.baseAmount.amount
        }

        let energyTotal = results.reduce(Decimal(0)) { $0 + $1.energyAmount.amount }

        return CostResult(
            total: Money(energyTotal + baseTotal, currency),
            energyAmount: Money(energyTotal, currency),
            baseAmount: Money(baseTotal, currency),
            confidence: results.map(\.confidence).max() ?? .measured,
            segments: results.flatMap(\.segments),
            warnings: results.flatMap(\.warnings)
        )
    }

    // MARK: - Hilfen

    /// Zerlegt den Zeitraum an den Tarifgrenzen.
    ///
    /// Ein Preiswechsel mitten im Abrechnungszeitraum ist der Regelfall, nicht
    /// die Ausnahme. Wer mit einem Durchschnittspreis über den ganzen Zeitraum
    /// rechnet, produziert Zahlen, die von der Jahresrechnung abweichen — und
    /// verliert damit genau das Vertrauen, das dieses Produkt trägt.
    ///
    /// Grenztage werden von beiden Abschnitten geteilt. Da ein Verbrauch die
    /// Differenz zweier Zählerstände ist, entsteht dabei keine Doppelzählung.
    static func segmentsOfValidity(
        for register: Register,
        tariffs: [Tariff],
        in range: DayRange
    ) throws -> [(DayRange, Tariff)] {

        let candidates = tariffs
            .filter { $0.registerID == nil || $0.registerID == register.id }
            .compactMap { tariff -> (DayRange, Tariff)? in
                tariff.validity(within: range).map { ($0, tariff) }
            }
            .sorted { lhs, rhs in lhs.0.start < rhs.0.start }

        var segments: [(DayRange, Tariff)] = []
        for (index, candidate) in candidates.enumerated() {
            var clipped = candidate.0
            if index + 1 < candidates.count {
                let nextStart = candidates[index + 1].0.start
                // Der Nachfolger übernimmt den Grenztag des Vorgängers. Das deckt
                // zwei Fälle ab: das fehlende Gültigkeitsende (häufigster
                // Eingabefehler, Tarife überlappen sich) und die lückenlose
                // Folge (alter Tarif bis 15., neuer ab dem 16.). Ohne diese
                // Angleichung fiele im zweiten Fall der Verbrauch des Grenztages
                // unter den Tisch.
                if nextStart <= clipped.end.adding(days: 1),
                   let adjusted = DayRange(start: clipped.start, end: nextStart) {
                    clipped = adjusted
                }
            }
            if clipped.spanInDays > 0 || candidates.count == 1 {
                segments.append((clipped, candidate.1))
            }
        }
        return segments
    }

    static func billedQuantity(
        _ quantity: Quantity,
        register: Register,
        tariff: Tariff
    ) throws -> Quantity {
        if quantity.unit.dimension == tariff.billingUnit.dimension {
            return try quantity.converted(to: tariff.billingUnit)
        }
        // Gas: gemessen in m³, abgerechnet in kWh. Die einzige zugelassene
        // dimensionsübergreifende Umrechnung, und nur mit hinterlegten Faktoren.
        if quantity.unit.dimension == .volume,
           tariff.billingUnit.dimension == .energy,
           let conversion = tariff.gasConversion {
            let energy = try conversion.energy(fromVolume: quantity)
            return try energy.converted(to: tariff.billingUnit)
        }
        throw CostError.missingConversion(from: quantity.unit, to: tariff.billingUnit)
    }

    static func price(for register: Register, tariff: Tariff) -> Decimal {
        if register.direction == .feedIn, let feedIn = tariff.feedInPricePerUnit {
            return feedIn
        }
        return tariff.pricePerUnit
    }

    /// Grundpreis je Tag. Über die tatsächliche Jahreslänge normalisiert, damit
    /// Schaltjahre nicht zu einem Tag zu viel führen.
    static func dailyBasePrice(_ tariff: Tariff, in range: DayRange) -> Decimal {
        let daysInYear = Decimal(CalendarDay.daysInYear(range.start.year))
        return tariff.monthlyBasePrice * 12 / daysInYear
    }
}
