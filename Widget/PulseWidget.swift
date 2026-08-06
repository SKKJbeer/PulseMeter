import WidgetKit
import SwiftUI
import PulseCore
import PulseUI

/// Der Stand auf Sperr- und Startbildschirm.
///
/// **Warum das der zweite Retention-Hebel ist.** Erinnerungen holen jemanden
/// zurück, der die App vergessen hat. Ein Widget sorgt dafür, dass er sie gar
/// nicht erst vergisst: Es steht da, ohne dass jemand danach greift, und
/// beantwortet die einzige Frage, die zwischen zwei Ablesungen zählt — ist
/// etwas fällig, und liege ich im Rahmen?
///
/// **Warum es nichts rechnet.** Alles Zählbare steht schon in der Datei, die
/// die App nach jeder Änderung schreibt (``WidgetBridge``). Das Widget liest
/// und stellt dar. Ein Widget, das rechnet, ist ein Widget, das manchmal leer
/// bleibt — und ein leeres Widget entfernt der Nutzer.
struct PulseEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
}

struct PulseProvider: TimelineProvider {

    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: Date(), summary: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(PulseEntry(date: Date(), summary: WidgetBridge.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let entry = PulseEntry(date: Date(), summary: WidgetBridge.read())
        // Einmal am Tag genügt: Die Zahlen ändern sich nur, wenn jemand
        // abliest — und dann schreibt die App die Datei und fordert eine
        // Aktualisierung an. Der tägliche Termin fängt nur den Fall ab, dass
        // ein Zähler über Nacht fällig wird.
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

struct PulseWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: - Klein

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Bewusst schlicht: Hier stand ein Helfer mit `@ViewBuilder` an
            // einem `some View`-Parameter. Das ist gültiges Swift, aber die
            // ausgefallenste Konstruktion der Datei — und ich baue dieses Ziel
            // ohne Compiler zur Hand. Ein `if let` kostet drei Zeilen mehr und
            // kann nicht überraschen.
            if let meter = entry.summary?.headline {
                Label(meter.name, systemImage: meter.symbolName)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PulseColor.resource(meter.colorToken))
                Spacer(minLength: 2)
                if let quantity = meter.quantity {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        if meter.isApproximate {
                            Text("≈").font(.system(.footnote)).foregroundStyle(.tertiary)
                        }
                        Text(number(quantity))
                            .font(.system(.title2, weight: .semibold))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(meter.unit).font(.system(.caption2)).foregroundStyle(.secondary)
                    }
                } else {
                    Text("—").font(.system(.title2, weight: .semibold))
                }
                Text(statusLine(for: meter))
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Mittel

    private var medium: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let summary = entry.summary, !summary.meters.isEmpty {
                ForEach(summary.meters.prefix(3)) { meter in
                    HStack(spacing: 8) {
                        Image(systemName: meter.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PulseColor.resource(meter.colorToken))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(meter.name).font(.system(.caption, weight: .medium))
                            Text(statusLine(for: meter))
                                .font(.system(.caption2))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        if let quantity = meter.quantity {
                            Text("\(meter.isApproximate ? "≈ " : "")\(number(quantity)) \(meter.unit)")
                                .font(.system(.caption, weight: .semibold))
                                .lineLimit(1)
                        } else {
                            Text("—").font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Bausteine

    /// Ein Widget ohne Daten sagt, was zu tun ist — statt leer zu bleiben.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PulseMeter").font(.system(.caption, weight: .semibold))
            Text("Öffne die App und trag deinen ersten Stand ein.")
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
    }

    /// Fälligkeit hat Vorrang vor dem Zeitraum.
    ///
    /// Wer im Vorbeigehen liest, liest eine Zeile. Steht dort der Zeitraum,
    /// während ein Zähler seit drei Monaten überfällig ist, hat das Widget die
    /// falsche Zeile gewählt.
    private func statusLine(for meter: WidgetSummary.Meter) -> String {
        if meter.isDue {
            return meter.daysSinceReading.map { "Seit \($0) Tagen fällig" }
                ?? "Noch nie abgelesen"
        }
        return meter.periodCaption
    }

    private func number(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
    }
}

struct PulseWidget: Widget {
    let kind = "PulseMeterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseProvider()) { entry in
            PulseWidgetView(entry: entry)
                .containerBackground(PulseColor.surface, for: .widget)
        }
        .configurationDisplayName("Zählerstände")
        .description("Zeigt, ob eine Ablesung fällig ist und wie viel bisher verbraucht wurde.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PulseWidgetBundle: WidgetBundle {
    var body: some Widget { PulseWidget() }
}
