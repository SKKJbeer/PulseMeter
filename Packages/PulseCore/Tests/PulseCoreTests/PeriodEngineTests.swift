import XCTest
@testable import PulseCore

/// Prüft die Zerlegung in Monate, Quartale und Jahre — und vor allem den
/// Vergleich desselben Abschnitts über mehrere Jahre.
///
/// Der Vergleich ist die Stelle, an der in diesem Projekt bisher jeder
/// Rechenfehler saß: Ein Zeitraum, den die Daten abdecken, gegen einen, den sie
/// nicht abdecken. Die Hälfte dieser Tests prüft deshalb nur, dass beide Seiten
/// denselben Ausschnitt des Jahres beschreiben.
final class PeriodEngineTests: XCTestCase {

    /// Zwei volle Jahre mit 100 Einheiten im Monat, ab 1. Januar 2025.
    /// Ablesungen liegen auf jedem Monatsersten, also alles exakt gemessen.
    private func evenSeries(perMonth: Decimal = 100, through end: CalendarDay) -> (Register, [Reading]) {
        let register = Fixture.electricityRegister()
        var readings: [Reading] = []
        var value: Decimal = 1000
        var year = 2025, month = 1, sequence = 0
        while let currentDay = CalendarDay(year: year, month: month, day: 1), currentDay <= end {
            readings.append(Fixture.reading(register, currentDay, value, sequence: sequence))
            value += perMonth
            sequence += 1
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
        return (register, readings)
    }

    // MARK: - Grenzen

    func testMonthRangeRunsToTheFirstOfTheNextMonth() {
        let range = PeriodEngine.range(year: 2026, slot: 2, granularity: .month)
        XCTAssertEqual(range?.start, day(2026, 2, 1))
        XCTAssertEqual(range?.end, day(2026, 3, 1))
    }

    func testQuarterRangeCoversThreeMonths() {
        let range = PeriodEngine.range(year: 2026, slot: 4, granularity: .quarter)
        XCTAssertEqual(range?.start, day(2026, 10, 1))
        XCTAssertEqual(range?.end, day(2027, 1, 1),
                       "Das vierte Quartal endet am 1. Januar des Folgejahres")
    }

    func testYearRangeCrossesIntoTheNextYear() {
        let range = PeriodEngine.range(year: 2026, slot: 1, granularity: .year)
        XCTAssertEqual(range?.start, day(2026, 1, 1))
        XCTAssertEqual(range?.end, day(2027, 1, 1))
    }

    // MARK: - Abschnitte

    func testTwelveMonthsWithEvenConsumption() {
        let (register, readings) = evenSeries(through: day(2027, 1, 1))
        let months = PeriodEngine.buckets(register: register, readings: readings,
                                          year: 2026, granularity: .month)

        XCTAssertEqual(months.count, 12)
        XCTAssertTrue(months.allSatisfy { $0.value == 100 })
        XCTAssertTrue(months.allSatisfy(\.isComplete))
        XCTAssertEqual(months.map(\.slot), Array(1...12))
    }

    func testQuartersSumTheirMonths() {
        let (register, readings) = evenSeries(through: day(2027, 1, 1))
        let quarters = PeriodEngine.buckets(register: register, readings: readings,
                                            year: 2026, granularity: .quarter)

        XCTAssertEqual(quarters.count, 4)
        XCTAssertTrue(quarters.allSatisfy { $0.value == 300 })
    }

    /// Monate ohne Daten fallen nicht heraus. Eine Lücke ist eine Aussage —
    /// wer sie weglässt, zeichnet ein Jahr, das so nie stattgefunden hat.
    func testMonthsWithoutDataAreReportedRatherThanDropped() {
        let (register, readings) = evenSeries(through: day(2026, 5, 1))
        let months = PeriodEngine.buckets(register: register, readings: readings,
                                          year: 2026, granularity: .month)

        XCTAssertEqual(months.count, 12)
        XCTAssertTrue(months[0].hasData, "Januar liegt vollständig vor")
        XCTAssertTrue(months[3].hasData, "April endet am 1. Mai, also gedeckt")
        XCTAssertFalse(months[5].hasData, "Ab Juni gibt es keine Ablesungen mehr")
        XCTAssertEqual(months[5].value, 0)
        XCTAssertEqual(months[5].result.coverage, .none)
    }

    // MARK: - Derselbe Monat über mehrere Jahre

    func testCompareSameMonthAcrossYears() {
        let register = Fixture.electricityRegister()
        // Februar 2025: 200, Februar 2026: 150.
        let readings = [
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 3, 1), 1200, sequence: 1),
            Fixture.reading(register, day(2026, 2, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 3, 1), 3150, sequence: 3)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 2, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertEqual(comparison?.entries.count, 2)
        XCTAssertEqual(comparison?.entries[0].year, 2026)
        XCTAssertEqual(comparison?.entries[0].value, 150)
        XCTAssertEqual(comparison?.entries[1].year, 2025)
        XCTAssertEqual(comparison?.entries[1].value, 200)
        XCTAssertEqual(comparison?.relativeChange, dec("-0.25"))
        XCTAssertEqual(comparison?.isPartial, false)
    }

    /// Der Kern: Läuft der Monat noch, wird das Vorjahr auf denselben
    /// Ausschnitt beschnitten. Sonst stünde ein halber Februar gegen einen
    /// ganzen und die App meldete einen Rückgang, den es nicht gibt.
    func testRunningMonthIsComparedAgainstTheSameSliceOfLastYear() {
        let register = Fixture.electricityRegister()
        let readings = [
            // Voller Februar 2025: 280 in 28 Tagen, also 10 am Tag.
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 3, 1), 1280, sequence: 1),
            // 2026 nur bis zum 15. Februar: 140 in 14 Tagen, ebenfalls 10 am Tag.
            Fixture.reading(register, day(2026, 2, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 2, 15), 3140, sequence: 3)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 2, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertEqual(comparison?.isPartial, true,
                       "Der Februar 2026 ist nicht vollständig gedeckt")
        XCTAssertEqual(comparison?.window.start, day(2026, 2, 1))
        XCTAssertEqual(comparison?.window.end, day(2026, 2, 15))
        XCTAssertEqual(comparison?.entries[0].value, 140)
        XCTAssertEqual(comparison?.entries[1].value, 140,
                       "Das Vorjahr muss auf den 1. bis 15. Februar beschnitten sein")
        XCTAssertEqual(comparison?.relativeChange, 0,
                       "Gleicher Tagesverbrauch, gleicher Ausschnitt — keine Veränderung")
    }

    /// Gegenprobe: Ohne Beschneidung stünden 140 gegen 280, also −50 %.
    /// Dieser Test hält fest, dass genau das *nicht* herauskommt.
    func testPartialMonthDoesNotReportAFalseDecline() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 3, 1), 1280, sequence: 1),
            Fixture.reading(register, day(2026, 2, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 2, 15), 3140, sequence: 3)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 2, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertNotEqual(comparison?.relativeChange, dec("-0.5"))
    }

    func testComparisonIsNilWhenTheReferenceYearHasNoData() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 3, 1), 1280, sequence: 1)
        ]

        XCTAssertNil(PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 2, granularity: .month, referenceYear: 2026, yearsBack: 1
        ), "Ohne Daten im Bezugsjahr gibt es nichts zu vergleichen")
    }

    /// Ein früheres Jahr, das den Ausschnitt nur halb abdeckt, darf nicht wie
    /// ein sparsames Jahr aussehen. Seine Zahl ist keine kleinere Menge,
    /// sondern eine unvollständige — und damit nicht vergleichbar.
    func testYearWithPartialDataIsNotComparable() {
        let register = Fixture.electricityRegister()
        let readings = [
            // 2025 endet mitten im Februar.
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 2, 14), 1130, sequence: 1),
            // 2026 hat den ganzen Februar.
            Fixture.reading(register, day(2026, 2, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 3, 1), 3280, sequence: 3)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 2, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertNil(comparison?.relativeChange,
                     "Als harte Zahl darf die Veränderung nicht gemeldet werden")
        // Seit 0.65.0 verschweigt die Karte sie trotzdem nicht, sondern zeigt
        // sie gekennzeichnet — der Ausschnitt ist dafür auf das gekürzt, was
        // beide Jahre abdecken.
        XCTAssertEqual(comparison?.isNarrowed, true)
        XCTAssertNotNil(comparison?.approximateChange)
        XCTAssertEqual(comparison?.changeIsApproximate, true)
    }

    /// Das Bezugsjahr rechnet über sein eigenes Fenster und ist darin immer
    /// vollständig — sonst ließe sich ein laufender Monat nicht von einem
    /// Monat mit fehlenden Ablesungen unterscheiden.
    func testReferenceYearIsAlwaysCompleteWithinItsOwnWindow() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 2, 1), 3000, sequence: 0),
            Fixture.reading(register, day(2026, 2, 15), 3140, sequence: 1)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 2, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertEqual(comparison?.isPartial, true)
        XCTAssertEqual(comparison?.entries[0].isComparable, true)
        XCTAssertEqual(comparison?.entries[0].value, 140)
    }

    /// Ein Schalttag darf die Verschiebung nicht zum Scheitern bringen.
    func testLeapDayShiftsToTheTwentyEighth() {
        XCTAssertEqual(PeriodEngine.shifted(day(2024, 2, 29), byYears: 1), day(2025, 2, 28))
        XCTAssertEqual(PeriodEngine.shifted(day(2024, 2, 29), byYears: -4), day(2020, 2, 29))
    }

    func testComparisonSpansThreeYears() {
        let (register, readings) = evenSeries(through: day(2027, 1, 1))
        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 3, granularity: .month, referenceYear: 2026, yearsBack: 2
        )

        XCTAssertEqual(comparison?.entries.map(\.year), [2026, 2025, 2024])
        XCTAssertEqual(comparison?.entries[0].value, 100)
        XCTAssertEqual(comparison?.entries[1].value, 100)
        XCTAssertFalse(comparison?.entries[2].hasData ?? true,
                       "2024 liegt vor der ersten Ablesung")
    }
    // MARK: - Ein angebrochenes Vorjahr

    /// **Der häufigste Fall bei einem neuen Nutzer.** Wer im Mai anfängt, hat
    /// vom Vorjahr nie einen vollen Monat — und bekam bis 0.64.1 „keine Daten"
    /// statt eines Vergleichs. Jetzt wird der Ausschnitt auf das gekürzt, was
    /// beide Jahre abdecken: gleicher Zeitausschnitt, nur ein kürzerer.
    func testACurtailedPreviousYearStillComparesOnTheSharedWindow() {
        let register = Fixture.electricityRegister()
        let readings = [
            // 2025 reicht nur bis zum 12. Mai: 120 in 11 Tagen.
            Fixture.reading(register, day(2025, 5, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 5, 12), 1120, sequence: 1),
            // 2026 deckt den ganzen Mai: 300 in 30 Tagen, also 10 am Tag.
            Fixture.reading(register, day(2026, 5, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 5, 31), 3300, sequence: 3)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 5, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertEqual(comparison?.isNarrowed, true,
                       "Der Ausschnitt wurde gekürzt, damit 2025 mitkommt")
        XCTAssertEqual(comparison?.window.start, day(2026, 5, 1))
        XCTAssertEqual(comparison?.window.end, day(2026, 5, 12))
        assertClose(comparison?.entries[0].value ?? 0, 110, "11 Tage à 10")
        XCTAssertEqual(comparison?.entries[1].value, 120)
        XCTAssertEqual(comparison?.entries[1].isComparable, true,
                       "Auf dem gemeinsamen Ausschnitt ruht das Vorjahr auf eigenen Ablesungen")
        XCTAssertNotNil(comparison?.approximateChange,
                        "Und damit gibt es endlich eine Veränderung zu zeigen")
        XCTAssertEqual(comparison?.entries[0].isApproximate, true,
                       "2026 ist hier aus einem Monatsschritt herausgeschnitten — gekennzeichnet, nicht verschwiegen")
    }

    /// Ein Jahr ganz ohne Ablesungen kürzt nichts. Sonst wäre der Vergleich mit
    /// dem Vorjahr davon abhängig, ob es ein Jahr davor gibt.
    func testAYearWithoutAnyReadingsDoesNotCurtailTheWindow() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 5, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 6, 1), 1300, sequence: 1),
            Fixture.reading(register, day(2026, 5, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 6, 1), 3300, sequence: 3)
        ]

        // 2024 gibt es nicht — und darf den Vergleich 2026 gegen 2025 nicht
        // anfassen.
        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 5, granularity: .month, referenceYear: 2026, yearsBack: 2
        )

        XCTAssertEqual(comparison?.isNarrowed, false)
        XCTAssertEqual(comparison?.window.start, day(2026, 5, 1))
        XCTAssertEqual(comparison?.window.end, day(2026, 6, 1))
        XCTAssertEqual(comparison?.entries.count, 3)
        XCTAssertEqual(comparison?.entries[2].hasData, false, "2024 bleibt leer")
        XCTAssertEqual(comparison?.relativeChange, 0)
    }

    /// Aber ein Stummel kürzt auch nicht: Vier Tage, die „Mai" heißen, sind
    /// wieder eine Aussage über einen Zeitraum, den die Zahlen nicht beschreiben.
    func testATinyOverlapIsNotWorthCurtailingFor() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 5, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2025, 5, 4), 1030, sequence: 1),
            Fixture.reading(register, day(2026, 5, 1), 3000, sequence: 2),
            Fixture.reading(register, day(2026, 5, 31), 3300, sequence: 3)
        ]

        let comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: 5, granularity: .month, referenceYear: 2026, yearsBack: 1
        )

        XCTAssertEqual(comparison?.isNarrowed, false)
        XCTAssertEqual(comparison?.window.end, day(2026, 5, 31), "Der volle Mai bleibt stehen")
        XCTAssertEqual(comparison?.entries[1].isComparable, false,
                       "Und 2025 sagt weiterhin: dazu liegt nichts vor")
    }

}

// MARK: - Vergleichbare Ausschnitte

/// **Acht Monate gegen zwei Tage sind kein Prozentwert.**
///
/// Auf dem Gerät des Gründers stand „≈ +8.657 % gegenüber Vorjahr": 1.532 kWh
/// aus acht Monaten 2026 gegen ≈ 18 kWh aus zwei Dezembertagen 2025 — seiner
/// allerersten Ablesung. Beide Zahlen für sich stimmen; die Zahl dazwischen ist
/// die wiederkehrende Fehlerklasse dieses Projekts.
final class VergleichbareAusschnitteTests: XCTestCase {

    private func punkt(_ readings: [(CalendarDay, Decimal)]) -> (MeteringPoint, [Reading]) {
        let werk = Fixture.electricityRegister()
        let point = MeteringPoint(propertyID: Fixture.property.id, name: "Strom 1",
                                  kind: .electricity, registers: [werk])
        var folge = 0
        let liste = readings.map { tag, wert -> Reading in
            folge += 1
            return Reading(registerID: werk.id, day: tag, value: wert,
                           createdAt: Date(timeIntervalSince1970: TimeInterval(folge)))
        }
        return (point, liste)
    }

    func testTwoDaysAgainstEightMonthsYieldsNoPercentage() throws {
        // Zwei Ablesungen im August 2025 — mehr gab es damals nicht —, danach
        // laufend durch 2026. Vom Fenster des Bezugsjahres (1. Januar bis
        // 20. August) deckt 2025 also zwei Tage ab, 2026 gut acht Monate.
        // Das Zusammenschneiden auf einen gemeinsamen Ausschnitt greift hier
        // nicht: Drei Tage sind kein Jahr, und die Vierteltagsgrenze in
        // `comparison(slot:…)` lehnt es zu Recht ab.
        var werte: [(CalendarDay, Decimal)] = [
            (day(2025, 8, 18), 1_000),
            (day(2025, 8, 20), 1_018),
            (day(2026, 1, 1), 2_600)
        ]
        var stand = Decimal(2_600)
        for monat in 2...8 {
            stand += 190
            werte.append((day(2026, monat, 20), stand))
        }
        let (point, readings) = punkt(werte)

        let vergleich = try XCTUnwrap(PeriodEngine.compareAcrossYears(
            meteringPoint: point, readings: readings, slot: 1, granularity: .year,
            referenceYear: 2026, yearsBack: 2))

        // Beide Zahlen dürfen dastehen — gekennzeichnet, wie Produktprinzip 7
        // es verlangt. Nur der Prozentwert dazwischen nicht.
        XCTAssertTrue(vergleich.entries[0].hasData, "2026 muss eine Zahl haben")
        XCTAssertTrue(vergleich.entries[1].hasData, "2025 hat zwei gemessene Tage")
        XCTAssertFalse(vergleich.spansAreComparable,
                       "Zwei Tage und acht Monate decken den Ausschnitt nicht ähnlich weit ab")
        XCTAssertNil(vergleich.approximateChange,
                     "Aus acht Monaten gegen zwei Tage darf kein Prozentwert entstehen")
    }

    func testASlightlyShorterPreviousYearKeepsItsComparison() throws {
        // Vorjahr fängt zwei Wochen später an — das bleibt vergleichbar.
        var werte: [(CalendarDay, Decimal)] = [(day(2025, 1, 15), 1_000)]
        var stand = Decimal(1_000)
        for monat in 2...12 {
            stand += 180
            werte.append((day(2025, monat, 1), stand))
        }
        for monat in 1...8 {
            stand += 170
            werte.append((day(2026, monat, 1), stand))
        }
        let (point, readings) = punkt(werte)

        let vergleich = try XCTUnwrap(PeriodEngine.compareAcrossYears(
            meteringPoint: point, readings: readings, slot: 1, granularity: .year,
            referenceYear: 2026, yearsBack: 1))

        XCTAssertTrue(vergleich.spansAreComparable,
                      "Zwei Wochen Unterschied sind kein Grund, den Vergleich wegzuwerfen")
        XCTAssertNotNil(vergleich.approximateChange,
                        "Hier gehört ein Prozentwert hin")
    }
}
