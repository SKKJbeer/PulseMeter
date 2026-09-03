import XCTest
@testable import PulseCore

final class ForecastEngineTests: XCTestCase {

    // Halboffen bis zum 1. Januar des Folgejahres — so, wie `BillingCycle`
    // einen Abrechnungszeitraum liefert und wie jede Verbrauchsrechnung im
    // Projekt einen Zeitraum versteht.
    private let year2026 = span(day(2026, 1, 1), day(2027, 1, 1))

    func testLinearProjectionWithoutHistory() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900)     // 90 Tage, 10 kWh je Tag
        ]

        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2026, 4, 1)
        )

        XCTAssertEqual(forecast?.method, .linear)
        XCTAssertEqual(forecast?.daysElapsed, 90)
        XCTAssertEqual(forecast?.daysRemaining, 275)
        assertClose(forecast?.projected.value ?? 0, 3650)   // 365 Tage × 10 kWh
        XCTAssertEqual(forecast?.confidence, .estimated, "Eine Hochrechnung ist nie gemessen")
    }

    /// Bei Gas und Heizung ist die lineare Hochrechnung im Winter grob falsch.
    /// Liegt das Vorjahr vollständig vor, wird dessen Verlauf als Muster genutzt.
    func testSeasonalProjectionUsesPreviousYearShape() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 1, 1), 0),
            Fixture.reading(register, day(2025, 4, 1), 1200),   // 40 % des Vorjahres
            Fixture.reading(register, day(2025, 12, 31), 3000),
            Fixture.reading(register, day(2026, 1, 1), 3000),
            Fixture.reading(register, day(2026, 4, 1), 4000)    // 1000 kWh bisher
        ]

        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2026, 4, 1)
        )

        XCTAssertEqual(forecast?.method, .previousYear)
        // 1000 kWh entsprechen 40 % → 2500 kWh erwartet,
        // deutlich unter der linearen Schätzung von rund 4040 kWh.
        assertClose(forecast?.projected.value ?? 0, 2500, accuracy: 0.01)
    }

    /// Ein veralteter Zählerstand darf die Prognose nicht drücken: Die Tage
    /// zwischen letzter Ablesung und heute gehören zur Restzeit, nicht zum
    /// gemessenen Zeitraum. Sonst sagt die App ausgerechnet dem Nutzer, der
    /// länger nicht abgelesen hat, einen zu niedrigen Verbrauch voraus.
    func testStaleReadingDoesNotDepressProjection() {
        let register = Fixture.electricityRegister()
        let upToDate = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900)      // 90 Tage, 10 kWh/Tag
        ]
        let stale = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 3, 1), 590)      // 59 Tage, 10 kWh/Tag
        ]

        let fresh = ForecastEngine.forecast(register: register, readings: upToDate,
                                            period: year2026, today: day(2026, 4, 1))
        let old = ForecastEngine.forecast(register: register, readings: stale,
                                          period: year2026, today: day(2026, 4, 1))

        XCTAssertEqual(old?.daysElapsed, 59)
        XCTAssertEqual(old?.daysRemaining, 306, "Die 31 Tage seit der letzten Ablesung zählen zur Restzeit")
        assertClose(old?.projected.value ?? 0, 3650)   // 365 Tage × 10 kWh
        XCTAssertEqual(approx(old?.projected.value ?? 0), approx(fresh?.projected.value ?? 0),
                       accuracy: 0.01, "Gleicher Tagesverbrauch, gleiche Prognose")
    }

    func testCompletedPeriodIsNotProjected() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            // Auf der Grenze, nicht einen Tag davor: Die Jahresablesung
            // gehört auf den Stichtag, sonst bleibt ein Tag ungedeckt und die
            // Reihe rechnet ihn zu Recht hoch.
            Fixture.reading(register, day(2027, 1, 1), 3000)
        ]

        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2027, 1, 15)
        )

        XCTAssertEqual(forecast?.daysRemaining, 0)
        XCTAssertEqual(forecast?.projected.value, 3000)
    }

    func testNoForecastWithoutReadings() {
        let register = Fixture.electricityRegister()
        XCTAssertNil(ForecastEngine.forecast(
            register: register, readings: [], period: year2026, today: day(2026, 4, 1)))
    }

    // MARK: - Abschlagsvergleich

    /// Die Aussage, für die das Produkt existiert.
    func testPrepaymentOutlookPredictsRefund() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 100)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 4, 1)
        )

        XCTAssertNotNil(outlook)
        // **Von Hand nachgerechnet, seit 0.38.0 nach dem Referenzprofil.**
        // Januar bis März sind im Standardlastprofil H0 zusammen 27,651 % des
        // Jahres — mehr als die 24,7 %, die 90 von 365 Tagen ergäben, denn im
        // Winter läuft das Licht länger. Also: 900 kWh ÷ 0,27651 = 3255 kWh
        // im Jahr, × 0,30 € = 976,46 €. Abschläge 12 × 100 € = 1200 €.
        //
        // Vorher stand hier 1095 € aus der gleichmäßigen Fortschreibung
        // (3650 kWh). Die 119 € Unterschied sind kein Rundungsfehler, sondern
        // der Betrag, um den die App einem Nutzer im Frühjahr zu viel
        // vorhergesagt hat.
        assertClose(outlook?.totalPrepayment.amount ?? 0, 1200, accuracy: 0.01)
        assertClose(outlook?.projectedCost.amount ?? 0, 976.46, accuracy: 0.01)
        assertClose(outlook?.balance.amount ?? 0, 223.54, accuracy: 0.01)
        XCTAssertEqual(outlook?.expectsRefund, true)
        XCTAssertEqual(outlook?.method, .reference,
                       "Ohne eigenes Vorjahr trägt das veröffentlichte Profil — und sagt das auch")
    }

    func testPrepaymentOutlookPredictsAdditionalPayment() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 1800)   // doppelter Verbrauch
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 100)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 4, 1)
        )

        XCTAssertEqual(outlook?.expectsRefund, false)
        // 1800 kWh ÷ 0,27651 = 6510 kWh × 0,30 € = 1952,91 €, minus 1200 € Abschläge.
        assertClose(outlook?.balance.amount ?? 0, -752.91, accuracy: 0.01)
    }

    func testNoOutlookWithoutPrepayment() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026)

        XCTAssertNil(try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: [], tariffs: [tariff],
            period: period, today: day(2026, 4, 1)
        ))
    }

    func testBillingPeriodLengthIsFractional() {
        let point = Fixture.meteringPoint(registers: [Fixture.electricityRegister()])
        let full = BillingPeriod(meteringPointID: point.id, range: year2026)
        assertClose(full.lengthInMonths, 12, accuracy: 0.01)

        let half = BillingPeriod(
            meteringPointID: point.id,
            range: span(day(2026, 1, 1), day(2026, 7, 1))
        )
        assertClose(half.lengthInMonths, 5.95, accuracy: 0.05)
    }

    /// Bei einem Zweirichtungszähler bekommt jedes Zählwerk seine eigene
    /// Hochrechnung.
    ///
    /// Der Fall, der die Fehlerklasse aus CLAUDE.md in neuem Gewand zeigt:
    /// Vorher wurde der Arbeitspreis der ganzen Messstelle — Bezug **minus**
    /// Einspeisevergütung — mit dem Faktor des ersten Zählwerks skaliert. Das
    /// ist nur richtig, wenn beide Zählwerke denselben Ausschnitt abdecken.
    ///
    /// Hier reicht der Bezug bis zum 1. Juli, die Einspeisung nur bis zum
    /// 1. April — jemand hat die zweite Zahl einmal vergessen. Der Bezug
    /// rechnet sich also mit 365/181 hoch, die Einspeisung mit 365/90.
    ///
    /// **Seit 0.38.0 mit den Referenzprofilen, und dadurch deutlich anders.**
    /// Der Bezug folgt dem Haushaltsprofil, die Einspeisung der Sonne — zwei
    /// gegenläufige Formen an einem Gerät.
    ///
    /// - Bezug: 900 kWh bis zum 1. Juli. Januar bis Juni sind im H0-Profil
    ///   50,499 % des Jahres → 1782,2 kWh × 0,30 € = **534,66 €**
    /// - Einspeisung: 300 kWh bis zum 1. April. Januar bis März bringen aber
    ///   nur 15,579 % des Jahresertrags einer Anlage → 1925,7 kWh
    ///   × 0,10 € = **192,57 €**
    /// - Erwartet: 534,66 − 192,57 = **342,09 €**
    ///
    /// Vorher stand hier 422,81 €. Der Unterschied von 81 € kommt fast
    /// vollständig aus der Einspeisung: Gleichmäßig fortgeschrieben hätte die
    /// Anlage im Rest des Jahres so weitergeliefert wie im Winter — bei
    /// Photovoltaik der schlechtestmögliche Schätzwert. Dezember zu Juni steht
    /// wie 1 zu 9.
    func testOutlookProjectsEachRegisterWithItsOwnShape() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [draw, feedIn])
        let readings = [
            Fixture.reading(draw, day(2026, 1, 1), 0),
            Fixture.reading(draw, day(2026, 7, 1), 900),
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2026, 4, 1), 300)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour,
                            feedInPricePerUnit: dec("0.10"))
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 50)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 7, 1)
        )

        assertClose(outlook?.projectedCost.amount ?? 0, 342.09, accuracy: 0.02)
        assertClose(outlook?.totalPrepayment.amount ?? 0, 600, accuracy: 0.01)
        assertClose(outlook?.balance.amount ?? 0, 257.91, accuracy: 0.02)
        XCTAssertEqual(outlook?.expectsRefund, true)
    }

    /// Die Einspeisung mindert die Vorschau tatsächlich.
    ///
    /// Ohne diese Prüfung könnte die Gegenrichtung stillschweigend wegfallen —
    /// die Zahl sähe plausibel aus und wäre um die ganze Vergütung zu hoch.
    func testFeedInLowersTheOutlook() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let readings = [
            Fixture.reading(draw, day(2026, 1, 1), 0),
            Fixture.reading(draw, day(2026, 7, 1), 900),
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2026, 7, 1), 600)
        ]

        func projected(_ registers: [Register], feedInPrice: Decimal?) throws -> Decimal {
            let point = Fixture.meteringPoint(registers: registers)
            let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                                pricePerUnit: dec("0.30"), billingUnit: .kilowattHour,
                                feedInPricePerUnit: feedInPrice)
            let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                       monthlyPrepayment: 50)
            let outlook = try ForecastEngine.prepaymentOutlook(
                meteringPoint: point, readings: readings, tariffs: [tariff],
                period: period, today: day(2026, 7, 1))
            return outlook?.projectedCost.amount ?? 0
        }

        let withoutFeedIn = try projected([draw], feedInPrice: nil)
        let withFeedIn = try projected([draw, feedIn], feedInPrice: dec("0.10"))
        XCTAssertLessThan(withFeedIn, withoutFeedIn,
                          "Die Einspeisung muss die erwarteten Kosten senken")
        // 600 kWh bis zum 1. Juli sind 53,684 % des Jahresertrags einer Anlage
        // → 1117,6 kWh × 0,10 € = 111,76 € Gutschrift. Gleichmäßig
        // fortgeschrieben wären es 120,99 € gewesen — zu viel, denn die
        // Sonnenhälfte des Jahres ist zur Jahresmitte schon zur Hälfte vorbei.
        assertClose(withoutFeedIn - withFeedIn, 111.76, accuracy: 0.02)
    }

    /// Die Grundlage kommt bis in den Abschlagsvergleich mit — sonst steht auf
    /// der Karte ein Betrag, dem niemand ansieht, worauf er beruht.
    ///
    /// Bei mehreren Zählwerken zählt die **schwächste** Grundlage. Hier hat
    /// der Bezug ein eigenes Vorjahr, die Einspeisung nicht; genannt wird
    /// deshalb das Referenzprofil.
    func testTheOutlookNamesItsWeakestBasis() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [draw, feedIn])
        let readings = [
            // Der Bezug hat ein vollständiges Vorjahr.
            Fixture.reading(draw, day(2025, 1, 1), 0),
            Fixture.reading(draw, day(2025, 4, 1), 1000),
            Fixture.reading(draw, day(2026, 1, 1), 3000),
            Fixture.reading(draw, day(2026, 4, 1), 3900),
            // Die Einspeisung erst seit Januar.
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2026, 4, 1), 300)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2025, 1, 1),
                            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour,
                            feedInPricePerUnit: dec("0.10"))
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 100)

        let outlook = try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 4, 1))

        XCTAssertEqual(outlook?.method, .reference,
                       "Genannt wird die schwächste Grundlage, nicht die schmeichelhafteste")
        XCTAssertEqual(outlook?.method.usesOwnHistory, false)
    }

    /// Ohne Profil und ohne Vorjahr bleibt es bei der gleichmäßigen
    /// Fortschreibung — und auch das steht dann da.
    ///
    /// Wasser ist der Fall: Es schwankt über das Jahr kaum, ein Profil dafür
    /// wäre erfunden, und gleichmäßig ist hier die ehrliche Annahme.
    func testWaterStaysLinearAndSaysSo() {
        let register = Register.standard(for: .water)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 30)
        ]
        let forecast = ForecastEngine.forecast(
            register: register, readings: readings,
            period: year2026, today: day(2026, 4, 1), kind: .water)

        XCTAssertEqual(forecast?.method, .linear)
        assertClose(forecast?.projected.value ?? 0, 121.667, accuracy: 0.01)
    }
    // MARK: - Der ganze Zähler

    /// **Bei Doppeltarif zählt die Summe, nicht das erste Zählwerk.**
    ///
    /// Der Verlauf zeichnet einen Balken je Zähler. Eine Hochrechnung, die nur
    /// das erste Zählwerk fortschreibt, stünde daneben und wäre systematisch zu
    /// klein — bei zwei gleich großen Zählwerken um die Hälfte.
    func testForecastForAWholeMeterAddsUpItsRegisters() {
        let hoch = Register(label: "Hochtarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let nieder = Register(label: "Niedertarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let point = MeteringPoint(propertyID: Fixture.property.id, name: "Strom",
                                  kind: .electricity, registers: [hoch, nieder])

        // Beide Zählwerke: 10 je Tag, vom 1. bis zum 15. August.
        var readings: [Reading] = []
        var folge = 0
        for werk in [hoch, nieder] {
            readings.append(Fixture.reading(werk, day(2026, 8, 1), 1_000, sequence: folge)); folge += 1
            readings.append(Fixture.reading(werk, day(2026, 8, 15), 1_140, sequence: folge)); folge += 1
        }

        let august = span(day(2026, 8, 1), day(2026, 9, 1))
        let prognose = ForecastEngine.forecast(meteringPoint: point, readings: readings,
                                               period: august, today: day(2026, 8, 15))

        XCTAssertNotNil(prognose)
        // Gemessen sind 280 (zweimal 140) in 14 Tagen; der August hat 31.
        XCTAssertEqual(prognose?.actual.quantity.value, 280)
        assertClose(prognose?.projected.value ?? 0, 620, accuracy: 1,
                    "Zwei Zählwerke à 10 kWh am Tag ergeben rund 620 kWh im August")

        // Und die Gegenprobe: Ein einzelnes Zählwerk kommt auf die Hälfte.
        let einzeln = ForecastEngine.forecast(register: hoch, readings: readings,
                                              period: august, today: day(2026, 8, 15),
                                              kind: .electricity)
        assertClose(einzeln?.projected.value ?? 0, 310, accuracy: 1)
    }

    /// Eine Hochrechnung darf nie unter dem liegen, was schon gemessen ist.
    func testAForecastIsNeverBelowWhatIsAlreadyMeasured() {
        let werk = Fixture.electricityRegister()
        let point = MeteringPoint(propertyID: Fixture.property.id, name: "Strom",
                                  kind: .electricity, registers: [werk])
        let readings = [
            Fixture.reading(werk, day(2026, 8, 1), 1_000, sequence: 0),
            Fixture.reading(werk, day(2026, 8, 20), 1_900, sequence: 1)
        ]
        let august = span(day(2026, 8, 1), day(2026, 9, 1))
        let prognose = ForecastEngine.forecast(meteringPoint: point, readings: readings,
                                               period: august, today: day(2026, 8, 20))
        XCTAssertNotNil(prognose)
        XCTAssertGreaterThanOrEqual(prognose!.projected.value, prognose!.actual.quantity.value,
                                    "Die Hochrechnung liegt unter dem Ist")
    }

    /// Ein abgeschlossener Monat wird nicht hochgerechnet — da gibt es nichts
    /// mehr zu erwarten.
    func testNoForecastForAFinishedPeriod() {
        let werk = Fixture.electricityRegister()
        let point = MeteringPoint(propertyID: Fixture.property.id, name: "Strom",
                                  kind: .electricity, registers: [werk])
        let readings = [
            Fixture.reading(werk, day(2026, 7, 1), 1_000, sequence: 0),
            Fixture.reading(werk, day(2026, 8, 1), 1_310, sequence: 1)
        ]
        let juli = span(day(2026, 7, 1), day(2026, 8, 1))
        XCTAssertNil(ForecastEngine.forecast(meteringPoint: point, readings: readings,
                                             period: juli, today: day(2026, 8, 21)),
                     "Der Juli ist vorbei")
    }


    // MARK: - Die Posten müssen die Summe ergeben

    /// **Der Test, der den Fehler des Entwurfs gefangen hätte.**
    ///
    /// Am 3. September fand der Gründer auf dem Erklärblatt „Wie diese Zahl
    /// entsteht" 947,68 € Arbeitspreis und 154,80 € Grundpreis über einer
    /// Summe von 911,88 €. Die fehlenden 190,60 € waren die
    /// Einspeisevergütung: abgezogen, aber nirgends genannt.
    ///
    /// Ein Schirm, der erklärt, wie eine Zahl entsteht, und dabei einen Posten
    /// auslässt, ist schlimmer als gar keiner — er sieht aus wie eine
    /// Herleitung. Deshalb ist die Aufschlüsselung eine Zusicherung des
    /// Rechenkerns und keine Sache der Oberfläche.
    func testAufschluesselungErgibtDieSumme() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [draw, feedIn])
        let readings = [
            Fixture.reading(draw, day(2026, 1, 1), 0),
            Fixture.reading(draw, day(2026, 7, 1), 900),
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2026, 4, 1), 300),
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"),
                            monthlyBasePrice: dec("12.90"),
                            billingUnit: .kilowattHour,
                            feedInPricePerUnit: dec("0.10"))
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 50)

        let outlook = try XCTUnwrap(try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 7, 1)))
        let posten = outlook.breakdown

        XCTAssertNotNil(posten.feedInCredit,
                        "Bei einer Anlage gehört die Vergütung in die Aufschlüsselung")
        XCTAssertGreaterThan(posten.feedInCredit?.amount ?? 0, 0,
                             "Sie steht positiv da und wird abgezogen — nicht umgekehrt")
        assertClose(posten.sum.amount,
                    (outlook.projectedCost.amount as NSDecimalNumber).doubleValue,
                    accuracy: 0.02)
        XCTAssertGreaterThan(posten.standingCost.amount, 0,
                             "Der Grundpreis läuft über den Zeitraum, nicht über die Ablesungen")
    }

    /// Ohne Einspeisung fehlt die Zeile — und die Summe stimmt trotzdem.
    ///
    /// Eine Vergütung von 0,00 € stünde da als Aussage über Geld, die niemand
    /// gemacht hat (Produktprinzip 7).
    func testAufschluesselungOhneEinspeisung() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 0),
            Fixture.reading(register, day(2026, 4, 1), 900),
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"),
                            monthlyBasePrice: dec("12.90"),
                            billingUnit: .kilowattHour)
        let period = BillingPeriod(meteringPointID: point.id, range: year2026,
                                   monthlyPrepayment: 100)

        let outlook = try XCTUnwrap(try ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: [tariff],
            period: period, today: day(2026, 4, 1)))

        XCTAssertNil(outlook.breakdown.feedInCredit)
        assertClose(outlook.breakdown.sum.amount,
                    (outlook.projectedCost.amount as NSDecimalNumber).doubleValue,
                    accuracy: 0.02)
        XCTAssertGreaterThan(outlook.breakdown.projectedConsumption.value,
                             outlook.breakdown.consumptionToDate.value,
                             "Hochgerechnet ist mehr als bisher gemessen")
    }
}
