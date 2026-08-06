import XCTest
@testable import PulseCore

/// Diese Testklasse ist die ausführbare Fassung der Randfall-Tabelle aus
/// docs/02-datenmodell.md, Abschnitt 3.
final class ConsumptionEngineTests: XCTestCase {

    // MARK: - Grundfall

    func testConsumptionBetweenTwoReadings() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertEqual(result.quantity.value, 300)
        XCTAssertEqual(result.quantity.unit, .kilowattHour)
        XCTAssertEqual(result.confidence, .measured)
        XCTAssertEqual(result.coveredDays, 31)
        XCTAssertTrue(result.isComplete)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testSingleReadingYieldsNoConsumption() {
        let register = Fixture.electricityRegister()
        let readings = [Fixture.reading(register, day(2026, 1, 1), 1000)]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertFalse(result.hasData)
        XCTAssertTrue(result.warnings.contains(.insufficientReadings))
    }

    // MARK: - Interpolation

    func testInterpolatesInsideGapAndFlagsIt() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1310)   // 310 kWh über 31 Tage
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 16), day(2026, 2, 1))
        )

        // 16 der 31 Tage → 160 kWh
        assertClose(result.quantity.value, 160)
        XCTAssertEqual(result.confidence, .interpolated,
                       "Eine interpolierte Zahl darf nie als gemessen ausgewiesen werden")
    }

    func testReportsMissingDataAtBothEnds() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 2, 1), 1000),
            Fixture.reading(register, day(2026, 3, 1), 1280)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 4, 1))
        )

        XCTAssertEqual(result.quantity.value, 280)
        XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.coveredRange, span(day(2026, 2, 1), day(2026, 3, 1)))
        XCTAssertTrue(result.warnings.contains(.noDataBeforeStart(firstReading: day(2026, 2, 1))))
        XCTAssertTrue(result.warnings.contains(.noDataAfterEnd(lastReading: day(2026, 3, 1))))
    }

    /// Über das Ende der Daten hinaus wird nicht extrapoliert. Eine Hochrechnung
    /// ist eine eigene, ausdrücklich gekennzeichnete Operation.
    func testDoesNotExtrapolate() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1310)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 12, 31))
        )

        XCTAssertEqual(result.quantity.value, 310, "Nicht 3720 — es wird nicht fortgeschrieben")
    }

    // MARK: - Zählerüberlauf

    func testRolloverNearCapacityIsBridged() {
        // Fünfstelliges Werk: Überlauf bei 100.000
        let register = Register(unit: .cubicMetre, integerDigits: 5, fractionDigits: 0)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 99_500),
            Fixture.reading(register, day(2026, 2, 1), 200)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        // 100.000 − 99.500 + 200 = 700
        XCTAssertEqual(result.quantity.value, 700)
        XCTAssertTrue(result.warnings.contains(.rolloverAssumed(on: day(2026, 2, 1))))
    }

    /// Ein Rücksprung weit unterhalb des Überlaufpunkts ist ein Tippfehler,
    /// kein Überlauf. Hier zu raten würde einen absurd hohen Verbrauch erzeugen —
    /// schlimmer als gar kein Ergebnis.
    func testUnexplainedDecreaseIsNotGuessed() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 900)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertEqual(result.quantity.value, 0)
        XCTAssertTrue(result.warnings.contains(
            .unexplainedDecrease(on: day(2026, 2, 1), previous: 1000, current: 900)
        ))
    }

    // MARK: - Zählerwechsel

    /// Der Fall, an dem verbreitete Zähler-Apps scheitern: Nach dem Wechsel
    /// beginnt das neue Gerät bei null, der Verbrauch muss trotzdem stetig bleiben.
    func testMeterReplacementKeepsHistoryContinuous() {
        let register = Fixture.electricityRegister()
        let oldDevice = MeterDevice(serialNumber: "ALT-1", installedOn: day(2020, 1, 1),
                                    removedOn: day(2026, 3, 1))
        let newDevice = MeterDevice(serialNumber: "NEU-2", installedOn: day(2026, 3, 1))

        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 50_000, device: oldDevice, sequence: 1),
            Fixture.reading(register, day(2026, 3, 1), 50_600, device: oldDevice, sequence: 2),
            Fixture.reading(register, day(2026, 3, 1), 0, device: newDevice, sequence: 3),
            Fixture.reading(register, day(2026, 4, 1), 200, device: newDevice, sequence: 4)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 4, 1))
        )

        XCTAssertEqual(result.quantity.value, 800, "600 am alten Gerät plus 200 am neuen")
        XCTAssertFalse(result.quantity.isNegative)
        XCTAssertTrue(result.warnings.contains(.deviceChange(on: day(2026, 3, 1))))
    }

    // MARK: - Mengen statt Ständen

    func testIntervalRegisterSumsDeliveries() {
        let register = Register(unit: .litre, direction: .consumption,
                                accumulation: .interval, integerDigits: 5, fractionDigits: 0)
        let readings = [
            Fixture.reading(register, day(2025, 3, 10), 2000),
            Fixture.reading(register, day(2025, 11, 5), 1500)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2025, 1, 1), day(2025, 12, 31))
        )

        XCTAssertEqual(result.quantity.value, 3500)
    }

    // MARK: - Geschätzte Werte

    func testEstimatedReadingDegradesConfidence() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300, origin: .estimated)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertEqual(result.confidence, .estimated)
    }

    // MARK: - Vorjahresvergleich

    func testYearOverYearNormalisesPerDay() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 1, 1), 0),
            Fixture.reading(register, day(2025, 2, 1), 300),
            Fixture.reading(register, day(2026, 1, 1), 3000),
            Fixture.reading(register, day(2026, 2, 1), 3279)
        ]

        let comparison = ConsumptionEngine.yearOverYear(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertNotNil(comparison)
        XCTAssertEqual(comparison?.current.quantity.value, 279)
        XCTAssertEqual(comparison?.previous.quantity.value, 300)
        // (279 − 300) / 300 = −7 %
        assertClose(comparison?.relativeChange ?? 0, -0.07)
        XCTAssertEqual(comparison?.isImprovement, true)
    }

    /// Bei einem Zähler mit veraltetem Stand darf nicht eine halbe Heizperiode
    /// gegen ein Vorjahresfenster inklusive Sommer verglichen werden. Der
    /// Vorjahreszeitraum folgt dem abgedeckten, nicht dem angefragten Zeitraum.
    func testYearOverYearComparesEqualWindows() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 1, 1), 0),
            Fixture.reading(register, day(2025, 4, 1), 1200),   // Heizperiode
            Fixture.reading(register, day(2025, 8, 1), 1500),   // Sommer, flach
            Fixture.reading(register, day(2026, 1, 1), 3000),
            Fixture.reading(register, day(2026, 4, 1), 4140)    // 1140 statt 1200
        ]

        let comparison = ConsumptionEngine.yearOverYear(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 8, 1))
        )

        XCTAssertEqual(comparison?.current.coveredRange, span(day(2026, 1, 1), day(2026, 4, 1)))
        XCTAssertEqual(comparison?.previous.coveredRange, span(day(2025, 1, 1), day(2025, 4, 1)))
        XCTAssertEqual(comparison?.previous.quantity.value, 1200)
        // (1140 − 1200) / 1200 = −5 %. Ohne gleiche Fenster käme hier +79 % heraus.
        assertClose(comparison?.relativeChange ?? 0, -0.05)
    }

    // MARK: - Plausibilität bei der Eingabe

    func testPlausibilityAcceptsOrdinaryValue() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]

        let verdict = ConsumptionEngine.plausibility(
            of: 1600, on: day(2026, 3, 1), register: register,
            readings: readings, today: day(2026, 3, 1)
        )

        guard case .normal(let consumption, let days) = verdict else {
            return XCTFail("Erwartet: normal, erhalten: \(verdict)")
        }
        XCTAssertEqual(consumption.value, 300)
        XCTAssertEqual(days, 28)
    }

    /// Der typische Tippfehler ist eine Stelle zu viel. Er muss im Moment der
    /// Eingabe auffallen, nicht Monate später im Diagramm.
    func testPlausibilityFlagsTenfoldTypo() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]

        let verdict = ConsumptionEngine.plausibility(
            of: 4300, on: day(2026, 3, 1), register: register,
            readings: readings, today: day(2026, 3, 1)
        )

        guard case .unusual(_, _, let factor) = verdict else {
            return XCTFail("Erwartet: unusual, erhalten: \(verdict)")
        }
        XCTAssertGreaterThan(factor, 4)
    }

    /// Ein Gaszähler verbraucht im Juli einen Bruchteil des Jahresmittels.
    /// Gegen den Durchschnitt geprüft würde die App jeden korrekten Sommerstand
    /// beanstanden und einen zehnfach zu hohen durchwinken — der sichere Weg,
    /// das Vertrauen in die Prüfung zu verlieren.
    func testPlausibilityUsesSeasonalReference() {
        let register = Fixture.gasRegister()
        var readings: [Reading] = []
        // Jahresverlauf einer Gasheizung, Stände am Monatsersten
        let monthly: [Decimal] = [418, 376, 298, 178, 92, 41, 36, 39, 84, 192, 308, 402]
        var value = Decimal(1000)
        var sequence = 0
        for year in [2025, 2026] {
            for month in 1...12 {
                readings.append(Fixture.reading(register, day(year, month, 1), value, sequence: sequence))
                value += monthly[month - 1]
                sequence += 1
                if year == 2026 && month == 7 { break }
            }
        }
        let last = readings.last!          // 1. Juli 2026
        let today = day(2026, 8, 1)

        // Ein korrekter Julistand: 36 m³, wie im Vorjahr.
        let correct = ConsumptionEngine.plausibility(
            of: last.value + 36, on: today, register: register,
            readings: readings, today: today
        )
        guard case .normal = correct else {
            return XCTFail("Ein normaler Sommerverbrauch darf nicht beanstandet werden: \(correct)")
        }

        // Dieselbe Ablesung mit einer Stelle zu viel.
        let typo = ConsumptionEngine.plausibility(
            of: last.value + 360, on: today, register: register,
            readings: readings, today: today
        )
        guard case .unusual = typo else {
            return XCTFail("Der zehnfache Wert muss auffallen: \(typo)")
        }
    }

    func testPlausibilityFlagsValueBelowPrevious() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]

        let verdict = ConsumptionEngine.plausibility(
            of: 1200, on: day(2026, 3, 1), register: register,
            readings: readings, today: day(2026, 3, 1)
        )

        XCTAssertEqual(verdict, .belowPrevious(previous: 1300))
    }

    func testPlausibilityRejectsFutureDate() {
        let register = Fixture.electricityRegister()
        let verdict = ConsumptionEngine.plausibility(
            of: 1000, on: day(2026, 9, 1), register: register,
            readings: [], today: day(2026, 8, 4)
        )
        XCTAssertEqual(verdict, .futureDate)
    }

    func testFirstReadingIsAlwaysAccepted() {
        let register = Fixture.electricityRegister()
        let verdict = ConsumptionEngine.plausibility(
            of: 123_456, on: day(2026, 8, 4), register: register,
            readings: [], today: day(2026, 8, 4)
        )
        XCTAssertEqual(verdict, .noReference)
    }

    // MARK: - Interpolation über große Lücken

    /// Monatlich abgelesen: Der Abstand ist etwas größer als der Monat selbst,
    /// und das ist der Normalfall — niemand trifft den Monatsersten genau.
    func testNormalReadingRhythmCountsAsItsOwnData() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 3), 1000, sequence: 0),
            Fixture.reading(register, day(2026, 2, 4), 1300, sequence: 1),
            Fixture.reading(register, day(2026, 3, 5), 1600, sequence: 2)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 2, 1), day(2026, 3, 1))
        )

        XCTAssertEqual(result.longestGapInDays, 32)
        XCTAssertTrue(result.restsOnOwnReadings,
                      "32 Tage für einen 28-Tage-Monat sind ein üblicher Ableserhythmus")
    }

    /// Ein Jahr zwischen zwei Ablesungen: Für einen einzelnen Monat daraus
    /// gibt es keine Aussage, nur einen anteiligen Jahresschnitt.
    func testYearLongGapDoesNotSupportAMonthlyFigure() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2026, 2, 1), 4650, sequence: 1)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2025, 2, 1), day(2025, 3, 1))
        )

        XCTAssertTrue(result.isComplete, "Der Ausschnitt liegt innerhalb der Reihe")
        XCTAssertEqual(result.longestGapInDays, 365)
        XCTAssertFalse(result.restsOnOwnReadings,
                       "Aus einer Geraden über ein Jahr folgt keine Monatsaussage")
    }

    /// Über das ganze Jahr gerechnet ist dieselbe Lücke unbedenklich — sie ist
    /// genauso lang wie der Zeitraum, den sie tragen soll.
    func testTheSameGapIsFineForAYearlyFigure() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2025, 2, 1), 1000, sequence: 0),
            Fixture.reading(register, day(2026, 2, 1), 4650, sequence: 1)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2025, 2, 1), day(2026, 2, 1))
        )

        XCTAssertTrue(result.restsOnOwnReadings)
        XCTAssertEqual(result.quantity.value, 3650)
    }

    // MARK: - Abdeckung eines Zeitraums

    func testFullCoverageWhenDataSpansTheWholeRange() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 8, 1), 2000)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 8, 1))
        )

        XCTAssertEqual(result.coverage, .full)
    }

    /// Der Fall, der auf der Übersicht sichtbar falsch beschriftet war: Der
    /// Gaszähler wurde zuletzt im Mai abgelesen, die Karte zeigte die Zahl
    /// trotzdem als Jahreswert. Das Ergebnis muss selbst sagen, wo es endet.
    func testCoverageReportsWhereStaleDataEnds() {
        let register = Fixture.gasRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 3000),
            Fixture.reading(register, day(2026, 5, 1), 4181)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 8, 5))
        )

        XCTAssertEqual(result.quantity.value, 1181)
        XCTAssertEqual(result.coverage, .endsEarly(lastDay: day(2026, 5, 1)),
                       "Die Zahl deckt nur bis zum 1. Mai — das muss sie mitführen")
    }

    /// Ein Zähler, der erst im Laufe des Jahres eingebaut wurde.
    func testCoverageReportsALateStart() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 3, 12), 0),
            Fixture.reading(register, day(2026, 8, 1), 900)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 8, 1))
        )

        XCTAssertEqual(result.coverage, .startsLate(firstDay: day(2026, 3, 12)))
    }

    func testCoverageReportsBothEndsMissing() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 3, 12), 0),
            Fixture.reading(register, day(2026, 5, 1), 400)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 8, 1))
        )

        XCTAssertEqual(result.coverage,
                       .partial(firstDay: day(2026, 3, 12), lastDay: day(2026, 5, 1)))
    }

    func testCoverageIsNoneWithoutData() {
        let register = Fixture.electricityRegister()
        let readings = [Fixture.reading(register, day(2026, 1, 1), 1000)]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2026, 1, 1), day(2026, 8, 1))
        )

        XCTAssertEqual(result.coverage, .none)
    }

    /// Ein Zeitraum, der genau auf einer einzelnen Ablesung endet, deckt nichts
    /// ab — sonst stünde eine Null da, als sei nichts verbraucht worden.
    func testCoverageIsNoneWhenRangeCollapsesToASingleDay() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]

        let result = ConsumptionEngine.consumption(
            register: register, readings: readings,
            in: span(day(2025, 6, 1), day(2026, 1, 1))
        )

        XCTAssertEqual(result.coverage, .none)
    }

    // MARK: - Fälligkeit

    func testReadingDueAfterInterval() {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [Fixture.reading(register, day(2026, 6, 1), 1000)]

        XCTAssertTrue(ConsumptionEngine.isReadingDue(
            meteringPoint: point, readings: readings, today: day(2026, 7, 15)))
        XCTAssertFalse(ConsumptionEngine.isReadingDue(
            meteringPoint: point, readings: readings, today: day(2026, 6, 20)))
        XCTAssertTrue(ConsumptionEngine.isReadingDue(
            meteringPoint: point, readings: [], today: day(2026, 6, 20)),
            "Ohne jede Ablesung ist immer eine fällig")
    }
}
