import Foundation

/// Eine Menge mit Einheit.
///
/// Die Einheit ist Teil des Wertes, nicht ein String daneben. Dadurch ist die
/// Fehlerklasse „m³ zu kWh addiert" strukturell ausgeschlossen statt nur unwahrscheinlich.
/// Siehe docs/01-architektur.md, ADR-004.
public struct Quantity: Hashable, Codable, Sendable, CustomStringConvertible {

    public let value: Decimal
    public let unit: MeasurementUnit

    public init(_ value: Decimal, _ unit: MeasurementUnit) {
        self.value = value
        self.unit = unit
    }

    public static func zero(_ unit: MeasurementUnit) -> Quantity {
        Quantity(0, unit)
    }

    public var isZero: Bool { value == 0 }
    public var isNegative: Bool { value < 0 }

    // MARK: - Umrechnung

    public enum ConversionError: Error, Equatable, Sendable {
        /// Die Einheiten gehören unterschiedlichen Dimensionen an. Für Gas ist
        /// stattdessen ``GasConversion`` zu verwenden.
        case incompatibleDimensions(from: MeasurementUnit, to: MeasurementUnit)
    }

    /// Rechnet in eine andere Einheit derselben Dimension um.
    public func converted(to target: MeasurementUnit) throws -> Quantity {
        guard unit.dimension == target.dimension else {
            throw ConversionError.incompatibleDimensions(from: unit, to: target)
        }
        guard unit != target else { return self }
        let inBase = value * unit.factorToBase
        return Quantity(inBase / target.factorToBase, target)
    }

    // MARK: - Arithmetik

    /// Addiert zwei Mengen. Das Ergebnis trägt die Einheit des linken Operanden.
    public func adding(_ other: Quantity) throws -> Quantity {
        let converted = try other.converted(to: unit)
        return Quantity(value + converted.value, unit)
    }

    public func subtracting(_ other: Quantity) throws -> Quantity {
        let converted = try other.converted(to: unit)
        return Quantity(value - converted.value, unit)
    }

    public func scaled(by factor: Decimal) -> Quantity {
        Quantity(value * factor, unit)
    }

    /// Verhältnis zweier Mengen derselben Dimension, `nil` bei Division durch null.
    public func ratio(to other: Quantity) throws -> Decimal? {
        let converted = try other.converted(to: unit)
        guard converted.value != 0 else { return nil }
        return value / converted.value
    }

    public var description: String { "\(value) \(unit.symbol)" }
}
