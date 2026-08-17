import Foundation
import SwiftData
import PulseCore

// Alle gespeicherten Typen halten sich an die Einschränkungen, die CloudKit
// dem Schema auferlegt (siehe docs/01-architektur.md, ADR-002):
//
// 1. Jede Eigenschaft hat einen Vorgabewert oder ist optional.
//    CloudKit kann bestehende Datensätze sonst nicht um neue Felder ergänzen.
// 2. Keine `@Attribute(.unique)`. Eindeutigkeit wird über die fachliche `id`
//    hergestellt, nicht über den Speicher.
// 3. Beziehungen zu vielen sind optionale Arrays mit erklärter Umkehrung.
//
// Zusätzlich wird der fachliche Fremdschlüssel (`registerID`, `meteringPointID`)
// **neben** der Beziehung gespeichert. Das ist bewusste Redundanz: Abfragen über
// optionale Beziehungen sind in SwiftData-Prädikaten unzuverlässig, ein direkter
// UUID-Vergleich ist es nicht.

@Model
public final class PropertyRecord {
    public var id: UUID = UUID()
    public var name: String = ""
    public var street: String?
    public var postalCode: String?
    public var city: String?
    public var note: String?
    public var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \MeteringPointRecord.property)
    public var meteringPoints: [MeteringPointRecord]?

    @Relationship(deleteRule: .cascade, inverse: \RentalUnitRecord.property)
    public var units: [RentalUnitRecord]?

    public init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
        self.meteringPoints = []
        self.units = []
    }
}

@Model
public final class RentalUnitRecord {
    public var id: UUID = UUID()
    public var name: String = ""
    public var sortIndex: Int = 0
    /// Mietverhältnisse als JSON. Sie werden nie einzeln abgefragt, nur
    /// gemeinsam gelesen — eine eigene Tabelle wäre Aufwand ohne Nutzen.
    public var occupancyData: Data?
    public var property: PropertyRecord?

    public init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
}

@Model
public final class MeteringPointRecord {
    public var id: UUID = UUID()
    public var name: String = ""

    /// Zählerart als eigene Spalte statt als Blob — dadurch abfragbar, und ein
    /// Umbenennen im Code bricht keine bestehenden Bestände.
    public var kindID: String = "electricity"
    public var customKindName: String?
    public var customKindUnit: String?

    public var symbolName: String = "gauge.medium"
    public var colorToken: String = "graphite"
    public var readingIntervalID: String = "monthly"

    /// Stichtag des Abrechnungsrhythmus, beide Felder gemeinsam gesetzt oder nil.
    public var billingAnchorMonth: Int?
    public var billingAnchorDay: Int?

    public var isArchived: Bool = false
    public var sortIndex: Int = 0
    public var note: String?
    public var unitID: UUID?
    public var propertyID: UUID = UUID()

    public var property: PropertyRecord?

    @Relationship(deleteRule: .cascade, inverse: \RegisterRecord.meteringPoint)
    public var registers: [RegisterRecord]?

    @Relationship(deleteRule: .cascade, inverse: \MeterDeviceRecord.meteringPoint)
    public var devices: [MeterDeviceRecord]?

    public init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
        self.registers = []
        self.devices = []
    }
}

@Model
public final class RegisterRecord {
    public var id: UUID = UUID()
    public var label: String?
    public var unitID: String = "kWh"
    public var directionID: String = "consumption"
    public var accumulationID: String = "cumulative"
    public var integerDigits: Int = 6
    public var fractionDigits: Int = 1
    public var obisCode: String?
    public var sortIndex: Int = 0

    public var meteringPoint: MeteringPointRecord?

    @Relationship(deleteRule: .cascade, inverse: \ReadingRecord.register)
    public var readings: [ReadingRecord]?

    public init(id: UUID = UUID()) {
        self.id = id
        self.readings = []
    }
}

@Model
public final class MeterDeviceRecord {
    public var id: UUID = UUID()
    public var serialNumber: String?
    /// Kalendertag als yyyyMMdd — zeitzonenfrei, sortierbar (ADR-004).
    public var installedOn: Int = 0
    public var removedOn: Int?
    public var photoID: UUID?
    public var meteringPoint: MeteringPointRecord?

    public init(id: UUID = UUID()) { self.id = id }
}

@Model
public final class ReadingRecord {
    public var id: UUID = UUID()
    /// Fremdschlüssel neben der Beziehung — siehe Anmerkung oben.
    public var registerID: UUID = UUID()
    public var deviceID: UUID?

    public var day: Int = 0
    /// Minuten seit Mitternacht, wenn eine Uhrzeit angegeben wurde.
    ///
    /// Optional und ohne Vorgabewert, damit CloudKit und SwiftData den Zusatz
    /// leichtgewichtig übernehmen: Alles, was vor 0.64.0 gespeichert wurde,
    /// bleibt gültig und trägt hier `nil` — „an diesem Tag", ohne Uhrzeit.
    public var timeMinutes: Int?

    /// Ganzzahliger Zählerstand mit mitgeführtem Dezimalfaktor.
    /// Niemals `Double`: CloudKit überträgt sonst 49157.399999999994
    /// statt 49157,4. Siehe `ScaledDecimal` in PulseCore.
    public var scaledValue: Int = 0
    public var valueScale: Int = 0

    public var originID: String = "manual"
    public var note: String?
    public var photoID: UUID?
    /// Erfassungszeitpunkt für Beweiszwecke und zur Sortierung mehrerer
    /// Ablesungen desselben Tages — nie Grundlage einer Berechnung.
    public var createdAt: Date = Date()

    public var register: RegisterRecord?

    public init(id: UUID = UUID()) { self.id = id }
}

@Model
public final class TariffRecord {
    public var id: UUID = UUID()
    public var meteringPointID: UUID = UUID()
    public var registerID: UUID?

    public var validFrom: Int = 0
    public var validTo: Int?

    public var pricePerUnitScaled: Int = 0
    public var monthlyBasePriceScaled: Int = 0
    public var valueScale: Int = ScaledDecimal.moneyScale
    public var currencyCode: String = "EUR"
    public var billingUnitID: String = "kWh"

    public var gasStateNumberScaled: Int?
    public var gasCalorificValueScaled: Int?
    public var feedInPriceScaled: Int?

    public init(id: UUID = UUID()) { self.id = id }
}

@Model
public final class BillingPeriodRecord {
    public var id: UUID = UUID()
    public var meteringPointID: UUID = UUID()
    public var provider: String?
    public var customerReference: String?
    public var rangeStart: Int = 0
    public var rangeEnd: Int = 0
    public var monthlyPrepaymentScaled: Int?
    public var valueScale: Int = ScaledDecimal.moneyScale
    public var currencyCode: String = "EUR"

    public init(id: UUID = UUID()) { self.id = id }
}
