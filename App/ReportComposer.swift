import Foundation
import SwiftData
import PulseCore
import PulseData

/// Setzt einen Verbrauchsbericht aus dem Gespeicherten zusammen.
///
/// **Warum getrennt von der Ansicht.** Der Bericht entsteht an zwei Stellen: im
/// Herunterladen-Menü des Verlaufs als fertige Datei, und auf dem
/// Berichtsschirm mit Auswahl und Vorschau. Zwei Fassungen dieser
/// Zusammenstellung würden früher oder später verschiedene PDFs erzeugen, und
/// der Unterschied fiele erst dem auf, der beide nebeneinanderlegt — also dem
/// Nutzer, vor seinem Vermieter.
@MainActor
struct ReportComposer {

    /// Kein Fehler des Programms, sondern eine Lage: Für den gewählten Zeitraum
    /// gibt es nichts zu berichten. Die Ansicht sagt das in einem Satz, statt
    /// ein leeres Dokument auszugeben.
    enum Problem: LocalizedError {
        case keineAblesungen(zeitraum: String)

        var errorDescription: String? {
            switch self {
            case .keineAblesungen(let zeitraum):
                return "Für \(zeitraum.lowercased()) liegen keine Ablesungen vor."
            }
        }
    }

    let context: ModelContext

    /// - Parameter scope: Ein einzelner Zähler, oder `nil` für alle zusammen.
    func report(
        scope: MeteringPoint.ID?,
        period: ReportBuilder.Period,
        today: CalendarDay
    ) throws -> ReportBuilder.Report {
        let repository = PulseRepository(context: context)
        let alle = try repository.meteringPoints()
        let gewaehlt = scope.map { id in alle.filter { $0.id == id } } ?? alle

        var readings: [MeteringPoint.ID: [Reading]] = [:]
        var tariffs: [MeteringPoint.ID: [Tariff]] = [:]
        var prepayments: [MeteringPoint.ID: Decimal] = [:]
        for meter in gewaehlt {
            readings[meter.id] = try repository.readings(for: meter)
            tariffs[meter.id] = try repository.tariffs(for: meter.id)
            // Der Abschlag des Zeitraums, in dem der Bericht liegt — nicht
            // irgendeiner. Ein Abschlag aus einem anderen Jahr gegen die Kosten
            // dieses Jahres zu rechnen wäre wieder der Vergleich zweier
            // verschiedener Zeitausschnitte.
            let billing = try repository.billingPeriods(for: meter.id)
            if let match = billing.first(where: { $0.range.contains(period.range.start) })
                ?? billing.last,
               let amount = match.monthlyPrepayment {
                prepayments[meter.id] = amount
            }
        }

        let built = ReportBuilder.build(
            meteringPoints: gewaehlt, readings: readings, tariffs: tariffs,
            prepayments: prepayments, period: period,
            propertyName: (try? repository.ensureDefaultProperty().name) ?? "Zuhause",
            today: today)

        guard !built.isEmpty else { throw Problem.keineAblesungen(zeitraum: period.label) }
        return built
    }
}
