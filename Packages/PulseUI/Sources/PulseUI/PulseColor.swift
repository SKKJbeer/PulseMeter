import SwiftUI
import UIKit

/// Farben des Design-Systems.
///
/// **Warum die Neutralen warm gebrochen sind.** Die Zählerfarben *sind* die
/// Palette — sie machen die App ohne Text lesbar. Damit sie tragen, muss alles
/// andere zurücktreten. Ein warm gebrochenes Grau tut das; das kalte
/// Standard-Grau konkurriert mit den Datenfarben.
///
/// Alle Werte kommen aus dem Klick-Dummy und sind dort in Hell und Dunkel
/// geprüft (`docs/prototype/index.html`).
public enum PulseColor {

    // MARK: - Flächen und Schrift

    /// Hintergrund des Bildschirms.
    public static var ground: Color { .adaptive(light: 0xFBFAF8, dark: 0x100F0D) }
    /// Karten und erhobene Flächen.
    public static var surface: Color { .adaptive(light: 0xFFFFFF, dark: 0x1B1917) }
    /// Zweite Ebene, etwa hinterlegte Umschalter.
    public static var surfaceMuted: Color { .adaptive(light: 0xF4F1EB, dark: 0x262320) }

    /// Haupttext.
    public static var ink: Color { .adaptive(light: 0x17150F, dark: 0xF5F2EC) }
    /// Beschreibender Text.
    public static var inkSecondary: Color { .adaptive(light: 0x6B6659, dark: 0xA39C8D) }
    /// Nebensächliches, Einheiten, Zeitangaben.
    public static var inkTertiary: Color { .adaptive(light: 0x9A9384, dark: 0x756F62) }

    public static var hairline: Color { .adaptive(light: 0xE7E3DA, dark: 0x2B2822) }
    public static var hairlineStrong: Color { .adaptive(light: 0xD8D2C6, dark: 0x383430) }

    /// Akzent der App. Wird sparsam eingesetzt — die Zählerfarben führen.
    public static var tint: Color { .adaptive(light: 0xC77A0E, dark: 0xE0A040) }

    // MARK: - Bedeutung

    /// Verbrauch gesunken, Guthaben, alles im Rahmen.
    public static var favourable: Color { .adaptive(light: 0x2F7F52, dark: 0x5CBF85) }
    /// Verbrauch gestiegen, Nachzahlung.
    public static var adverse: Color { .adaptive(light: 0xB03A38, dark: 0xDC6E6C) }
    /// Hinweis, der keine Blockade ist — etwa eine fällige Ablesung.
    public static var noticeBackground: Color { .adaptive(light: 0xFBF0DA, dark: 0x33290F) }
    public static var noticeInk: Color { .adaptive(light: 0x8A5A08, dark: 0xE8C070) }

    /// Schrift auf einer mit einer Akzentfarbe gefüllten Fläche.
    ///
    /// Im Dunkelmodus sind die Akzentfarben aufgehellt, damit sie auf dunklem
    /// Grund lesbar sind. Als Füllung brauchen sie dann dunkle Schrift — weiß
    /// auf hellem Orange erreicht keinen ausreichenden Kontrast.
    public static var onAccent: Color { .adaptive(light: 0xFFFFFF, dark: 0x100F0D) }

    // MARK: - Zählerarten

    /// Farbe zu einer Kennung, wie sie im Datenmodell hinterlegt ist.
    ///
    /// Die Zuordnung liegt hier und nicht in der Domäne: `PulseCore` speichert
    /// nur einen Namen, damit es keine Darstellung kennen muss (ADR-003).
    public static func resource(_ token: String) -> Color {
        switch token {
        case "amber":    return .adaptive(light: 0xC98410, dark: 0xE8A945)
        case "green":    return .adaptive(light: 0x2F8B57, dark: 0x5CBF85)
        case "blue":     return .adaptive(light: 0x2A6FB8, dark: 0x5C9EE0)
        case "rose":     return .adaptive(light: 0xB5527A, dark: 0xE08AAE)
        case "orange":   return .adaptive(light: 0xC25C22, dark: 0xE08551)
        case "red":      return .adaptive(light: 0xB03A38, dark: 0xDC6E6C)
        case "teal":     return .adaptive(light: 0x2A7F7A, dark: 0x63BAB4)
        case "mint":     return .adaptive(light: 0x2E8B6E, dark: 0x62C6A5)
        case "indigo":   return .adaptive(light: 0x4B54A8, dark: 0x8B92E0)
        case "brown":    return .adaptive(light: 0x7A5A3C, dark: 0xC0A183)
        default:         return .adaptive(light: 0x5F5A50, dark: 0xA8A197)
        }
    }
}

extension Color {

    /// Eine Farbe, die dem Erscheinungsbild folgt.
    ///
    /// SwiftUI bietet dafür ohne Asset-Katalog nichts an, deshalb der Umweg
    /// über `UIColor`. Der Vorteil: Die Palette bleibt im Code lesbar und
    /// versionierbar, statt in einer Binärdatei zu verschwinden.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
