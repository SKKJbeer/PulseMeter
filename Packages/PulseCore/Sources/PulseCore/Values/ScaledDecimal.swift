import Foundation

/// Ein `Decimal` als ganzzahliger Wert mit festem Dezimalfaktor.
///
/// **Warum das nötig ist.** Speichert man Zählerstände und Preise als
/// Fließkommazahl, verliert man Genauigkeit — und CloudKit kennt als Zahlentypen
/// nur `Int64` und `Double`. Ein `Decimal`, das über die Synchronisation läuft,
/// wird unterwegs zu `Double` und kommt als 49157.399999999994 zurück. In einem
/// Kostenbericht ist das sichtbar, und es widerspricht ADR-004.
///
/// `Int64` überträgt CloudKit dagegen verlustfrei. Ein Zählwerk ist ohnehin
/// diskret: 49157,4 kWh sind 491574 Zehntel. Der Faktor wird beim Wert
/// mitgespeichert, damit ein späteres Ändern der Nachkommastellen die Historie
/// nicht verschiebt.
public struct ScaledDecimal: Hashable, Codable, Sendable, CustomStringConvertible {

    /// Der ganzzahlig gespeicherte Wert.
    public let scaled: Int
    /// Anzahl der Nachkommastellen, die `scaled` abbildet.
    public let scale: Int

    /// Rundet kaufmännisch auf `scale` Nachkommastellen — dieselbe Regel wie
    /// bei ``Money/roundedToCents``, damit nirgends eine andere Rundung gilt.
    public init(_ value: Decimal, scale: Int) {
        let scale = Swift.max(0, scale)
        var shifted = value * Decimal(sign: .plus, exponent: scale, significand: 1)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &shifted, 0, .bankers)
        self.scaled = NSDecimalNumber(decimal: rounded).intValue
        self.scale = scale
    }

    public init(scaled: Int, scale: Int) {
        self.scaled = scaled
        self.scale = Swift.max(0, scale)
    }

    public var value: Decimal {
        Decimal(scaled) * Decimal(sign: .plus, exponent: -scale, significand: 1)
    }

    public var description: String { "\(value)" }
}

extension ScaledDecimal {
    /// Nachkommastellen für Geldbeträge und Arbeitspreise.
    ///
    /// Sechs Stellen, nicht zwei: Ein Gaspreis von 0,1120 €/kWh und eine
    /// Einspeisevergütung von 0,0820 €/kWh brauchen mehr als Cent-Genauigkeit,
    /// sonst rundet man den Preis, bevor man ihn mit dem Verbrauch multipliziert.
    public static let moneyScale = 6

    public init(money: Decimal) {
        self.init(money, scale: Self.moneyScale)
    }

    /// Nachkommastellen eines Zählwerks. Der Wert wird so gespeichert, wie das
    /// Gerät ihn anzeigt.
    public init(reading value: Decimal, register: Register) {
        self.init(value, scale: register.fractionDigits)
    }
}
