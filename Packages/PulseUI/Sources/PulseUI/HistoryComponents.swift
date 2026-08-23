import Foundation
import SwiftUI

/// Diagonale Striche — im ganzen Produkt das Zeichen für „nicht gemessen".
///
/// **Warum eine Schraffur und keine dritte Farbe.** Im Verlauf sind beide
/// Farben schon vergeben: Der Ton des Zählers heißt „gemessen", Grau heißt
/// „Vorjahr". Eine blasse Fassung des Zählertons las sich als „dasselbe, nur
/// schwächer", und Grau war schlicht besetzt — auf dem Bildschirmfoto des
/// Gründers stand die graue Hochrechnung neben den grauen Vorjahresbalken und
/// war von ihnen nicht zu unterscheiden.
///
/// Eine Schraffur ist keine Farbe. Sie sagt „hier ist nichts abgelesen worden",
/// und zwar unabhängig davon, welche Farbe darunterliegt. Der Klick-Dummy und
/// die Jahresansicht benutzen sie seit jeher für genau das.
public struct Hatching: Shape {
    private let spacing: CGFloat

    public init(spacing: CGFloat = 4) { self.spacing = spacing }

    public func path(in rect: CGRect) -> Path {
        var pfad = Path()
        // Von links außerhalb beginnen: Sonst bliebe die untere linke Ecke
        // ungestrichelt, weil die Diagonale sie erst hinter dem Rand erreicht.
        var x = rect.minX - rect.height
        while x < rect.maxX {
            pfad.move(to: CGPoint(x: x, y: rect.maxY))
            pfad.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return pfad
    }
}

/// Ein Feld Schraffur für die Legende — dasselbe Muster wie im Balken.
public struct HatchSwatch: View {
    private let color: Color

    public init(color: Color) { self.color = color }

    public var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color.opacity(0.16))
            .overlay {
                Hatching(spacing: 3)
                    .stroke(color.opacity(0.75), lineWidth: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
    }
}

/// Der laufende Abschnitt in voller Breite: was feststeht, was erwartet wird.
///
/// **Warum eine eigene Leiste und keine Zahl am Balken.** Drei Anläufe, die
/// erwartete Menge im Jahresbild unterzubringen, sind an derselben Sache
/// gescheitert: Ein Monatsbalken ist elf Punkte breit, die Zahl dreißig. Sie
/// überschnitt Gitterlinien, ragte aus dem Bild oder brauchte ein Schild, das
/// wie ein Fremdkörper wirkte. Der Gründer hat alle drei abgelehnt und sich für
/// diese Fassung entschieden.
///
/// Über die ganze Breite ist Platz für beides: links, was gemessen ist, rechts,
/// was erwartet wird, und dazwischen sieht man, wie weit der Abschnitt ist —
/// eine Auskunft, die im Jahresbild überhaupt nicht vorkommt.
///
/// Dieselbe Bildsprache wie im Diagramm darüber: voll heißt gemessen,
/// schraffiert heißt nicht gemessen.
public struct ForecastStrip: View {
    private let measured: String
    private let expected: String
    private let share: Double
    private let caption: String
    private let accent: Color
    private let accentInk: Color
    private let spoken: String

    /// - Parameter share: Anteil des Gemessenen an der Erwartung, 0 bis 1.
    /// - Parameter spoken: Was VoiceOver vorliest. Die Leiste besteht aus vier
    ///   Stücken, die einzeln vorgelesen nichts ergeben; als ein Satz ergeben
    ///   sie dieselbe Auskunft wie das Bild.
    public init(measured: String, expected: String, share: Double, caption: String,
                accent: Color, accentInk: Color, spoken: String) {
        self.measured = measured
        self.expected = expected
        self.share = share
        self.caption = caption
        self.accent = accent
        self.accentInk = accentInk
        self.spoken = spoken
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(measured)
                    .foregroundStyle(PulseColor.ink)
                Spacer(minLength: 10)
                Text(expected)
                    .foregroundStyle(accentInk)
            }
            // `PulseText.caption` bringt die gleich breiten Ziffern schon mit.
            .font(PulseText.caption.weight(.semibold))

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: geometry.size.width * min(max(share, 0), 1))
                    Rectangle()
                        .fill(accent.opacity(0.14))
                        .overlay {
                            Hatching()
                                .stroke(accent.opacity(0.6), lineWidth: 1)
                                .clipShape(Rectangle())
                        }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())

            Text(caption)
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        // Für den Oberflächentest. Am Wortlaut zu suchen hat schon einmal
        // gebrochen, als sich der Wortlaut änderte — die Kennung überlebt jede
        // Umformulierung.
        .accessibilityIdentifier("forecast-strip")
    }
}

/// Ein Balken je Abschnitt, mit dem Vorjahr als Marke darin.
///
/// Warum eine Marke und kein zweiter Balken: Zwölf Monate mal zwei Balken
/// ergeben auf einem Telefon Striche von fünf Punkten Breite — man sieht sie,
/// aber man liest sie nicht mehr. Die Marke sitzt auf derselben Achse wie der
/// Balken, und die Frage „mehr oder weniger als voriges Jahr?" beantwortet sich
/// dadurch ohne Vergleich zweier Höhen an verschiedenen Orten.
public struct PeriodBars: View {

    public struct Column: Identifiable, Hashable, Sendable {
        public let id: Int
        public let label: String
        public let value: Double?
        public let reference: Double?
        /// Nicht vollständig durch Ablesungen gedeckt — wird schraffiert
        /// gezeichnet, damit eine Teilmenge nicht wie ein voller Monat aussieht.
        public let isPartial: Bool
        /// Was am Ende des Abschnitts voraussichtlich dasteht — nur beim
        /// laufenden. Gezeichnet als blasse Verlängerung über dem Gemessenen,
        /// nicht als eigener Balken: Es ist derselbe Monat, nur sein Rest.
        public let projection: Double?

        public init(id: Int, label: String, value: Double?, reference: Double?,
                    isPartial: Bool, projection: Double? = nil) {
            self.id = id
            self.label = label
            self.value = value
            self.reference = reference
            self.isPartial = isPartial
            self.projection = projection
        }
    }

    private let columns: [Column]
    private let accent: Color
    private let selection: Int?
    private let unit: String
    private let onSelect: (Int) -> Void

    /// - Parameter unit: Einheit für die Ansage. Ein Balken, der „312" sagt,
    ///   sagt nichts — kWh und m³ stehen in derselben App nebeneinander, und
    ///   ohne Einheit ist die Zahl nicht zu deuten.
    public init(columns: [Column], accent: Color, selection: Int?, unit: String = "",
                onSelect: @escaping (Int) -> Void) {
        self.columns = columns
        self.accent = accent
        self.selection = selection
        self.unit = unit
        self.onSelect = onSelect
    }

    /// Was ein Balken sagt, wenn man ihn nicht sehen kann.
    ///
    /// Mit Einheit, mit dem Vorjahreswert und mit dem Hinweis auf einen
    /// unvollständigen Abschnitt: Genau diese drei Angaben stecken im Bild —
    /// Höhe, Marke und blasse Färbung —, und ohne sie bleibt von der Auskunft
    /// eine nackte Zahl übrig.
    private func spokenValue(for column: Column) -> String {
        guard let value = column.value else { return "keine Ablesung" }
        var text = unit.isEmpty ? "\(Int(value.rounded()))" : "\(Int(value.rounded())) \(unit)"
        if column.isPartial { text += ", unvollständiger Abschnitt" }
        if let projection = column.projection {
            text += unit.isEmpty
                ? ", voraussichtlich \(Int(projection.rounded()))"
                : ", voraussichtlich \(Int(projection.rounded())) \(unit)"
        }
        if let reference = column.reference {
            text += unit.isEmpty ? ", Vorjahr \(Int(reference.rounded()))"
                                 : ", Vorjahr \(Int(reference.rounded())) \(unit)"
        }
        return text
    }

    private var upperBound: Double {
        // Die Hochrechnung gehört in den Maßstab. Ohne sie ragte die
        // Verlängerung des laufenden Monats über den Rand hinaus und wäre
        // abgeschnitten — also gerade dort falsch, wo sie etwas sagen soll.
        let values = columns.flatMap { [$0.value, $0.reference, $0.projection].compactMap { $0 } }
        // Im Diagramm steht keine Zahl mehr — die beiden Zahlen stehen in der
        // Leiste darunter (``ForecastStrip``). Damit braucht der Maßstab keinen
        // Kopfraum mehr; die Schraffur darf bis oben reichen.
        return Swift.max(values.max() ?? 1, 0.0001)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(columns) { column in
                    bar(for: column)
                }
            }
            .frame(height: 140)

            // Eine durchgehende Grundlinie statt einer Spur je Spalte.
            //
            // Vorher stand hinter jedem Abschnitt ein hoher heller Block. Auf
            // dem Bildschirmfoto las sich das Jahr dadurch als zwölf Balken,
            // von denen vier farbig waren — obwohl es nur vier Balken gibt und
            // acht Monate ohne Ablesung. Ein leerer Abschnitt zeigt jetzt
            // nichts, und das ist die richtige Aussage.
            Rectangle()
                .fill(PulseColor.hairlineStrong)
                .frame(height: 1)

            HStack(spacing: 4) {
                ForEach(columns) { column in
                    Text(column.label)
                        .font(.system(size: 10, weight: selection == column.id ? .semibold : .regular))
                        .foregroundStyle(selection == column.id ? PulseColor.ink : PulseColor.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 6)
        }
    }

    private func bar(for column: Column) -> some View {
        let selected = selection == column.id
        return GeometryReader { geometry in
            let height = geometry.size.height
            // **Der Stapel muss die ganze Höhe einnehmen, sonst hängen die
            // Balken oben.**
            //
            // Ein `GeometryReader` setzt seinen Inhalt oben links ab, in dessen
            // *eigener* Größe. Der Stapel ist aber nur so hoch wie sein
            // höchstes Kind — bei einem Balken von 30 Punkten also 30 —, und
            // `alignment: .bottom` richtet dann innerhalb dieser 30 Punkte aus,
            // nicht innerhalb der 140. Ergebnis: Der Balken schwebt am oberen
            // Rand statt auf der Grundlinie zu stehen.
            //
            // Sichtbar wurde es erst im echten Gebrauch, und zwar an einer
            // Merkwürdigkeit: Der **ausgewählte** Abschnitt sah richtig aus.
            // Dessen blasse Fläche hat keine feste Höhe, füllt also die 140
            // Punkte, und damit stand sein Balken plötzlich unten. Ein Bild mit
            // einem richtigen und elf falschen Balken — das war der Hinweis.
            ZStack(alignment: .bottom) {
                // Der ausgewählte Abschnitt bekommt eine blasse Fläche. Ohne
                // Spur wäre ein Tipp auf einen leeren Monat sonst folgenlos
                // sichtbar.
                if selected {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accent.opacity(0.12))
                }

                // **Erst die Erwartung, dann das Gemessene darüber.**
                //
                // Die Verlängerung reicht vom Boden bis zur hochgerechneten
                // Menge und liegt *hinter* dem gemessenen Balken. Zwei Stücke
                // übereinanderzusetzen wäre das Naheliegende und das Falsche:
                // Beim geringsten Rundungsunterschied klaffte eine Fuge, und
                // eine Fuge in einem Balken liest sich als Lücke in den Daten.
                if let projection = column.projection, let value = column.value,
                   projection > value {
                    // **Schraffiert, nicht eingefärbt.**
                    //
                    // Zwei Anläufe davor waren falsch. Blass in der Farbe des
                    // Zählers las sich als „dasselbe, nur schwächer" — gemessen
                    // und hochgerechnet sind aber zweierlei. Grau war schlimmer:
                    // Grau heißt in diesem Bild „Vorjahr", und auf dem
                    // Bildschirmfoto stand die graue Hochrechnung direkt neben
                    // den grauen Vorjahresbalken.
                    //
                    // Die Schraffur ist keine dritte Farbe, sondern eine
                    // Aussage über die Fläche: hier wurde nichts abgelesen. Der
                    // Ton bleibt der des Zählers — es sind ja seine Zahlen.
                    let voll = Swift.max(2, height * projection / upperBound)
                    let ecke = RoundedRectangle(cornerRadius: 3, style: .continuous)
                    ecke
                        .fill(accent.opacity(0.14))
                        .overlay {
                            Hatching()
                                .stroke(accent.opacity(0.6), lineWidth: 1)
                                .clipShape(ecke)
                        }
                        .frame(height: voll)
                }

                if let value = column.value {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accent.opacity(column.isPartial ? 0.4 : 1))
                        .frame(height: Swift.max(2, height * value / upperBound))
                }

                // Vorjahresmarke: liegt auf der Achse des Balkens, nicht
                // daneben. Zwei Höhen an einem Ort vergleichen sich von
                // selbst; zwei Höhen an zwei Orten muss man messen.
                if let reference = column.reference {
                    Rectangle()
                        .fill(PulseColor.inkTertiary)
                        .frame(height: 2)
                        .offset(y: -(height * reference / upperBound) + 1)
                }
            }
            .frame(width: geometry.size.width, height: height, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(column.id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(column.label)
        .accessibilityValue(spokenValue(for: column))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Öffnet den Vergleich mit den Vorjahren")
        // Die Beschriftung taugt nicht zum Ansprechen: „J" tragen Januar, Juni
        // und Juli gemeinsam. Die Kennung ist eindeutig und übersteht jede
        // Umbenennung — dieselbe Lehre wie beim Vorschau-Streifen in 0.69.2.
        .accessibilityIdentifier("periodbar-\(column.id)")
    }
}

/// Derselbe Abschnitt über mehrere Jahre, ein Balken je Jahr.
///
/// Die eigentlich interessante Frage der App: Februar 2026 gegen Februar 2025.
/// Gleiche Grundlinie, gleicher Maßstab, das laufende Jahr hervorgehoben.
public struct YearBars: View {

    public struct Row: Identifiable, Hashable, Sendable {
        public let id: Int
        public let year: String
        public let value: Double?
        public let text: String
        /// Wie viel des Ausschnitts diese Zahl abdeckt — nur gesetzt, wenn es
        /// deutlich weniger ist als beim Rest. Ohne diese Angabe liest sich ein
        /// Jahr mit zwei gemessenen Tagen wie ein sparsames Jahr.
        public let note: String?
        public let isCurrent: Bool

        public init(id: Int, year: String, value: Double?, text: String,
                    note: String? = nil, isCurrent: Bool) {
            self.id = id
            self.year = year
            self.value = value
            self.text = text
            self.note = note
            self.isCurrent = isCurrent
        }
    }

    private let rows: [Row]
    private let accent: Color

    /// Wächst mit der eingestellten Schriftgröße mit.
    @ScaledMetric(relativeTo: .subheadline) private var yearColumnWidth: CGFloat = 38

    public init(rows: [Row], accent: Color) {
        self.rows = rows
        self.accent = accent
    }

    private var upperBound: Double {
        Swift.max(rows.compactMap(\.value).max() ?? 1, 0.0001)
    }

    public var body: some View {
        VStack(spacing: 9) {
            ForEach(rows) { row in
                HStack(spacing: 11) {
                    // **Die Jahreszahl bricht nicht um.**
                    //
                    // 38 Punkte reichen für „2026" — bei kleiner Schrift. Wer
                    // die Schrift größer stellt, bekam „202" und darunter „6".
                    // Die Breite wächst jetzt mit der Schrift mit, und wenn das
                    // nicht genügt, wird die Zahl kleiner statt zweizeilig.
                    Text(row.year)
                        .font(.system(.subheadline, weight: row.isCurrent ? .bold : .regular))
                        .foregroundStyle(row.isCurrent ? PulseColor.ink : PulseColor.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: yearColumnWidth, alignment: .leading)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(PulseColor.surfaceMuted)
                            if let value = row.value {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(row.isCurrent ? accent : PulseColor.hairlineStrong)
                                    .frame(width: Swift.max(3, geometry.size.width * value / upperBound))
                            }
                        }
                    }
                    .frame(height: 22)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(row.text)
                            .font(.system(.subheadline, weight: row.isCurrent ? .semibold : .regular))
                            .foregroundStyle(row.value == nil ? PulseColor.inkTertiary : PulseColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        // Die Deckung, wenn sie deutlich kleiner ist als beim
                        // Rest. Ohne sie liest sich ein Jahr mit zwei gemessenen
                        // Tagen wie ein sparsames Jahr.
                        if let note = row.note {
                            Text(note)
                                .font(.system(.caption2))
                                .foregroundStyle(PulseColor.inkTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(width: 92, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
