import XCTest
@testable import PulseCore

/// Die Referenzprofile und was sie leisten.
///
/// **Warum diese Prüfungen anders gebaut sind als die übrigen.** Ein Profil
/// gegen Daten zu prüfen, die aus demselben Profil erzeugt wurden, beweist
/// nichts — der Rechenkern findet dann seine eigene Kurve wieder. Geprüft wird
/// deshalb zweierlei:
///
/// 1. **Eigenschaften**, die aus der Quelle folgen und die ein Tippfehler
///    zerstören würde: Summe, Verhältnis Winter zu Sommer, Reihenfolge der
///    Monate.
/// 2. **Vorhersagegüte gegen ein fremdes Jahr** — ein Jahr, das dem Profil
///    ausdrücklich *nicht* folgt. Nur so zeigt sich, was passiert, wenn ein
///    echter Haushalt vom Durchschnitt abweicht, und genau das ist der
///    Normalfall.
final class SeasonalProfileTests: XCTestCase {

    private let year2026 = span(day(2026, 1, 1), day(2027, 1, 1))

    // MARK: - Eigenschaften der Quellen

    func testEveryProfileSumsToOne() {
        for profile in [SeasonalProfile.heating, .household, .solar] {
            let total = profile.monthlyShares.reduce(0, +)
            assertClose(total, 1, accuracy: 0.0000001,
                        "Das Profil \(profile.source) summiert sich nicht auf ein Jahr")
            XCTAssertEqual(profile.monthlyShares.count, 12)
            XCTAssertFalse(profile.source.isEmpty, "Ein Profil ohne Quelle ist eine Behauptung")
        }
    }

    /// Heizen ist stark saisonal — das ist der ganze Grund für das Profil.
    /// Januar zu Juli steht nach den Gradtagszahlen bei rund 6 zu 1.
    func testHeatingIsStronglySeasonal() {
        let januar = approx(SeasonalProfile.heating.monthlyShares[0])
        let juli = approx(SeasonalProfile.heating.monthlyShares[6])
        XCTAssertGreaterThan(januar / juli, 5, "Der Winter muss den Sommer deutlich überragen")
        XCTAssertLessThan(januar / juli, 7)
        // Und der Sommer ist nicht null: Wer mit Gas auch das Wasser wärmt,
        // verbraucht im Juli etwas.
        XCTAssertGreaterThan(juli, 0.015, "Warmwasser fällt auch im Sommer an")
    }

    /// Haushaltsstrom schwankt, aber flach — rund 1,4 zu 1. Wer ihn wie
    /// Heizung behandelt, liegt genauso falsch wie umgekehrt.
    func testHouseholdElectricityIsMildlySeasonal() {
        let januar = approx(SeasonalProfile.household.monthlyShares[0])
        let juli = approx(SeasonalProfile.household.monthlyShares[6])
        XCTAssertGreaterThan(januar / juli, 1.2)
        XCTAssertLessThan(januar / juli, 1.6)
    }

    /// Photovoltaik läuft gegenläufig zum Verbrauch. Genau deshalb darf auf
    /// eine Einspeisung nie das Bezugsprofil angewandt werden.
    func testSolarRunsAgainstTheGrain() {
        let dezember = approx(SeasonalProfile.solar.monthlyShares[11])
        let juni = approx(SeasonalProfile.solar.monthlyShares[5])
        XCTAssertGreaterThan(juni / dezember, 6, "Sommer und Winter liegen bei PV um ein Vielfaches auseinander")

        // Sommerhalbjahr April bis September: veröffentlicht sind gut 70 %.
        let sommerhalbjahr = SeasonalProfile.solar.monthlyShares[3...8].reduce(0, +)
        XCTAssertGreaterThan(approx(sommerhalbjahr), 0.68)
        XCTAssertLessThan(approx(sommerhalbjahr), 0.76)
    }

    /// Eine Einspeisung folgt der Sonne, unabhängig davon, an welcher
    /// Zählerart sie hängt.
    func testFeedInAlwaysUsesTheSolarProfile() {
        for kind in [ResourceKind.electricity, .gas, .districtHeating] {
            XCTAssertEqual(SeasonalProfile.reference(for: kind, direction: .feedIn)?.source,
                           SeasonalProfile.solar.source)
        }
    }

    /// Wo es keine belastbare Quelle gibt, gibt es kein Profil — und dann
    /// rechnet der Rechenkern gleichmäßig weiter und sagt das. Ein erfundenes
    /// Profil wäre schlimmer als gar keines.
    func testNoProfileIsInventedWhereThereIsNoSource() {
        for kind in [ResourceKind.water, .hotWater, .rainwater, .operatingHours] {
            XCTAssertNil(SeasonalProfile.reference(for: kind),
                         "\(kind) hat keine belastbare Quelle und darf keine bekommen")
        }
    }

    // MARK: - Anteile über Zeiträume

    func testShareOfAFullYearIsEverything() {
        assertClose(SeasonalProfile.heating.share(of: year2026), 1, accuracy: 0.0000001)
    }

    /// Der Ausschnitt Januar bis März deckt beim Heizen fast die Hälfte des
    /// Jahres ab — bei 90 von 365 Tagen. Das ist die ganze Aussage.
    func testWinterQuarterCarriesAlmostHalfTheHeatingYear() {
        let quartal = SeasonalProfile.heating.share(of: span(day(2026, 1, 1), day(2026, 4, 1)))
        XCTAssertGreaterThan(approx(quartal), 0.40)
        XCTAssertLessThan(approx(quartal), 0.46)
        // Zum Vergleich: nach Tagen wären es 24,7 %.
        XCTAssertGreaterThan(approx(quartal), 90.0 / 365 * 1.6)
    }

    /// Innerhalb eines Monats wird nach Tagen geteilt — ein halber Januar ist
    /// der halbe Januar.
    func testAPartialMonthIsSplitByDays() {
        let voll = SeasonalProfile.heating.share(of: span(day(2026, 1, 1), day(2026, 2, 1)))
        let halb = SeasonalProfile.heating.share(of: span(day(2026, 1, 1), day(2026, 1, 16)))
        assertClose(halb, approx(voll) * 15 / 31, accuracy: 0.0001)
    }

    /// Ein Abrechnungszeitraum muss kein Kalenderjahr sein. Beginnt er im Juli,
    /// ist der Nenner ein anderer — und ein Anteil, der sich auf das
    /// Kalenderjahr bezieht, wäre schlicht falsch.
    func testShareIsRelativeToTheBillingPeriodNotTheCalendarYear() {
        let julyToJuly = span(day(2026, 7, 1), day(2027, 7, 1))
        let firstHalf = span(day(2026, 7, 1), day(2027, 1, 1))
        let share = SeasonalProfile.heating.share(of: firstHalf, within: julyToJuly)
        XCTAssertNotNil(share)
        // **Und zwar den kleineren Teil, nicht den größeren.** Juli bis
        // Dezember bringt beim Heizen rund 43 %: Der Winteranfang liegt zwar
        // darin, die beiden schwersten Monate — Januar und Februar — aber in
        // der zweiten Hälfte eines Juli-Jahres.
        //
        // Ich hatte hier zuerst „über die Hälfte" erwartet und lag falsch. Die
        // Zahl steht jetzt so da, weil genau diese Verwechslung der Grund ist,
        // warum der Anteil auf den Abrechnungszeitraum bezogen sein muss und
        // nicht aufs Kalenderjahr.
        XCTAssertGreaterThan(approx(share ?? 0), 0.40)
        XCTAssertLessThan(approx(share ?? 0), 0.46)
    }

    // MARK: - Vorhersagegüte gegen ein fremdes Jahr

    /// **Der eigentliche Prüfstein.** Ein Haushalt, dessen Jahr dem Profil
    /// *nicht* folgt: Die Heizperiode fällt 30 % milder aus, der Rest bleibt.
    /// Gemessen wird, wie weit die Hochrechnung am 1. Februar danebenliegt —
    /// dem schlechtesten Zeitpunkt des Jahres.
    ///
    /// Ohne Profil lag der Fehler dort bei **+100 %**. Erlaubt sind hier 25 %,
    /// und das ist keine Zielmarke, sondern eine Schranke: Wer sie reißt, hat
    /// etwas kaputtgemacht.
    func testHeatingForecastSurvivesAMilderWinter() {
        let register = Register.standard(for: .gas)
        // Ein Jahr, das ausdrücklich anders verläuft als das Profil.
        let echterVerlauf: [Decimal] = [280, 250, 230, 160, 90, 40, 35, 38, 80, 170, 250, 300]
        let jahresziel = echterVerlauf.reduce(0, +)

        var readings: [Reading] = []
        var value = Decimal(1000)
        for month in 1...12 {
            readings.append(Fixture.reading(register, day(2026, month, 1), value))
            value += echterVerlauf[month - 1]
        }
        readings.append(Fixture.reading(register, day(2027, 1, 1), value))

        for (monat, schranke) in [(2, 0.25), (4, 0.20), (7, 0.15)] {
            let heute = day(2026, monat, 1)
            let forecast = ForecastEngine.forecast(
                register: register, readings: readings.filter { $0.day <= heute },
                period: year2026, today: heute, kind: .gas)

            XCTAssertEqual(forecast?.method, .reference,
                           "Ohne eigenes Vorjahr muss das Profil greifen")
            let fehler = abs(approx(forecast?.projected.value ?? 0) - approx(jahresziel)) / approx(jahresziel)
            XCTAssertLessThan(fehler, schranke,
                              "Hochrechnung am 1.\(monat). liegt \(Int(fehler * 100)) % daneben")
        }
    }

    /// Dieselbe Messung ohne Profil — als Beleg dafür, dass die Schranke oben
    /// nicht trivial ist. Gleichmäßig fortgeschrieben liegt derselbe Gaszähler
    /// am 1. Februar um mehr als **60 %** zu hoch.
    ///
    /// Diese Prüfung darf nie grün werden, indem jemand die lineare Rechnung
    /// „verbessert": Sie hält fest, warum es die Profile gibt.
    func testWithoutAProfileTheSameYearIsWildlyOverstated() {
        let register = Register.standard(for: .gas)
        let echterVerlauf: [Decimal] = [280, 250, 230, 160, 90, 40, 35, 38, 80, 170, 250, 300]
        let jahresziel = approx(echterVerlauf.reduce(0, +))

        var readings: [Reading] = []
        var value = Decimal(1000)
        for month in 1...2 {
            readings.append(Fixture.reading(register, day(2026, month, 1), value))
            value += echterVerlauf[month - 1]
        }

        // `kind` fehlt bewusst — das ist der Zustand vor 0.38.0.
        let ohneProfil = ForecastEngine.forecast(
            register: register, readings: readings, period: year2026, today: day(2026, 2, 1))
        XCTAssertEqual(ohneProfil?.method, .linear)

        let fehler = (approx(ohneProfil?.projected.value ?? 0) - jahresziel) / jahresziel
        XCTAssertGreaterThan(fehler, 0.6,
                             "Ohne Profil muss die Hochrechnung im Februar grob zu hoch liegen — "
                             + "sonst prüft der Vergleich darüber nichts")
    }

    /// Das eigene Jahr schlägt das fremde Profil, sobald es vorliegt.
    ///
    /// Ein Referenzprofil ist der Durchschnitt vieler Haushalte, und niemand
    /// wohnt im Durchschnitt.
    func testOwnHistoryBeatsTheReferenceProfile() {
        let register = Register.standard(for: .gas)
        let verlauf: [Decimal] = [280, 250, 230, 160, 90, 40, 35, 38, 80, 170, 250, 300]

        var readings: [Reading] = []
        var value = Decimal(1000)
        for jahr in [2025, 2026] {
            for month in 1...12 {
                readings.append(Fixture.reading(register, day(jahr, month, 1), value))
                value += verlauf[month - 1]
            }
        }
        readings.append(Fixture.reading(register, day(2027, 1, 1), value))

        let heute = day(2026, 2, 1)
        let forecast = ForecastEngine.forecast(
            register: register, readings: readings.filter { $0.day <= heute },
            period: year2026, today: heute, kind: .gas)

        XCTAssertEqual(forecast?.method, .previousYear)
        // Gleicher Verlauf wie im Vorjahr → die Hochrechnung trifft.
        assertClose(forecast?.projected.value ?? 0, approx(verlauf.reduce(0, +)), accuracy: 1)
    }

    /// Drei eigene Jahre werden gemittelt, und die Methode sagt es.
    ///
    /// Der Nutzen zeigt sich am Ausreißer: Ein einzelnes verzerrtes Vorjahr
    /// zöge die Form sonst allein. Hier ist das mittlere Jahr doppelt so warm
    /// gefahren worden; das Mittel aus drei Jahren fängt das ab.
    func testThreeYearsAreAveragedAndSaidSo() {
        let register = Register.standard(for: .gas)
        let normal: [Decimal] = [280, 250, 230, 160, 90, 40, 35, 38, 80, 170, 250, 300]
        let ausreisser: [Decimal] = normal.map { $0 * dec("1.9") }

        var readings: [Reading] = []
        var value = Decimal(1000)
        for (jahr, verlauf) in [(2023, normal), (2024, ausreisser), (2025, normal), (2026, normal)] {
            for month in 1...12 {
                readings.append(Fixture.reading(register, day(jahr, month, 1), value))
                value += verlauf[month - 1]
            }
        }

        let heute = day(2026, 3, 1)
        let forecast = ForecastEngine.forecast(
            register: register, readings: readings.filter { $0.day <= heute },
            period: year2026, today: heute, kind: .gas)

        XCTAssertEqual(forecast?.method, .ownHistory, "Mehrere Jahre müssen als solche benannt werden")
        // Das Niveau kommt aus dem laufenden Jahr, die Form aus dem Mittel —
        // und weil der Ausreißer nur im Niveau abweicht, bleibt die Form
        // dieselbe und die Hochrechnung trifft.
        assertClose(forecast?.projected.value ?? 0, approx(normal.reduce(0, +)), accuracy: 1)
    }

    // MARK: - Kennzeichnung

    /// Jede Methode muss sich in einem Satzteil erklären lassen, und keiner
    /// davon darf technisch klingen (Produktprinzip 6).
    func testEveryMethodExplainsItself() {
        let verboten = ["Messstelle", "Zählwerk", "Register", "OBIS", "Entität",
                        "Datensatz", "Synchronisation", "linear", "Profil"]
        for method in ForecastEngine.Method.allCases {
            XCTAssertFalse(method.explanation.isEmpty)
            for wort in verboten {
                XCTAssertFalse(method.explanation.contains(wort),
                               "\(wort) gehört nicht auf den Schirm: \(method.explanation)")
            }
        }
        XCTAssertTrue(ForecastEngine.Method.ownHistory.usesOwnHistory)
        XCTAssertTrue(ForecastEngine.Method.previousYear.usesOwnHistory)
        XCTAssertFalse(ForecastEngine.Method.reference.usesOwnHistory,
                       "Ein fremdes Profil ist keine Beobachtung am Nutzer")
        XCTAssertFalse(ForecastEngine.Method.linear.usesOwnHistory)
    }
}
