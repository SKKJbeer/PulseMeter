import Foundation
import SwiftData
import PulseCore
import PulseData

/// Der Ausgangszustand für Oberflächentests und Bildschirmfotos.
///
/// **Warum beim Start und nicht in der Übersicht.** Bis 0.21.3 wertete
/// `OverviewView` die Startschalter aus. SwiftUI baut einen Tab aber erst,
/// wenn er sichtbar wird — ein Lauf, der direkt im Zähler-Schirm beginnt,
/// erreichte diesen Code nie. Übrig blieb, was der **vorherige** Start
/// hinterlassen hatte, und weil davor `-pulse-empty` lief, zeigte das Bild des
/// Zähler-Schirms „Noch kein Zähler", während die Übersicht drei Zähler
/// führte.
///
/// Der Fehler saß nicht in der App, sondern in der Prüfung — und das ist der
/// schlimmere Ort: Ein Bild, das lügt, sieht aus wie ein Bild. Der
/// Ausgangszustand gehört deshalb dorthin, wo er unabhängig von der
/// Bildschirmfolge entsteht.
///
/// `@MainActor`, und hier zu Recht: `ModelContext` ist weder threadsicher noch
/// `Sendable`. Das ist der Gegenfall zu `Reminders`, wo die Isolation an einer
/// ohnehin threadsicheren Systemschnittstelle nur geschadet hat.
@MainActor
enum LaunchFixture {

    /// Wird beim Start ausgeführt, bevor die erste Ansicht entsteht.
    ///
    /// Ohne Startschalter passiert nichts — im Alltag berührt diese Datei die
    /// Daten des Nutzers nie.
    static func apply(to container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        let empty = arguments.contains("-pulse-empty")
        let reset = arguments.contains("-pulse-reset")
        guard empty || reset else { return }

        let repository = PulseRepository(context: ModelContext(container))
        do {
            try repository.deleteEverything()
            if reset && !empty {
                try seedSamples(into: repository, today: CalendarDay.containing(Date(), in: .current))
            }
        } catch {
            // Absichtlich laut. Ein stillschweigend fehlgeschlagener
            // Ausgangszustand sähe auf dem Bild aus wie der Kaltstart — also
            // wie ein gültiger Zustand —, und genau daran wäre der Fehler
            // wieder unsichtbar. Erreichbar ist diese Stelle nur mit einem
            // Startschalter, den kein Nutzer setzt.
            fatalError("Der Ausgangszustand ließ sich nicht herstellen: \(error)")
        }
    }

    /// Legt drei Zähler mit gut zwei Jahren Historie an.
    ///
    /// So viel Vergangenheit braucht es, damit Verlaufslinie und
    /// Vorjahresvergleich überhaupt etwas zeigen können. Und drei Zähler statt
    /// einem, weil der Gaszähler bewusst überfällig ist: Nur so lassen sich
    /// der Fällig-Zustand, die Hinweiszeile und der Erfassungsfluss prüfen.
    /// Nicht privat: Der leere Startzustand bietet dieselben Beispieldaten an.
    /// Zwei Fassungen davon würden auseinanderlaufen, und dann zeigte das Bild
    /// etwas anderes als der Knopf.
    static func seedSamples(into repository: PulseRepository, today: CalendarDay) throws {
        // Jahresverläufe: Strom flach mit Winterhügel, Gas stark saisonal,
        // Wasser fast gleichmäßig.
        // Preise nach den Größenordnungen einer deutschen Jahresrechnung 2026.
        // Gas rechnet in kWh ab, obwohl der Zähler m³ misst — deshalb dort die
        // Umrechnung, ohne die der Rechenkern zu Recht keinen Betrag bildet.
        let profiles: [(name: String, kind: ResourceKind, start: Decimal,
                        monthly: [Decimal], staleMonths: Int,
                        price: Decimal, base: Decimal, gas: Bool,
                        prepay: Decimal?)] = [
            ("Strom", .electricity, 41_230,
             [312, 286, 268, 241, 218, 205, 198, 204, 226, 258, 289, 315], 0,
             Decimal(string: "0.34")!, Decimal(string: "12.90")!, false, 100),
            ("Wasser", .water, 998,
             [10.8, 9.9, 11.2, 10.6, 12.4, 13.1, 13.8, 13.2, 11.6, 10.9, 10.4, 11.1], 0,
             Decimal(string: "2.15")!, Decimal(string: "8.40")!, false, nil),
            ("Gas", .gas, 3_579,
             [418, 376, 298, 178, 92, 41, 36, 39, 84, 192, 308, 402], 3,
             Decimal(string: "0.11")!, Decimal(string: "14.50")!, true, 230)
        ]

        let property = try repository.ensureDefaultProperty()

        for profile in profiles {
            // Nur Zähler mit Abschlag bekommen einen Abrechnungsrhythmus —
            // sonst entstünden Zeiträume, gegen die es nichts zu rechnen
            // gibt. Wasser läuft hier bewusst ohne, damit auf den Bildern
            // beide Fälle nebeneinander stehen.
            let point = MeteringPoint(
                propertyID: property.id, name: profile.name, kind: profile.kind,
                billingCycle: profile.prepay == nil ? nil : BillingCycle(anchorMonth: 1, anchorDay: 1)
            )
            try repository.save(point)
            guard let register = point.primaryRegister else { continue }

            var value = profile.start
            for offset in stride(from: 25, through: profile.staleMonths, by: -1) {
                var month = today.month - offset
                var year = today.year
                while month < 1 { month += 12; year -= 1 }
                guard let day = CalendarDay(year: year, month: month, day: 1) else { continue }
                try repository.save(
                    Reading(registerID: register.id, day: day, value: value),
                    fractionDigits: register.fractionDigits
                )
                // Das laufende Jahr liegt sieben Prozent unter dem Vorjahr.
                let seasonal = profile.monthly[month - 1]
                value += year == today.year ? seasonal * Decimal(string: "0.93")! : seasonal
            }

            guard let yearStart = CalendarDay(year: today.year - 2, month: 1, day: 1) else { continue }
            try repository.save(Tariff(
                meteringPointID: point.id,
                validFrom: yearStart,
                pricePerUnit: profile.price,
                monthlyBasePrice: profile.base,
                billingUnit: profile.gas ? .kilowattHour : profile.kind.defaultUnit,
                gasConversion: profile.gas ? .typical : nil
            ))

            if let prepay = profile.prepay,
               let running = point.currentBillingPeriod(on: today) {
                try repository.save(BillingPeriod(
                    meteringPointID: point.id,
                    range: running,
                    monthlyPrepayment: prepay
                ))
            }
        }
    }
}
