import SwiftUI

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

        public init(id: Int, label: String, value: Double?, reference: Double?, isPartial: Bool) {
            self.id = id
            self.label = label
            self.value = value
            self.reference = reference
            self.isPartial = isPartial
        }
    }

    private let columns: [Column]
    private let accent: Color
    private let selection: Int?
    private let onSelect: (Int) -> Void

    public init(columns: [Column], accent: Color, selection: Int?, onSelect: @escaping (Int) -> Void) {
        self.columns = columns
        self.accent = accent
        self.selection = selection
        self.onSelect = onSelect
    }

    private var upperBound: Double {
        let values = columns.flatMap { [$0.value, $0.reference].compactMap { $0 } }
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
            ZStack(alignment: .bottom) {
                // Der ausgewählte Abschnitt bekommt eine blasse Fläche. Ohne
                // Spur wäre ein Tipp auf einen leeren Monat sonst folgenlos
                // sichtbar.
                if selected {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accent.opacity(0.12))
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
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(column.id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(column.label)
        .accessibilityValue(column.value.map { "\(Int($0.rounded()))" } ?? "keine Ablesung")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
        public let isCurrent: Bool

        public init(id: Int, year: String, value: Double?, text: String, isCurrent: Bool) {
            self.id = id
            self.year = year
            self.value = value
            self.text = text
            self.isCurrent = isCurrent
        }
    }

    private let rows: [Row]
    private let accent: Color

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
                    Text(row.year)
                        .font(.system(.subheadline, weight: row.isCurrent ? .bold : .regular))
                        .foregroundStyle(row.isCurrent ? PulseColor.ink : PulseColor.inkSecondary)
                        .frame(width: 38, alignment: .leading)

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

                    Text(row.text)
                        .font(.system(.subheadline, weight: row.isCurrent ? .semibold : .regular))
                        .foregroundStyle(row.value == nil ? PulseColor.inkTertiary : PulseColor.ink)
                        .frame(width: 92, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
