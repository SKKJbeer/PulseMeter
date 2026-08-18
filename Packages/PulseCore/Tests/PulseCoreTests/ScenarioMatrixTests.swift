import XCTest
@testable import PulseCore

/// **Viele Szenarien, wenige Behauptungen.**
///
/// Die übrigen Prüfungen dieses Projekts rechnen je einen Fall von Hand nach.
/// Das ist genau, aber es deckt nur ab, woran jemand gedacht hat — und die
/// Rechenfehler dieses Projekts entstanden bisher alle dort, wo niemand
/// hingesehen hat: bei einem Zeitraum, den die Daten nicht abdecken.
///
/// Diese Datei geht andersherum vor. Sie baut **hunderte** Zähler aus allen
/// Kombinationen, die das Modell zulässt — Sparte, Zählwerke, Ablesetakt,
/// Zählerwechsel, Überlauf, Schätzungen, Uhrzeiten, Schaltjahre — und prüft an
/// jedem einzelnen dieselben **Invarianten**: Sätze, die für jede richtige
/// Rechnung gelten müssen, egal wie die Zahlen aussehen.
///
/// Der Zufall ist gesät und damit wiederholbar: Fällt eine Prüfung, fällt sie
/// beim nächsten Lauf wieder, und die Beschreibung nennt den Fall beim Namen.
final class ScenarioMatrixTests: XCTestCase {

    // MARK: - Wiederholbarer Zufall

    /// Linearer Kongruenzgenerator. Absichtlich kein `SystemRandomNumberGenerator`:
    /// Ein Fehlschlag, der sich nicht wiederholen lässt, ist keine Prüfung,
    /// sondern eine Anekdote.
    struct Wuerfel {
        private var zustand: UInt64
        init(saat: UInt64) { zustand = saat &* 6_364_136_223_846_793_005 &+ 1 }

        mutating func naechste() -> UInt64 {
            zustand = zustand &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return zustand >> 16
        }
        mutating func ganzzahl(_ bereich: ClosedRange<Int>) -> Int {
            let spanne = UInt64(bereich.upperBound - bereich.lowerBound + 1)
            return bereich.lowerBound + Int(naechste() % spanne)
        }
        mutating func waehle<T>(_ werte: [T]) -> T { werte[ganzzahl(0...(werte.count - 1))] }
        mutating func trifft(_ prozent: Int) -> Bool { ganzzahl(1...100) <= prozent }
    }

    // MARK: - Ein Szenario

    struct Szenario {
        let name: String
        let point: MeteringPoint
        let readings: [Reading]
        let jahre: [Int]
    }

    /// Baut einen Zähler samt Ablesungen. Alles daran ist eine Achse, auf der
    /// dieses Produkt schon einmal falsch gerechnet hat.
    private func szenario(saat: UInt64) -> Szenario {
        var w = Wuerfel(saat: saat)

        let sparte: ResourceKind = w.waehle([.electricity, .gas, .water, .wallbox,
                                             .solarProduction, .districtHeating])
        let modus: AccumulationMode = w.trifft(15) ? .interval : .cumulative
        let stellen = w.ganzzahl(4...7)
        let nachkomma = w.waehle([0, 1, 2, 3])

        // Ein, zwei oder drei Zählwerke: Doppeltarif und Zweirichtung sind die
        // Fälle, in denen ein Export schon einmal die Hälfte verloren hat.
        let bauart = w.ganzzahl(1...3)
        var werke: [Register] = [
            Register(label: bauart > 1 ? "Hochtarif" : nil, unit: sparte.defaultUnit,
                     accumulation: modus, integerDigits: stellen, fractionDigits: nachkomma)
        ]
        if bauart >= 2 {
            werke.append(Register(label: "Niedertarif", unit: sparte.defaultUnit,
                                  accumulation: modus, integerDigits: stellen,
                                  fractionDigits: nachkomma))
        }
        if bauart == 3 {
            werke.append(Register(label: "Einspeisung", unit: sparte.defaultUnit,
                                  direction: .feedIn, accumulation: modus,
                                  integerDigits: stellen, fractionDigits: nachkomma))
        }

        // Ein Zählerwechsel mitten in der Reihe. Der erklärte Rücksprung ist der
        // Fall, an dem der Rechenkern am leichtesten einen Verbrauch erfindet.
        let wechseltag = w.trifft(30) ? day(2025, w.ganzzahl(2...11), w.ganzzahl(1...28)) : nil
        var geraete: [MeterDevice] = []
        if let wechseltag {
            geraete = [
                MeterDevice(serialNumber: "ALT", installedOn: day(2024, 1, 1), removedOn: wechseltag),
                MeterDevice(serialNumber: "NEU", installedOn: wechseltag)
            ]
        }

        let point = MeteringPoint(propertyID: Fixture.property.id,
                                  name: "Prüfzähler \(saat)", kind: sparte,
                                  registers: werke, devices: geraete)

        // Der Takt: täglich, wöchentlich, monatlich, unregelmäßig — und mit
        // Lücken, weil echte Nutzer in den Urlaub fahren.
        let takt = w.waehle([1, 7, 14, 30, 45, 90])
        let lueckenAnteil = w.waehle([0, 0, 10, 25])
        let startJahr = 2024
        let jahre = [2024, 2025, 2026]

        var readings: [Reading] = []
        for werk in werke {
            var stand = Decimal(w.ganzzahl(0...5_000))
            let kapazitaet = werk.capacity
            var tag = day(startJahr, 1, 1)
            let ende = day(2026, 8, 1)
            var geraeteWechselErledigt = false

            while tag <= ende {
                let ueberspringen = w.ganzzahl(1...100) <= lueckenAnteil
                if !ueberspringen {
                    let herkunft: ReadingOrigin = w.trifft(10) ? .estimated : .manual
                    let zeit = w.trifft(40) ? TimeOfDay(hour: w.ganzzahl(0...23),
                                                        minute: w.ganzzahl(0...59)) : nil
                    let geraet = wechseltag.map { tag < $0 ? geraete[0].id : geraete[1].id }
                    readings.append(Reading(registerID: werk.id, deviceID: geraet,
                                            day: tag, time: zeit,
                                            value: stand, origin: herkunft,
                                            createdAt: Date(timeIntervalSince1970:
                                                            TimeInterval(tag.serialNumber))))
                }
                // Am Wechseltag steht der neue Zähler auf null — der erklärte
                // Rücksprung, den die Kette aushalten muss.
                if let wechseltag, tag >= wechseltag, !geraeteWechselErledigt {
                    stand = Decimal(w.ganzzahl(0...50))
                    geraeteWechselErledigt = true
                } else {
                    stand += Decimal(w.ganzzahl(0...40)) + Decimal(w.ganzzahl(0...9)) / 10
                    // Überlauf: Ein volles Zählwerk springt auf null zurück.
                    if stand >= kapazitaet { stand -= kapazitaet }
                }
                tag = tag.adding(days: Swift.max(1, takt + w.ganzzahl(-2...2)))
            }
        }

        let beschreibung = "\(sparte) · \(werke.count) Werk(e) · \(modus) · Takt \(takt)"
            + " · Lücken \(lueckenAnteil)%" + (wechseltag != nil ? " · Wechsel" : "")
        return Szenario(name: beschreibung, point: point, readings: readings, jahre: jahre)
    }

    // MARK: - Die Invarianten

    /// Wie viele Zähler geprüft werden. 240 Szenarien × je ein Dutzend Zusagen
    /// laufen in Sekunden — die Zahl ist so gewählt, dass die Prüfung noch in
    /// den Vor-dem-Push-Haken passt.
    private let anzahl = 240

    func testEveryScenarioObeysTheInvariants() {
        for saat in 1...UInt64(anzahl) {
            let s = szenario(saat: saat)
            let hinweis = "Szenario \(saat): \(s.name)"

            for jahr in s.jahre {
                let monate = PeriodEngine.buckets(meteringPoint: s.point, readings: s.readings,
                                                  year: jahr, granularity: .month)
                let quartale = PeriodEngine.buckets(meteringPoint: s.point, readings: s.readings,
                                                    year: jahr, granularity: .quarter)
                let jahrBucket = PeriodEngine.buckets(meteringPoint: s.point, readings: s.readings,
                                                      year: jahr, granularity: .year)

                XCTAssertEqual(monate.count, 12, hinweis)
                XCTAssertEqual(quartale.count, 4, hinweis)
                XCTAssertEqual(jahrBucket.count, 1, hinweis)

                // **1. Kein negativer Verbrauch.** Ein Rücksprung, den der Kern
                // nicht erklären kann, muss null ergeben — nie eine negative
                // Menge, die sich später in eine Summe schleicht.
                for bucket in monate + quartale + jahrBucket {
                    XCTAssertGreaterThanOrEqual(bucket.value, 0,
                        "\(hinweis): negativer Verbrauch in \(bucket.id)")
                }

                // **2. Die Teile ergeben das Ganze — aber nur bei gleichem
                // Ausschnitt.** Sind alle zwölf Monate vollständig gedeckt, muss
                // ihre Summe das Jahr ergeben. Genau hier lag die
                // wiederkehrende Fehlerklasse dieses Projekts.
                if monate.allSatisfy(\.isComplete), let jahrWert = jahrBucket.first, jahrWert.isComplete {
                    let summe = monate.reduce(Decimal(0)) { $0 + $1.value }
                    assertClose(summe, approx(jahrWert.value), accuracy: 0.5,
                                "\(hinweis): zwölf volle Monate ≠ das Jahr")
                }

                // **3. Dasselbe eine Ebene tiefer:** drei volle Monate sind ein
                // volles Quartal.
                for (index, quartal) in quartale.enumerated() where quartal.isComplete {
                    let drei = Array(monate[(index * 3)..<(index * 3 + 3)])
                    guard drei.allSatisfy(\.isComplete) else { continue }
                    let summe = drei.reduce(Decimal(0)) { $0 + $1.value }
                    assertClose(summe, approx(quartal.value), accuracy: 0.5,
                                "\(hinweis): drei volle Monate ≠ das Quartal Q\(index + 1)")
                }

                // **4. Ein abgedeckter Abschnitt hat eine Zahl, ein leerer
                // nicht.** „Keine Daten" und „null Verbrauch" dürfen nie
                // dasselbe sein — sonst sieht ein fehlender Monat aus wie ein
                // sparsamer.
                for bucket in monate where !bucket.hasData {
                    XCTAssertEqual(bucket.value, 0,
                        "\(hinweis): Abschnitt ohne Daten trägt eine Menge")
                }
            }

            // **5. Die Reihenfolge der Eingabe darf nichts ändern.** Ablesungen
            // kommen aus dem Speicher in beliebiger Reihenfolge; `chronological`
            // ist die einzige Stelle, die das ordnet.
            var w = Wuerfel(saat: saat &* 7)
            var gemischt = s.readings
            for i in stride(from: gemischt.count - 1, to: 0, by: -1) {
                gemischt.swapAt(i, w.ganzzahl(0...i))
            }
            let ordentlich = PeriodEngine.buckets(meteringPoint: s.point, readings: s.readings,
                                                  year: 2025, granularity: .month)
            let gewuerfelt = PeriodEngine.buckets(meteringPoint: s.point, readings: gemischt,
                                                  year: 2025, granularity: .month)
            XCTAssertEqual(ordentlich.map(\.value), gewuerfelt.map(\.value),
                           "\(hinweis): die Eingabereihenfolge ändert das Ergebnis")

            // **6. Der Export verliert nichts.** Ein Zähler mit zwei Zahlen hat
            // schon einmal die Hälfte verloren, und die Datei sah vollständig
            // aus.
            let csv = TableExport.readings(s.readings, meteringPoint: s.point,
                                           meterName: s.point.name)
            let zeilen = csv.split(separator: "\r\n").count
            XCTAssertEqual(zeilen, s.readings.count + 1,
                           "\(hinweis): der Export hat Zeilen verloren oder erfunden")
        }
    }

    /// **7. Jeder Vergleich stellt gleiche Ausschnitte gegenüber.**
    ///
    /// Die eine Invariante, um die es diesem Projekt am meisten geht. Geprüft
    /// wird nicht das Ergebnis, sondern die Form: Beide Seiten müssen
    /// gleich lange Fenster beschreiben, auf den Tag genau.
    func testEveryComparisonPutsEqualWindowsSideBySide() {
        for saat in 1...UInt64(anzahl) {
            let s = szenario(saat: saat)
            let hinweis = "Szenario \(saat): \(s.name)"

            for granularitaet in PeriodEngine.Granularity.allCases {
                for slot in 1...granularitaet.slotsPerYear {
                    guard let vergleich = PeriodEngine.compareAcrossYears(
                        meteringPoint: s.point, readings: s.readings,
                        slot: slot, granularity: granularitaet,
                        referenceYear: 2026, yearsBack: 2) else { continue }

                    let laengen = Set(vergleich.entries.map(\.result.requestedRange.dayCount))
                    XCTAssertEqual(laengen.count, 1,
                        "\(hinweis): \(granularitaet) \(slot) vergleicht verschieden lange Zeiträume: \(laengen)")

                    // Und der Ausschnitt liegt in jedem Jahr an derselben
                    // Stelle des Jahres — sonst wäre bei einem saisonalen
                    // Zähler Januar gegen Juli verglichen.
                    let tage = Set(vergleich.entries.map {
                        "\($0.result.requestedRange.start.month)-\($0.result.requestedRange.start.day)"
                    })
                    XCTAssertEqual(tage.count, 1,
                        "\(hinweis): \(granularitaet) \(slot) vergleicht verschiedene Ausschnitte des Jahres: \(tage)")

                    // Eine gemeldete Veränderung setzt zwei Zahlen voraus.
                    if vergleich.approximateChange != nil {
                        XCTAssertTrue(vergleich.entries[0].hasData && vergleich.entries[1].hasData,
                            "\(hinweis): Veränderung ohne zwei Zahlen")
                    }
                }
            }
        }
    }

    /// **8. Eine Ablesung, die auf der Linie liegt, ändert nichts.**
    ///
    /// Wer zwischen zwei Ablesungen eine dritte einträgt, die genau dem
    /// interpolierten Wert entspricht, darf den Gesamtverbrauch nicht
    /// verschieben. Fällt diese Zusage, rechnet die Interpolation schief — und
    /// das fiele sonst niemandem auf, weil beide Zahlen für sich plausibel sind.
    func testAnInterpolatedReadingChangesNothing() {
        let register = Fixture.electricityRegister()
        for saat in 1...60 {
            var w = Wuerfel(saat: UInt64(saat))
            let start = Decimal(w.ganzzahl(100...9_000))
            let tage = w.ganzzahl(10...200)
            let menge = Decimal(w.ganzzahl(10...4_000))
            let von = day(2025, w.ganzzahl(1...6), w.ganzzahl(1...28))
            let bis = von.adding(days: tage)

            let basis = [
                Fixture.reading(register, von, start, sequence: 0),
                Fixture.reading(register, bis, start + menge, sequence: 1)
            ]
            let mitte = von.adding(days: tage / 2)
            let anteil = Decimal(mitte.days(since: von)) / Decimal(tage)
            let dazwischen = Fixture.reading(register, mitte, start + menge * anteil, sequence: 2)

            let ohne = ConsumptionEngine.consumption(register: register, readings: basis,
                                                     in: span(von, bis))
            let mit = ConsumptionEngine.consumption(register: register,
                                                    readings: basis + [dazwischen],
                                                    in: span(von, bis))
            assertClose(mit.quantity.value, approx(ohne.quantity.value), accuracy: 0.5,
                        "Eine Ablesung auf der Interpolationslinie hat den Verbrauch verschoben")
        }
    }
}
