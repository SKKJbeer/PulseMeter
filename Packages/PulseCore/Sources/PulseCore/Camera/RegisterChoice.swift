import Foundation

/// Gehört eine Zahl, die die Kamera liest, sicher zum gefragten Zählwerk?
///
/// **Der Anlass:** Die moderne Messeinrichtung zeigt Bezug (1.8.0) und Einspeisung
/// (2.8.0) abwechselnd auf **einem** Display, jede Zahl fünf bis zehn Sekunden lang.
/// Die Einigung „vier von sechs“ steht nach einer Sekunde. Wer im Schritt „Bezug“ die
/// Kamera hält, während gerade 2.8.0 dasteht, bekäme die Einspeisung als Bezug
/// vorgeschlagen: eine falsche Zahl, die plausibel aussieht (Produktprinzip 7,
/// `docs/kamera/stufe-2.md`).
///
/// **Die Regel:** Hat der Zähler weitere Zählwerke, wird nur vorgeschlagen, wenn deren
/// Bereiche die Zahl ausschließen. Ein anderes Zählwerk ohne Bereich (nie abgelesen)
/// schließt nichts aus. Liegt die Zahl im Bereich eines anderen, kann sie zu ihm
/// gehören, und wer davorsteht, tippt sie lieber selbst.
///
/// Der eigene Bereich spielt hier keine Rolle: Ihn prüft schon ``MeterTextReader``.
public enum RegisterChoice: Hashable, Sendable {
    /// Die Zahl gehört zum gefragten Zählwerk, soweit sich das sagen lässt.
    case own
    /// Die Zahl könnte zu diesem anderen Zählwerk gehören (Index in `others`).
    case couldBeOther(Int)

    /// - Parameters:
    ///   - value: die Zahl, auf die sich die Kamera geeinigt hat.
    ///   - others: die Bereiche der **anderen** Zählwerke desselben Zählers,
    ///     `nil` für eines ohne letzten Stand.
    public static func check(_ value: Decimal, others: [ClosedRange<Decimal>?]) -> RegisterChoice {
        for (index, range) in others.enumerated() {
            guard let range else { return .couldBeOther(index) }
            if range.contains(value) { return .couldBeOther(index) }
        }
        return .own
    }
}
