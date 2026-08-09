import XCTest
@testable import PulseCore

/// Der Bericht ist das Dokument, das neben die Jahresabrechnung gelegt wird.
/// Eine falsche Zahl darin wiegt schwerer als eine falsche Zahl auf dem
/// Bildschirm — sie ist gedruckt und weitergereicht.
final class ReportBuilderTests: XCTestCase {

    private let today = day(2026, 8, 4)

    // MARK: - Zeiträume

    func testPeriodsWithoutABillingCycleOfferTheUsualFour() {
        let periods = ReportBuilder.periods(today: today)
        XCTAssertEqual(periods.map(\.id), ["ytd", "last12", "year-2025", "year-2024"])
    }

    /// Das Abrechnungsjahr des Versorgers beginnt selten am 1. Januar — genau
    /// deshalb steht es oben und nicht als Kalenderjahr getarnt.
    func testBillingCycleAddsItsOwnPeriodsFirst() {
        let cycle = BillingCycle(anchorMonth: 4, anchorDay: 1)!
        let periods = ReportBuilder.periods(today: today, billingCycle: cycle)

        XCTAssertEqual(periods.first?.id, "billing-current")
        XCTAssertEqual(periods.first?.range.start, day(2026, 4, 1))
        XCTAssertEqual(periods.first?.range.end, today)
        XCTAssertEqual(periods[1].id, "billing-last")
        XCTAssertEqual(periods[1].range, span(day(2025, 4, 1), day(2026, 4, 1)))
        XCTAssertTrue(periods[1].label.contains("2025/26"))
    }

    /// Bei einem abgeschlossenen Zeitraum ist das Ende der Stichtag danach.
    /// Angezeigt wird der letzte Tag, der noch dazugehört — „bis 1. Januar"
    /// für das Kalenderjahr 2025 wäre schlicht falsch.
    func testClosedPeriodNamesItsLastDayNotTheNextAnchor() {
        let year = ReportBuilder.periods(today: today).first { $0.id == "year-2025" }
        XCTAssertEqual(year?.range.end, day(2026, 1, 1))
        XCTAssertEqual(year?.lastIncludedDay, day(2025, 12, 31))
    }

    // MARK: - Ein Doppeltarifzähler im Bericht

    private func dualTariffFixture() -> (MeteringPoint, [Reading], [Tariff]) {
        let high = Register(label: "Hochtarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let low = Register(label: "Niedertarif", unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
        let point = Fixture.meteringPoint(registers: [high, low])
        var readings: [Reading] = []
        // Monatlich vom 1.1.2025 bis 1.6.2026, gleichmäßig — damit die
        // Monatstabelle und der Vorjahresvergleich Substanz haben.
        var highValue = Decimal(21_000)
        var lowValue = Decimal(26_000)
        for offset in 0...17 {
            let year = 2025 + (offset / 12)
            let month = offset % 12 + 1
            readings.append(Fixture.reading(high, day(year, month, 1), highValue))
            readings.append(Fixture.reading(low, day(year, month, 1), lowValue))
            highValue += 250
            lowValue += 260
        }
        let tariffs = [
            Tariff(meteringPointID: point.id, registerID: high.id, validFrom: day(2024, 1, 1),
                   pricePerUnit: dec("0.31"), monthlyBasePrice: dec("8.90"), billingUnit: .kilowattHour),
            Tariff(meteringPointID: point.id, registerID: low.id, validFrom: day(2024, 1, 1),
                   pricePerUnit: dec("0.21"), monthlyBasePrice: 0, billingUnit: .kilowattHour)
        ]
        return (point, readings, tariffs)
    }

    /// Beide Tarife stehen im Bericht — mit ihrem eigenen Preis, nicht mit
    /// einem Mischpreis, den es auf keiner Rechnung gibt.
    func testBothTariffsAppearWithTheirOwnPrice() {
        let (point, readings, tariffs) = dualTariffFixture()
        let period = ReportBuilder.Period(id: "t", label: "Prüfzeitraum",
                                          range: span(day(2026, 1, 1), day(2026, 6, 1)),
                                          isRunning: false)

        let report = ReportBuilder.build(
            meteringPoints: [point], readings: [point.id: readings], tariffs: [point.id: tariffs],
            prepayments: [:], period: period, propertyName: "Zuhause", today: today)

        XCTAssertEqual(report.sections.count, 1)
        let section = report.sections[0]
        XCTAssertEqual(section.registers.count, 2)
        XCTAssertEqual(section.registers[0].label, "Hochtarif")
        XCTAssertEqual(section.registers[0].pricePerUnit, dec("0.31"))
        XCTAssertEqual(section.registers[1].label, "Niedertarif")
        XCTAssertEqual(section.registers[1].pricePerUnit, dec("0.21"))

        // 5 Monate × 250 + 5 × 260 = 1.250 + 1.300 = 2.550 kWh
        XCTAssertEqual(section.consumption.quantity.value, 2_550)
        XCTAssertEqual(section.registers[0].quantity.value, 1_250)
        XCTAssertEqual(section.registers[1].quantity.value, 1_300)
    }

    /// Im Bericht steht der **Stand**, der am Tag auf dem Gerät stand — nicht
    /// der aufgelaufene Verbrauch. Wer den Bericht neben den Zähler hält, muss
    /// dieselbe Zahl sehen.
    func testTheReportCarriesTheRawMeterReadings() {
        let (point, readings, tariffs) = dualTariffFixture()
        let period = ReportBuilder.Period(id: "t", label: "Prüfzeitraum",
                                          range: span(day(2026, 1, 1), day(2026, 6, 1)),
                                          isRunning: false)

        let report = ReportBuilder.build(
            meteringPoints: [point], readings: [point.id: readings], tariffs: [point.id: tariffs],
            prepayments: [:], period: period, propertyName: "Zuhause", today: today)

        let high = report.sections[0].registers[0]
        // 21.000 + 12 × 250 = 24.000 am 1.1.2026, + 5 × 250 = 25.250 am 1.6.
        XCTAssertEqual(high.startValue, 24_000)
        XCTAssertEqual(high.endValue, 25_250)
    }

    /// Der Grundpreis fällt einmal an, nicht je Zählwerk — dieselbe Regel wie
    /// überall, hier auf dem Papier.
    func testTheStandingRateIsChargedOnce() {
        let (point, readings, tariffs) = dualTariffFixture()
        let period = ReportBuilder.Period(id: "t", label: "Prüfzeitraum",
                                          range: span(day(2026, 1, 1), day(2026, 6, 1)),
                                          isRunning: false)

        let report = ReportBuilder.build(
            meteringPoints: [point], readings: [point.id: readings], tariffs: [point.id: tariffs],
            prepayments: [:], period: period, propertyName: "Zuhause", today: today)

        let section = report.sections[0]
        // 8,90 €/Monat × 12 ÷ 365 × 151 Tage = 44,18 €
        assertClose(section.baseAmount?.amount ?? 0, 44.183, accuracy: 0.005)
        // 1.250 × 0,31 + 1.300 × 0,21 = 387,50 + 273,00 = 660,50 €
        assertClose(section.energyAmount?.amount ?? 0, 660.50, accuracy: 0.005)
        assertClose(section.total?.amount ?? 0, 704.683, accuracy: 0.005)
    }

    /// Die Monatstabelle zeigt nur **vollständige** Monate.
    ///
    /// Ein angefangener Monat neben fünf ganzen sähe aus wie ein sparsamer
    /// Monat — die wiederkehrende Fehlerklasse in Tabellenform.
    func testOnlyCompleteMonthsEnterTheTable() {
        let (point, readings, tariffs) = dualTariffFixture()
        let period = ReportBuilder.Period(id: "t", label: "Laufendes Jahr",
                                          range: span(day(2026, 1, 1), day(2026, 8, 4)),
                                          isRunning: true)

        let report = ReportBuilder.build(
            meteringPoints: [point], readings: [point.id: readings], tariffs: [point.id: tariffs],
            prepayments: [:], period: period, propertyName: "Zuhause", today: today)

        let section = report.sections[0]
        // Ablesungen enden am 1.6.2026 — Januar bis Mai sind vollständig.
        XCTAssertEqual(section.months.map(\.month), [1, 2, 3, 4, 5])
        XCTAssertEqual(section.months.allSatisfy { $0.value == 510 }, true,
                       "250 Hochtarif + 260 Niedertarif je Monat")
        XCTAssertFalse(section.isComplete,
                       "Der Zeitraum reicht bis August, die Ablesungen bis Juni — das muss im Bericht stehen")
        XCTAssertTrue(report.hasIncompleteData)
    }

    /// Jeder Monat gegen denselben Monat des Vorjahres.
    func testMonthsCarryTheirOwnPreviousYear() {
        let (point, readings, tariffs) = dualTariffFixture()
        let period = ReportBuilder.Period(id: "t", label: "Prüfzeitraum",
                                          range: span(day(2026, 1, 1), day(2026, 6, 1)),
                                          isRunning: false)

        let report = ReportBuilder.build(
            meteringPoints: [point], readings: [point.id: readings], tariffs: [point.id: tariffs],
            prepayments: [:], period: period, propertyName: "Zuhause", today: today)

        let january = report.sections[0].months.first { $0.month == 1 }
        XCTAssertEqual(january?.previousValue, 510, "Januar 2025 liegt in den Daten")
        XCTAssertEqual(january?.relativeChange, 0)
    }

    // MARK: - Abschläge

    /// **Nur Zähler mit hinterlegtem Abschlag dürfen in den Saldo.**
    ///
    /// Stellte man die Gesamtkosten den Abschlägen eines einzigen Zählers
    /// gegenüber, entstünde eine erfundene Nachzahlung in Höhe der übrigen.
    func testOnlyMetersWithAPrepaymentEnterTheBalance() {
        let (point, readings, tariffs) = dualTariffFixture()
        let other = Fixture.meteringPoint(registers: [Fixture.gasRegister()], kind: .gas)
        let gasReadings = [
            Fixture.reading(other.registers[0], day(2026, 1, 1), 1_000),
            Fixture.reading(other.registers[0], day(2026, 6, 1), 1_400)
        ]
        let gasTariff = [Tariff(meteringPointID: other.id, validFrom: day(2024, 1, 1),
                                pricePerUnit: dec("0.11"), monthlyBasePrice: 0,
                                billingUnit: .kilowattHour, gasConversion: .typical)]
        let period = ReportBuilder.Period(id: "t", label: "Prüfzeitraum",
                                          range: span(day(2026, 1, 1), day(2026, 6, 1)),
                                          isRunning: false)

        let report = ReportBuilder.build(
            meteringPoints: [point, other],
            readings: [point.id: readings, other.id: gasReadings],
            tariffs: [point.id: tariffs, other.id: gasTariff],
            prepayments: [point.id: 60],
            period: period, propertyName: "Zuhause", today: today)

        XCTAssertEqual(report.sections.count, 2)
        XCTAssertEqual(report.namesOnAccount, ["Strom"])
        // 60 € × 151 Tage ÷ (365 ÷ 12) = 297,86 €
        assertClose(report.prepaymentTotal?.amount ?? 0, 297.8, accuracy: 0.2)
        assertClose(report.costOnAccount?.amount ?? 0, 704.683, accuracy: 0.005,
                    "Nur der Zähler mit Abschlag, nicht die Summe beider")
        XCTAssertNotEqual(report.costOnAccount?.amount, report.totalCost?.amount,
                          "Sonst wäre der Saldo um die Kosten des Gaszählers zu hoch")
        XCTAssertTrue((report.balance?.amount ?? 0) < 0, "Hier steht eine Nachzahlung an")
    }

    /// Ein Zähler ohne Ablesungen im Zeitraum kommt nicht in den Bericht.
    /// Eine Zeile mit Strichen sagt nichts und macht das Dokument länger.
    func testAMeterWithoutDataIsLeftOut() {
        let (point, readings, tariffs) = dualTariffFixture()
        let period = ReportBuilder.Period(id: "t", label: "Kalenderjahr 2020",
                                          range: span(day(2020, 1, 1), day(2021, 1, 1)),
                                          isRunning: false)

        let report = ReportBuilder.build(
            meteringPoints: [point], readings: [point.id: readings], tariffs: [point.id: tariffs],
            prepayments: [:], period: period, propertyName: "Zuhause", today: today)

        XCTAssertTrue(report.isEmpty)
    }

    /// Über einen Rücksprung hinweg wird kein Stand eingesetzt: Nach einem
    /// Gerätewechsel ergäbe die Gerade eine Zahl, die auf keinem der beiden
    /// Geräte je stand.
    func testNoInterpolationAcrossADrop() {
        let register = Fixture.electricityRegister()
        let readings = [
            Fixture.reading(register, day(2026, 1, 1), 99_000),
            Fixture.reading(register, day(2026, 3, 1), 120)
        ]

        XCTAssertEqual(
            ReportBuilder.rawReading(readings, register: register, on: day(2026, 2, 1)),
            99_000,
            "Zwischen 99.000 und 120 liegt keine sinnvolle Zahl")
    }
}
