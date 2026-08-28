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
    ///
    /// **Strom steht seit 0.46.0 auf zwei statt einer.** Mechanische
    /// Ferraris-Zähler haben eine rote Ziffer, moderne elektronische Zähler
    /// führen zwei — und die hängen inzwischen in vielen Haushalten. Wer nur
    /// eine Stelle eintragen kann, rundet bei jeder Ablesung, und über ein Jahr
    /// summiert sich das sichtbar. Umgekehrt kostet eine Stelle zu viel nichts:
    /// Sie bleibt eben null.
    ///
    /// Die Zahl ist eine **Vorbelegung**, kein Gesetz — sie steht an jedem
    /// Zählwerk einzeln und lässt sich dort ändern.
    public var defaultFractionDigits: Int {
        switch self {
        case .electricity, .solarProduction, .wallbox, .batteryStorage, .districtHeating: return 2
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

extension ResourceKind {

    /// Stabile Kennung für die Speicherung.
    ///
    /// Bewusst kein `Codable`-Blob: Als eigene Spalte bleibt die Zählerart
    /// abfragbar („alle Gaszähler"), und ein späteres Umbenennen eines Falls
    /// bricht keine bestehenden Datenbestände. Die Zeichenketten sind damit
    /// Teil des Dateiformats und dürfen sich nie ändern.
    public var storageID: String {
        switch self {
        case .electricity:     return "electricity"
        case .water:           return "water"
        case .hotWater:        return "hotWater"
        case .gas:             return "gas"
        case .districtHeating: return "districtHeating"
        case .heatingOil:      return "heatingOil"
        case .solarProduction: return "solarProduction"
        case .wallbox:         return "wallbox"
        case .batteryStorage:  return "batteryStorage"
        case .operatingHours:  return "operatingHours"
        case .rainwater:       return "rainwater"
        case .custom:          return "custom"
        }
    }

    public var customName: String? {
        if case .custom(let name, _) = self { return name }
        return nil
    }

    public var customUnit: MeasurementUnit? {
        if case .custom(_, let unit) = self { return unit }
        return nil
    }

    /// Stellt eine Zählerart aus den gespeicherten Feldern wieder her.
    ///
    /// Eine unbekannte Kennung — etwa aus einer neueren App-Version — wird zu
    /// einem frei definierten Zähler statt zu einem Fehler. Ein Nutzer verliert
    /// dadurch nur die Vorbelegung, nie seine Ablesungen.
    public static func restore(
        storageID: String,
        customName: String? = nil,
        customUnit: MeasurementUnit? = nil
    ) -> ResourceKind {
        switch storageID {
        case "electricity":     return .electricity
        case "water":           return .water
        case "hotWater":        return .hotWater
        case "gas":             return .gas
        case "districtHeating": return .districtHeating
        case "heatingOil":      return .heatingOil
        case "solarProduction": return .solarProduction
        case "wallbox":         return .wallbox
        case "batteryStorage":  return .batteryStorage
        case "operatingHours":  return .operatingHours
        case "rainwater":       return .rainwater
        default:
            return .custom(name: customName ?? storageID,
                           unit: customUnit ?? .kilowattHour)
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
