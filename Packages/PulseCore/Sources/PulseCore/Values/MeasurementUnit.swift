import Foundation

/// Physikalische Dimension einer Einheit.
///
/// Einheiten unterschiedlicher Dimension lassen sich nicht ineinander umrechnen —
/// mit einer bewussten Ausnahme: Gas wird über Zustandszahl und Brennwert von
/// Volumen in Energie überführt. Diese Umrechnung ist immer explizit
/// (siehe ``GasConversion``) und nie implizit.
public enum UnitDimension: String, Codable, Hashable, Sendable, CaseIterable {
    case energy
    case volume
    case duration
    case mass
}

/// Einheiten, in denen Zählwerke messen.
public enum MeasurementUnit: String, Codable, Hashable, Sendable, CaseIterable {
    case kilowattHour = "kWh"
    case megawattHour = "MWh"
    case gigajoule = "GJ"
    case cubicMetre = "m³"
    case litre = "l"
    case hour = "h"
    case kilogram = "kg"

    public var symbol: String { rawValue }

    public var dimension: UnitDimension {
        switch self {
        case .kilowattHour, .megawattHour, .gigajoule: return .energy
        case .cubicMetre, .litre: return .volume
        case .hour: return .duration
        case .kilogram: return .mass
        }
    }

    /// Umrechnungsfaktor in die Basiseinheit der jeweiligen Dimension.
    /// Basis: kWh (Energie), m³ (Volumen), h (Dauer), kg (Masse).
    var factorToBase: Decimal {
        switch self {
        case .kilowattHour: return 1
        case .megawattHour: return 1_000
        case .gigajoule: return Decimal(string: "277.777777777778")!  // 1 GJ = 1/0,0036 kWh
        case .cubicMetre: return 1
        case .litre: return Decimal(string: "0.001")!
        case .hour: return 1
        case .kilogram: return 1
        }
    }

    /// Übliche Anzahl Nachkommastellen bei der Anzeige.
    public var displayFractionDigits: Int {
        switch self {
        case .kilowattHour, .megawattHour, .gigajoule: return 0
        case .cubicMetre: return 1
        case .litre: return 0
        case .hour: return 0
        case .kilogram: return 1
        }
    }
}
