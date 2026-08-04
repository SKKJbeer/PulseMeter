import Foundation
import SwiftData
import PulseCore

/// Aufbau und Verwaltung des Datenspeichers.
public enum PulseStore {

    /// Berechnet statt gespeichert: `Schema` ist nicht `Sendable`, und eine
    /// statische Konstante wäre unter Swift 6 global geteilter Zustand. Der
    /// Aufbau ist billig und geschieht ohnehin nur beim Start.
    public static var schema: Schema {
        Schema([
            PropertyRecord.self,
            RentalUnitRecord.self,
            MeteringPointRecord.self,
            RegisterRecord.self,
            MeterDeviceRecord.self,
            ReadingRecord.self,
            TariffRecord.self,
            BillingPeriodRecord.self
        ])
    }

    public enum StoreError: Error {
        case containerUnavailable(underlying: Error)
    }

    /// Erzeugt den Datenspeicher.
    ///
    /// - Parameter cloudKit: Synchronisation über die private iCloud-Datenbank
    ///   des Nutzers. Kostet uns nichts, verlässt die Apple-Sphäre nie und
    ///   verlangt kein Konto — die Voraussetzung dafür, dass ein Einmalkauf
    ///   trägt (ADR-002, docs/04-monetarisierung.md).
    /// - Parameter name: Benennt den Speicher. Mehrere Speicher gleichzeitig
    ///   im selben Prozess verträgt SwiftData allerdings auch mit Namen nicht —
    ///   wer einen leeren Bestand braucht, löscht ihn, statt einen zweiten
    ///   anzulegen.
    public static func container(
        name: String? = nil,
        inMemory: Bool = false,
        cloudKit: Bool = true
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit && !inMemory ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw StoreError.containerUnavailable(underlying: error)
        }
    }
}

/// Ein Zugriff auf den Speicher, gebunden an den Hauptakteur.
///
/// Bewusst einfach gehalten: Die Datenmengen sind klein (einige tausend
/// Ablesungen), und die App liest fast ausschließlich für die Anzeige. Sollte
/// ein Import je spürbar blockieren, wird genau diese Klasse zu einem
/// `@ModelActor` — die Protokolle darüber bleiben unverändert.
@MainActor
public final class PulseRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public convenience init(container: ModelContainer) {
        self.init(context: container.mainContext)
    }

    // MARK: - Objekte

    public func properties() throws -> [Property] {
        let descriptor = FetchDescriptor<PropertyRecord>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    /// Legt das Standard-Objekt an, falls noch keines existiert.
    ///
    /// Für Einzelnutzer bleibt diese Ebene unsichtbar; sie existiert nur, damit
    /// später ein zweites Gebäude hinzukommen kann, ohne dass eine Migration
    /// nötig wird (docs/02-datenmodell.md).
    @discardableResult
    public func ensureDefaultProperty(named name: String = "Zuhause") throws -> Property {
        if let first = try properties().first { return first }
        let record = PropertyRecord(name: name)
        context.insert(record)
        try context.save()
        return record.toDomain()
    }

    public func save(_ property: Property) throws {
        let record = try findProperty(property.id) ?? {
            let fresh = PropertyRecord(id: property.id)
            context.insert(fresh)
            return fresh
        }()
        record.apply(property)
        try context.save()
    }

    // MARK: - Zähler

    public func meteringPoints(in propertyID: Property.ID? = nil,
                               includeArchived: Bool = false) throws -> [MeteringPoint] {
        let descriptor = FetchDescriptor<MeteringPointRecord>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
            .filter { includeArchived || !$0.isArchived }
            .filter { propertyID == nil || $0.propertyID == propertyID }
            .map { $0.toDomain() }
    }

    public func meteringPoint(_ id: MeteringPoint.ID) throws -> MeteringPoint? {
        try findMeteringPoint(id)?.toDomain()
    }

    public func save(_ point: MeteringPoint) throws {
        let record = try findMeteringPoint(point.id) ?? {
            let fresh = MeteringPointRecord(id: point.id)
            context.insert(fresh)
            return fresh
        }()
        record.apply(point, in: context)
        record.property = try findProperty(point.propertyID)
        try context.save()
    }

    /// Archiviert statt zu löschen.
    ///
    /// Ein gelöschter Zähler nähme über die Löschregel `.cascade` seine gesamte
    /// Ablesehistorie mit. Das darf nur passieren, wenn der Nutzer es
    /// ausdrücklich verlangt — deshalb ``deletePermanently(meteringPointID:)``
    /// als getrennter Weg.
    public func archive(meteringPointID: MeteringPoint.ID) throws {
        guard let record = try findMeteringPoint(meteringPointID) else { return }
        record.isArchived = true
        try context.save()
    }

    public func deletePermanently(meteringPointID: MeteringPoint.ID) throws {
        guard let record = try findMeteringPoint(meteringPointID) else { return }
        context.delete(record)
        try context.save()
    }

    // MARK: - Ablesungen

    public func readings(for registerID: Register.ID) throws -> [Reading] {
        let descriptor = FetchDescriptor<ReadingRecord>(
            predicate: #Predicate { $0.registerID == registerID },
            sortBy: [SortDescriptor(\.day), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    public func readings(for point: MeteringPoint) throws -> [Reading] {
        try point.registers.flatMap { try readings(for: $0.id) }
    }

    /// Letzte Ablesung eines Zählwerks — der Wert, gegen den die
    /// Plausibilitätsprüfung bei der Eingabe rechnet.
    public func lastReading(for registerID: Register.ID) throws -> Reading? {
        var descriptor = FetchDescriptor<ReadingRecord>(
            predicate: #Predicate { $0.registerID == registerID },
            sortBy: [SortDescriptor(\.day, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toDomain()
    }

    public func save(_ reading: Reading, fractionDigits: Int) throws {
        let record = try findReading(reading.id) ?? {
            let fresh = ReadingRecord(id: reading.id)
            context.insert(fresh)
            return fresh
        }()
        record.apply(reading, scale: fractionDigits)
        record.register = try findRegister(reading.registerID)
        try context.save()
    }

    public func delete(readingID: Reading.ID) throws {
        guard let record = try findReading(readingID) else { return }
        context.delete(record)
        try context.save()
    }

    // MARK: - Tarife und Abrechnungszeiträume

    public func tariffs(for meteringPointID: MeteringPoint.ID) throws -> [Tariff] {
        let descriptor = FetchDescriptor<TariffRecord>(
            predicate: #Predicate { $0.meteringPointID == meteringPointID },
            sortBy: [SortDescriptor(\.validFrom)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ tariff: Tariff) throws {
        let id = tariff.id
        let descriptor = FetchDescriptor<TariffRecord>(predicate: #Predicate { $0.id == id })
        let record = try context.fetch(descriptor).first ?? {
            let fresh = TariffRecord(id: id)
            context.insert(fresh)
            return fresh
        }()
        record.apply(tariff)
        try context.save()
    }

    public func billingPeriods(for meteringPointID: MeteringPoint.ID) throws -> [BillingPeriod] {
        let descriptor = FetchDescriptor<BillingPeriodRecord>(
            predicate: #Predicate { $0.meteringPointID == meteringPointID },
            sortBy: [SortDescriptor(\.rangeStart)]
        )
        return try context.fetch(descriptor).compactMap { $0.toDomain() }
    }

    public func save(_ period: BillingPeriod) throws {
        let id = period.id
        let descriptor = FetchDescriptor<BillingPeriodRecord>(predicate: #Predicate { $0.id == id })
        let record = try context.fetch(descriptor).first ?? {
            let fresh = BillingPeriodRecord(id: id)
            context.insert(fresh)
            return fresh
        }()
        record.apply(period)
        try context.save()
    }

    // MARK: - Sicherung und Wiederherstellung

    /// Vollständiger Abzug für Sicherung und Export.
    public func snapshot() throws -> PulseSnapshot {
        let points = try context.fetch(FetchDescriptor<MeteringPointRecord>()).map { $0.toDomain() }
        return PulseSnapshot(
            properties: try properties(),
            units: try context.fetch(FetchDescriptor<RentalUnitRecord>()).map { $0.toDomain() },
            meteringPoints: points,
            readings: try context.fetch(FetchDescriptor<ReadingRecord>()).map { $0.toDomain() },
            tariffs: try context.fetch(FetchDescriptor<TariffRecord>()).map { $0.toDomain() },
            billingPeriods: try context.fetch(FetchDescriptor<BillingPeriodRecord>()).compactMap { $0.toDomain() }
        )
    }

    /// Spielt einen Abzug ein. Idempotent über die Kennungen: Zweimal
    /// dieselbe Sicherung einzulesen erzeugt keine Dubletten.
    public func restore(_ snapshot: PulseSnapshot) throws {
        for property in snapshot.properties { try save(property) }
        for point in snapshot.meteringPoints { try save(point) }

        // Nachkommastellen kommen vom zugehörigen Zählwerk, damit ein
        // eingelesener Wert exakt so gespeichert wird, wie er gemessen wurde.
        var scales: [Register.ID: Int] = [:]
        for point in snapshot.meteringPoints {
            for register in point.registers { scales[register.id] = register.fractionDigits }
        }
        for reading in snapshot.readings {
            try save(reading, fractionDigits: scales[reading.registerID] ?? 3)
        }
        for tariff in snapshot.tariffs { try save(tariff) }
        for period in snapshot.billingPeriods { try save(period) }
        try context.save()
    }

    // MARK: - Intern

    private func findProperty(_ id: UUID) throws -> PropertyRecord? {
        try context.fetch(FetchDescriptor<PropertyRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func findMeteringPoint(_ id: UUID) throws -> MeteringPointRecord? {
        try context.fetch(FetchDescriptor<MeteringPointRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func findRegister(_ id: UUID) throws -> RegisterRecord? {
        try context.fetch(FetchDescriptor<RegisterRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func findReading(_ id: UUID) throws -> ReadingRecord? {
        try context.fetch(FetchDescriptor<ReadingRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
