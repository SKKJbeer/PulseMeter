import SwiftUI

/// Textstile des Design-Systems.
///
/// Durchgehend auf Dynamic Type aufgebaut: Jeder Stil leitet sich von einem
/// Systemstil ab und wächst deshalb mit der Einstellung des Nutzers. Feste
/// Punktgrößen wären der bequemere Weg und würden bei der größten Stufe
/// zerbrechen — genau dort, wo Barrierefreiheit anfängt.
public enum PulseText {

    /// Bildschirmtitel.
    public static var screenTitle: Font { .system(.largeTitle, design: .default, weight: .bold) }

    /// Der große Wert auf einer Karte. Ziffern in fester Breite, damit die Zahl
    /// beim Aktualisieren nicht springt.
    public static var value: Font {
        .system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()
    }

    /// Einheit neben einem Wert.
    public static var unit: Font { .system(.callout, weight: .medium) }

    /// Name eines Zählers.
    public static var cardTitle: Font { .system(.headline, weight: .semibold) }

    /// Erläuternde Zeile unter einem Wert.
    public static var detail: Font { .system(.subheadline).monospacedDigit() }

    /// Kleingedrucktes: Zeitangaben, Herkunft, Hinweise.
    public static var caption: Font { .system(.caption).monospacedDigit() }

    /// Abschnittsüberschrift in Versalien.
    public static var sectionLabel: Font { .system(.caption2, weight: .semibold) }
}

extension View {
    /// Abschnittsüberschrift, wie sie über Listen steht.
    public func pulseSectionLabel() -> some View {
        self.font(PulseText.sectionLabel)
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(PulseColor.inkTertiary)
    }
}
