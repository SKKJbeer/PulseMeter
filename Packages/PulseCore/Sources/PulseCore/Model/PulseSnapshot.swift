import Foundation

/// Ein vollständiger Abzug aller Daten.
///
/// Dient drei Zwecken, die alle auf dasselbe hinauslaufen — der Nutzer soll
/// seine Daten nie verlieren können:
///
/// 1. **Sicherung vor jeder Schema-Migration** (siehe docs/02-datenmodell.md, §5)
/// 2. **Export**, dauerhaft kostenlos (Produktprinzip 5)
/// 3. **Wiederherstellung**, auch in eine leere Installation
///
/// Ein Export enthält deshalb *alle* Entitäten, nicht nur Ablesungen. Ein Abzug,
/// aus dem sich der Zustand nicht rekonstruieren lässt, ist keine Sicherung.
public struct PulseSnapshot: Codable, Hashable, Sendable {

    /// Format-Version. Steigt nur, wenn sich die Struktur so ändert, dass
    /// ältere Fassungen sie nicht mehr lesen können.
    public var version: Int
    public var createdAt: Date
    public var properties: [Property]
    public var units: [RentalUnit]
    public var meteringPoints: [MeteringPoint]
    public var readings: [Reading]
    public var tariffs: [Tariff]
    public var billingPeriods: [BillingPeriod]

    public static let currentVersion = 1

    public init(
        version: Int = PulseSnapshot.currentVersion,
        createdAt: Date = Date(),
        properties: [Property] = [],
        units: [RentalUnit] = [],
        meteringPoints: [MeteringPoint] = [],
        readings: [Reading] = [],
        tariffs: [Tariff] = [],
        billingPeriods: [BillingPeriod] = []
    ) {
        self.version = version
        self.createdAt = createdAt
        self.properties = properties
        self.units = units
        self.meteringPoints = meteringPoints
        self.readings = readings
        self.tariffs = tariffs
        self.billingPeriods = billingPeriods
    }

    public var isEmpty: Bool {
        properties.isEmpty && meteringPoints.isEmpty && readings.isEmpty
    }

    public var readingCount: Int { readings.count }
}

extension PulseSnapshot {

    public enum DecodingProblem: Error, Equatable, Sendable {
        /// Der Abzug stammt aus einer neueren Fassung der App.
        case unsupportedVersion(found: Int, supported: Int)
    }

    public static func decode(from data: Data) throws -> PulseSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PulseSnapshot.self, from: data)
        guard snapshot.version <= currentVersion else {
            throw DecodingProblem.unsupportedVersion(found: snapshot.version, supported: currentVersion)
        }
        return snapshot
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Führt einen Abzug in einen bestehenden Bestand ein.
    ///
    /// **Idempotent über die `UUID`s:** Zweimal denselben Export einzulesen
    /// erzeugt keine Dubletten. Das ist keine Feinheit — ohne diese Eigenschaft
    /// traut sich niemand, eine Sicherung einzuspielen, wenn er nicht mehr weiß,
    /// ob er es schon getan hat.
    ///
    /// Bei gleicher Kennung gewinnt der eingelesene Wert, weil ein
    /// Wiederherstellen den vorliegenden Stand ersetzen soll.
    public func merged(into existing: PulseSnapshot) -> PulseSnapshot {
        PulseSnapshot(
            version: Self.currentVersion,
            createdAt: Date(),
            properties: Self.merge(existing.properties, self.properties),
            units: Self.merge(existing.units, self.units),
            meteringPoints: Self.merge(existing.meteringPoints, self.meteringPoints),
            readings: Self.merge(existing.readings, self.readings),
            tariffs: Self.merge(existing.tariffs, self.tariffs),
            billingPeriods: Self.merge(existing.billingPeriods, self.billingPeriods)
        )
    }

    private static func merge<T: Identifiable>(_ base: [T], _ incoming: [T]) -> [T] where T.ID == UUID {
        var byID = Dictionary(base.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var order = base.map(\.id)
        for element in incoming {
            if byID[element.id] == nil { order.append(element.id) }
            byID[element.id] = element
        }
        return order.compactMap { byID[$0] }
    }

    /// Verwaiste Verweise, die eine Wiederherstellung unbrauchbar machen würden.
    ///
    /// Wird vor dem Einspielen geprüft: Eine Ablesung ohne Zählwerk ließe sich
    /// nirgends anzeigen und wäre stillschweigend verloren.
    public func danglingReferences() -> [String] {
        var problems: [String] = []
        let propertyIDs = Set(properties.map(\.id))
        let registerIDs = Set(meteringPoints.flatMap { $0.registers.map(\.id) })
        let pointIDs = Set(meteringPoints.map(\.id))

        for point in meteringPoints where !propertyIDs.contains(point.propertyID) {
            problems.append("Zähler \(point.name) verweist auf ein unbekanntes Objekt")
        }
        let orphanReadings = readings.filter { !registerIDs.contains($0.registerID) }
        if !orphanReadings.isEmpty {
            problems.append("\(orphanReadings.count) Ablesungen ohne zugehörigen Zähler")
        }
        for tariff in tariffs where !pointIDs.contains(tariff.meteringPointID) {
            problems.append("Ein Tarif verweist auf einen unbekannten Zähler")
        }
        return problems
    }
}
