import Foundation
import SwiftData
import PulseCore
#if canImport(CoreData)
import CoreData
#endif

/// Aufbau und Verwaltung des Datenspeichers.
public enum PulseStore {

    /// Berechnet statt gespeichert: `Schema` ist nicht `Sendable`, und eine
    /// statische Konstante wäre unter Swift 6 global geteilter Zustand. Der
    /// Aufbau ist billig und geschieht ohnehin nur beim Start.
    public static var schema: Schema {
        Schema(modelTypes)
    }

    /// Die Datensatzarten, an einer Stelle. Der Speicher, das CloudKit-Schema
    /// und sein Anlegen lesen alle drei hier, sonst fehlt eine neue Art beim
    /// Abgleich, ohne dass es jemand merkt.
    public static var modelTypes: [any PersistentModel.Type] {
        [
            PropertyRecord.self,
            RentalUnitRecord.self,
            MeteringPointRecord.self,
            RegisterRecord.self,
            MeterDeviceRecord.self,
            ReadingRecord.self,
            TariffRecord.self,
            BillingPeriodRecord.self,
            HeatingChangeRecord.self
        ]
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

#if DEBUG && canImport(CoreData)
extension PulseStore {

    /// Die Kennung des iCloud-Behälters, wie sie in den Berechtigungen steht.
    public static let cloudKitContainer = "iCloud.de.karjoth.pulsemeter"

    /// Legt das Schema in der **Entwicklungsumgebung** von CloudKit an.
    ///
    /// **Warum es das gibt.** Ein Bau aus dem Laden oder aus TestFlight spricht
    /// mit der **Produktionsumgebung**. Dort legt CloudKit keine neuen
    /// Datensatztypen an, es lehnt jedes Hochladen ab, dessen Typ es nicht
    /// kennt. Die Typen kommen nur auf einem Weg dorthin: Sie stehen in der
    /// Entwicklungsumgebung, und jemand überträgt sie in der CloudKit-Konsole
    /// („Deploy Schema Changes"). Bis 0.141.0 hat das niemand getan, und die
    /// App merkt davon nichts. SwiftData schreibt lokal weiter, der Abgleich
    /// scheitert im Hintergrund, und auf dem zweiten Gerät bleibt alles leer.
    /// Gemeldet hat es ein Käufer am 14. Oktober.
    ///
    /// Apple beschreibt genau diesen Weg für SwiftData: dasselbe Modell als
    /// `NSManagedObjectModel`, ein `NSPersistentCloudKitContainer` darum und
    /// `initializeCloudKitSchema()`. Der Speicher liegt in einer eigenen Datei
    /// im Zwischenordner, damit der echte Bestand nicht angefasst wird.
    ///
    /// Nur im `Debug`-Bau: Ein Entwicklungsprofil zeigt auf die
    /// Entwicklungsumgebung, und nur dort darf das Schema wachsen.
    /// Aufgerufen von `scripts/cloudkit-schema.sh`.
    public static func cloudKitSchemaAnlegen() throws {
        guard let modell = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else {
            throw StoreError.containerUnavailable(underlying: CocoaError(.featureUnsupported))
        }
        let datei = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloudkit-schema.store")
        let beschreibung = NSPersistentStoreDescription(url: datei)
        beschreibung.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainer)
        beschreibung.shouldAddStoreAsynchronously = false

        let behaelter = NSPersistentCloudKitContainer(name: "CloudKitSchema",
                                                      managedObjectModel: modell)
        behaelter.persistentStoreDescriptions = [beschreibung]
        var ladefehler: Error?
        behaelter.loadPersistentStores { _, fehler in ladefehler = fehler }
        if let ladefehler { throw ladefehler }

        try behaelter.initializeCloudKitSchema()

        // Wieder abmelden, sonst gleicht der Hilfsspeicher weiter ab.
        for speicher in behaelter.persistentStoreCoordinator.persistentStores {
            try behaelter.persistentStoreCoordinator.remove(speicher)
        }
    }
}
#endif

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

    /// Wie viele Ablesungen an einem Zählwerk hängen.
    ///
    /// **Zählen, ohne zu laden.** Die Zählerliste braucht diese Zahl für jeden
    /// Zähler, und sie hat sie sich bis 0.72.1 über `readings(for:).count`
    /// geholt — also alle Sätze aus dem Speicher gefischt und in Domänenwerte
    /// übersetzt, um sie danach wegzuwerfen. Bei drei Jahren täglicher
    /// Ablesungen sind das über tausend Übersetzungen je Zähler, jedes Mal,
    /// wenn der Schirm erscheint. `fetchCount` fragt den Speicher nach der
    /// Zahl und lädt nichts.
    public func readingCount(for registerID: Register.ID) throws -> Int {
        try context.fetchCount(FetchDescriptor<ReadingRecord>(
            predicate: #Predicate { $0.registerID == registerID }
        ))
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

    /// Mehrere Ablesungen in einem Vorgang — alle oder keine.
    ///
    /// Ein Zweirichtungszähler zeigt Bezug und Einspeisung auf demselben
    /// Gerät und wird in einem Zug abgelesen. Würde jeder Wert einzeln
    /// festgeschrieben, bliebe nach einem Fehler beim zweiten Zählwerk der
    /// erste allein stehen — und sähe aus wie eine vollständige Ablesung. Der
    /// Rechenkern bildete daraus einen Verbrauch für einen Zeitraum, in dem
    /// die Gegenrichtung fehlt. Das ist die wiederkehrende Fehlerklasse aus
    /// CLAUDE.md, hier auf der Ebene des Speichers.
    public func save(_ readings: [(reading: Reading, fractionDigits: Int)]) throws {
        guard !readings.isEmpty else { return }
        do {
            for entry in readings {
                let record = try findReading(entry.reading.id) ?? {
                    let fresh = ReadingRecord(id: entry.reading.id)
                    context.insert(fresh)
                    return fresh
                }()
                record.apply(entry.reading, scale: entry.fractionDigits)
                record.register = try findRegister(entry.reading.registerID)
            }
            try context.save()
        } catch {
            // Ohne Rücknahme blieben die eingefügten Sätze im Kontext stehen
            // und gingen beim nächsten Sichern irgendeiner anderen Stelle
            // stillschweigend mit — also genau das, was hier verhindert
            // werden soll, nur später und unauffindbar.
            context.rollback()
            throw error
        }
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

    /// Entfernt einen Tarif.
    ///
    /// Gebraucht, wenn ein Zählwerk wieder verschwindet — sonst bliebe sein
    /// Tarif liegen und stünde beim erneuten Anlegen ein zweites Mal daneben.
    public func delete(tariffID: Tariff.ID) throws {
        let descriptor = FetchDescriptor<TariffRecord>(predicate: #Predicate { $0.id == tariffID })
        guard let record = try context.fetch(descriptor).first else { return }
        context.delete(record)
        try context.save()
    }

    // MARK: - Heizungswechsel (1.9)

    public func heatingChanges() throws -> [HeatingChange] {
        try context.fetch(FetchDescriptor<HeatingChangeRecord>(sortBy: [SortDescriptor(\.day)]))
            .map { $0.toDomain() }
    }

    public func save(_ change: HeatingChange) throws {
        let id = change.id
        let descriptor = FetchDescriptor<HeatingChangeRecord>(predicate: #Predicate { $0.id == id })
        let record = try context.fetch(descriptor).first ?? {
            let fresh = HeatingChangeRecord(id: id)
            context.insert(fresh)
            return fresh
        }()
        record.apply(change)
        try context.save()
    }

    /// Nimmt nur die Verbindung weg. Beide Zähler und ihre Ablesungen bleiben.
    public func delete(heatingChangeID: HeatingChange.ID) throws {
        let descriptor = FetchDescriptor<HeatingChangeRecord>(predicate: #Predicate { $0.id == heatingChangeID })
        guard let record = try context.fetch(descriptor).first else { return }
        context.delete(record)
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

    /// Löscht alle Daten.
    ///
    /// Gehört später in die Einstellungen („Alle Daten löschen") und wird
    /// heute schon von den Oberflächentests gebraucht, damit jeder Test von
    /// einem bekannten Stand aus startet statt vom Ergebnis des vorherigen.
    public func deleteEverything() throws {
        for record in try context.fetch(FetchDescriptor<MeteringPointRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<PropertyRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<TariffRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<BillingPeriodRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<HeatingChangeRecord>()) {
            context.delete(record)
        }
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
            billingPeriods: try context.fetch(FetchDescriptor<BillingPeriodRecord>()).compactMap { $0.toDomain() },
            heatingChanges: try heatingChanges()
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
        for change in snapshot.heatingChanges { try save(change) }
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
