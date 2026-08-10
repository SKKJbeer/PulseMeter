import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Schreibt einen Bericht als PDF.
///
/// Jede Seite wird für sich gerendert und als eigene PDF-Seite geschrieben.
/// Die Begründung steht bei ``ReportPaper``: Der naheliegende Weg verschiebt
/// den Zeichenkontext seitenweise, und ein Vorzeichenfehler in dieser
/// Verschiebung fällt erst dem Nutzer auf.
@MainActor
enum ReportPDF {

    static func write(_ report: ReportBuilder.Report, to url: URL) -> Bool {
        let pages = ReportPage.pages(for: report)
        var box = CGRect(x: 0, y: 0, width: ReportPaper.pageWidth, height: ReportPaper.pageHeight)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return false }

        for (index, page) in pages.enumerated() {
            let view = ReportPageView(page: page, pageNumber: index + 1, pageCount: pages.count)
            let renderer = ImageRenderer(content: view)
            // Die Seite ist bereits genau A4 groß. Damit stimmt der
            // Zeichenbereich mit dem Seitenrahmen überein, und es gibt nichts
            // zu verschieben.
            renderer.proposedSize = ProposedViewSize(width: ReportPaper.pageWidth,
                                                     height: ReportPaper.pageHeight)
            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return true
    }

    /// Dateiname ohne Zeichen, die einem Dateisystem oder einem Mailprogramm
    /// im Weg stehen.
    static func fileName(for report: ReportBuilder.Report) -> String {
        let scope = report.sections.count == 1 ? report.sections[0].name : "Alle-Zähler"
        let cleaned = scope
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let day = report.period.lastIncludedDay
        return String(format: "PulseMeter-Bericht-%@-%04d-%02d-%02d.pdf",
                      cleaned, day.year, day.month, day.day)
    }
}

/// Der Weg zum Bericht: Umfang wählen, Zeitraum wählen, ansehen, teilen.
///
/// **Warum die Wahl vor dem Dokument steht.** Ein Bericht ohne Zeitraum ist
/// keiner — und der Zeitraum, der zählt, ist selten das Kalenderjahr. Wer die
/// Rechnung seines Versorgers prüfen will, braucht dessen Abrechnungsjahr, und
/// das beginnt bei Strom oft im April und bei Gas im Oktober.
struct ReportView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var meters: [MeteringPoint] = []
    @State private var scope: MeteringPoint.ID?
    @State private var periodID: String?
    @State private var report: ReportBuilder.Report?
    @State private var file: URL?
    @State private var problem: String?
    /// Breite, die für die Vorschau zur Verfügung steht. Gemessen statt
    /// geraten: Eine feste Verkleinerung säße auf einem kleinen Gerät zu
    /// breit und auf einem großen zu schmal.
    @State private var contentWidth: CGFloat = 0

    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }

    /// Der Abrechnungsrhythmus gilt nur für einen **einzelnen** Zähler. Für
    /// einen gemeinsamen Bericht gibt es keinen gemeinsamen Rhythmus.
    private var periods: [ReportBuilder.Period] {
        let cycle = scope.flatMap { id in meters.first { $0.id == id }?.billingCycle }
        return ReportBuilder.periods(today: today, billingCycle: cycle)
    }

    private var period: ReportBuilder.Period? {
        periods.first { $0.id == periodID } ?? periods.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    }
                    if let report {
                        preview(report)
                    } else {
                        chooser
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            // **Der Messfühler darf nicht messen, was er selbst bestimmt.**
            // Vorher hing der `GeometryReader` am Hintergrund genau des
            // Stapels, dessen Breite von den Seiten kommt — und deren Breite
            // kommt aus dieser Messung. Ein Kreisschluss: Die Vorschau blieb
            // bei einer viel zu kleinen Breite stehen, und die sechs Seiten
            // standen als schmale, praktisch leere Rahmen in der Mitte des
            // Schirms. Der Inhalt war die ganze Zeit da — die
            // Oberflächenprüfungen finden „Arbeitspreis Hochtarif“ im Baum —,
            // nur unlesbar klein gezeichnet.
            //
            // Gemessen wird jetzt die **Bildlaufansicht**. Ihre Breite kommt
            // von außen und hängt an nichts, was von `contentWidth` abhängt.
            // Die seitliche Polsterung wird abgezogen, weil die Seiten
            // innerhalb davon stehen. `onChange` zieht bei Drehung oder
            // geteiltem Bildschirm nach; `onAppear` allein feuert einmal und
            // bleibt danach falsch stehen.
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { contentWidth = geometry.size.width - 36 }
                        .onChange(of: geometry.size.width) { _, neu in
                            contentWidth = neu - 36
                        }
                }
            }
            .background(PulseColor.ground)
            .navigationTitle("Verbrauchsbericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if report == nil {
                        Button("Abbrechen") { dismiss() }
                    } else {
                        Button("Zurück") { report = nil; file = nil }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let file {
                        ShareLink(item: file) { Text("Teilen") }
                    }
                }
            }
            .onAppear {
                load()
                // Siehe oben: Für die Bildschirmfotos wird der Bericht gleich
                // gebaut, sonst zeigt das Bild nur die Auswahl.
                if ProcessInfo.processInfo.arguments.contains("-pulse-bericht") {
                    build()
                }
            }
        }
    }

    // MARK: - Wahl

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Umfang") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        chip("Alle Zähler", selected: scope == nil) { scope = nil }
                        ForEach(meters) { meter in
                            chip(meter.name, selected: scope == meter.id) { scope = meter.id }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            section("Zeitraum") {
                VStack(spacing: 0) {
                    ForEach(periods) { option in
                        Button {
                            periodID = option.id
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(.system(.subheadline, weight: .medium))
                                        .foregroundStyle(PulseColor.ink)
                                    Text(rangeText(option))
                                        .font(PulseText.detail)
                                        .foregroundStyle(PulseColor.inkTertiary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "checkmark")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PulseColor.tint)
                                    .opacity(option.id == period?.id ? 1 : 0)
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(option.id == period?.id ? [.isSelected] : [])
                        if option.id != periods.last?.id {
                            Divider().overlay(PulseColor.hairline)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PulseColor.hairlineStrong, lineWidth: 1)
                )
            }

            if scope == nil {
                Text("""
                     Der Abrechnungszeitraum des Versorgers beginnt bei Strom oft im April und bei Gas \
                     im Oktober. Für einen gemeinsamen Bericht gibt es deshalb keinen. Wähle einen \
                     einzelnen Zähler, um nach seinem Abrechnungsjahr zu berichten.
                     """)
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkTertiary)
            }

            Button(action: build) {
                Text("Bericht erstellen")
                    .font(.system(.headline))
                    .foregroundStyle(PulseColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(PulseColor.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(meters.isEmpty)
        }
    }

    // MARK: - Vorschau

    private func preview(_ report: ReportBuilder.Report) -> some View {
        let pages = ReportPage.pages(for: report)
        // Auf Bildschirmbreite verkleinert, aber inhaltlich unverändert: Was
        // hier steht, steht auch im PDF. Eine Vorschau, die anders aussieht
        // als das Ergebnis, ist keine.
        let scale = contentWidth > 0 ? contentWidth / ReportPaper.pageWidth : 0.55
        return VStack(spacing: 14) {
            // **Die Zahlen aufs Bild, statt eine fünfte Vermutung.**
            //
            // Vier Erklärungen für die leeren Seiten sind widerlegt: die
            // Wartezeit, der fehlende Inhalt, der Kreisschluss bei der Messung
            // und die Ausrichtung unter `scaleEffect`. Nach der dritten
            // gescheiterten Diagnose kostet jede weitere Vermutung eine
            // Viertelstunde Läuferzeit und bringt nichts.
            //
            // Diese Zeile erscheint ausschließlich beim Bildschirmfoto-Start
            // (`-pulse-bericht`) — kein Nutzer sieht sie je. Das nächste Bild
            // sagt dann selbst, welche Zahl falsch ist, statt dass jemand sie
            // errät.
            if ProcessInfo.processInfo.arguments.contains("-pulse-bericht") {
                Text(verbatim: "Messung: breite=\(Int(contentWidth)) "
                     + "maßstab=\(String(format: "%.3f", scale)) "
                     + "rahmen=\(Int(ReportPaper.pageWidth * scale))×"
                     + "\(Int(ReportPaper.pageHeight * scale)) "
                     + "seiten=\(pages.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                ReportPageView(page: page, pageNumber: index + 1, pageCount: pages.count)
                    .scaleEffect(scale, anchor: .topLeading)
                    // **`alignment: .topLeading` ist hier nicht Geschmack,
                    // sondern der Unterschied zwischen sichtbar und leer.**
                    //
                    // `scaleEffect` ändert die Layoutgröße **nicht**: Die Seite
                    // bleibt 595 × 842 groß und wird nur kleiner gezeichnet.
                    // Ein Rahmen ohne Ausrichtung zentriert diese unveränderte
                    // Box im kleinen Rahmen — gezeichnet wird aber ab oben
                    // links. Der gemalte Inhalt sitzt dadurch weit oberhalb und
                    // links des Zuschnitts und wird vollständig weggeschnitten.
                    // Übrig bleibt genau das, was auf dem Bild zu sehen war:
                    // ein leerer Seitenrahmen mit Haarlinie.
                    //
                    // Je kleiner der Maßstab, desto vollständiger der Verlust —
                    // deshalb fielen beide Fehler zusammen auf und deshalb sah
                    // es aus, als rendere der Bericht gar nichts.
                    .frame(width: ReportPaper.pageWidth * scale,
                           height: ReportPaper.pageHeight * scale,
                           alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PulseColor.hairlineStrong, lineWidth: 1)
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Seite \(index + 1) von \(pages.count)")
            }
        }
    }

    // MARK: - Bausteine

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)
            content()
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(selected ? PulseColor.tint : PulseColor.inkSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(selected ? PulseColor.tint.opacity(0.13) : PulseColor.surface, in: Capsule())
                .overlay(
                    Capsule().stroke(selected ? PulseColor.tint.opacity(0.4) : PulseColor.hairlineStrong,
                                     lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func rangeText(_ period: ReportBuilder.Period) -> String {
        "\(germanDate(period.range.start)) bis \(germanDate(period.lastIncludedDay))"
    }

    private func germanDate(_ day: CalendarDay) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: components) else { return day.description }
        return date.formatted(.dateTime.day().month(.abbreviated).year()
            .locale(Locale(identifier: "de_DE")))
    }

    // MARK: - Daten

    private func load() {
        do {
            meters = try PulseRepository(context: context).meteringPoints()
        } catch {
            problem = "Die Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    private func build() {
        guard let period else { return }
        do {
            let repository = PulseRepository(context: context)
            let chosen = scope.map { id in meters.filter { $0.id == id } } ?? meters
            var readings: [MeteringPoint.ID: [Reading]] = [:]
            var tariffs: [MeteringPoint.ID: [Tariff]] = [:]
            var prepayments: [MeteringPoint.ID: Decimal] = [:]
            for meter in chosen {
                readings[meter.id] = try repository.readings(for: meter)
                tariffs[meter.id] = try repository.tariffs(for: meter.id)
                // Der Abschlag des Zeitraums, in dem der Bericht liegt — nicht
                // irgendeiner. Ein Abschlag aus einem anderen Jahr gegen die
                // Kosten dieses Jahres zu rechnen wäre wieder der Vergleich
                // zweier verschiedener Zeitausschnitte.
                let periods = try repository.billingPeriods(for: meter.id)
                if let match = periods.first(where: { $0.range.contains(period.range.start) })
                    ?? periods.last,
                   let amount = match.monthlyPrepayment {
                    prepayments[meter.id] = amount
                }
            }

            let built = ReportBuilder.build(
                meteringPoints: chosen, readings: readings, tariffs: tariffs,
                prepayments: prepayments, period: period,
                propertyName: (try? repository.ensureDefaultProperty().name) ?? "Zuhause",
                today: today)

            guard !built.isEmpty else {
                problem = "Für \(period.label.lowercased()) liegen keine Ablesungen vor."
                return
            }
            problem = nil
            report = built

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(ReportPDF.fileName(for: built))
            try? FileManager.default.removeItem(at: url)
            file = ReportPDF.write(built, to: url) ? url : nil
            if file == nil {
                problem = "Das PDF ließ sich nicht erzeugen."
            }
        } catch {
            problem = "Der Bericht ließ sich nicht erstellen: \(error.localizedDescription)"
        }
    }
}
