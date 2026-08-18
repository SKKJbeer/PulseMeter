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

    /// - Parameter watermarked: Ob quer über jede Seite ein Schriftzug liegt.
    ///   Die PDF-Datei ist das, was weitergegeben wird — hier zählt es also
    ///   am meisten.
    static func write(_ report: ReportBuilder.Report, to url: URL,
                      watermarked: Bool = false) -> Bool {
        var box = CGRect(x: 0, y: 0, width: ReportPaper.pageWidth, height: ReportPaper.pageHeight)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return false }
        draw(report, in: context, watermarked: watermarked)
        return true
    }

    /// Dasselbe Dokument, nur ohne Umweg über die Platte.
    ///
    /// Das Herunterladen-Menü im Verlauf gibt die Datei direkt weiter, und was
    /// weitergegeben wird, sind Bytes. Eine Datei im Zwischenordner wäre ein
    /// zweiter Ort für dasselbe Dokument — und einer, der liegen bleibt.
    static func data(_ report: ReportBuilder.Report, watermarked: Bool = false) -> Data? {
        let sammler = NSMutableData()
        guard let consumer = CGDataConsumer(data: sammler as CFMutableData) else { return nil }
        var box = CGRect(x: 0, y: 0, width: ReportPaper.pageWidth, height: ReportPaper.pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        draw(report, in: context, watermarked: watermarked)
        return sammler as Data
    }

    private static func draw(_ report: ReportBuilder.Report, in context: CGContext,
                             watermarked: Bool) {
        let pages = ReportPage.pages(for: report)
        for (index, page) in pages.enumerated() {
            let view = ReportPageView(page: page, pageNumber: index + 1,
                                      pageCount: pages.count, watermarked: watermarked)
            let renderer = ImageRenderer(content: view)
            // Die Seite ist bereits genau A4 groß. Damit stimmt der
            // Zeichenbereich mit dem Seitenrahmen überein, und es gibt nichts
            // zu verschieben.
            renderer.proposedSize = ProposedViewSize(width: ReportPaper.pageWidth,
                                                     height: ReportPaper.pageHeight)
            renderer.render { _, zeichne in
                context.beginPDFPage(nil)
                zeichne(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
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
    @Environment(Purchase.self) private var purchase

    @State private var meters: [MeteringPoint] = []
    @State private var showingUnlock = false
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
            // **Gemessen wird außerhalb der Bildlaufansicht.**
            //
            // Der Messfühler saß bis 0.63.0 am Hintergrund der `ScrollView`.
            // Deren Breite hängt aber am Inhalt — und der Inhalt sind die
            // Seiten, deren Breite aus dieser Messung kommt. Ein Kreisschluss
            // mit zwei Ruhelagen: Im Lauf zu `9445365` blieb er bei rund 50
            // Punkten stehen, die Seiten waren unlesbar; im Lauf zu `6d0939d`
            // bei 237 von 440 verfügbaren, also lesbar, aber halb so breit wie
            // möglich. Dieselbe Fassung, zwei Ergebnisse — das ist das Erkennen
            // eines Kreisschlusses, nicht zweier Fehler.
            //
            // Ein `GeometryReader` **um** die Bildlaufansicht bekommt seine
            // Breite vom Blatt und hängt an nichts, was hier drin entschieden
            // wird. Die seitliche Polsterung wird abgezogen, weil die Seiten
            // innerhalb davon stehen.
            GeometryReader { geometry in
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onAppear { contentWidth = geometry.size.width - 36 }
                // `onChange` zieht bei Drehung und geteiltem Bildschirm nach;
                // `onAppear` allein feuert einmal und bleibt danach falsch
                // stehen.
                .onChange(of: geometry.size.width) { _, neu in contentWidth = neu - 36 }
            }
            .background(PulseColor.ground)
            .navigationTitle("Verbrauchsbericht")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingUnlock) {
                UnlockSheet(product: .pdfReport)
            }
            // Nach dem Kauf muss das PDF neu geschrieben werden — die Datei
            // auf der Platte trägt sonst weiter das Wasserzeichen, und der
            // Nutzer teilt genau das, wofür er gerade bezahlt hat.
            .onChange(of: purchase.reportIsWatermarked) { _, _ in
                if report != nil { build() }
            }
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
                if Startschalter.gesetzt("-pulse-bericht") {
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
                                    .accessibilityHidden(true)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PulseColor.tintInk)
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
            // **Der Hinweis steht über der Vorschau, nicht als Sperre davor.**
            // Wer den Bericht nur für sich ansieht, soll ihn ansehen; wer ihn
            // weitergeben will, erfährt hier den Preis, bevor er das PDF
            // teilt und den Schriftzug darauf entdeckt.
            if purchase.reportIsWatermarked {
                Button { showingUnlock = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.badge.ellipsis")
                            .accessibilityHidden(true)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PulseColor.noticeInk)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vorschau mit Wasserzeichen")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PulseColor.noticeInk)
                            Text("Ansehen und drucken kannst du ihn so. Zum Weitergeben ohne Schriftzug freischalten.")
                                .font(PulseText.caption)
                                .foregroundStyle(PulseColor.noticeInk.opacity(0.85))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        PriceBadge(product: .pdfReport)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PulseColor.noticeBackground,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Vorschau mit Wasserzeichen. Ansehen und drucken geht so; zum Weitergeben ohne Schriftzug freischalten für \(purchase.price(for: .pdfReport))")
                .accessibilityAddTraits(.isButton)
            }
            // Hier stand in 0.33.4 eine rote Messzeile, die `breite`,
            // `maßstab` und `rahmen` aufs Bildschirmfoto schrieb. Sie hat ihren
            // Zweck erfüllt und ist wieder draußen: Der Lauf zu `28a52cf` las
            // `breite=400 maßstab=0.673 rahmen=400×566` ab — also genau das,
            // was zu erwarten war. Damit war belegt, dass die Messung stimmt
            // und der Fehler allein im Zuschnitt lag.
            //
            // Die Lehre bleibt und steht in `docs/08-baukasten.md`: Nach dem
            // zweiten Fehlversuch nicht weiterraten, sondern die Ansicht ihre
            // eigenen Zahlen berichten lassen. Vier Vermutungen hatten je einen
            // Lauf gekostet und nichts geklärt; die eine Messung klärte alles.
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                ReportPageView(page: page, pageNumber: index + 1, pageCount: pages.count,
                               watermarked: purchase.reportIsWatermarked)
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
            // Zusammengestellt wird in ``ReportComposer`` — dieselbe Stelle, die
            // auch das Herunterladen-Menü im Verlauf benutzt.
            let built = try ReportComposer(context: context)
                .report(scope: scope, period: period, today: today)
            problem = nil
            report = built

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(ReportPDF.fileName(for: built))
            try? FileManager.default.removeItem(at: url)
            file = ReportPDF.write(built, to: url,
                                   watermarked: purchase.reportIsWatermarked) ? url : nil
            if file == nil {
                problem = "Das PDF ließ sich nicht erzeugen."
            }
        } catch let lage as ReportComposer.Problem {
            // Eine Lage, kein Fehler: Der Satz steht am Fehlertyp und wird hier
            // nicht noch einmal in „ließ sich nicht erstellen" eingewickelt.
            problem = lage.errorDescription
        } catch {
            problem = "Der Bericht ließ sich nicht erstellen: \(error.localizedDescription)"
        }
    }
}
