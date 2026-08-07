import SwiftUI

// Die Komponenten kennen keine Fachbegriffe: `ValueCard`, nicht `MeterCard`.
// Was sie zeigen, entscheidet der Aufrufer — dadurch bleiben sie auch für
// Ansichten brauchbar, die es noch nicht gibt (ADR-003).

/// Eine erhobene Fläche mit Innenabstand.
public struct PulseCard<Content: View>: View {
    private let content: Content
    private let accent: Color?

    public init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        content
            .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent?.opacity(0.45) ?? .clear, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

/// Ein Satz in ganzen Worten, der die Frage „Ist alles im Rahmen?" beantwortet.
///
/// Bewusst kein Kennzahlenblock: Der Startbildschirm soll in fünf Sekunden
/// Blickzeit lesbar sein, und ein Satz liest sich schneller als eine Tabelle
/// (docs/03-ux-konzept.md, Abschnitt 2).
public struct StatusBanner: View {
    public enum Tone { case calm, notice }

    private let tone: Tone
    private let message: AttributedString

    /// Punktgröße und Abstand wachsen mit der Schrift.
    ///
    /// Vorher standen dort feste 9 und 6 Punkt. Auf dem Bild bei der größten
    /// Schriftgröße blieb der Punkt winzig und schwebte oben neben einem
    /// Absatz, dessen erste Zeile dreimal so hoch war — er gehört an diese
    /// Zeile, nicht an den oberen Rand. Aufgefallen ist das erst, als es die
    /// Bilder bei größter Schrift gab; vier Fassungen lang stand die Zusage
    /// „Dynamic Type bis zur größten Stufe" ungeprüft im Dokument.
    @ScaledMetric(relativeTo: .subheadline) private var dotSize: CGFloat = 9
    @ScaledMetric(relativeTo: .subheadline) private var dotOffset: CGFloat = 6

    public init(tone: Tone, message: AttributedString) {
        self.tone = tone
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(tone == .calm ? PulseColor.favourable : PulseColor.noticeInk)
                .frame(width: dotSize, height: dotSize)
                .padding(.top, dotOffset)
                // Der Punkt trägt keine Aussage — er wiederholt farblich, was
                // der Text sagt. Vorgelesen wäre er eine Unterbrechung.
                .accessibilityHidden(true)
            Text(message)
                .font(.system(.subheadline))
                .foregroundStyle(tone == .calm ? PulseColor.ink : PulseColor.noticeInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            tone == .calm ? PulseColor.surface : PulseColor.noticeBackground,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }
}

/// Ein Wert mit Einheit, Erläuterung und optionaler Verlaufslinie.
public struct ValueCard<Footer: View>: View {

    private let title: String
    private let symbolName: String
    private let accent: Color
    private let caption: String
    private let value: String
    private let isApproximate: Bool
    private let unit: String
    private let detail: Text
    private let badge: String?
    private let series: [Double]
    private let footer: Footer

    /// - Parameter caption: Der Zeitraum, den der Wert abdeckt. Kein
    ///   Standardwert und nicht optional: Eine große Zahl ohne Zeitraum ist
    ///   nicht knapp, sondern unvollständig — genau daran ist die Übersicht
    ///   schon einmal gescheitert. Wer nichts zu sagen hat, muss das hier
    ///   ausdrücklich tun.
    /// - Parameter isApproximate: Setzt ein „≈" vor den Wert (Produktprinzip
    ///   7). Die Komponente zeichnet es kleiner und blasser als die Zahl,
    ///   statt es in die Zeichenkette zu schreiben: Bei einem länger geführten
    ///   Zähler ist es fast immer da, und was fast immer da ist, darf der Zahl
    ///   nicht die Aufmerksamkeit nehmen.
    public init(
        title: String,
        symbolName: String,
        accent: Color,
        caption: String,
        value: String,
        isApproximate: Bool = false,
        unit: String,
        detail: Text,
        badge: String? = nil,
        series: [Double] = [],
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.symbolName = symbolName
        self.accent = accent
        self.caption = caption
        self.value = value
        self.isApproximate = isApproximate
        self.unit = unit
        self.detail = detail
        self.badge = badge
        self.series = series
        self.footer = footer()
    }

    public var body: some View {
        PulseCard(accent: badge == nil ? nil : accent) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 27, height: 27)
                        .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(title)
                        .font(PulseText.cardTitle)
                        .foregroundStyle(PulseColor.ink)
                    Spacer(minLength: 8)
                    if let badge {
                        Text(badge)
                            .font(.system(.caption2, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.16), in: Capsule())
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 14)

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Über der Zahl, nicht darunter: Der Zeitraum ist die
                        // Frage, die Zahl die Antwort. In dieser Reihenfolge
                        // gelesen kann die Zahl nicht mehr versprechen, als
                        // sie deckt.
                        if !caption.isEmpty {
                            Text(caption)
                                .font(PulseText.caption)
                                .foregroundStyle(PulseColor.inkTertiary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            if isApproximate {
                                Text(verbatim: "≈")
                                    .font(PulseText.unit)
                                    .foregroundStyle(PulseColor.inkTertiary)
                                    .accessibilityLabel("ungefähr")
                                    .padding(.trailing, -2)
                            }
                            Text(value)
                                .font(PulseText.value)
                                .foregroundStyle(PulseColor.ink)
                            Text(unit)
                                .font(PulseText.unit)
                                .foregroundStyle(PulseColor.inkSecondary)
                        }
                        detail
                            .font(PulseText.detail)
                            .foregroundStyle(PulseColor.inkSecondary)
                    }
                    // Zeitraum, Zahl, Einheit und Erläuterung sind ein Satz,
                    // kein Stapel. Einzeln vorgelesen kämen vier Fetzen —
                    // „1. Januar bis 1. Mai", „ungefähr", „1.181", „m³" —,
                    // und der Zusammenhang, auf den es hier ankommt, ginge
                    // genau dabei verloren.
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 0)
                    if series.count > 1 {
                        Sparkline(values: series, accent: accent)
                            .frame(width: 78, height: 34)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)
                .padding(.bottom, 15)

                footer
            }
        }
    }
}

/// Verlauf der letzten Zeiträume als kleine Linie.
///
/// Ohne Achsen und ohne Zahlen — sie beantwortet nur „steigt oder fällt es?".
/// Wer den Wert braucht, tippt die Karte an.
public struct Sparkline: View {
    private let values: [Double]
    private let accent: Color

    public init(values: [Double], accent: Color) {
        self.values = values
        self.accent = accent
    }

    public var body: some View {
        GeometryReader { geo in
            let points = positions(in: geo.size)
            if points.count > 1 {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        path.addLines(points)
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(accent.opacity(0.11))

                    Path { path in path.addLines(points) }
                        .stroke(accent, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

                    Circle()
                        .fill(accent)
                        .frame(width: 5.2, height: 5.2)
                        .position(points[points.count - 1])
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let padding: CGFloat = 3
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 1
        let span = highest - lowest
        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(values.count - 1) * (size.width - 2 * padding) + padding
            // Bei einer waagerechten Reihe würde die Division scheitern; dann
            // liegt die Linie mittig statt am Rand.
            let ratio = span == 0 ? 0.5 : (value - lowest) / span
            let y = size.height - padding - CGFloat(ratio) * (size.height - 2 * padding)
            return CGPoint(x: x, y: y)
        }
    }
}

/// Eine Zeile unter dem Wert, durch eine Haarlinie abgetrennt.
public struct CardFooterRow<Trailing: View>: View {
    private let label: String
    private let trailing: Trailing

    public init(_ label: String, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(PulseColor.hairline)
            HStack {
                Text(label)
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                Spacer(minLength: 10)
                trailing
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            // „Kosten bis 1. Mai" und „1.399,41 €" gehören zusammen. Getrennt
            // gelesen stünde der Betrag ohne seinen Zeitraum da — und das ist
            // die wiederkehrende Fehlerklasse dieses Projekts, nur mit den
            // Ohren statt mit den Augen.
            .accessibilityElement(children: .combine)
        }
    }
}
