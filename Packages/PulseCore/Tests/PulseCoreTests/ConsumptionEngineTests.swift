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
