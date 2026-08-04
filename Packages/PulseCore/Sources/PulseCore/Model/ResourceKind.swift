import Foundation

/// Was an einer Messstelle gemessen wird.
///
/// `ResourceKind` ist ein *Preset*, kein Constraint: Es bestimmt nur die
/// Vorbelegung von Einheit, Nachkommastellen und typischem Ableseintervall.
/// Jede Vorbelegung ist überschreibbar.
///
/// Bewusst kein Vererbungsbaum und keine Sonderlogik je Art: Ein
/// Wärmepumpenzähler ist ein Stromzähler mit anderem Namen, kein eigener Typ.
/// Sondertypen im Code wären der Anfang der Unwartbarkeit — und stünden dem
/// Ziel „frei definierbare Zähler" im Weg.
/// Siehe docs/02-datenmodell.md, Abschnitt 2.
public enum ResourceKind: Hashable, Codable, Sendable {
    case electricity
    case water
    case hotWater
    case gas
    case districtHeating
    case heatingOil
    case solarProduction
    case wallbox
    case batteryStorage
    case operatingHours
    case rainwater
    case custom(name: String, unit: MeasurementUnit)

    public var defaultUnit: MeasurementUnit {
        switch self {
        case .electricity, .solarProduction, .wallbox, .batteryStorage: return .kilowattHour
        case .districtHeating: return .kilowattHour
        case .water, .hotWater, .gas, .rainwater: return .cubicMetre
        case .heatingOil: return .litre
        case .operatingHours: return .hour
        case .custom(_, let unit): return unit
        }
    }

    /// Nachkommastellen des typischen Zählwerks dieser Art.
    public var defaultFractionDigits: Int {
        switch self {
        case .electricity, .solarProduction, .wallbox, .batteryStorage, .districtHeating: return 1
        case .water, .hotWater, .rainwater: return 3
        case .gas: return 3
        case .heatingOil: return 0
        case .operatingHours: return 1
        case .custom: return 2
        }
    }

    /// Vorkommastellen des typischen Zählwerks — bestimmt den Überlaufpunkt.
    public var defaultIntegerDigits: Int {
        switch self {
        case .electricity, .solarProduction, .wallbox, .batteryStorage, .districtHeating: return 6
        case .water, .hotWater, .gas, .rainwater: return 5
        case .heatingOil: return 5
        case .operatingHours: return 5
        case .custom: return 6
        }
    }

    public var defaultInterval: ReadingInterval {
        switch self {
        case .electricity, .gas, .districtHeating, .solarProduction: return .monthly
        case .water, .hotWater: return .monthly
        case .heatingOil, .rainwater: return .quarterly
        case .wallbox, .batteryStorage: return .monthly
        case .operatingHours: return .quarterly
        case .custom: return .monthly
        }
    }

    /// Ob es sich um ein aufsummierendes Zählwerk handelt (Regelfall) oder um
    /// Mengen je Zeitraum (z. B. gelieferte Heizöl-Mengen).
    public var defaultAccumulation: AccumulationMode {
        switch self {
        case .heatingOil: return .interval
        default: return .cumulative
        }
    }
}

/// Erwarteter Ableserhythmus — Grundlage für Erinnerungen und für die Erkennung
/// von Datenlücken.
public enum ReadingInterval: String, Hashable, Codable, Sendable, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case yearly
    case never

    public var approximateDays: Int? {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 91
        case .yearly: return 365
        case .never: return nil
        }
    }
}
