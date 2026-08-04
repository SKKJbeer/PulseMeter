import XCTest
import SwiftData
@testable import PulseData
@testable import PulseCore

/// Läuft gegen einen Speicher im Arbeitsspeicher, nie gegen CloudKit.
/// Geprüft wird die Übersetzung zwischen Datensatz und Domäne — dort entstehen
/// die Fehler, die man erst Monate später an falschen Zahlen bemerkt.
@MainActor
final class PulseRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var repo: PulseRepository!

    override func setUp() async throws {
        container = try PulseStore.container(name: "primary", inMemory: true, cloudKit: false)
        repo = PulseRepository(container: container)
    }

    override func tearDown() async throws {
        repo = nil
        container = nil
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay {
        CalendarDay(year: y, month: m, day: d)!
    }
    private func dec(_ s: String) -> Decimal { Decimal(string: s)! }

    private func makePoint() throws -> (MeteringPoint, Property) {
        let property = try repo.ensureDefaultProperty()
        let point = MeteringPoint(
            propertyID: property.id, name: "Strom", kind: .electricity,
            registers: [Register(unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)],
            billingCycle: BillingCycle(anchorMonth: 4, anchorDay: 1)
        )
        try repo.save(point)
        return (point, property)
    }

    // MARK: - Grundfälle

    func testDefaultPropertyIsCreatedOnce() throws {
        let first = try repo.ensureDefaultProperty()
        let second = try repo.ensureDefaultProperty()
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try repo.properties().count, 1)
    }

    func testMeteringPointRoundTrip() throws {
        let (point, _) = try makePoint()
        let loaded = try XCTUnwrap(try repo.meteringPoint(point.id))

        XCTAssertEqual(loaded.id, point.id)
        XCTAssertEqual(loaded.name, "Strom")
        XCTAssertEqual(loaded.kind, .electricity)
        XCTAssertEqual(loaded.propertyID, point.propertyID)
        XCTAssertEqual(loaded.registers.count, 1)
        XCTAssertEqual(loaded.registers[0].id, point.registers[0].id)
        XCTAssertEqual(loaded.billingCycle?.anchorMonth, 4)
    }

    func testCustomKindSurvivesStorage() throws {
        let property = try repo.ensureDefaultProperty()
        let point = MeteringPoint(propertyID: property.id, name: "Poolpumpe",
                                  kind: .custom(name: "Poolpumpe", unit: .hour))
        try repo.save(point)
        let loaded = try XCTUnwrap(try repo.meteringPoint(point.id))
        XCTAssertEqual(loaded.kind, .custom(name: "Poolpumpe", unit: .hour))
    }

    func testBidirectionalMeterKeepsBothRegisters() throws {
        let property = try repo.ensureDefaultProperty()
        let point = MeteringPoint.bidirectionalElectricity(propertyID: property.id, name: "Strom")
        try repo.save(point)

        let loaded = try XCTUnwrap(try repo.meteringPoint(point.id))
        XCTAssertEqual(loaded.registers.count, 2)
        XCTAssertEqual(loaded.registers[0].label, "Bezug")
        XCTAssertEqual(loaded.registers[1].label, "Einspeisung")
        XCTAssertEqual(loaded.registers[1].direction, .feedIn)
    }

    // MARK: - Genauigkeit

    /// Der Grund für `ScaledDecimal`: Über eine Fließkommazahl käme
    /// 49157.399999999994 zurück.
    func testReadingValueIsExactAfterRoundTrip() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        let reading = Reading(registerID: register.id, day: day(2026, 8, 1), value: dec("49157.4"))
        try repo.save(reading, fractionDigits: register.fractionDigits)

        let loaded = try XCTUnwrap(try repo.readings(for: register.id).first)
        XCTAssertEqual(loaded.value, dec("49157.4"))
        XCTAssertEqual(loaded.day, day(2026, 8, 1))
    }

    func testTariffPricesStayExact() throws {
        let (point, _) = try makePoint()
        let tariff = Tariff(
            meteringPointID: point.id, validFrom: day(2026, 1, 1),
            pricePerUnit: dec("0.112"), monthlyBasePrice: dec("14.20"),
            billingUnit: .kilowattHour,
            gasConversion: GasConversion(stateNumber: dec("0.9563"), calorificValue: dec("11.482")),
            feedInPricePerUnit: dec("0.082")
        )
        try repo.save(tariff)

        let loaded = try XCTUnwrap(try repo.tariffs(for: point.id).first)
        XCTAssertEqual(loaded.pricePerUnit, dec("0.112"))
        XCTAssertEqual(loaded.monthlyBasePrice, dec("14.20"))
        XCTAssertEqual(loaded.gasConversion?.stateNumber, dec("0.9563"))
        XCTAssertEqual(loaded.gasConversion?.calorificValue, dec("11.482"))
        XCTAssertEqual(loaded.feedInPricePerUnit, dec("0.082"))
    }

    // MARK: - Reihenfolge und Abfragen

    func testReadingsComeBackChronologically() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        for (index, spec) in [(day(2026, 3, 1), "1580"), (day(2026, 1, 1), "1000"),
                              (day(2026, 2, 1), "1300")].enumerated() {
            try repo.save(Reading(registerID: register.id, day: spec.0, value: dec(spec.1),
                                  createdAt: Date(timeIntervalSince1970: TimeInterval(index))),
                          fractionDigits: register.fractionDigits)
        }
        let values = try repo.readings(for: register.id).map(\.value)
        XCTAssertEqual(values, [dec("1000"), dec("1300"), dec("1580")])
    }

    func testLastReadingIsTheMostRecentDay() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 1, 1), value: 1000),
                      fractionDigits: 1)
        try repo.save(Reading(registerID: register.id, day: day(2026, 3, 1), value: 1580),
                      fractionDigits: 1)
        XCTAssertEqual(try repo.lastReading(for: register.id)?.value, 1580)
    }

    /// Zwei Ablesungen an einem Tag sind am Tag eines Zählerwechsels zulässig
    /// und notwendig — sie dürfen einander nicht verdrängen.
    func testTwoReadingsOnTheSameDayBothSurvive() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 3, 1), value: 50600,
                              createdAt: Date(timeIntervalSince1970: 1)), fractionDigits: 1)
        try repo.save(Reading(registerID: register.id, day: day(2026, 3, 1), value: 0,
                              createdAt: Date(timeIntervalSince1970: 2)), fractionDigits: 1)
        XCTAssertEqual(try repo.readings(for: register.id).count, 2)
    }

    // MARK: - Die gefährliche Stelle

    /// Beim Speichern eines geänderten Zählers dürfen die Zählwerke nicht
    /// ersetzt werden — die Löschregel `.cascade` nähme sonst sämtliche
    /// Ablesungen mit. Genau dafür gleicht `apply` über die Kennung ab.
    func testUpdatingMeteringPointKeepsItsReadings() throws {
        var (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 1, 1), value: 1000),
                      fractionDigits: 1)
        try repo.save(Reading(registerID: register.id, day: day(2026, 2, 1), value: 1300),
                      fractionDigits: 1)

        point.name = "Strom Haupthaus"
        point.readingInterval = .quarterly
        try repo.save(point)

        XCTAssertEqual(try repo.meteringPoint(point.id)?.name, "Strom Haupthaus")
        XCTAssertEqual(try repo.readings(for: register.id).count, 2,
                       "Ein Umbenennen darf keine Ablesung kosten")
    }

    func testArchivingHidesButKeepsData() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 1, 1), value: 1000),
                      fractionDigits: 1)

        try repo.archive(meteringPointID: point.id)
        XCTAssertTrue(try repo.meteringPoints().isEmpty)
        XCTAssertEqual(try repo.meteringPoints(includeArchived: true).count, 1)
        XCTAssertEqual(try repo.readings(for: register.id).count, 1)
    }

    // MARK: - Sicherung

    func testSnapshotAndRestoreAreIdempotent() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 1, 1), value: dec("1000.5")),
                      fractionDigits: 1)
        try repo.save(Tariff(meteringPointID: point.id, validFrom: day(2026, 1, 1),
                             pricePerUnit: dec("0.34"), billingUnit: .kilowattHour))

        let snapshot = try repo.snapshot()
        XCTAssertEqual(snapshot.readings.count, 1)
        XCTAssertTrue(snapshot.danglingReferences().isEmpty)

        // Zweimal einspielen darf nichts verdoppeln.
        try repo.restore(snapshot)
        try repo.restore(snapshot)

        XCTAssertEqual(try repo.meteringPoints().count, 1)
        XCTAssertEqual(try repo.readings(for: register.id).count, 1)
        XCTAssertEqual(try repo.readings(for: register.id).first?.value, dec("1000.5"))
        XCTAssertEqual(try repo.tariffs(for: point.id).count, 1)
    }

    func testRestoreIntoEmptyStore() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 1, 1), value: 1000),
                      fractionDigits: 1)
        let snapshot = try repo.snapshot()
        let encoded = try snapshot.encoded()

        // Frischer Speicher, als wäre die App neu installiert.
        let fresh = PulseRepository(
            container: try PulseStore.container(name: "restore-target", inMemory: true, cloudKit: false)
        )
        try fresh.restore(try PulseSnapshot.decode(from: encoded))

        XCTAssertEqual(try fresh.meteringPoints().count, 1)
        XCTAssertEqual(try fresh.readings(for: register.id).count, 1)
        XCTAssertEqual(try fresh.meteringPoint(point.id)?.billingCycle?.anchorMonth, 4)
    }

    // MARK: - Zusammenspiel mit dem Rechenkern

    func testStoredDataFeedsTheEngine() throws {
        let (point, _) = try makePoint()
        let register = point.registers[0]
        try repo.save(Reading(registerID: register.id, day: day(2026, 1, 1), value: 1000),
                      fractionDigits: 1)
        try repo.save(Reading(registerID: register.id, day: day(2026, 2, 1), value: 1300),
                      fractionDigits: 1)

        let loaded = try XCTUnwrap(try repo.meteringPoint(point.id))
        let readings = try repo.readings(for: loaded)
        let range = DayRange(start: day(2026, 1, 1), end: day(2026, 2, 1))!
        let result = ConsumptionEngine.consumption(register: loaded.registers[0],
                                                   readings: readings, in: range)

        XCTAssertEqual(result.quantity.value, 300)
        XCTAssertEqual(result.confidence, .measured)
    }
}
