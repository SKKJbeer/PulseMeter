import SwiftUI

/// Ein Zählwerk, wie es am Gerät aussieht: weiße Vorkomma-, rote
/// Nachkommastellen auf dunklem Grund.
///
/// Der Nutzer steht im Keller und vergleicht optisch, statt zu übersetzen.
/// Sieht die Eingabe aus wie das Gerät, sinkt die Zahl der Tippfehler — und
/// der Tippfehler ist der häufigste Datenfehler in dieser Art App.
public struct CounterDisplay: View {

    private let digits: String
    private let integerDigits: Int
    private let fractionDigits: Int

    /// - Parameter digits: Nur Ziffern, ohne Trennzeichen. Kürzere Eingaben
    ///   werden von rechts aufgefüllt, wie bei einem Betragsfeld.
    public init(digits: String, integerDigits: Int, fractionDigits: Int) {
        self.digits = digits
        self.integerDigits = integerDigits
        self.fractionDigits = fractionDigits
    }

    private var padded: [Character] {
        let total = integerDigits + fractionDigits
        let trimmed = String(digits.suffix(total))
        return Array(String(repeating: "0", count: max(0, total - trimmed.count)) + trimmed)
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(padded.enumerated()), id: \.offset) { index, digit in
                if index == integerDigits { Spacer().frame(width: 8) }
                drum(digit, decimal: index >= integerDigits)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(red: 0.16, green: 0.15, blue: 0.13),
                                    Color(red: 0.26, green: 0.24, blue: 0.20)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zählerstand")
        .accessibilityValue(readableValue)
        // Wer die Rollen nicht sieht, weiß sonst nicht, wie viele Ziffern das
        // Gerät überhaupt hat — und tippt gegen eine Grenze, die es für ihn
        // nicht gibt.
        .accessibilityHint(fractionDigits > 0
            ? "\(integerDigits) Stellen vor und \(fractionDigits) nach dem Komma"
            : "\(integerDigits) Stellen")
    }

    private var readableValue: String {
        let whole = String(padded.prefix(integerDigits)).drop(while: { $0 == "0" })
        let fraction = String(padded.suffix(fractionDigits))
        let head = whole.isEmpty ? "0" : String(whole)
        return fractionDigits > 0 ? "\(head) Komma \(fraction)" : head
    }

    private func drum(_ digit: Character, decimal: Bool) -> some View {
        Text(String(digit))
            .font(.system(size: 27, weight: .semibold, design: .monospaced))
            .foregroundStyle(decimal ? .white : Color(red: 0.09, green: 0.08, blue: 0.06))
            .frame(width: 30, height: 46)
            .background(decimal ? Self.redDrum : Self.whiteDrum)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.28), lineWidth: 1))
            // Die Rolle springt beim Wechsel kurz, wie ein mechanisches Werk.
            .id(digit)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Zylindrische Schattierung — hell in der Mitte, dunkel an den Kanten.
    private static var whiteDrum: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(red: 0.72, green: 0.70, blue: 0.65), location: 0),
            .init(color: Color(red: 0.99, green: 0.99, blue: 0.98), location: 0.20),
            .init(color: .white, location: 0.48),
            .init(color: Color(red: 0.94, green: 0.92, blue: 0.89), location: 0.76),
            .init(color: Color(red: 0.72, green: 0.70, blue: 0.65), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    private static var redDrum: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(red: 0.48, green: 0.11, blue: 0.09), location: 0),
            .init(color: Color(red: 0.85, green: 0.21, blue: 0.18), location: 0.20),
            .init(color: Color(red: 0.93, green: 0.29, blue: 0.26), location: 0.48),
            .init(color: Color(red: 0.76, green: 0.16, blue: 0.15), location: 0.76),
            .init(color: Color(red: 0.48, green: 0.11, blue: 0.09), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }
}

/// Rückmeldung während der Eingabe.
///
/// Bewusst kein Fehlerdialog: Ein auffälliger Wert kann richtig sein. Die App
/// weist hin und lässt sichern — sie weiß es nicht besser als der Mensch, der
/// vor dem Zähler steht.
public struct VerdictBanner: View {
    public enum Tone { case neutral, confirmed, questionable }

    private let tone: Tone
    private let message: AttributedString

    /// Wächst mit der Schrift — dieselbe Sache wie beim Punkt der
    /// ``StatusBanner``, und beim Suchen nach ihr hier ein zweites Mal
    /// gefunden. Feste 13 Punkt neben einer Zeile, die auf die dreifache Höhe
    /// wachsen kann, sind kein Hinweis mehr, sondern ein Fleck.
    @ScaledMetric(relativeTo: .subheadline) private var markOffset: CGFloat = 2

    public init(tone: Tone, message: AttributedString) {
        self.tone = tone
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if tone != .neutral {
                Image(systemName: tone == .confirmed ? "checkmark" : "exclamationmark")
                    .font(.system(.subheadline, weight: .bold))
                    .padding(.top, markOffset)
                    // Trägt keine eigene Aussage: Der Text sagt bereits, ob
                    // der Wert plausibel ist. Vorgelesen wäre das Zeichen eine
                    // Unterbrechung mitten im Satz.
                    .accessibilityHidden(true)
            }
            Text(message)
                .font(.system(.subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(foreground)
        .padding(13)
        .frame(minHeight: 62, alignment: .top)
        .background(background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return PulseColor.inkTertiary
        case .confirmed: return PulseColor.inkSecondary
        case .questionable: return PulseColor.noticeInk
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: return .clear
        case .confirmed: return PulseColor.surface
        case .questionable: return PulseColor.noticeBackground
        }
    }
}

/// Großflächiger Ziffernblock.
///
/// Eigener Block statt Systemtastatur: Die Ziele sind größer, mit Handschuhen
/// bedienbar, und es gibt keine Zeichen, die hier nichts zu suchen haben.
public struct NumberPad: View {

    public enum Key: Hashable {
        case digit(Int)
        case delete
    }

    private let onKey: (Key) -> Void

    public init(onKey: @escaping (Key) -> Void) {
        self.onKey = onKey
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    /// Höhe und Schriftgröße wachsen mit der eingestellten Schrift.
    ///
    /// Bis 0.36.0 standen hier feste 52 und 26 Punkt. Auf der größten Stufe
    /// blieb der Ziffernblock damit als einziger Teil des Schirms unverändert
    /// klein, während alles darüber wuchs — ausgerechnet der Teil, der
    /// getroffen werden muss. `00-produktstrategie.md` nennt „Dynamic Type bis
    /// zur größten Stufe" nicht verhandelbar.
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .title2) private var keyFontSize: CGFloat = 26

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(1...9, id: \.self) { number in
                key(label: "\(number)") { onKey(.digit(number)) }
            }
            // **Hier saß bis 0.36.0 eine Taste, die nichts tat.** Sie trug ein
            // Kamerasymbol und hieß für VoiceOver „Belegfoto"; angetippt
            // passierte nichts. Gedacht war sie als Platzhalter, damit das
            // Raster später nicht wandert — der Preis dafür wäre gewesen, in
            // 1.0 einen angekündigten Knopf auszuliefern, der ins Leere greift.
            // Für jemanden, der die Tasten nur hört, ist das keine Kleinigkeit,
            // sondern eine Sackgasse (Produktprinzip 4).
            //
            // Belegfotos sind für 1.0 gestrichen (docs/07-v1-plan.md) und
            // kommen mit 1.1. Bis dahin steht hier eine leere Fläche: Die Null
            // bleibt in der Mitte, das Löschen unten rechts, und die Plätze
            // wandern später trotzdem nicht.
            Color.clear
                .frame(minHeight: 52)
                .accessibilityHidden(true)
            key(label: "0") { onKey(.digit(0)) }
            auxKey(symbol: "delete.left", label: "Löschen") { onKey(.delete) }
        }
    }

    private func key(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                // Wächst mit der Schrift, aber gedeckelt: Bei der größten
                // Stufe wären drei ungebremste Ziffern nebeneinander breiter
                // als der Schirm, und ein Ziffernblock, der überläuft, ist
                // schlechter zu treffen als einer, der etwas kleiner bleibt.
                .font(.system(size: keyFontSize, weight: .regular, design: .default))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(PulseColor.ink)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PulseColor.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func auxKey(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(PulseColor.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
