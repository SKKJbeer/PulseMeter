import Foundation

/// Richtung, in die ein Zählwerk zählt.
public enum FlowDirection: String, Hashable, Codable, Sendable, CaseIterable {
    /// Bezug — was verbraucht wird.
    case consumption
    /// Eigenerzeugung, z. B. PV-Ertrag.
    case production
    /// Einspeisung ins Netz.
    case feedIn
    /// Beladung eines Speichers.
    case charge
    /// Entladung eines Speichers.
    case discharge
}

/// Ob ein Zählwerk aufsummiert oder Mengen je Zeitraum erfasst.
public enum AccumulationMode: String, Hashable, Codable, Sendable, CaseIterable {
    /// Klassischer Zählerstand, der nur steigt. Verbrauch = Differenz.
    case cumulative
    /// Der erfasste Wert *ist* die Menge des Zeitraums (z. B. Öllieferung).
    case interval
}

/// Ein einzelnes Zählwerk.
///
/// Die Trennung von Messstelle und Zählwerk ist die zentrale Modellentscheidung
/// des Projekts. Ein Zweirichtungszähler (PV) und ein Doppeltarifzähler (HT/NT)
/// sind jeweils *ein* Gerät mit *zwei* Zählwerken. Würde eine Messstelle nur
/// eine Zahl führen, ließen sich beide Fälle nur durch zwei getrennte „Zähler"
/// abbilden — was Gerät, Nummer und Wechselhistorie zerreißt.
/// Siehe docs/02-datenmodell.md, Abschnitt 1.
///
/// In der Oberfläche existiert dieser Begriff nicht. Bei einem einzelnen
/// Zählwerk (`label == nil`) wird er nirgends angezeigt.
public struct Register: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID

    /// `nil` bei einem einzelnen Zählwerk. Sonst die Bezeichnung in der Sprache
    /// des Nutzers: „Hochtarif", „Einspeisung", „Ladung".
    public var label: String?

    public var unit: MeasurementUnit
    public var direction: FlowDirection
    public var accumulation: AccumulationMode

    /// Vorkommastellen des mechanischen Zählwerks. Bestimmt den Überlaufpunkt
    /// *und* die Optik der Eingabemaske.
    public var integerDigits: Int

    /// Nachkommastellen — bei mechanischen Zählern die roten Ziffern.
    public var fractionDigits: Int

    /// OBIS-Kennzahl, z. B. „1.8.0". Rein optional und nur in der Expertenansicht
    /// sichtbar; für die Berechnung ohne Bedeutung.
    public var obisCode: String?

    public init(
        id: UUID = UUID(),
        label: String? = nil,
        unit: MeasurementUnit,
        direction: FlowDirection = .consumption,
        accumulation: AccumulationMode = .cumulative,
        integerDigits: Int = 6,
        fractionDigits: Int = 1,
        obisCode: String? = nil
    ) {
        self.id = id
        self.label = label
        self.unit = unit
        self.direction = direction
        self.accumulation = accumulation
        self.integerDigits = integerDigits
        self.fractionDigits = fractionDigits
        self.obisCode = obisCode
    }

    /// Wert, bei dem das Zählwerk auf null zurückspringt.
    /// Ein sechsstelliges Zählwerk läuft bei 1.000.000 über.
    public var capacity: Decimal {
        Decimal(sign: .plus, exponent: integerDigits, significand: 1)
    }

    /// Ein Zählwerk mit den Vorgaben einer Zählerart.
    public static func standard(for kind: ResourceKind, direction: FlowDirection = .consumption) -> Register {
        Register(
            unit: kind.defaultUnit,
            direction: direction,
            accumulation: kind.defaultAccumulation,
            integerDigits: kind.defaultIntegerDigits,
            fractionDigits: kind.defaultFractionDigits
        )
    }
}

/// Ein physisches Zählergerät.
///
/// Getrennt von der Messstelle, weil Geräte gewechselt werden, die Messstelle
/// aber über Jahrzehnte dieselbe bleibt. Hinge die Gerätenummer an der Messstelle,
/// ginge beim Wechsel entweder die Historie verloren oder der Verbrauch würde
/// negativ — der Fehler, an dem verbreitete Zähler-Apps scheitern.
public struct MeterDevice: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var serialNumber: String?
    public var installedOn: CalendarDay
    public var removedOn: CalendarDay?
    public var photoID: UUID?

    public init(
        id: UUID = UUID(),
        serialNumber: String? = nil,
        installedOn: CalendarDay,
        removedOn: CalendarDay? = nil,
        photoID: UUID? = nil
    ) {
        self.id = id
        self.serialNumber = serialNumber
        self.installedOn = installedOn
        self.removedOn = removedOn
        self.photoID = photoID
    }

    public var isActive: Bool { removedOn == nil }
}
