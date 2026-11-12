import Foundation

/// Der Preisverlauf eines Zählers: neuer Preis ab einem Tag, jüngsten löschen.
///
/// Bis 1.6 schrieb die Oberfläche bei jedem Sichern denselben Tarif mit
/// demselben Beginn neu. Wer nach einer Preiserhöhung den Preis änderte,
/// änderte damit die ganze Vergangenheit: Die App rechnete das Jahr rückwirkend
/// mit dem neuen Preis. Der Rechenkern konnte mehrere Tarife nacheinander
/// schon (``CostEngine/segmentsOfValidity(for:tariffs:in:)``); es fehlte der
/// Weg, sie anzulegen, ohne einen zu überschreiben.
///
/// **Eine Generation** sind die Tarife eines Zählers, die am selben Tag
/// beginnen. Beim Doppeltarif sind das zwei oder drei (Hochtarif, Niedertarif,
/// Einspeisung), sonst einer. Ein neuer Preis schließt immer die ganze jüngste
/// Generation und legt eine neue an: Ein Wechsel des Anbieters ändert alle
/// Preise am selben Tag, und ein Zählwerk ohne Preis gäbe eine Lücke.
///
/// Reine Funktionen über Wertetypen, ohne Speicher. Die Oberfläche ruft nur
/// diese und sichert, was zurückkommt.
public enum TariffHistory {

    public enum HistoryError: Error, Equatable, Sendable {
        /// Für den Zähler liegt noch kein Preis vor. Ein erster Preis ist kein
        /// „neuer Preis ab“, sondern das gewöhnliche Sichern im Zähler.
        case noTariff
        /// Der Tag liegt nicht nach dem Beginn des jüngsten Preises. Ab dann
        /// gilt schon der jetzige; davor einzufügen hieße, ihn zu zerteilen.
        case notAfterNewestStart(CalendarDay)
        /// Es gibt nur einen Preis. Löschte man ihn, stünde der Zähler ohne da.
        case onlyOnePrice
    }

    /// Die Tarife eines Zählers, die am selben Tag beginnen.
    public struct Generation: Hashable, Sendable {
        public let validFrom: CalendarDay
        /// `nil` = gilt bis auf Weiteres.
        public let validTo: CalendarDay?
        public let tariffs: [Tariff]

        /// Der Tarif, der für ein Zählwerk gilt: sein eigener, sonst der ohne
        /// Bindung. Wie ``CostEngine/segmentsOfValidity(for:tariffs:in:)``
        /// auswählt.
        public func tariff(for registerID: Register.ID?) -> Tariff? {
            tariffs.first { $0.registerID == registerID && registerID != nil }
                ?? tariffs.first { $0.registerID == nil }
        }
    }

    /// Die Generationen eines Zählers, **neueste zuerst** — so steht der
    /// Preisverlauf auf dem Schirm.
    public static func generations(
        of tariffs: [Tariff],
        meteringPointID: MeteringPoint.ID
    ) -> [Generation] {
        let own = tariffs.filter { $0.meteringPointID == meteringPointID }
        let starts = Set(own.map(\.validFrom)).sorted(by: >)
        return starts.map { start in
            let group = own.filter { $0.validFrom == start }
                .sorted { ($0.registerID?.uuidString ?? "") < ($1.registerID?.uuidString ?? "") }
            // Ende der Generation: das späteste Ende ihrer Tarife; `nil`,
            // sobald einer offen ist.
            let ends = group.map(\.validTo)
            let end: CalendarDay? = ends.contains(where: { $0 == nil }) ? nil : ends.compactMap { $0 }.max()
            return Generation(validFrom: start, validTo: end, tariffs: group)
        }
    }

    /// Ein neuer Preis ab `day`.
    ///
    /// Die jüngste Generation endet am Vortag, die neue beginnt am Tag als
    /// Kopie der jüngsten mit neuer Kennung. `adjust` ändert jeden neuen Tarif;
    /// was es nicht anfasst, bleibt beim bisherigen Wert. So tippt jemand nach
    /// einer Erhöhung nur den Arbeitspreis, und Grundpreis, Brennwert und
    /// Vergütung kommen mit.
    ///
    /// Erlaubt ist jeder Tag nach dem Beginn des jüngsten Preises, auch einer
    /// in der Zukunft: Die angekündigte Erhöhung zum 1. Januar ist der
    /// häufigste Fall. Auch einer vor der letzten Ablesung; dann rechnen sich
    /// die Kosten ab dem Tag neu, und das Blatt sagt es.
    ///
    /// - Returns: Alle Tarife des Zählers danach. Tarife anderer Zähler in
    ///   `tariffs` kommen unverändert mit zurück.
    public static func startingNewPrice(
        on day: CalendarDay,
        tariffs: [Tariff],
        meteringPointID: MeteringPoint.ID,
        adjust: (inout Tariff) -> Void = { _ in }
    ) throws -> [Tariff] {
        guard let newest = generations(of: tariffs, meteringPointID: meteringPointID).first else {
            throw HistoryError.noTariff
        }
        guard newest.validFrom < day else {
            throw HistoryError.notAfterNewestStart(newest.validFrom)
        }
        let closeOn = day.adding(days: -1)
        let newestIDs = Set(newest.tariffs.map(\.id))

        var result = tariffs.map { tariff -> Tariff in
            guard newestIDs.contains(tariff.id) else { return tariff }
            var closed = tariff
            // Ein schon früher gesetztes Ende bleibt, wenn es vor dem neuen
            // Tag liegt. Eine Lücke, die jemand bewusst gelassen hat, wird
            // hier nicht stillschweigend geschlossen.
            if closed.validTo.map({ $0 >= day }) ?? true {
                closed.validTo = closeOn
            }
            return closed
        }
        for old in newest.tariffs {
            var fresh = Tariff(
                id: UUID(),
                meteringPointID: old.meteringPointID,
                registerID: old.registerID,
                validFrom: day,
                validTo: nil,
                pricePerUnit: old.pricePerUnit,
                monthlyBasePrice: old.monthlyBasePrice,
                currency: old.currency,
                billingUnit: old.billingUnit,
                gasConversion: old.gasConversion,
                feedInPricePerUnit: old.feedInPricePerUnit
            )
            adjust(&fresh)
            // Beginn, Zähler und Bindung gehören dem Verlauf, nicht dem Aufrufer.
            fresh.validFrom = day
            fresh.validTo = nil
            fresh.meteringPointID = old.meteringPointID
            fresh.registerID = old.registerID
            result.append(fresh)
        }
        return result
    }

    /// Löscht die jüngste Generation; die vorige gilt wieder bis auf Weiteres.
    ///
    /// Nur die jüngste: Eine ältere zu löschen hinterließe eine Lücke ohne
    /// Preis, und für den Zeitraum stünden auf einmal keine Kosten mehr da.
    public static func removingNewest(
        tariffs: [Tariff],
        meteringPointID: MeteringPoint.ID
    ) throws -> [Tariff] {
        let all = generations(of: tariffs, meteringPointID: meteringPointID)
        guard all.count >= 2 else { throw HistoryError.onlyOnePrice }
        let removed = Set(all[0].tariffs.map(\.id))
        let reopened = Set(all[1].tariffs.map(\.id))
        let endBefore = all[0].validFrom.adding(days: -1)
        return tariffs.compactMap { tariff in
            if removed.contains(tariff.id) { return nil }
            guard reopened.contains(tariff.id) else { return tariff }
            var open = tariff
            // Nur ein Ende, das der neue Preis gesetzt hat, wird wieder offen.
            if open.validTo == endBefore { open.validTo = nil }
            return open
        }
    }
}
