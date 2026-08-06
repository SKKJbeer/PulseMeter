import XCTest
@testable import PulseCore

final class CostEngineTests: XCTestCase {

    private let year2026 = span(day(2026, 1, 1), day(2027, 1, 1))

    func testEnergyAndBasePrice() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1300)
        ]
        let tariff = Tariff(
            meteringPointID: point.id,
            validFrom: day(2026, 1, 1),
            pricePerUnit: dec("0.30"),
            monthlyBasePrice: 12,
            billingUnit: .kilowattHour
        )

        let result = try CostEngine.cost(
            register: register, readings: readings, tariffs: [tariff],
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertEqual(result.energyAmount.amount, 90, "300 kWh × 0,30 €")
        // Grundpreis tagesgenau: 12 € × 12 Monate / 365 Tage × 31 Tage
        assertClose(result.baseAmount.amount, 144.0 / 365.0 * 31.0, accuracy: 0.001)
        assertClose(result.total.amount, 90 + 144.0 / 365.0 * 31.0, accuracy: 0.001)
        XCTAssertEqual(result.confidence, .measured)
    }

    /// Ein Preiswechsel mitten im Zeitraum ist der Regelfall. Wer mit einem
    /// Durchschnittspreis rechnet, weicht von der Jahresrechnung ab.
    func testSplitsAtTariffBoundary() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1310)   // 10 kWh je Tag
        ]
        let cheap = Tariff(
            meteringPointID: point.id,
            validFrom: day(2026, 1, 1), validTo: day(2026, 1, 15),
            pricePerUnit: dec("0.30"), billingUnit: .kilowattHour
        )
        let expensive = Tariff(
            meteringPointID: point.id,
            validFrom: day(2026, 1, 16),
            pricePerUnit: dec("0.40"), billingUnit: .kilowattHour
        )

        let result = try CostEngine.cost(
            register: register, readings: readings, tariffs: [cheap, expensive],
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        XCTAssertEqual(result.segments.count, 2)
        // 15 Tage × 10 kWh × 0,30 € = 45 €; 16 Tage × 10 kWh × 0,40 € = 64 €
        assertClose(result.segments[0].billedQuantity.value, 150)
        assertClose(result.segments[1].billedQuantity.value, 160)
        assertClose(result.energyAmount.amount, 109)
    }

    /// Der Grenztag darf weder verloren gehen noch doppelt zählen: Die Summe
    /// der Abschnitte muss exakt dem Gesamtverbrauch entsprechen.
    func testSegmentsCoverPeriodWithoutGapOrOverlap() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1310)
        ]
        let tariffs = [
            Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1), validTo: day(2026, 1, 10),
                   pricePerUnit: dec("0.30"), billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 11), validTo: day(2026, 1, 20),
                   pricePerUnit: dec("0.35"), billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 21),
                   pricePerUnit: dec("0.40"), billingUnit: .kilowattHour)
        ]

        let result = try CostEngine.cost(
            register: register, readings: readings, tariffs: tariffs,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        let summed = result.segments.reduce(Decimal(0)) { $0 + $1.billedQuantity.value }
        assertClose(summed, 310, accuracy: 0.0001)

        let days = result.segments.reduce(0) { $0 + $1.range.spanInDays }
        XCTAssertEqual(days, 31)
    }

    /// Ein vergessenes Gültigkeitsende ist der häufigste Eingabefehler.
    /// Der Nachfolgetarif muss den Vorgänger begrenzen statt zu überlappen.
    func testOverlappingTariffsAreTruncated() throws {
        let register = Fixture.electricityRegister()
        let point = Fixture.meteringPoint(registers: [register])
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1310)
        ]
        let tariffs = [
            Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                   pricePerUnit: dec("0.30"), billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 16),
                   pricePerUnit: dec("0.40"), billingUnit: .kilowattHour)
        ]

        let result = try CostEngine.cost(
            register: register, readings: readings, tariffs: tariffs,
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        let summed = result.segments.reduce(Decimal(0)) { $0 + $1.billedQuantity.value }
        assertClose(summed, 310, accuracy: 0.0001, "Kein Doppelzählen trotz offener Gültigkeit")
        assertClose(result.energyAmount.amount, 109)
    }

    func testGasIsBilledInEnergy() throws {
        let register = Fixture.gasRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .gas)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1200)   // 200 m³
        ]
        let tariff = Tariff(
            meteringPointID: point.id,
            validFrom: day(2026, 1, 1),
            pricePerUnit: dec("0.12"),
            billingUnit: .kilowattHour,
            gasConversion: GasConversion(stateNumber: dec("0.95"), calorificValue: dec("10.5"))
        )

        let result = try CostEngine.cost(
            register: register, readings: readings, tariffs: [tariff],
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )

        // 200 m³ × 0,95 × 10,5 = 1995 kWh × 0,12 € = 239,40 €
        XCTAssertEqual(result.segments[0].billedQuantity.value, 1995)
        XCTAssertEqual(result.energyAmount.amount, dec("239.40"))
    }

    func testGasWithoutConversionFactorsFails() {
        let register = Fixture.gasRegister()
        let point = Fixture.meteringPoint(registers: [register], kind: .gas)
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 1000),
            Fixture.reading(register, day(2026, 2, 1), 1200)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.12"), billingUnit: .kilowattHour)

        XCTAssertThrowsError(try CostEngine.cost(
            register: register, readings: readings, tariffs: [tariff],
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        )) { error in
            XCTAssertEqual(error as? CostEngine.CostError,
                           .missingConversion(from: .cubicMetre, to: .kilowattHour))
        }
    }

    /// Der Fall, für den das Zählwerk-Modell überhaupt existiert: ein Gerät,
    /// zwei Zählwerke, und am Ende eine Zahl, die den PV-Besitzer interessiert.
    func testBidirectionalMeterOffsetsFeedInAgainstGridCost() throws {
        let point = MeteringPoint.bidirectionalElectricity(
            propertyID: Fixture.property.id, name: "Strom"
        )
        let grid = point.registers[0]
        let feedIn = point.registers[1]

        let readings = [
            Fixture.reading(grid, day(2026, 1, 1), 1000),
            Fixture.reading(grid, day(2026, 2, 1), 1200),      // 200 kWh Bezug
            Fixture.reading(feedIn, day(2026, 1, 1), 500),
            Fixture.reading(feedIn, day(2026, 2, 1), 900)      // 400 kWh Einspeisung
        ]
        let tariffs = [
            Tariff(meteringPointID: point.id, registerID: grid.id, validFrom: day(2026, 1, 1),
                   pricePerUnit: dec("0.30"), billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, registerID: feedIn.id, validFrom: day(2026, 1, 1),
                   pricePerUnit: 0, billingUnit: .kilowattHour,
                   feedInPricePerUnit: dec("0.08"))
        ]

        let range = span(day(2026, 1, 1), day(2026, 2, 1))

        let gridCost = try CostEngine.cost(register: grid, readings: readings,
                                           tariffs: tariffs, in: range)
        XCTAssertEqual(gridCost.total.amount, 60)

        let feedInCost = try CostEngine.cost(register: feedIn, readings: readings,
                                             tariffs: tariffs, in: range)
        XCTAssertEqual(feedInCost.total.amount, -32, "Einspeisung ist eine Gutschrift")
        XCTAssertTrue(feedInCost.isCredit)

        let combined = try CostEngine.cost(meteringPoint: point, readings: readings,
                                           tariffs: tariffs, in: range)
        XCTAssertEqual(combined?.total.amount, 28, "60 € Bezug minus 32 € Vergütung")
    }

    func testMissingTariffThrows() {
        let register = Fixture.electricityRegister()
        XCTAssertThrowsError(try CostEngine.cost(
            register: register, readings: [], tariffs: [],
            in: span(day(2026, 1, 1), day(2026, 2, 1))
        ))
    }

    /// Der Grundpreis wird einmal berechnet, nicht je Zählwerk.
    ///
    /// Ein Zweirichtungszähler ist **ein** Anschluss mit **einer** Rechnung.
    /// Vorher summierte die Messstellen-Rechnung die Grundpreise beider
    /// Zählwerke; auf dem Bildschirmfoto vom 6. August stand deshalb ein
    /// Betrag, der neunzig Euro zu hoch war — und die Einspeisevergütung sah
    /// um denselben Betrag zu klein aus, weil dort derselbe Grundpreis noch
    /// einmal abgezogen wurde.
    ///
    /// - Bezug 1000 kWh × 0,30 € = 300 €
    /// - Einspeisung 400 kWh × 0,10 € = 40 € Gutschrift
    /// - Grundpreis 10 €/Monat über das Jahr 2026 = 120 €
    /// - Erwartet: 300 − 40 + 120 = **380 €**, nicht 500 €
    func testBasePriceIsChargedOncePerConnectionNotPerRegister() throws {
        let draw = Fixture.electricityRegister()
        let feedIn = Register(label: "Einspeisung", unit: .kilowattHour,
                              direction: .feedIn, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [draw, feedIn])
        let readings = [
            Fixture.reading(draw, day(2026, 1, 1), 0),
            Fixture.reading(draw, day(2027, 1, 1), 1000),
            Fixture.reading(feedIn, day(2026, 1, 1), 0),
            Fixture.reading(feedIn, day(2027, 1, 1), 400)
        ]
        let tariff = Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                            pricePerUnit: dec("0.30"), monthlyBasePrice: 10,
                            billingUnit: .kilowattHour,
                            feedInPricePerUnit: dec("0.10"))

        let result = try CostEngine.cost(meteringPoint: point, readings: readings,
                                         tariffs: [tariff], in: year2026)

        assertClose(result?.baseAmount.amount ?? 0, 120, accuracy: 0.01)
        assertClose(result?.energyAmount.amount ?? 0, 260, accuracy: 0.01)
        assertClose(result?.total.amount ?? 0, 380, accuracy: 0.01)
    }

    /// Zwei Zählwerke mit eigenen Tarifen behalten jeder seinen Grundpreis.
    ///
    /// Die Gegenprobe zur vorigen Prüfung: Wer den Grundpreis pauschal nur
    /// einmal zählte, würde hier zu wenig berechnen. Zwei eigene Tarife heißen
    /// zwei Anschlüsse.
    func testSeparateTariffsKeepTheirOwnBasePrice() throws {
        let first = Fixture.electricityRegister()
        let second = Register(label: "Wärmepumpe", unit: .kilowattHour,
                              direction: .consumption, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [first, second])
        let readings = [
            Fixture.reading(first, day(2026, 1, 1), 0),
            Fixture.reading(first, day(2027, 1, 1), 1000),
            Fixture.reading(second, day(2026, 1, 1), 0),
            Fixture.reading(second, day(2027, 1, 1), 1000)
        ]
        let tariffs = [
            Tariff(meteringPointID: point.id, registerID: first.id, validFrom: day(2026, 1, 1),
                   pricePerUnit: dec("0.30"), monthlyBasePrice: 10, billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, registerID: second.id, validFrom: day(2026, 1, 1),
                   pricePerUnit: dec("0.20"), monthlyBasePrice: 8, billingUnit: .kilowattHour)
        ]

        let result = try CostEngine.cost(meteringPoint: point, readings: readings,
                                         tariffs: tariffs, in: year2026)

        assertClose(result?.baseAmount.amount ?? 0, 216, accuracy: 0.01)   // 120 + 96
        assertClose(result?.energyAmount.amount ?? 0, 500, accuracy: 0.01) // 300 + 200
    }
}
