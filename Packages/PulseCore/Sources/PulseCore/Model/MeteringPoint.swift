import Foundation

/// Ein Objekt bzw. Standort.
///
/// Für Einzelnutzer wird beim ersten Start implizit ein Standard-Objekt angelegt,
/// das in der Oberfläche nicht erscheint. Die Ebene wird erst ab dem zweiten
/// Objekt sichtbar. Dadurch muss niemand ein Konzept lernen, das er nicht braucht —
/// und es ist trotzdem keine Migration nötig, wenn er es später doch braucht.
public struct Property: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var name: String
    public var street: String?
    public var postalCode: String?
    public var city: String?
    public var note: String?
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        street: String? = nil,
        postalCode: String? = nil,
        city: String? = nil,
        note: String? = nil,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.street = street
        self.postalCode = postalCode
        self.city = city
        self.note = note
        self.sortIndex = sortIndex
    }
}

/// Ein Mietverhältnis über einen Zeitraum.
public struct OccupancyPeriod: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var tenantName: String
    public var movedIn: CalendarDay
    public var movedOut: CalendarDay?

    public init(id: UUID = UUID(), tenantName: String, movedIn: CalendarDay, movedOut: CalendarDay? = nil) {
        self.id = id
        self.tenantName = tenantName
        self.movedIn = movedIn
        self.movedOut = movedOut
    }
}

/// Eine Einheit innerhalb eines Objekts (Wohnung, Gewerbefläche).
///
/// Ab Tag 1 im Modell, in v1 bewusst ohne Oberfläche: rein additiv, blockiert nichts
/// und erspart uns später eine Migration bei zahlenden Nutzern.
/// Siehe docs/05-roadmap.md.
public struct RentalUnit: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var propertyID: Property.ID
    public var name: String
    public var occupancies: [OccupancyPeriod]
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        propertyID: Property.ID,
        name: String,
        occupancies: [OccupancyPeriod] = [],
        sortIndex: Int = 0
    ) {
        self.id = id
        self.propertyID = propertyID
        self.name = name
        self.occupancies = occupancies
        self.sortIndex = sortIndex
    }

    /// Mietverhältnis, das an einem bestimmten Tag bestand.
    public func occupancy(on day: CalendarDay) -> OccupancyPeriod? {
        occupancies.first { period in
            day >= period.movedIn && (period.movedOut.map { day <= $0 } ?? true)
        }
    }
}

/// Darstellung einer Messstelle in der Oberfläche.
///
/// Farbe ist funktional, nicht dekorativ: Sie macht die App ohne Text lesbar.
/// Siehe docs/03-ux-konzept.md, Abschnitt 6.
public struct Appearance: Hashable, Codable, Sendable {
    public var symbolName: String
    public var colorToken: String

    public init(symbolName: String, colorToken: String) {
        self.symbolName = symbolName
        self.colorToken = colorToken
    }

    public static func standard(for kind: ResourceKind) -> Appearance {
        switch kind {
        case .electricity:      return Appearance(symbolName: "bolt.fill", colorToken: "amber")
        case .water:            return Appearance(symbolName: "drop.fill", colorToken: "blue")
        case .hotWater:         return Appearance(symbolName: "drop.fill", colorToken: "rose")
        case .gas:              return Appearance(symbolName: "flame.fill", colorToken: "orange")
        case .districtHeating:  return Appearance(symbolName: "thermometer.medium", colorToken: "red")
        case .heatingOil:       return Appearance(symbolName: "fuelpump.fill", colorToken: "brown")
        case .solarProduction:  return Appearance(symbolName: "sun.max.fill", colorToken: "green")
        case .wallbox:          return Appearance(symbolName: "car.fill", colorToken: "teal")
        case .batteryStorage:   return Appearance(symbolName: "battery.100", colorToken: "mint")
        case .operatingHours:   return Appearance(symbolName: "clock.fill", colorToken: "graphite")
        case .rainwater:        return Appearance(symbolName: "cloud.rain.fill", colorToken: "indigo")
        case .custom:           return Appearance(symbolName: "gauge.medium", colorToken: "graphite")
        }
    }
}

/// Eine Messstelle — in der Oberfläche schlicht „Zähler".
///
/// Die stabile Identität über die gesamte Lebensdauer: „Strom Haupthaus" bleibt
/// dieselbe Messstelle, auch wenn das Gerät dreimal gewechselt wurde.
public struct MeteringPoint: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var propertyID: Property.ID
    /// `nil` = Allgemein bzw. Gesamtobjekt.
    public var unitID: RentalUnit.ID?
    public var name: String
    public var kind: ResourceKind
    public var appearance: Appearance
    /// Mindestens ein Zählwerk. Mehrere bei Doppeltarif, Zweirichtung, Speicher.
    public var registers: [Register]
    /// Wechselhistorie. Darf leer sein — dann ist die Gerätezuordnung unbekannt.
    public var devices: [MeterDevice]
    public var readingInterval: ReadingInterval
    /// Rhythmus, in dem der Versorger abrechnet. `nil`, solange der Nutzer ihn
    /// nicht hinterlegt hat — dann bleiben nur Kalenderzeiträume.
    public var billingCycle: BillingCycle?
    public var isArchived: Bool
    public var sortIndex: Int
    public var note: String?

    public init(
        id: UUID = UUID(),
        propertyID: Property.ID,
        unitID: RentalUnit.ID? = nil,
        name: String,
        kind: ResourceKind,
        appearance: Appearance? = nil,
        registers: [Register]? = nil,
        devices: [MeterDevice] = [],
        readingInterval: ReadingInterval? = nil,
        billingCycle: BillingCycle? = nil,
        isArchived: Bool = false,
        sortIndex: Int = 0,
        note: String? = nil
    ) {
        self.id = id
        self.propertyID = propertyID
        self.unitID = unitID
        self.name = name
        self.kind = kind
        self.appearance = appearance ?? .standard(for: kind)
        self.registers = registers ?? [.standard(for: kind)]
        self.devices = devices
        self.readingInterval = readingInterval ?? kind.defaultInterval
        self.billingCycle = billingCycle
        self.isArchived = isArchived
        self.sortIndex = sortIndex
        self.note = note
    }

    /// Ob die Messstelle mehr als ein Zählwerk führt. Nur dann darf die
    /// Oberfläche überhaupt Zählwerk-Bezeichnungen anzeigen.
    public var hasMultipleRegisters: Bool { registers.count > 1 }

    public var primaryRegister: Register? { registers.first }

    public func register(id: Register.ID) -> Register? {
        registers.first { $0.id == id }
    }

    /// Gerät, das an einem bestimmten Tag verbaut war.
    public func device(on day: CalendarDay) -> MeterDevice? {
        devices.first { device in
            day >= device.installedOn && (device.removedOn.map { day <= $0 } ?? true)
        }
    }

    /// Der laufende Abrechnungszeitraum, am angegebenen Tag abgeschnitten.
    public func runningBillingPeriod(on day: CalendarDay) -> DayRange? {
        billingCycle?.runningPeriod(on: day)
    }

    /// Der zuletzt abgeschlossene Abrechnungszeitraum — der Zeitraum, zu dem
    /// die Jahresabrechnung des Versorgers vorliegt und den ein Bericht prüfen soll.
    public func lastCompletedBillingPeriod(before day: CalendarDay) -> DayRange? {
        billingCycle?.completedPeriod(before: day)
    }

    // MARK: - Vorlagen

    /// Zweirichtungszähler: ein Gerät, zwei Zählwerke (Bezug und Einspeisung).
    /// Der häufigste Fall bei PV-Anlagen und der Fall, an dem ein
    /// „eine Zahl pro Zähler"-Modell scheitern würde.
    public static func bidirectionalElectricity(
        propertyID: Property.ID,
        name: String
    ) -> MeteringPoint {
        MeteringPoint(
            propertyID: propertyID,
            name: name,
            kind: .electricity,
            registers: [
                Register(label: "Bezug", unit: .kilowattHour, direction: .consumption,
                         integerDigits: 6, fractionDigits: 1, obisCode: "1.8.0"),
                Register(label: "Einspeisung", unit: .kilowattHour, direction: .feedIn,
                         integerDigits: 6, fractionDigits: 1, obisCode: "2.8.0")
            ]
        )
    }

    /// Doppeltarifzähler: ein Gerät, zwei Zählwerke mit unterschiedlichen Preisen.
    public static func dualTariffElectricity(
        propertyID: Property.ID,
        name: String
    ) -> MeteringPoint {
        MeteringPoint(
            propertyID: propertyID,
            name: name,
            kind: .electricity,
            registers: [
                Register(label: "Hochtarif", unit: .kilowattHour, direction: .consumption,
                         integerDigits: 6, fractionDigits: 1, obisCode: "1.8.1"),
                Register(label: "Nachttarif", unit: .kilowattHour, direction: .consumption,
                         integerDigits: 6, fractionDigits: 1, obisCode: "1.8.2")
            ]
        )
    }
}
