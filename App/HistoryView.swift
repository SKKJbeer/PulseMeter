import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI
import UniformTypeIdentifiers

/// Der Verlauf: ein Zähler, ein Zeitraum.
///
/// Bewusst kein Übersichtsschirm mit allen Zählern gleichzeitig — kWh und m³
/// lassen sich nicht addieren, und ein Diagramm, das es doch tut, ist eine
/// Lüge. Wer vergleichen will, wählt einen Zähler (docs/03-ux-konzept.md).
struct HistoryView: View {

    /// Ein Zähler, den die Übersicht hier sehen möchte.
    ///
    /// Wird beim Übernehmen auf `nil` gesetzt — der Wunsch gilt einmal. Sonst
    /// überschriebe er jede spätere eigene Wahl des Nutzers, sobald er den Tab
    /// wechselt.
    @Binding var zeige: MeteringPoint.ID?

    init(zeige: Binding<MeteringPoint.ID?> = .constant(nil)) {
        _zeige = zeige
    }

    @Environment(\.modelContext) private var context
    @Environment(Purchase.self) private var purchase
    @Environment(Datenstand.self) private var datenstand

    @State private var meters: [MeteringPoint] = []
    @State private var showingPaywall = false
    @State private var selectedMeterID: MeteringPoint.ID?
    @State private var granularity: PeriodEngine.Granularity = .month
    @State private var buckets: [PeriodEngine.Bucket] = []
    @State private var previousYear: [PeriodEngine.Bucket] = []
    @State private var selectedSlot: Int?
    @State private var comparison: PeriodEngine.SlotComparison?
    @State private var readings: [Reading] = []
    @State private var showingReadings = false
    @State private var showingReport = false
    @State private var mode: Mode = .chart
    @State private var metric: Metric = .quantity
    @State private var tariffs: [Tariff] = []
    /// Kosten je Abschnitt, nach ``PeriodEngine/Bucket/id``.
    @State private var costs: [String: Money] = [:]
    @State private var problem: String?
    /// Der Bericht für den voreingestellten Zeitraum — gerechnet, nicht
    /// gezeichnet. Siehe ``recomputeReport``.
    @State private var bericht: ReportBuilder.Report?
    /// Was im laufenden Abschnitt voraussichtlich zusammenkommt. `nil`, sobald
    /// der Abschnitt abgeschlossen ist oder nichts vorliegt, worauf sich eine
    /// Hochrechnung stützen ließe.
    @State private var vorschau: ForecastEngine.Forecast?

    /// Menge oder Geld.
    ///
    /// Nur in der Tabelle, nicht im Diagramm: Ein Balken, der mal kWh und mal
    /// Euro bedeutet, sieht in beiden Fällen gleich aus — die Verwechslung
    /// wäre eingebaut. In einer Tabelle steht die Einheit in der Kopfzeile.
    enum Metric: Hashable { case quantity, cost }

    /// Diagramm oder alle Zahlen.
    ///
    /// Die Tabelle ist ein Ziel, keine Eingangstür: Wer Verbrauch ernsthaft
    /// verfolgt, will irgendwann alle Zahlen nebeneinander — nur eben nicht
    /// beim Öffnen der App (docs/03-ux-konzept.md).
    enum Mode: Hashable { case chart, table }

    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }
    private var meter: MeteringPoint? { meters.first { $0.id == selectedMeterID } }
    private var register: Register? { meter?.primaryRegister }
    private var accent: Color { PulseColor.resource(meter?.appearance.colorToken ?? "amber") }
    /// Dieselbe Farbe für Text. Eine Fläche darf leuchten, eine Zahl in
    /// Fußnotengröße muss lesbar bleiben.
    private var accentInk: Color { PulseColor.resourceInk(meter?.appearance.colorToken ?? "amber") }
    private var unit: String { register?.unit.symbol ?? "" }

    /// Namen der Zählwerke — nur bei einem Zähler, der mehr als eine Zahl
    /// führt. Sonst bleibt die Liste, wie sie war.
    private var registerLabels: [Register.ID: String] {
        guard let meter, meter.registers.count > 1 else { return [:] }
        return Dictionary(uniqueKeysWithValues: meter.registers.compactMap { register in
            register.label.map { (register.id, $0) }
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    } else if meters.isEmpty {
                        emptyState
                    } else {
                        meterPicker
                        granularityPicker
                        modePicker
                        if buckets.isEmpty {
                            noHistoryYet
                        } else if mode == .chart {
                            chartCard
                            if let comparison {
                                comparisonCard(comparison)
                            }
                        } else {
                            if !tariffs.isEmpty { metricPicker }
                            tableCard
                        }
                        if !buckets.isEmpty { exportRow }
                        reportRow
                        readingsRow
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Verlauf")
            .onAppear {
                load()
                uebernimmWunsch()
                // Nur für die Bildschirmfotos: `simctl` kann nicht tippen, und
                // ein Dokument, das niemand ansieht, ist ein Dokument, in dem
                // sich ein Fehler beliebig lange hält.
                if Startschalter.gesetzt("-pulse-bericht") {
                    showingReport = true
                }
            }
            // Beim ersten Mal ist der Verlauf noch gar nicht gebaut, dann
            // greift `onAppear`. Beim zweiten Mal steht er schon und bekommt
            // nur den neuen Wunsch — deshalb beide Wege.
            .onChange(of: zeige) { _, _ in uebernimmWunsch() }
            // Auch wenn die Änderung woanders passiert ist: Ein Stand, der auf
            // der Übersicht eingetragen wurde, gehört in dieselbe Reihe wie
            // einer aus der Ablesungsliste hier.
            .onChange(of: datenstand.version) { _, _ in load() }
            .sheet(isPresented: $showingReport) {
                ReportView()
            }
            .sheet(isPresented: $showingReadings) {
                ReadingsList(readings: readings, unit: unit,
                             fractionDigits: register?.fractionDigits ?? 1,
                             labels: registerLabels,
                             meteringPoint: meter,
                             onChanged: {
                                 // Neu laden statt nur neu rechnen: Die Liste
                                 // hat gerade den Bestand geändert, und
                                 // `readings` hängt an ihm. Über den Datenstand
                                 // und nicht mit `load()`, damit die Übersicht
                                 // und die Zählerliste dieselbe Meldung
                                 // bekommen.
                                 datenstand.geaendert()
                             })
            }
            .sheet(isPresented: $showingPaywall) {
                UnlockSheet(product: .pdfReport)
            }
        }
    }

    // MARK: - Bausteine

    private var emptyState: some View {
        PulseCard {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .accessibilityHidden(true)
                    .font(.system(size: 30))
                    .foregroundStyle(PulseColor.inkTertiary)
                Text("Noch nichts zu zeigen")
                    .font(PulseText.cardTitle)
                    .foregroundStyle(PulseColor.ink)
                Text("Sobald ein Zähler zweimal abgelesen wurde, entsteht hier ein Verlauf.")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
        }
    }

    /// Ein Zähler mit weniger als zwei Ablesungen hat keinen Verlauf.
    ///
    /// Vorher stand hier ein Diagramm ohne Balken und darüber „0 m³" — eine
    /// Zahl, die aussieht wie eine Messung und keine ist. Der Fall trat bis
    /// 0.16 nie auf, weil jeder Zähler mit zwei Jahren Historie angelegt
    /// wurde; für einen neuen Nutzer ist er der Normalfall.
    private var noHistoryYet: some View {
        PulseCard {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .accessibilityHidden(true)
                    .font(.system(size: 28))
                    .foregroundStyle(PulseColor.inkTertiary)
                Text(readings.isEmpty ? "Noch keine Ablesung" : "Erst eine Ablesung")
                    .font(PulseText.cardTitle)
                    .foregroundStyle(PulseColor.ink)
                Text(readings.isEmpty
                     ? "Trag den ersten Stand ein — auf der Übersicht."
                     : "Ein Verbrauch ergibt sich aus zwei Ablesungen. Sobald die zweite da ist, steht hier der Verlauf.")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
        }
    }

    private var meterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(meters) { point in
                    let chosen = point.id == selectedMeterID
                    let tint = PulseColor.resource(point.appearance.colorToken)
                    Button {
                        selectedMeterID = point.id
                        selectedSlot = nil
                        recompute()
                    } label: {
                        Text(point.name)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(chosen ? tint : PulseColor.inkSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(chosen ? tint.opacity(0.13) : PulseColor.surface, in: Capsule())
                            .overlay(
                                Capsule().stroke(chosen ? tint.opacity(0.4) : PulseColor.hairlineStrong,
                                                 lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    // Ohne diese Angabe liest VoiceOver alle Zähler gleich vor,
                    // und der gewählte ist nicht zu erkennen — die Farbe allein
                    // sagt niemandem etwas, der sie nicht sieht.
                    .accessibilityAddTraits(chosen ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityLabel("Zähler auswählen")
    }

    private var granularityPicker: some View {
        Picker("Zeitraum", selection: $granularity) {
            Text("Monat").tag(PeriodEngine.Granularity.month)
            Text("Quartal").tag(PeriodEngine.Granularity.quarter)
            Text("Jahr").tag(PeriodEngine.Granularity.year)
        }
        .pickerStyle(.segmented)
        .onChange(of: granularity) { _, _ in
            selectedSlot = nil
            recompute()
        }
    }

    private var modePicker: some View {
        Picker("Darstellung", selection: $mode) {
            Text("Diagramm").tag(Mode.chart)
            Text("Alle Zahlen").tag(Mode.table)
        }
        .pickerStyle(.segmented)
    }

    private var metricPicker: some View {
        Picker("Einheit", selection: $metric) {
            Text("Menge").tag(Metric.quantity)
            Text("Kosten").tag(Metric.cost)
        }
        .pickerStyle(.segmented)
    }

    private var tableCard: some View {
        PulseCard {
            VStack(spacing: 0) {
                HStack {
                    Text("Zeitraum")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(metric == .cost ? "Kosten" : "Verbrauch")
                        .frame(width: 108, alignment: .trailing)
                }
                .font(PulseText.sectionLabel)
                .foregroundStyle(PulseColor.inkTertiary)
                .textCase(.uppercase)
                // Eine Kopfzeile ist ein Satz über die Spalten, keine zwei
                // Wörter hintereinander.
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 15)
                .padding(.top, 14)
                .padding(.bottom, 8)

                ForEach(buckets) { bucket in
                    Divider().overlay(PulseColor.hairline)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slotName(bucket))
                                .font(PulseText.detail)
                                .foregroundStyle(PulseColor.ink)
                            // Unvollständige Abschnitte werden benannt, nicht
                            // ausgelassen: Eine Zahl für einen halben Monat
                            // neben elf ganzen ist sonst nicht zu erkennen.
                            if bucket.hasData, !bucket.isComplete,
                               let covered = bucket.result.coveredRange {
                                Text("nur \(germanDate(covered.start)) bis \(germanDate(covered.end))")
                                    .font(PulseText.caption)
                                    .foregroundStyle(PulseColor.noticeInk)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(cellText(for: bucket))
                            .font(PulseText.detail)
                            .foregroundStyle(bucket.hasData ? PulseColor.ink : PulseColor.inkTertiary)
                            .frame(width: 108, alignment: .trailing)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    // Als ein Satz: „Januar, nur 1. bis 15. Januar, 312 kWh".
                    // Getrennt vorgelesen steht der Hinweis auf den halben
                    // Monat neben der Zahl, ohne erkennbar dazuzugehören —
                    // und genau er ist der Grund, warum die Zahl kleiner ist.
                    .accessibilityElement(children: .combine)
                }

                Divider().overlay(PulseColor.ink)
                HStack {
                    Text(totalCaption)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PulseColor.ink)
                    Spacer(minLength: 8)
                    Text(totalText)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PulseColor.ink)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Produktprinzip 5 — Datenfreiheit. Der Export bleibt kostenlos, auch
    /// wenn später eine Bezahlschranke kommt.
    ///
    /// **Ein Knopf mit Auswahl statt zwei Kacheln.** Bis 0.61.0 standen hier
    /// „Ablesungen" und „Auswertung" nebeneinander — zwei gleich aussehende
    /// Felder ohne einen Satz dazu, und beim Antippen kam unerwartet ein
    /// Teilen-Blatt. Der Gründer beim ersten Gebrauch: „verstehe nicht, was
    /// dahinter ist". Produktprinzip 4 verlangt, dass sich jede Fläche
    /// erklärt; diese zwei taten es nicht.
    ///
    /// Jetzt sagt das Symbol, dass etwas herauskommt, und die Auswahl sagt
    /// **was** — mit Dateiart und einem Halbsatz, was drinsteht.
    private var exportRow: some View {
        Menu {
            ShareLink(item: ablesungenAusgabe,
                      preview: SharePreview(ablesungenAusgabe.dateiname)) {
                Label("Ablesungen als CSV", systemImage: "list.number")
            }
            ShareLink(item: auswertungAusgabe,
                      preview: SharePreview(auswertungAusgabe.dateiname)) {
                Label("Auswertung als CSV", systemImage: "tablecells")
            }
            Divider()
            // **Der Bericht ist hier eine Datei, kein Schirm.**
            //
            // Bis 0.62.2 öffnete dieser Eintrag den Berichtsschirm mit Auswahl
            // und Vorschau. Der Gründer beim ersten Gebrauch: „gar kein Weg zur
            // Datei". Er hatte recht — in einem Menü, in dem zwei Einträge eine
            // Datei liefern, ist der dritte, der einen Schirm aufmacht, ein
            // Bruch im Versprechen.
            //
            // Genommen wird der Zeitraum, den der Berichtsschirm auch
            // voreinstellt: der erste zum Abrechnungsrhythmus dieses Zählers.
            // Wer einen anderen braucht, geht über die Zeile „Verbrauchsbericht"
            // darunter — dort steht die Wahl, und der Weg dorthin bleibt.
            if let ausgabe = berichtAusgabe {
                ShareLink(item: ausgabe, preview: SharePreview(ausgabe.dateiname)) {
                    Label(berichtTitel, systemImage: "doc.richtext")
                }
            } else {
                Button { showingReport = true } label: {
                    Label(berichtTitel, systemImage: "doc.richtext")
                }
            }
        } label: {
            exportLabel("Herunterladen", symbol: "square.and.arrow.down")
        }
        .accessibilityLabel("Herunterladen")
        .accessibilityHint("Ablesungen oder Auswertung als CSV, oder den Verbrauchsbericht als PDF")
    }

    /// Das Wasserzeichen steht im Titel, bevor jemand die Datei verschickt —
    /// nicht danach, wenn er den Schriftzug darauf entdeckt.
    private var berichtTitel: String {
        purchase.reportIsWatermarked
            ? "Verbrauchsbericht als PDF (mit Wasserzeichen)"
            : "Verbrauchsbericht als PDF"
    }

    /// Der Bericht steht unter dem Export und nicht daneben.
    ///
    /// Er ist kein dritter Export, sondern ein Dokument: Wer die Rechnung des
    /// Versorgers prüfen will, braucht Zeitraum und Zähler zur Wahl — und
    /// danach Papier, keine Tabelle.
    private var reportRow: some View {
        Button {
            // **Der Bericht ist nie gesperrt.** Seit 0.40.0 lässt er sich immer
            // öffnen; ungekauft trägt er ein Wasserzeichen. Das ist ehrlicher
            // als eine Sperre — man sieht vorher, was man bekommt, und zahlt
            // für das, was man weitergeben will.
            showingReport = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .accessibilityHidden(true)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PulseColor.tintInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verbrauchsbericht")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PulseColor.ink)
                    Text("Gestaltetes Dokument zum Prüfen der Jahresabrechnung")
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkTertiary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if purchase.reportIsWatermarked { PriceBadge(product: .pdfReport) }
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(PulseColor.inkTertiary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PulseColor.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        // Ohne diesen Zusatz sagte VoiceOver nur „Verbrauchsbericht,
        // gestaltetes Dokument…" — und führte auf die Kaufseite, ohne dass
        // vorher irgendwo das Wort Pro gefallen wäre.
        .accessibilityValue(purchase.reportIsWatermarked
                            ? "Mit Wasserzeichen, bis er freigeschaltet ist" : "")
        .accessibilityHint("Öffnet den Bericht")
    }

    private func exportLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(.system(.subheadline, weight: .semibold))
        }
            .foregroundStyle(PulseColor.tintInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PulseColor.hairlineStrong, lineWidth: 1)
            )
    }

    private var chartCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headlineCaption)
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        // Dasselbe Zeichen wie überall sonst: gerechnet, nicht
                        // gemessen (Produktprinzip 7).
                        if headlineIsApproximate {
                            Text(verbatim: "≈")
                                .font(PulseText.unit)
                                .foregroundStyle(PulseColor.inkTertiary)
                                .accessibilityLabel("ungefähr")
                                .padding(.trailing, -2)
                        }
                        Text(headlineNumber)
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(PulseColor.ink)
                        if headlineHasValue {
                            Text(unit)
                                .font(PulseText.unit)
                                .foregroundStyle(PulseColor.inkSecondary)
                        }
                    }
                }
                .accessibilityIdentifier("verlauf-kopfzahl")
                // Als ein Satz: „Verbrauch 2026, 2.541 kWh". Getrennt
                // vorgelesen käme die Einheit als eigener Brocken nach der
                // Zahl — dieselbe Änderung wie auf der Übersichtskarte in
                // 0.27.0.
                .accessibilityElement(children: .combine)

                PeriodBars(columns: chartColumns, accent: accent,
                           selection: selectedSlot, unit: unit) { slot in
                    selectedSlot = selectedSlot == slot ? nil : slot
                    recomputeComparison()
                }

                // Die Legende erklärt nur, was auch zu sehen ist. „2025"
                // entfällt in der Jahresansicht — dort ist das Vorjahr der
                // Balken daneben —, und „unvollständig" nur dann, wenn
                // wirklich ein Abschnitt angebrochen ist.
                HStack(spacing: 14) {
                    legendDot(color: accent, text: granularity == .year ? "Verbrauch" : "\(today.year)")
                    if granularity != .year {
                        legendLine(text: "\(today.year - 1)")
                    }
                    if chartColumns.contains(where: \.isPartial) {
                        legendDot(color: accent.opacity(0.4), text: "unvollständig")
                    }
                    // Die Schraffur heißt „hier wurde nichts abgelesen". Ohne
                    // Legende wäre das ein Muster, das man sich zusammenreimen
                    // muss — und ausgerechnet bei der Zahl, die keine Messung
                    // ist, darf nichts geraten werden.
                    if vorschau != nil, chartColumns.contains(where: { $0.projection != nil }) {
                        legendHatch(text: "erwartet")
                    }
                }
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)
                // Eine Legende erklärt Farben. Wer sie nicht sieht, braucht
                // die Erklärung nicht als drei einzelne Wörter vorgelesen —
                // die Balken darunter sagen ihren Wert selbst.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(legendDescription)

                forecastLine

                Text(selectedSlot == nil
                     ? "Tippe einen Abschnitt an, um ihn mit den Vorjahren zu vergleichen"
                     : "Noch einmal antippen hebt die Auswahl auf")
                    .font(PulseText.caption)
                    .foregroundStyle(PulseColor.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(15)
        }
    }

    /// Der laufende Abschnitt als eigene Leiste unter dem Diagramm.
    ///
    /// **Warum nicht am Balken.** Drei Anläufe, die erwartete Menge im
    /// Jahresbild unterzubringen, sind an derselben Sache gescheitert: Ein
    /// Monatsbalken ist elf Punkte breit, die Zahl dreißig. Der Gründer hat
    /// alle drei abgelehnt und aus drei Vorschlägen diesen gewählt.
    ///
    /// Beide Zahlen stehen benannt nebeneinander — „es muss klar sein welche
    /// zahl fix schon ist und welche prognose für den laufenden monat ist" —,
    /// und die Leiste dazwischen zeigt, wie weit der Abschnitt ist.
    ///
    /// Die Grundlage steht ausgeschrieben („nach dem Verlauf deines
    /// Vorjahres"), weil sie den Unterschied zwischen einer Beobachtung an dir
    /// und einer Annahme über dich benennt — und den Text dafür liefert der
    /// Rechenkern, damit App, Bericht und Entwurf dieselben Wörter benutzen.
    @ViewBuilder
    private var forecastLine: some View {
        if let vorschau, vorschau.daysRemaining > 0 {
            let gemessen = "\(number(vorschau.actual.quantity.value, digits: 0)) \(unit)"
            let erwartet = "≈ \(number(vorschau.projected.value, digits: 0)) \(unit)"
            let tage = "\(vorschau.daysElapsed) von "
                + "\(vorschau.daysElapsed + vorschau.daysRemaining) Tagen"
            ForecastStrip(
                measured: "\(gemessen) gemessen",
                expected: "\(erwartet) erwartet",
                // Anteil des Gemessenen an der Erwartung. Beides kommt aus
                // derselben Rechnung, und die Prognose liegt nie unter dem Ist —
                // die Leiste kann also nicht über ihr Ende hinauslaufen.
                share: vorschau.projected.value > 0
                    ? double(vorschau.actual.quantity.value) / double(vorschau.projected.value)
                    : 0,
                caption: "\(laufenderAbschnittName) · \(tage) · \(vorschau.method.explanation)",
                accent: accent,
                accentInk: accentInk,
                spoken: "Bisher \(gemessen) gemessen, voraussichtlich \(erwartet) "
                    + "bis Ende \(laufenderAbschnittName) — \(vorschau.method.explanation), "
                    + "gerechnet aus \(tage)."
            )
        }
    }

    /// „August" oder „3. Quartal" — der Abschnitt, in dem heute liegt.
    private var laufenderAbschnittName: String {
        guard let laufend = buckets.first(where: { $0.range.contains(today) }) else { return "" }
        return slotName(laufend)
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(text)
        }
    }

    /// Ein Feld Schraffur statt eines Farbklecks — dasselbe Muster wie im
    /// Balken, sonst erklärt die Legende etwas anderes, als im Bild steht.
    private func legendHatch(text: String) -> some View {
        HStack(spacing: 5) {
            HatchSwatch(color: accent).frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(text)
        }
    }

    private func legendLine(text: String) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(PulseColor.inkTertiary).frame(width: 10, height: 2)
                .accessibilityHidden(true)
            Text(text)
        }
    }

    /// Was die Legende in einem Satz sagt.
    private var legendDescription: String {
        var parts = [granularity == .year ? "Balken zeigen den Verbrauch"
                                          : "Balken zeigen \(today.year)"]
        if granularity != .year { parts.append("die Linie \(today.year - 1)") }
        if chartColumns.contains(where: \.isPartial) {
            parts.append("blasse Balken sind unvollständige Abschnitte")
        }
        if chartColumns.contains(where: { $0.projection != nil }) {
            parts.append("die schraffierte Fläche ist die Erwartung für den laufenden Abschnitt")
        }
        return parts.joined(separator: ", ")
    }

    private func comparisonCard(_ comparison: PeriodEngine.SlotComparison) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comparisonTitle(comparison))
                        .font(PulseText.cardTitle)
                        .foregroundStyle(PulseColor.ink)
                    Spacer(minLength: 8)
                    if let change = comparison.approximateChange {
                        Text("\(comparison.changeIsApproximate ? "≈ " : "")\(percentText(change))")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(change < 0 ? PulseColor.favourable : PulseColor.adverse)
                    } else {
                        // Kein Prozentwert heißt nicht immer dasselbe: Mal fehlt
                        // das Vorjahr ganz, mal deckt es nur ein paar Tage ab.
                        // Der zweite Fall braucht ein anderes Wort, sonst sucht
                        // man einen Fehler, wo eine Ablesung fehlt.
                        Text(comparison.entries.count >= 2 && comparison.entries[1].hasData
                             ? "Zu wenig Vorjahr zum Vergleichen"
                             : "Kein Vergleich möglich")
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkTertiary)
                    }
                }
                // „Februar gegenüber Vorjahr, −7 %" als ein Satz. Die Richtung
                // steckt sonst allein in der Farbe, und die liest niemand vor.
                .accessibilityElement(children: .combine)

                YearBars(rows: comparisonRows(comparison), accent: accent)

                // **Kurz halten.** Hier standen zwei Sätze: welcher Ausschnitt
                // verglichen wird, und was ≈ bedeutet. Der Ausschnitt steht
                // jetzt in der Überschrift; was übrig bleibt, ist das, was die
                // Überschrift nicht sagen kann.
                if comparison.isNarrowed {
                    Text("Weiter reichen die Ablesungen der Vorjahre nicht.")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkSecondary)
                        .padding(.top, 2)
                }
                if comparison.entries.contains(where: \.isApproximate) {
                    Text("≈ gerechnet, nicht gemessen.")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                }
            }
            .padding(15)
        }
    }

    private var readingsRow: some View {
        PulseCard {
            Button {
                showingReadings = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alle Ablesungen")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(PulseColor.ink)
                        Text(readings.isEmpty ? "Noch keine" : "\(readings.count) Einträge")
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkTertiary)
                    }
                    Spacer(minLength: 10)
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PulseColor.inkTertiary)
                }
                .padding(15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Daten

    /// Nimmt den Zähler an, den die Übersicht angetippt hat.
    ///
    /// Der ausgewählte Abschnitt fällt dabei weg: Er gehörte zum vorigen
    /// Zähler, und ein Balken, der beim Wechsel stehen bleibt, zeigt den
    /// Ausschnitt eines anderen Zählers — genau die wiederkehrende
    /// Fehlerklasse dieses Projekts.
    private func uebernimmWunsch() {
        guard let gewuenscht = zeige else { return }
        zeige = nil
        guard gewuenscht != selectedMeterID else { return }
        selectedMeterID = gewuenscht
        selectedSlot = nil
        recompute()
    }

    private func load() {
        do {
            let repository = PulseRepository(context: context)
            meters = try repository.meteringPoints()
            if selectedMeterID == nil || !meters.contains(where: { $0.id == selectedMeterID }) {
                // Nur für die Bildschirmfotos, wie `-pulse-bericht` weiter
                // oben: Vorn steht sonst der Zähler, der zuerst im Alphabet
                // kommt, und in den Beispieldaten ist das der absichtlich
                // überfällige Gaszähler. An dem gibt es nichts hochzurechnen —
                // ein Bild vom Verlauf zeigte die Vorschau also nie.
                //
                // Gewählt wird der zuletzt abgelesene Zähler und nicht ein
                // Zähler mit festem Namen: Ein Name in der App, der nur in
                // einem Datensatz vorkommt, ist eine Falle für später.
                if Startschalter.gesetzt("-pulse-verlauf-vorschau") {
                    selectedMeterID = zuletztAbgelesenerZaehler() ?? meters.first?.id
                } else {
                    selectedMeterID = meters.first?.id
                }
            }
            recompute()
        } catch {
            problem = "Der Verlauf ließ sich nicht laden: \(error.localizedDescription)"
        }
    }

    /// Der Zähler mit der jüngsten Ablesung.
    ///
    /// Nur für den Startschalter `-pulse-verlauf-vorschau` gedacht, siehe
    /// `load()`. Ohne Ablesung fällt ein Zähler heraus — er wäre der schlechteste
    /// Kandidat für ein Bild vom Verlauf.
    private func zuletztAbgelesenerZaehler() -> MeteringPoint.ID? {
        let repository = PulseRepository(context: context)
        return meters
            .compactMap { punkt -> (MeteringPoint.ID, CalendarDay)? in
                guard let letzte = try? repository.readings(for: punkt).map(\.day).max() else {
                    return nil
                }
                return (punkt.id, letzte)
            }
            .max { links, rechts in links.1 < rechts.1 }?.0
    }

    private func recompute() {
        guard let meter, register != nil else {
            buckets = []; previousYear = []; readings = []; comparison = nil
            return
        }
        do {
            let repository = PulseRepository(context: context)
            // Alle Zählwerke, nicht nur das erste: Bei Doppeltarif zeigte der
            // Verlauf sonst den Hochtarif und die Karte darüber beide — zwei
            // Zahlen über verschiedene Sachverhalte, direkt untereinander.
            readings = try repository.readings(for: meter)
            tariffs = try repository.tariffs(for: meter.id)
            if granularity == .year {
                // Ein Jahr hat genau einen Abschnitt — als Diagramm wäre das
                // ein einzelner Balken und damit keine Aussage. Bei „Jahr"
                // stehen deshalb mehrere Jahre nebeneinander, und die
                // Vorjahresmarke entfällt: Das Vorjahr ist der Balken daneben.
                buckets = yearSpan.compactMap { year in
                    PeriodEngine.buckets(meteringPoint: meter, readings: readings,
                                         year: year, granularity: .year).first
                }
                previousYear = []
            } else {
                buckets = PeriodEngine.buckets(meteringPoint: meter, readings: readings,
                                               year: today.year, granularity: granularity)
                previousYear = PeriodEngine.buckets(meteringPoint: meter, readings: readings,
                                                    year: today.year - 1, granularity: granularity)
            }
            recomputeCosts(meter: meter)
            recomputeComparison()
            recomputeReport()
            recomputeForecast(meter: meter)
        } catch {
            problem = "Die Ablesungen ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    /// Rechnet hoch, was im **laufenden** Abschnitt zusammenkommen wird.
    ///
    /// Der Gründer beim Gebrauch: „ich will sehen, wie viel man wahrscheinlich
    /// im laufenden Monat verbrauchen wird." Am 21. August sagt ein Balken über
    /// 580 kWh nichts darüber, ob der Monat teuer wird — er zeigt drei Wochen.
    ///
    /// Gerechnet wird über den ganzen Zähler, nicht über ein Zählwerk: Der
    /// Balken daneben ist die Summe, und eine Zahl, die eine andere Sache meint
    /// als der Balken, neben dem sie steht, ist schlimmer als keine.
    ///
    /// **Auch beim Jahr.** Bis 0.76.2 stand hier `granularity != .year` mit der
    /// Begründung, eine Verlängerung am letzten Balken wäre „ein vierter
    /// Balken, den es nicht gibt". Das war schon damals die falsche Frage: Die
    /// Erwartung steht nicht im Balken, sondern in der Leiste darunter — die
    /// gibt es genau deshalb, weil eine Zahl in einen elf Punkte breiten Balken
    /// nicht passt.
    ///
    /// Vom Gerät gemeldet: „ich möchte aber auch den Forecast haben wie viel
    /// Verbrauch aufs Jahr ist … so wie bei Quartal und Monat. immer den Ist
    /// darstellen und den Forecast."
    private func recomputeForecast(meter: MeteringPoint) {
        guard let laufend = buckets.first(where: { $0.range.contains(today) }) else {
            vorschau = nil
            return
        }
        vorschau = ForecastEngine.forecast(meteringPoint: meter, readings: readings,
                                           period: laufend.range, today: today)
    }

    /// Stellt den Bericht zusammen, den das Herunterladen-Menü ausgibt.
    ///
    /// **Zusammengestellt beim Laden, gezeichnet beim Teilen.** Das Rechnen ist
    /// ein Lesen aus dem Speicher und dauert Millisekunden; das Zeichnen von
    /// sechs A4-Seiten dauert lang genug, dass es kein Menü aufhalten darf.
    /// Deshalb liegt hier das Ergebnis und nicht das Dokument.
    ///
    /// `try?` ohne Meldung ist Absicht: Fehlt für den Zeitraum eine Ablesung,
    /// bleibt der Eintrag im Menü ein Knopf zum Berichtsschirm, und **dort**
    /// steht der Satz, warum es nichts zu berichten gibt. Ein Hinweisband über
    /// dem Verlauf wegen eines Berichts, den niemand angefordert hat, wäre eine
    /// Störung.
    private func recomputeReport() {
        guard let zeitraum = berichtsZeitraum else {
            bericht = nil
            return
        }
        bericht = try? ReportComposer(context: context)
            .report(scope: selectedMeterID, period: zeitraum, today: today)
    }

    private func recomputeComparison() {
        guard let meter, let selection = selectedSlot else {
            comparison = nil
            return
        }
        // Bei „Jahr" ist die Auswahl eine Jahreszahl, sonst die Nummer des
        // Abschnitts im laufenden Jahr.
        comparison = PeriodEngine.compareAcrossYears(
            meteringPoint: meter, readings: readings,
            slot: granularity == .year ? 1 : selection,
            granularity: granularity,
            referenceYear: granularity == .year ? selection : today.year,
            yearsBack: 2
        )
    }

    /// Kosten je Abschnitt.
    ///
    /// Abschnitte ohne Tarif oder ohne verwertbaren Tarif — Gas ohne
    /// Umrechnung etwa — bleiben leer statt null. Eine Null wäre die Aussage
    /// „hat nichts gekostet", und die hat niemand gemacht.
    private func recomputeCosts(meter: MeteringPoint) {
        costs = [:]
        guard !tariffs.isEmpty else { return }
        for bucket in buckets where bucket.hasData {
            guard let covered = bucket.result.coveredRange else { continue }
            // Über den ganzen Zähler: Bei Doppeltarif werden beide Arbeitspreise
            // gebraucht, und der Grundpreis darf trotzdem nur einmal anfallen —
            // das kann nur die Rechnung über die Messstelle leisten.
            guard let result = try? CostEngine.cost(meteringPoint: meter, readings: readings,
                                                    tariffs: tariffs, in: covered) else { continue }
            costs[bucket.id] = result.total
        }
    }

    /// Die drei Jahre, die die Jahresansicht zeigt.
    private var yearSpan: [Int] { [today.year - 2, today.year - 1, today.year] }

    private func columnID(_ bucket: PeriodEngine.Bucket) -> Int {
        granularity == .year ? bucket.year : bucket.slot
    }

    // MARK: - Aufbereitung

    private var chartColumns: [PeriodBars.Column] {
        buckets.map { bucket in
            let reference = previousYear.first { $0.slot == bucket.slot }
            // Die Verlängerung gehört an den Abschnitt, in dem heute liegt —
            // und an keinen anderen. Ein abgeschlossener Monat erwartet nichts
            // mehr, und ein künftiger hat noch nichts, worauf sich etwas
            // stützen ließe.
            let laufend = bucket.range.contains(today)
            return PeriodBars.Column(
                id: columnID(bucket),
                label: shortSlotName(bucket),
                value: bucket.hasData ? double(bucket.value) : nil,
                reference: (reference?.hasData ?? false) ? double(reference!.value) : nil,
                isPartial: bucket.hasData && !bucket.isComplete,
                projection: laufend ? vorschau.map { double($0.projected.value) } : nil
            )
        }
    }

    private func comparisonRows(_ comparison: PeriodEngine.SlotComparison) -> [YearBars.Row] {
        // **Geschätzt heißt gekennzeichnet, nicht verschwiegen.**
        //
        // Bis 0.64.1 stand hier `isComparable`: Ein Jahr, dessen Zahl zwischen
        // zwei weit auseinanderliegenden Ablesungen herausgeschnitten ist,
        // bekam „keine Daten" und keinen Balken. Beim ersten echten Gebrauch
        // standen dadurch drei leere Zeilen untereinander — auch für das
        // laufende Jahr. Produktprinzip 7 verlangt eine Kennzeichnung, und die
        // ist das ≈; ein Verschweigen verlangt es nicht.
        // **Und eine Zahl sagt, wie viele Tage sie meint.**
        //
        // Auf dem Gerät stand „2025 · ≈ 18 kWh" neben „2026 · 1.532 kWh". Die
        // 18 stammten aus zwei Tagen, die 1.532 aus acht Monaten. Beide Zahlen
        // stimmen, die Zeile daneben log: „2025" verspricht ein Jahr. Wie beim
        // August gilt — erst die Beschriftung, dann der Text.
        let fenster = comparison.window.spanInDays
        return comparison.entries.map { entry in
            let knapp = entry.hasData && entry.coveredDays * 2 < fenster
            return YearBars.Row(
                id: entry.year,
                year: String(entry.year),
                value: entry.hasData ? double(entry.value) : nil,
                text: entry.hasData
                    ? "\(entry.isApproximate ? "≈ " : "")\(number(entry.value, digits: 0)) \(unit)"
                    : "keine Daten",
                note: knapp ? "aus \(entry.coveredDays) von \(fenster) Tagen" : nil,
                isCurrent: entry.year == comparison.entries.first?.year
            )
        }
    }

    // MARK: - Export

    private var exportBaseName: String {
        let name = (meter?.name ?? "Zaehler")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "PulseMeter-\(name)"
    }

    /// Die Ablesungen als Tabelle — eine Zeile je eingetippter Zahl.
    ///
    /// **Hier wird nichts erzeugt.** Es entsteht nur die Beschreibung dessen,
    /// was beim Teilen entstehen soll; die Zeichenkette baut ``CSVAusgabe``
    /// erst, wenn jemand wirklich teilt.
    private var ablesungenAusgabe: CSVAusgabe {
        let inhalt = readings
        let punkt = meter
        return CSVAusgabe(dateiname: "\(exportBaseName)-Ablesungen.csv") {
            guard let punkt else { return "" }
            return TableExport.readings(inhalt, meteringPoint: punkt, meterName: punkt.name)
        }
    }

    /// Die Auswertung als Tabelle — eine Zeile je Zeitraum, mit dem gerechneten
    /// Verbrauch. Nicht die Zählerstände, sondern was daraus geworden ist.
    private var auswertungAusgabe: CSVAusgabe {
        let abschnitte = buckets
        // Die Einheit kommt aus dem Zählwerk und ist keine Zeichenkette — ein
        // `?? ""` daneben sieht harmlos aus und übersetzt nicht.
        let werk = register
        let punkt = meter
        return CSVAusgabe(dateiname: "\(exportBaseName)-Auswertung.csv") {
            guard let werk, let punkt else { return "" }
            return TableExport.breakdown(abschnitte, unit: werk.unit, meterName: punkt.name)
        }
    }

    /// Der Zeitraum, den ein Bericht aus dem Menü abdeckt.
    ///
    /// Derselbe, den der Berichtsschirm voreinstellt: der erste zum
    /// Abrechnungsrhythmus dieses Zählers. Zwei verschiedene Voreinstellungen
    /// wären zwei verschiedene Berichte für dieselbe Handlung.
    private var berichtsZeitraum: ReportBuilder.Period? {
        ReportBuilder.periods(today: today, billingCycle: meter?.billingCycle).first
    }

    /// Der Verbrauchsbericht als PDF — gezeichnet erst beim Teilen.
    ///
    /// `nil`, solange für den Zeitraum nichts vorliegt. Dann bleibt im Menü ein
    /// Knopf zum Berichtsschirm stehen, statt dass der Eintrag verschwindet:
    /// Eine Auswahl, in der ein Eintrag je nach Datenlage da ist oder nicht,
    /// erklärt sich nicht mehr selbst.
    private var berichtAusgabe: PDFAusgabe? {
        guard let bericht else { return nil }
        return PDFAusgabe(dateiname: ReportPDF.fileName(for: bericht),
                          bericht: bericht,
                          wasserzeichen: purchase.reportIsWatermarked)
    }

    private func cellText(for bucket: PeriodEngine.Bucket) -> String {
        guard bucket.hasData else { return "—" }
        if metric == .cost {
            return costs[bucket.id].map(money) ?? "—"
        }
        return number(bucket.value, digits: 0)
    }

    /// Die Summe zählt nur, was auch in der Spalte steht.
    ///
    /// Bei Kosten heißt das: Abschnitte ohne Tarif fehlen in der Summe, und
    /// die Beschriftung sagt es. Eine Summe über eine Spalte mit Lücken, die
    /// so aussieht wie eine Summe über eine volle, ist die wiederkehrende
    /// Fehlerklasse dieses Projekts.
    private var totalText: String {
        guard metric == .cost else { return "\(number(total, digits: 0)) \(unit)" }
        let amounts = buckets.compactMap { costs[$0.id] }
        guard let first = amounts.first else { return "—" }
        let sum = amounts.reduce(Decimal(0)) { $0 + $1.amount }
        return money(Money(sum, first.currency))
    }

    private func money(_ money: Money) -> String {
        money.amount.formatted(.currency(code: money.currency.code)
            .locale(Locale(identifier: "de_DE")))
    }

    /// Summe der Abschnitte, die tatsächlich Daten haben.
    private var total: Decimal {
        buckets.filter(\.hasData).reduce(Decimal(0)) { $0 + $1.value }
    }

    // MARK: - Die Zahl über dem Diagramm

    /// Der angetippte Abschnitt, oder keiner.
    ///
    /// Die Auswahl ist bei „Jahr" eine Jahreszahl und sonst die Nummer des
    /// Abschnitts — dieselbe Kennung, die auch die Balken tragen.
    private var selectedBucket: PeriodEngine.Bucket? {
        guard let selection = selectedSlot else { return nil }
        return buckets.first { columnID($0) == selection }
    }

    /// Was über dem Diagramm steht, wenn ein Balken angetippt ist.
    ///
    /// **Vom Gerät gemeldet:** „wenn ich hier oben im Monat die Balken anklicke
    /// will ich direkt oben sehen wie viel ich verbraucht habe. gerade wird das
    /// ganze Jahr angezeigt. das will ich aber auf Monatsebene gar nicht sehen."
    ///
    /// Er hatte recht: Die Zahl oben blieb die Jahressumme, egal was man antippt.
    /// Die Auswahl stand allein im Balken und in der Vergleichskarte weiter
    /// unten — also außerhalb des Blickfelds, in dem die große Zahl steht.
    ///
    /// Die Beschriftung nennt den Ausschnitt, den die Zahl meint, und bei einem
    /// angebrochenen Abschnitt auch, aus wie vielen Tagen sie stammt. Dieselbe
    /// Wendung wie in den Vergleichszeilen: „aus 12 von 31 Tagen".
    /// Was oben steht, wenn niemand einen Balken angetippt hat.
    ///
    /// **In der Jahresansicht das laufende Jahr, keine Summe darüber.** Vom
    /// Gerät gemeldet: „auf Jahresbasis macht es keinen Sinn über alle Jahre
    /// die Summe. damit fängt ja keiner was an und daran werden ja keine
    /// Analysen gemacht."
    ///
    /// Er hat recht. „2024 bis 2026, zusammen" beantwortet keine Frage, die
    /// jemand stellt: Verbrauch vergleicht man Jahr gegen Jahr, und dafür
    /// stehen die Balken nebeneinander. Bei Monat und Quartal bleibt die Summe
    /// des laufenden Jahres — dort ist sie die Klammer um die zwölf Balken.
    private var defaultBucket: PeriodEngine.Bucket? {
        guard granularity == .year else { return nil }
        return buckets.first { $0.year == today.year }
    }

    private var headlineBucket: PeriodEngine.Bucket? { selectedBucket ?? defaultBucket }

    private var headlineCaption: String {
        guard let bucket = headlineBucket else {
            // In der Jahresansicht gibt es keine Summe mehr, auf die
            // zurückzufallen wäre. Fehlt der Balken für das laufende Jahr,
            // steht das da — und nicht die Summe der anderen.
            return granularity == .year ? "\(today.year) · keine Ablesung" : totalCaption
        }
        let name = granularity == .year ? "\(bucket.year)" : "\(slotName(bucket)) \(bucket.year)"
        guard bucket.hasData else { return "\(name) · keine Ablesung" }
        guard !bucket.isComplete else { return name }
        return "\(name) · aus \(bucket.result.coveredDays) von \(bucket.range.spanInDays) Tagen"
    }

    private var headlineHasValue: Bool {
        guard let bucket = headlineBucket else { return granularity != .year }
        return bucket.hasData
    }

    private var headlineNumber: String {
        guard let bucket = headlineBucket else {
            return granularity == .year ? "—" : number(total, digits: 0)
        }
        guard bucket.hasData else { return "—" }
        return number(bucket.value, digits: 0)
    }

    /// Ob die Zahl gerechnet ist statt gemessen.
    ///
    /// Ohne Auswahl gilt sie für die Summe: Steckt in **einem** Abschnitt eine
    /// Interpolation, steckt sie auch in der Summe. Bis 0.74.0 stand sie dort
    /// ohne Zeichen — und hätte nach dieser Änderung ausgerechnet neben einem
    /// angetippten Monat mit „≈" gestanden, der in ihr enthalten ist.
    private var headlineIsApproximate: Bool {
        guard let bucket = headlineBucket else {
            return buckets.contains { $0.hasData && $0.result.confidence != .measured }
        }
        return bucket.hasData && bucket.result.confidence != .measured
    }

    /// Sagt, was die Summe umfasst — und wenn sie unvollständig ist, dass sie
    /// es ist. Eine Jahressumme, die im Mai endet, sieht sonst aus wie ein Jahr.
    private var totalCaption: String {
        var complete = buckets.filter(\.hasData).allSatisfy(\.isComplete)
        // Bei Kosten kommt eine zweite Lücke dazu: Abschnitte ohne Tarif.
        if metric == .cost {
            complete = complete && buckets.filter(\.hasData).allSatisfy { costs[$0.id] != nil }
        }
        // Nur noch für Monat und Quartal: Dort ist die Jahressumme die Klammer
        // um die Balken darunter. In der Jahresansicht steht seit 0.76.0 das
        // laufende Jahr, siehe `defaultBucket`.
        let base = "\(today.year), zusammen"
        return complete ? base : base + " · unvollständig"
    }

    // MARK: - Beschriftung

    private static let monthsShort = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private static let monthsLong = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                                     "Juli", "August", "September", "Oktober", "November", "Dezember"]

    private func shortSlotName(_ bucket: PeriodEngine.Bucket) -> String {
        switch granularity {
        case .month: return Self.monthsShort[safe: bucket.slot - 1] ?? "\(bucket.slot)"
        case .quarter: return "Q\(bucket.slot)"
        case .year: return "\(bucket.year)"
        }
    }

    private func slotName(_ bucket: PeriodEngine.Bucket) -> String {
        switch granularity {
        case .month: return Self.monthsLong[safe: bucket.slot - 1] ?? "\(bucket.slot)"
        case .quarter: return "\(bucket.slot). Quartal"
        case .year: return "\(bucket.year)"
        }
    }

    /// Überschrift der Vergleichskarte. Beim Jahr steht die Jahreszahl schon
    /// in der Auswahl, sonst der Name des Abschnitts.
    /// Die Überschrift nennt den Ausschnitt, den die Zahlen meinen.
    ///
    /// **Warum nicht einfach „August".** Genau das stand da, über einer Zahl,
    /// die drei Tage meint — der Gründer las 11 kWh als Augustverbrauch und
    /// hielt sie für falsch. Sie war richtig, nur falsch beschriftet. Ein Satz
    /// weiter unten hat es erklärt; eine Zahl, die eine Erklärung braucht, ist
    /// die falsche Beschriftung.
    private func comparisonTitle(_ comparison: PeriodEngine.SlotComparison) -> String {
        let voll: String
        switch comparison.granularity {
        case .month: voll = Self.monthsLong[safe: comparison.slot - 1] ?? "\(comparison.slot)"
        case .quarter: voll = "\(comparison.slot). Quartal"
        case .year: return "Jahresvergleich"
        }
        guard comparison.isPartial else { return voll }
        return "\(comparison.window.start.day).–\(comparison.window.end.day). \(voll)"
    }

    private func percentText(_ change: Decimal) -> String {
        let sign = change < 0 ? "−" : "+"
        return "\(sign)\(number(abs(change) * 100, digits: 0)) % gegenüber Vorjahr"
    }

    private func germanDate(_ day: CalendarDay) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: components) else { return day.description }
        return date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "de_DE")))
    }

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }

    private func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

/// Die Liste aller Ablesungen — bewusst hinter einer Zeile versteckt.
///
/// Vom Nutzer so gewünscht: Beim Öffnen des Verlaufs interessiert der Verlauf,
/// nicht die Rohdaten. Wer sie braucht, findet sie an einer Stelle.
struct ReadingsList: View {

    let readings: [Reading]
    let unit: String
    let fractionDigits: Int
    /// Name je Zählwerk, aber nur wenn der Zähler mehr als eine Zahl führt.
    /// Bei einem gewöhnlichen Zähler stünde sonst „Bezug" an jeder Zeile —
    /// ein Wort, das der Nutzer nie gebraucht hat.
    var labels: [Register.ID: String] = [:]
    /// Der Zähler, zu dem die Ablesungen gehören. Ohne ihn ließe sich keine
    /// ändern: Stellen, Einheit und Gerätewechsel hängen am Zählwerk.
    var meteringPoint: MeteringPoint?
    /// Wird gerufen, wenn sich etwas geändert hat — der Verlauf dahinter muss
    /// dann neu rechnen.
    var onChanged: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Reading?
    @State private var deleting: Reading?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                if let problem {
                    Text(problem)
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.adverse)
                }
                ForEach(readings.reversed()) { reading in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            // Die Uhrzeit steht dabei, wenn eine angegeben
                            // wurde. Zwei Zeilen mit demselben Datum und
                            // verschiedenen Zahlen sehen sonst aus wie ein
                            // doppelter Eintrag — und genau das sollten sie
                            // nicht: Es sind Morgen und Abend.
                            Text(reading.time.map { "\(germanDate(reading.day)), \($0) Uhr" }
                                 ?? germanDate(reading.day))
                                .font(PulseText.detail)
                                .foregroundStyle(PulseColor.inkSecondary)
                            if let label = labels[reading.registerID] {
                                Text(label)
                                    .font(PulseText.detail)
                                    .foregroundStyle(PulseColor.inkTertiary)
                            }
                        }
                        Spacer(minLength: 10)
                        Text("\(number(reading.value)) \(unit)")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(PulseColor.ink)
                        if meteringPoint != nil {
                            Image(systemName: "chevron.right")
                                .accessibilityHidden(true)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PulseColor.inkTertiary)
                        }
                    }
                    // Die ganze Zeile führt zum Ändern, nicht nur die Schrift.
                    .contentShape(Rectangle())
                    .onTapGesture { if meteringPoint != nil { editing = reading } }
                    // Löschen zusätzlich über das Wischen — der schnelle Weg
                    // für den, der ihn kennt. Gefragt wird trotzdem: Eine
                    // gelöschte Ablesung ist nicht wiederzuholen.
                    .swipeActions(edge: .trailing) {
                        if meteringPoint != nil {
                            Button(role: .destructive) { deleting = reading } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                    // Als ein Satz: „1. Juni 2026, Hochtarif, 25.971,5 kWh".
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(meteringPoint == nil ? "" : "Öffnet die Ablesung zum Ändern")
                    .accessibilityAddTraits(meteringPoint == nil ? [] : .isButton)
                }
            }
            .navigationTitle("Ablesungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $editing) { reading in
                if let meteringPoint {
                    ReadingEditor(reading: reading,
                                  meteringPoint: meteringPoint,
                                  others: readings.filter {
                                      $0.registerID == reading.registerID && $0.id != reading.id
                                  },
                                  onDone: {
                                      onChanged()
                                      dismiss()
                                  })
                }
            }
            .confirmationDialog("Diese Ablesung löschen?",
                                isPresented: Binding(get: { deleting != nil },
                                                     set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { entfernen() }
                Button("Abbrechen", role: .cancel) { deleting = nil }
            } message: {
                Text(deleting.map {
                    "Der Stand vom \(germanDate($0.day)) wird entfernt. Der Verbrauch davor und danach wird neu gerechnet."
                } ?? "")
            }
        }
    }

    /// **Warum das Blatt danach zugeht.** Die Liste hat ihre Ablesungen als
    /// Kopie bekommen; nach einer Änderung stimmt sie nicht mehr. Sie an Ort
    /// und Stelle nachzuladen hieße, denselben Bestand an zwei Orten zu führen
    /// — die Liste zeigt danach den Stand des Verlaufs dahinter, und der ist
    /// gerade neu gerechnet worden.
    private func entfernen() {
        guard let reading = deleting else { return }
        deleting = nil
        do {
            try PulseRepository(context: context).delete(readingID: reading.id)
            onChanged()
            dismiss()
        } catch {
            problem = "Die Ablesung ließ sich nicht löschen: \(error.localizedDescription)"
        }
    }

    private func germanDate(_ day: CalendarDay) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: components) else { return day.description }
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE")))
    }

    private func number(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(Locale(identifier: "de_DE")))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Eine Tabelle, die **erst beim Teilen** entsteht.
///
/// **Der Grund, warum dieser Typ existiert.** Bis 0.61.0 waren die zwei
/// Exportdateien berechnete Eigenschaften, die im Bildaufbau standen. Jede
/// Neuauswertung des Verlaufsschirms hat damit zwei CSV-Dateien gebaut **und
/// auf die Platte geschrieben** — beim Blättern, beim Umschalten von Monat auf
/// Quartal, und beim Antippen von „Alle Ablesungen", weil auch das den Zustand
/// ändert. Der Gründer beim ersten Gebrauch: „lädt ziemlich lange".
///
/// Dateien als Nebenwirkung des Zeichnens zu schreiben ist unabhängig von der
/// Geschwindigkeit falsch. `Transferable` löst beides: Die Beschreibung ist
/// billig, `inhalt` läuft erst, wenn das Teilen-Blatt die Daten anfordert.
///
/// `exportedContentType: .commaSeparatedText` sagt dem System ausdrücklich,
/// dass es eine Tabelle ist — vorher hing das allein an der Dateiendung, und
/// je nach Ziel kam sie als Textdatei an.
struct CSVAusgabe: Transferable {

    let dateiname: String
    /// Wird genau einmal aufgerufen, und nur beim Teilen.
    let inhalt: () -> String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { ausgabe in
            // Byte-Reihenfolge-Marke für Excel: Ohne sie öffnet es eine
            // UTF-8-Datei mit Umlauten als Buchstabensalat.
            Data("\u{FEFF}\(ausgabe.inhalt())".utf8)
        }
        .suggestedFileName { $0.dateiname }
    }
}

/// Der Verbrauchsbericht als PDF, zum Weitergeben.
///
/// **Der Bericht ist fertig gerechnet, aber noch nicht gezeichnet.** Er steckt
/// hier als Ergebnis — ein Wertetyp, kein Zugriff auf den Speicher — und wird
/// erst zu Papier, wenn ein Ziel für die Datei gewählt ist. Das Zeichnen läuft
/// auf dem Hauptakteur, weil `ImageRenderer` dort zu Hause ist; deshalb ist der
/// Bericht `Sendable` und die Zeichenarbeit in ``MainActor/run(resultType:body:)``
/// eingepackt und nicht umgekehrt.
struct PDFAusgabe: Transferable, Sendable {

    let dateiname: String
    let bericht: ReportBuilder.Report
    let wasserzeichen: Bool

    /// Kein erwarteter Fall: Der Bericht steht, das Papier nicht.
    /// `DataRepresentation` verlangt Daten oder einen Fehler — ein leeres PDF
    /// wäre die dritte Möglichkeit und die schlechteste.
    enum Ausfall: LocalizedError {
        case nichtGezeichnet
        var errorDescription: String? { "Das PDF ließ sich nicht erzeugen." }
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { ausgabe in
            let daten = await MainActor.run {
                ReportPDF.data(ausgabe.bericht, watermarked: ausgabe.wasserzeichen)
            }
            guard let daten else { throw Ausfall.nichtGezeichnet }
            return daten
        }
        .suggestedFileName { $0.dateiname }
    }
}
