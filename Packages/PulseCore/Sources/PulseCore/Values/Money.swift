import Foundation

public struct CurrencyCode: Hashable, Codable, Sendable, CustomStringConvertible {
    public let code: String

    public init(_ code: String) {
        self.code = code.uppercased()
    }

    public static let eur = CurrencyCode("EUR")
    public static let chf = CurrencyCode("CHF")

    public var description: String { code }
}

/// Ein Geldbetrag.
///
/// Beträge werden als `Decimal` geführt, nie als `Double`. Bei `Double` erzeugen
/// Beträge wie 0,1 + 0,2 Rundungsartefakte, die in einem Kostenbericht sichtbar
/// werden und Vertrauen kosten. Siehe docs/01-architektur.md, ADR-004.
public struct Money: Hashable, Codable, Sendable, CustomStringConvertible {

    public let amount: Decimal
    public let currency: CurrencyCode

    public init(_ amount: Decimal, _ currency: CurrencyCode) {
        self.amount = amount
        self.currency = currency
    }

    public static func zero(_ currency: CurrencyCode) -> Money {
        Money(0, currency)
    }

    public var isNegative: Bool { amount < 0 }

    public enum CurrencyMismatch: Error, Equatable, Sendable {
        case differentCurrencies(CurrencyCode, CurrencyCode)
    }

    public func adding(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw CurrencyMismatch.differentCurrencies(currency, other.currency)
        }
        return Money(amount + other.amount, currency)
    }

    public func subtracting(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw CurrencyMismatch.differentCurrencies(currency, other.currency)
        }
        return Money(amount - other.amount, currency)
    }

    public func scaled(by factor: Decimal) -> Money {
        Money(amount * factor, currency)
    }

    /// Kaufmännisch gerundeter Betrag auf zwei Nachkommastellen.
    ///
    /// Wird ausschließlich zur Anzeige und für Endsummen verwendet — Zwischenergebnisse
    /// bleiben ungerundet, damit sich Rundungsfehler nicht aufsummieren.
    public var roundedToCents: Money {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .bankers)
        return Money(output, currency)
    }

    public var description: String { "\(amount) \(currency.code)" }
}
