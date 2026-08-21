import XCTest
@testable import PulseCore

/// **Was der Rechenkern kosten darf.**
///
/// Nicht funktional, sondern zeitlich: Diese Prüfungen sagen nichts darüber,
/// *ob* richtig gerechnet wird, sondern *wie lange* es dauert. Der Anlass ist
/// echt — der Gründer beim ersten Gebrauch: „das ‚alle Ablesungen' lädt ziemlich
/// lange". Der Grund lag damals in der Ansicht, nicht im Kern. Damit das so
/// bleibt, stehen hier Obergrenzen.
///
/// **Die Grenzen sind großzügig gesetzt, mit Absicht.** Ein Prüfrechner ist
/// launisch; eine Grenze, die knapp über dem Messwert liegt, schlägt irgendwann
/// grundlos an, und eine Prüfung, die grundlos anschlägt, liest nach drei Tagen
/// niemand mehr. Sie fangen Größenordnungen ab — aus Millisekunden werden
/// Sekunden, weil jemand eine Schleife in eine Schleife gelegt hat.
///
/// Gemessen wird gegen einen **großen, aber realistischen** Bestand: zehn Jahre
/// tägliche Ablesungen an einem Doppeltarifzähler. Das ist mehr, als ein
/// Haushalt je erzeugt, und genau deshalb der richtige Maßstab.
final class PerformanceBudgetTests: XCTestCase {

    private struct Bestand {
        let point: MeteringPoint
        let readings: [Reading]
        let tariffs: [Tariff]
    }

    /// Zehn Jahre, jeden Tag, zwei Zählwerke — 7.306 Ablesungen.
    private func grosserBestand() -> Bestand {
        let hoch = Register(label: "Hochtarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let nieder = Register(label: "Niedertarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let point = MeteringPoint(propertyID: Fixture.property.id, name: "Dauerlast",
                                  kind: .electricity, registers: [hoch, nieder])

        var readings: [Reading] = []
        for werk in [hoch, nieder] {
            var stand = Decimal(1_000)
            var tag = day(2016, 1, 1)
            var folge = 0
            while tag < day(2026, 1, 1) {
                readings.append(Reading(registerID: werk.id, day: tag, value: stand,
                                        createdAt: Date(timeIntervalSince1970: TimeInterval(folge))))
                stand += 12
                tag = tag.adding(days: 1)
                folge += 1
            }
        }

        let tariffs = [
            Tariff(meteringPointID: point.id, registerID: hoch.id,
                   validFrom: day(2016, 1, 1), pricePerUnit: dec("0.31"),
                   monthlyBasePrice: dec("9.90"), billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, registerID: nieder.id,
                   validFrom: day(2016, 1, 1), pricePerUnit: dec("0.21"),
                   monthlyBasePrice: 0, billingUnit: .kilowattHour)
        ]
        return Bestand(point: point, readings: readings, tariffs: tariffs)
    }

    /// Misst einen Durchgang und meldet, wenn er über der Grenze liegt.
    private func hoechstens(_ sekunden: Double, _ was: String,
                            datei: StaticString = #filePath, zeile: UInt = #line,
                            _ arbeit: () -> Void) {
        let beginn = DispatchTime.now()
        arbeit()
        let dauer = Double(DispatchTime.now().uptimeNanoseconds - beginn.uptimeNanoseconds) / 1_000_000_000
        // Die gemessene Zeit steht im Protokoll, auch wenn nichts anschlägt.
        // Eine Grenze ohne Messwert daneben sagt nur „noch gut", und niemand
        // sieht, dass es von 40 auf 900 Millisekunden gegangen ist.
        print(String(format: "  ⏱  %@: %.3f s (Grenze %.1f s)", was, dauer, sekunden))
        XCTAssertLessThan(dauer, sekunden,
                          "\(was) braucht \(String(format: "%.3f", dauer)) s — Grenze ist \(sekunden) s",
                          file: datei, line: zeile)
    }

    func testTheHistoryScreenComputesInTime() {
        let b = grosserBestand()

        // Was der Verlaufsschirm beim Öffnen tut: zwölf Monate, drei Jahre
        // Vergleich, dazu die Kosten je Abschnitt.
        hoechstens(1.5, "Zwölf Monatsabschnitte über 7.306 Ablesungen") {
            _ = PeriodEngine.buckets(meteringPoint: b.point, readings: b.readings,
                                     year: 2025, granularity: .month)
        }

        hoechstens(1.5, "Jahresansicht über drei Jahre") {
            for jahr in 2023...2025 {
                _ = PeriodEngine.buckets(meteringPoint: b.point, readings: b.readings,
                                         year: jahr, granularity: .year)
            }
        }

        hoechstens(2.0, "Vergleich eines Monats über drei Jahre") {
            _ = PeriodEngine.compareAcrossYears(meteringPoint: b.point, readings: b.readings,
                                                slot: 2, granularity: .month,
                                                referenceYear: 2025, yearsBack: 2)
        }
    }

    func testCostAndReportStayFast() {
        let b = grosserBestand()

        hoechstens(2.0, "Kosten über ein ganzes Jahr") {
            _ = try? CostEngine.cost(meteringPoint: b.point, readings: b.readings,
                                     tariffs: b.tariffs,
                                     in: span(day(2025, 1, 1), day(2026, 1, 1)))
        }

        hoechstens(3.0, "Verbrauchsbericht für ein Jahr") {
            guard let zeitraum = ReportBuilder.periods(today: day(2026, 1, 15)).first else { return }
            _ = ReportBuilder.build(
                meteringPoints: [b.point],
                readings: [b.point.id: b.readings],
                tariffs: [b.point.id: b.tariffs],
                prepayments: [:],
                period: zeitraum,
                propertyName: "Zuhause",
                today: day(2026, 1, 15))
        }
    }

    /// Der Export ist der Fall, der wirklich alle Zeilen anfasst.
    func testExportOfEverythingStaysFast() {
        let b = grosserBestand()
        hoechstens(2.0, "CSV über 7.306 Ablesungen") {
            let csv = TableExport.readings(b.readings, meteringPoint: b.point, meterName: b.point.name)
            XCTAssertGreaterThan(csv.count, 100_000)
        }
    }

    /// **Der Widerhaken gegen quadratisches Wachstum.**
    ///
    /// Eine Grenze allein fängt eine Schleife in einer Schleife nicht: Bei
    /// tausend Ablesungen bleibt auch quadratisch unter einer Sekunde. Deshalb
    /// wird hier verglichen, wie sich die Zeit entwickelt, wenn die Menge sich
    /// vervierfacht — linear wäre viermal, quadratisch sechzehnmal.
    func testWorkGrowsRoughlyWithTheData() {
        func dauer(tage: Int) -> Double {
            let werk = Fixture.electricityRegister()
            var readings: [Reading] = []
            var stand = Decimal(1_000)
            var tag = day(2020, 1, 1)
            for folge in 0..<tage {
                readings.append(Reading(registerID: werk.id, day: tag, value: stand,
                                        createdAt: Date(timeIntervalSince1970: TimeInterval(folge))))
                stand += 10
                tag = tag.adding(days: 1)
            }
            let beginn = DispatchTime.now()
            _ = PeriodEngine.buckets(register: werk, readings: readings,
                                     year: 2020, granularity: .month)
            return Double(DispatchTime.now().uptimeNanoseconds - beginn.uptimeNanoseconds) / 1_000_000_000
        }

        // **Bestzeit statt Einzelmessung.**
        //
        // Eine Messung kann durch fremde Last auf demselben Rechner nur größer
        // werden, nie kleiner. Der Mittelwert bildet damit die Auslastung des
        // Prüfrechners ab, das Minimum die Arbeit des Codes. Genau daran ist
        // diese Prüfung in 0.67.1 gescheitert: 10,1 auf dem Prüfrechner gegen
        // 3,3 auf demselben Stand daneben — ein Ausreißer in einer einzigen
        // Messung, kein Fund am Rechenkern.
        func bestzeit(tage: Int) -> Double {
            (0..<5).map { _ in dauer(tage: tage) }.min() ?? 0
        }

        // Aufwärmen: Der erste Durchgang zahlt für Zwischenspeicher, die mit der
        // Sache nichts zu tun haben.
        _ = dauer(tage: 500)
        // Größer als vorher (500/2.000), damit die kleinere Messung deutlich
        // über der Auflösung der Uhr liegt. Bei einer halben Millisekunde misst
        // man den Taktgeber mit.
        let klein = bestzeit(tage: 2_000)
        let gross = bestzeit(tage: 8_000)
        let faktor = gross / Swift.max(klein, 0.0001)
        print(String(format: "  ⏱  Vervierfachte Menge kostet das %.1f-fache (%.1f ms → %.1f ms)",
                     faktor, klein * 1000, gross * 1000))
        // Linear wäre vier, `n log n` knapp fünf, quadratisch sechzehn. Sechs
        // trennt das, was tragen wird, von dem, was bei zehn Jahren umkippt.
        XCTAssertLessThan(faktor, 6,
                          "Vierfache Datenmenge kostet das \(String(format: "%.1f", faktor))-fache — "
                          + "das wächst zu schnell, um bei zehn Jahren noch zu tragen")
    }
}
