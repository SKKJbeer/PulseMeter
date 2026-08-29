import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Gerüst der Navigation aus docs/03-ux-konzept.md: drei Ziele, keine
/// Einstellungen als vierter Tab.
struct RootView: View {

    /// Welcher Tab beim Start offen ist. Nur für die Bildschirmfotos: Ein
    /// automatischer Lauf kann nicht tippen, und ein Schirm, den niemand
    /// fotografiert, wird auch von niemandem angesehen — genau daran sind
    /// zuletzt drei Fehler im Erfassungsschirm monatelang vorbeigelaufen.
    @State private var tab: Int = {
        if Startschalter.einerVon("-pulse-verlauf", "-pulse-bericht") { return 1 }
        if Startschalter.einerVon("-pulse-zaehler", "-pulse-kaufen") { return 2 }
        return 0
    }()

    /// Welcher Zähler im Verlauf gezeigt werden soll, wenn jemand seine Karte
    /// auf der Übersicht antippt.
    ///
    /// Ein Wunsch, kein Zustand: Der Verlauf nimmt ihn entgegen und setzt ihn
    /// zurück. Bliebe er stehen, führte jeder spätere Wechsel auf den Verlauf
    /// wieder zu diesem Zähler — auch Wochen später.
    @State private var verlaufFuer: MeteringPoint.ID?

    var body: some View {
        TabView(selection: $tab) {
            OverviewView(oeffneVerlauf: { id in
                verlaufFuer = id
                tab = 1
            })
                .tabItem { Label("Übersicht", systemImage: "house") }
                .tag(0)
            HistoryView(zeige: $verlaufFuer)
                .tabItem { Label("Verlauf", systemImage: "chart.bar") }
                .tag(1)
            MetersView()
                .tabItem { Label("Zähler", systemImage: "gauge.medium") }
                .tag(2)
        }
        .tint(PulseColor.tint)
    }
}

struct PlaceholderView: View {
    let title: String
    let note: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text(note))
                .navigationTitle(title)
        }
    }
}

/// Ein Zähler, so weit für die Anzeige aufbereitet.
///
/// Die Ansicht rechnet nicht selbst — sie bekommt fertige Ergebnisse aus
/// `ConsumptionEngine`. Dadurch bleibt die Rechenlogik an einer Stelle und
/// bleibt ohne Simulator prüfbar.
struct MeterRow: Identifiable {
    let id: UUID
    let name: String
    let unit: String
    let symbolName: String
    let colorToken: String
    let lastValue: Decimal?
    let lastDay: CalendarDay?
    /// Wie viele Ablesungen es gibt. Null und eins sehen für den Rechenkern
    /// gleich aus — beide ergeben keinen Verbrauch —, für den Nutzer aber
    /// nicht: Bei eins fehlt nur noch eine.
    let readingCount: Int
    /// Nachkommastellen des Zählwerks — der Stand wird so geschrieben, wie er
    /// am Gerät abzulesen ist. Sonst steht derselbe Wert auf der Übersicht als
    /// „8.285,1" und im Erfassungsschirm als „8.285,100".
    let fractionDigits: Int
    let yearToDate: ConsumptionResult?
    let changeVersusLastYear: Decimal?
    let monthlySeries: [Double]
    let daysSinceReading: Int?
    let isDue: Bool
    /// Kosten des laufenden Jahres, `nil` ohne hinterlegten Tarif.
    let cost: Money?
    /// Ob der Betrag Schätzungen enthält.
    ///
    /// Er erbt die Verlässlichkeit vom Verbrauch: Steckt in der Menge eine
    /// Interpolation, steckt sie auch im Betrag. Bis 0.39.0 trug die Menge ihr
    /// Zeichen und der Euro-Betrag daneben nicht — dieselbe Unsicherheit,
    /// einmal gekennzeichnet und einmal nicht (Produktprinzip 7).
    let costIsApproximate: Bool
    /// Warum keine Kosten dastehen, wenn ein Tarif zwar da ist, aber nicht
    /// reicht — bei Gas ohne Zustandszahl und Brennwert etwa. Ein leeres Feld
    /// erklärt sich nicht; ein Satz schon.
    let costProblem: String?
    /// Vorschau auf das Ende des Abrechnungszeitraums, wenn ein Abschlag
    /// hinterlegt ist.
    let outlook: ForecastEngine.PrepaymentOutlook?
    /// Eingespeiste Menge und Vergütung — nur bei einem Zweirichtungszähler.
    ///
    /// Getrennt von ``cost``, weil der Betrag dort bereits **netto** ist: Der
    /// Rechenkern zieht die Vergütung ab. Stünde die Gutschrift unter den
    /// Kosten, zöge jeder Leser sie ein zweites Mal ab — deshalb steht sie auf
    /// der Karte darüber.
    let feedIn: FeedIn?

    struct FeedIn {
        let quantity: Decimal
        let unit: String
        /// `nil`, solange kein Einspeisepreis hinterlegt ist. Dann steht die
        /// Menge allein da — eine Null wäre eine Behauptung über Geld, die
        /// niemand aufgestellt hat.
        let credit: Money?
    }
}

struct OverviewView: View {

    /// Wohin eine angetippte Karte führt. Ohne Angabe bleibt die Übersicht
    /// eine Anzeige — so, wie sie in Vorschauen und Prüfungen gebraucht wird.
    var oeffneVerlauf: ((MeteringPoint.ID) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(Datenstand.self) private var datenstand
    // Gebraucht wird davon nur eines: ob erinnert werden darf. Die Planung
    // laeuft nach jeder Ablesung mit und darf einen fehlenden Kauf nicht
    // uebergehen.
    @Environment(Purchase.self) private var purchase
    @State private var rows: [MeterRow] = []
    @State private var points: [MeteringPoint] = []
    @State private var capturing: MeteringPoint?
    @State private var addingMeter = false
    @State private var problem: String?

    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(germanDate(today))
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkTertiary)
                        .padding(.bottom, 2)

                    if let problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    } else if !rows.isEmpty {
                        StatusBanner(tone: statusTone, message: statusMessage)
                    }

                    if rows.isEmpty && problem == nil {
                        emptyState
                    } else {
                        ForEach(rows) { row in card(for: row) }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Übersicht")
            .onAppear(perform: start)
            // **Ein Weg für alle drei Ansichten.** Die Blätter melden nur, dass
            // sich etwas geändert hat; neu geladen wird hier, an derselben
            // Stelle, an der auch eine Änderung aus dem Verlauf oder der
            // Zählerliste ankommt. Zwei Wege wären zwei Gelegenheiten, dass
            // einer davon etwas ausrechnet, was der andere nicht kennt.
            .onChange(of: datenstand.version) { _, _ in reload() }
            .sheet(item: $capturing) { point in
                CaptureView(meteringPoint: point, onSaved: { datenstand.geaendert() })
            }
            .sheet(isPresented: $addingMeter) {
                MeterEditor(draft: MeterDraft(), readingCount: 0,
                            onDone: { datenstand.geaendert() })
            }
        }
    }

    // MARK: - Bausteine

    private var emptyState: some View {
        PulseCard {
            VStack(spacing: 14) {
                Image(systemName: "gauge.medium")
                    .accessibilityHidden(true)
                    .font(.system(size: 34))
                    .foregroundStyle(PulseColor.inkTertiary)
                Text("Noch kein Zähler")
                    .font(PulseText.cardTitle)
                    .foregroundStyle(PulseColor.ink)
                Text("Leg deinen ersten Zähler an — Name und Art genügen. Danach trägst du den Stand ein, und der Rest ergibt sich.")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .multilineTextAlignment(.center)

                // Die Hauptsache führt zum eigenen Zähler, nicht zu
                // Beispieldaten. „Beispieldaten anlegen" stand hier als
                // einzige Möglichkeit und war Entwicklersprache an der
                // Stelle, an der ein neuer Nutzer zum ersten Mal etwas tut.
                Button { addingMeter = true } label: {
                    Text("Ersten Zähler anlegen")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PulseColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(PulseColor.tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                Button("Stattdessen Beispieldaten anlegen", action: seed)
                    .font(PulseText.caption)
                    .foregroundStyle(PulseColor.inkTertiary)
            }
            .padding(20)
        }
    }

    private func card(for row: MeterRow) -> some View {
        let accent = PulseColor.resource(row.colorToken)
        return ValueCard(
            title: row.name,
            symbolName: row.symbolName,
            accent: accent,
            caption: periodCaption(for: row),
            value: valueText(for: row.yearToDate),
            isApproximate: isApproximate(row.yearToDate),
            unit: row.unit,
            detail: detailText(for: row),
            badge: row.isDue ? "Fällig" : nil,
            series: row.monthlySeries,
            onOpen: oeffneVerlauf.map { sprung in { sprung(row.id) } }
        ) {
            VStack(spacing: 0) {
                if let value = row.lastValue, let day = row.lastDay {
                    CardFooterRow("Stand \(number(value, digits: row.fractionDigits)) \(row.unit)") {
                        Text(germanDate(day))
                            .font(PulseText.detail)
                            .foregroundStyle(PulseColor.inkTertiary)
                    }
                    // Für die Oberflächenprüfung, die belegt, dass eine im
                    // Verlauf gelöschte Ablesung auch hier ankommt. Der Stand
                    // ist dafür die einzige Zahl, die sich zwangsläufig ändert:
                    // Ein Zählwerk läuft vorwärts, also ist der vorletzte Wert
                    // ein anderer als der letzte. Am Jahresverbrauch ließe sich
                    // dasselbe nur wahrscheinlich zeigen, und eine Prüfung, die
                    // meistens stimmt, ist keine.
                    .accessibilityIdentifier("kartenstand-\(row.name)")
                }
                // Vor den Kosten, nicht danach: Der Betrag darunter ist
                // bereits netto — die Vergütung ist abgezogen. Stünde sie
                // hinterher, zöge sie jeder Leser ein zweites Mal ab.
                if let feed = row.feedIn {
                    CardFooterRow("Einspeisung \(number(feed.quantity, digits: 0)) \(feed.unit)") {
                        if let credit = feed.credit {
                            Text("≈ \(money(credit)) vergütet")
                                .font(PulseText.detail)
                                .foregroundStyle(PulseColor.favourable)
                        } else {
                            EmptyView()
                        }
                    }
                }
                if let cost = row.cost {
                    CardFooterRow(costCaption(for: row)) {
                        // Dasselbe Zeichen wie über der großen Zahl und wie an
                        // der Einspeisung: Ein „≈" heißt in dieser App überall
                        // dasselbe.
                        Text((row.costIsApproximate ? "≈ " : "") + money(cost))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PulseColor.ink)
                    }
                } else if let costProblem = row.costProblem {
                    CardFooterRow(costProblem) { EmptyView() }
                }
                if let outlook = row.outlook {
                    // „Voraussichtlich" ist kein Füllwort: Die Zahl beruht auf
                    // einer Hochrechnung des restlichen Zeitraums, nicht auf
                    // gemessenem Verbrauch (Produktprinzip 7).
                    CardFooterRow("Abschlag \(money(outlook.totalPrepayment)) im Jahr") {
                        Text(outlook.expectsRefund
                             ? "≈ \(money(outlook.balance)) Guthaben"
                             : "≈ \(money(Money(-outlook.balance.amount, outlook.balance.currency))) Nachzahlung")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(outlook.expectsRefund ? PulseColor.favourable : PulseColor.adverse)
                    }
                    // **Worauf die Zahl beruht — und zwar direkt darunter.**
                    //
                    // Bis 0.38.0 stand hier „≈ 71,63 € Guthaben" und sonst
                    // nichts. Ob dahinter das eigene Vorjahr steckte oder eine
                    // gleichmäßige Fortschreibung, die bei Gas im Februar um
                    // 100 % danebenliegt, war der Zahl nicht anzusehen. Das
                    // ist die folgenreichste Zahl der App, und Produktprinzip 7
                    // verlangt genau hier eine Kennzeichnung.
                    //
                    // Der Klick-Dummy konnte das längst; die App nicht. Eine
                    // Abweichung zwischen beiden ist ein Fehler (Regel 2).
                    Text("Hochgerechnet \(outlook.method.explanation)")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 15)
                        .padding(.bottom, 10)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().overlay(PulseColor.hairline)
                Button {
                    capturing = points.first { $0.id == row.id }
                } label: {
                    Text("Stand eintragen")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        // Der Schriftzug ist schmal, die Zeile breit. Ohne
                        // diese Zeile reagiert nur die Schrift — beim
                        // meistbenutzten Knopf der App.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // **Der Knopf sagt, für welchen Zähler er gilt.**
                //
                // Sichtbar steht „Stand eintragen“ — in der Karte ist das
                // eindeutig, denn der Name steht zwei Zeilen darüber. Für
                // VoiceOver war es das nicht: Wer vier Zähler hat, fand vier
                // Knöpfe mit demselben Namen und musste sich merken, in
                // welcher Karte er gerade steht. Genau die Art Sackgasse, die
                // Produktprinzip 4 ausschließt.
                //
                // Aufgefallen ist es einer Oberflächenprüfung, die den
                // richtigen Knopf nicht ansprechen konnte.
                .accessibilityLabel("Stand eintragen für \(row.name)")
            }
        }
    }

    /// Beschriftet die große Zahl mit dem Zeitraum, den sie tatsächlich
    /// abdeckt — nicht mit dem, der angefragt wurde.
    ///
    /// Die Unterscheidung ist der Kern der wiederkehrenden Fehlerklasse aus
    /// CLAUDE.md. Auf dem Schirm sah sie zuletzt so aus: „1.181 m³" beim
    /// Gaszähler, groß und ohne Zusatz, obwohl die Ablesungen im Mai enden.
    /// Daneben „1.607 kWh" beim Strom, das bis August reicht. Zwei Zahlen
    /// untereinander, die verschiedene Ausschnitte des Jahres meinen und
    /// dieselbe Form haben — der Vergleich, zu dem die Karte einlädt, ist
    /// dann falsch, und niemand kann es sehen.
    private func periodCaption(for row: MeterRow) -> String {
        guard let result = row.yearToDate else { return "Noch keine Ablesung" }
        if case .none = result.coverage {
            return row.readingCount == 0 ? "Noch keine Ablesung" : "Seit der ersten Ablesung"
        }
        return periodText(for: result)
    }

    /// Derselbe Satz, gebildet allein aus dem Ergebnis.
    ///
    /// Herausgelöst, weil das Widget ihn ebenfalls braucht und eine zweite
    /// Fassung früher oder später eine andere Beschriftung zeigte als der
    /// Bildschirm daneben.
    ///
    /// Eigener Name statt einer Überladung: Zwei Funktionen `periodCaption(for:)`
    /// mit `MeterRow` und `ConsumptionResult?` wären in einem Abschluss eine
    /// Einladung an den Typprüfer, die falsche zu wählen — und ich baue hier
    /// gerade ohne Compiler zur Hand.
    private func periodText(for result: ConsumptionResult?) -> String {
        guard let result else { return "Noch keine Ablesung" }

        // Ein verkürzter Zeitraum wird als Spanne ausgeschrieben, nicht als
        // „Seit Jahresbeginn" mit angehängtem Vorbehalt. Der Grund ist
        // praktisch: Wer den Strom am 1. August abliest, hat am 5. August eine
        // Zahl, die vier Tage zurückliegt — das ist normal. Beim Gaszähler
        // sind es drei Monate. Als Vorbehalt gelesen sähen beide gleich
        // dringlich aus; als Spanne stehen „bis 1. August" und „bis 1. Mai"
        // nebeneinander, und der Unterschied ist ohne ein Wort zu sehen.
        let period: String
        switch result.coverage {
        case .none:
            return "Noch keine Ablesung"
        case .full:
            period = "Seit Jahresbeginn"
        case .startsLate(let firstDay):
            period = "Seit \(shortDate(firstDay))"
        case .endsEarly(let lastDay):
            period = "\(shortDate(result.requestedRange.start)) bis \(shortDate(lastDay))"
        case .partial(let firstDay, let lastDay):
            period = "\(shortDate(firstDay)) bis \(shortDate(lastDay))"
        }

        // Nur die stärkere Einstufung bekommt Worte. Ein an der Jahresgrenze
        // interpolierter Startwert ist bei jedem länger geführten Zähler der
        // Normalfall; stünde dort jedes Mal ein Hinweis, läse ihn niemand
        // mehr. Diesen Fall trägt das Zeichen vor der Zahl.
        return result.confidence == .estimated ? period + " · enthält Schätzungen" : period
    }

    /// Beschriftet den Betrag mit dem Zeitraum, den er abdeckt.
    ///
    /// Vorher stand dort fest „Kosten seit Jahresbeginn". Auf dem Bild vom
    /// 6. August sah das so aus: Der Gaszähler war seit dem 1. Mai nicht
    /// abgelesen, die Karte sagte das auch — und zwei Zeilen tiefer standen
    /// 1.399,41 € „seit Jahresbeginn". Drei Monate, die der Betrag nicht
    /// enthält. Es ist die wiederkehrende Fehlerklasse aus CLAUDE.md, diesmal
    /// nicht in der Rechnung, sondern in ihrer Beschriftung: Die Zahl war
    /// richtig, der Satz darüber nicht.
    ///
    /// Der Zeitraum kommt aus derselben Quelle wie die Kopfzeile der Karte,
    /// damit beide nicht auseinanderlaufen können.
    private func costCaption(for row: MeterRow) -> String {
        guard let result = row.yearToDate else { return "Kosten" }
        switch result.coverage {
        case .none:
            return "Kosten"
        case .full:
            return "Kosten seit Jahresbeginn"
        case .startsLate(let firstDay):
            return "Kosten seit \(shortDate(firstDay))"
        case .endsEarly(let lastDay):
            return "Kosten bis \(shortDate(lastDay))"
        case .partial(let firstDay, let lastDay):
            return "Kosten \(shortDate(firstDay)) bis \(shortDate(lastDay))"
        }
    }

    /// Ein Strich statt einer Null, wenn für den Zeitraum nichts vorliegt:
    /// Unbekannt ist nicht dasselbe wie null verbraucht.
    private func valueText(for result: ConsumptionResult?) -> String {
        guard let result, result.hasData else { return "—" }
        return number(result.quantity.value, digits: 0)
    }

    /// Produktprinzip 7: Was nicht ausschließlich auf gemessenen Werten
    /// beruht, wird als solches gekennzeichnet.
    private func isApproximate(_ result: ConsumptionResult?) -> Bool {
        guard let result, result.hasData else { return false }
        return result.confidence != .measured
    }

    private func detailText(for row: MeterRow) -> Text {
        if row.isDue {
            return Text(row.daysSinceReading.map { "Seit \($0) Tagen fällig" }
                        ?? "Noch nie abgelesen")
        }
        guard let change = row.changeVersusLastYear else {
            // Mit genau einer Ablesung steht noch kein Verbrauch fest — das
            // ist kein Mangel, sondern der zweite Schritt. Die Karte sagt ihn.
            return Text(row.readingCount == 1
                        ? "Der Verbrauch ergibt sich aus zwei Ablesungen"
                        : "Noch kein Vergleichswert")
        }
        let sign = change < 0 ? "−" : "+"
        let percent = number(abs(change) * 100, digits: 0)
        return Text("\(sign)\(percent) %")
            .foregroundColor(change < 0 ? PulseColor.favourable : PulseColor.adverse)
            + Text(" gegenüber Vorjahr")
    }

    private var statusTone: StatusBanner.Tone {
        rows.contains(where: \.isDue) ? .notice : .calm
    }

    private var statusMessage: AttributedString {
        // `daysSinceReading` ist `nil`, solange der Zähler nie abgelesen wurde.
        // Vorher fiel dieser Fall durch die Bedingung hindurch, und die App
        // meldete „Alles im Rahmen. Alle Zähler sind aktuell." für einen
        // Zähler, der noch nie einen Stand hatte — also genau im Zustand, in
        // dem jeder neue Nutzer die App zum ersten Mal öffnet.
        if let due = rows.first(where: \.isDue) {
            var text = AttributedString(due.daysSinceReading.map {
                "\(due.name) ist seit \($0) Tagen nicht abgelesen."
            } ?? "\(due.name) wurde noch nie abgelesen.")
            text.font = .system(.subheadline, weight: .semibold)
            var rest = AttributedString(due.daysSinceReading == nil
                ? " Trag den ersten Stand ein, dann fängt der Verlauf an."
                : " Ohne aktuellen Stand ist die Vorschau ungenau.")
            rest.font = .system(.subheadline)
            text.append(rest)
            return text
        }
        var text = AttributedString("Alles im Rahmen.")
        text.font = .system(.subheadline, weight: .semibold)
        if let first = rows.first, let change = first.changeVersusLastYear, change < -0.02 {
            let percent = number(abs(change) * 100, digits: 0)
            text.append(AttributedString(" \(first.name) liegt \(percent) % unter dem Vorjahr."))
        } else {
            text.append(AttributedString(" Alle Zähler sind aktuell."))
        }
        return text
    }

    // MARK: - Daten

    /// Beim Start. Liest, was da ist.
    ///
    /// Zurückgesetzt und mit Beispielen befüllt wird nicht mehr hier, sondern
    /// beim Start der App in ``LaunchFixture``. Der Grund steht dort: Ein Lauf,
    /// der in einem anderen Tab beginnt, erreichte diese Stelle nie, und die
    /// Bildschirmfotos hingen dadurch voneinander ab.
    private func start() {
        reload()

        // Öffnet den Erfassungsschirm gleich beim Start. Nur für die
        // Bildschirmfotos: Es ist der wichtigste Schirm der App und der
        // einzige, den ein automatischer Lauf sonst nie zu Gesicht bekommt —
        // `simctl` kann nicht tippen.
        if Startschalter.einerVon("-pulse-capture-pv", "-pulse-capture-step2") {
            // Eigener Schalter für den Zweirichtungszähler: `-pulse-capture`
            // nimmt den ersten Zähler, und das ist Gas mit einem einzigen
            // Zählwerk. Der zweistufige Ablauf — erst Bezug, dann Einspeisung —
            // kam dadurch auf keinem Bild vor, obwohl er neu ist.
            capturing = points.first { $0.registers.count > 1 } ?? points.first
        } else if Startschalter.gesetzt("-pulse-capture") {
            capturing = points.first
        }
    }

    private func reload() {
        problem = nil
        do {
            let repository = PulseRepository(context: context)
            let points = try repository.meteringPoints()
            self.points = points
            let today = self.today
            guard let yearStart = CalendarDay(year: today.year, month: 1, day: 1),
                  let yearRange = DayRange(start: yearStart, end: today) else { return }

            rows = try points.map { point in
                guard let register = point.primaryRegister else {
                    return MeterRow(id: point.id, name: point.name, unit: "",
                                    symbolName: point.appearance.symbolName,
                                    colorToken: point.appearance.colorToken,
                                    lastValue: nil, lastDay: nil, readingCount: 0,
                                    fractionDigits: 0, yearToDate: nil,
                                    changeVersusLastYear: nil, monthlySeries: [],
                                    daysSinceReading: nil, isDue: false,
                                    cost: nil, costIsApproximate: false,
                                    costProblem: nil, outlook: nil, feedIn: nil)
                }
                // **Zwei Listen, und die Namen sagen welche.**
                //
                // `primary` sind die Ablesungen des Bezugs, `everything` die
                // aller Zählwerke. Beide hießen einmal `readings`, und beim
                // Umstellen auf den Zweirichtungszähler bekam die
                // Abschlagsvorschau die falsche: Sie rechnete dann, als gäbe
                // es die Anlage nicht, und zeigte auf den Cent denselben Wert
                // wie vorher. Ein Name, der die Verwechslung nicht bemerkbar
                // macht, ist ein Fehler, der auf seine Gelegenheit wartet.
                //
                // Menge, Stand und Vorjahresvergleich gehören zum **Bezug** —
                // sonst stünde bei einem PV-Zähler der Einspeisestand auf der
                // Karte. Kosten, Vorschau und Einspeisezeile gehören zur
                // **Messstelle**, weil die Vergütung dort gegengerechnet wird.
                let primary = try repository.readings(for: register.id)
                let everything = point.registers.count > 1
                    ? try repository.readings(for: point)
                    : primary
                let last = primary.last
                let tariffs = try repository.tariffs(for: point.id)
                let periods = try repository.billingPeriods(for: point.id)
                let costs = cost(point: point, readings: everything,
                                 tariffs: tariffs, in: yearRange)
                // **Menge und Vergleich gehören zum Zähler, nicht zum ersten
                // Zählwerk.** Bei einem Doppeltarifzähler stünde sonst der
                // Hochtarif allein auf der Karte, und der Niedertarif fehlte
                // wortlos. Beim Zweirichtungszähler ändert sich dadurch nichts:
                // Die Einspeisung ist kein Bezug und zählt nicht mit.
                let result = ConsumptionEngine.consumption(meteringPoint: point,
                                                           readings: everything, in: yearRange)
                let comparison = ConsumptionEngine.yearOverYear(meteringPoint: point,
                                                               readings: everything, in: yearRange)
                return MeterRow(
                    id: point.id,
                    name: point.name,
                    unit: register.unit.symbol,
                    symbolName: point.appearance.symbolName,
                    colorToken: point.appearance.colorToken,
                    lastValue: last?.value,
                    lastDay: last?.day,
                    readingCount: primary.count,
                    fractionDigits: register.fractionDigits,
                    yearToDate: result,
                    changeVersusLastYear: comparison?.relativeChange,
                    monthlySeries: monthlySeries(point: point, readings: everything, today: today),
                    daysSinceReading: last.map { today.days(since: $0.day) },
                    isDue: ConsumptionEngine.isReadingDue(meteringPoint: point,
                                                          readings: primary, today: today),
                    cost: costs.value,
                    costIsApproximate: costs.isApproximate,
                    costProblem: costs.problem,
                    outlook: outlook(point: point, readings: everything,
                                     tariffs: tariffs, periods: periods),
                    feedIn: feedIn(point: point, readings: everything,
                                   tariffs: tariffs, in: yearRange)
                )
            }
            // Das Widget bekommt dieselbe Rechnung wie dieser Schirm, nur
            // kleiner. Gebaut wird sie in `PulseCore`, damit die beiden nicht
            // auseinanderlaufen können — ein Widget, das eine andere Zahl
            // zeigt als der Bildschirm daneben, ist schlimmer als keines.
            WidgetBridge.write(WidgetSummary.build(
                meteringPoints: points,
                readings: Dictionary(uniqueKeysWithValues: try points.map { point in
                    (point.id, try repository.readings(for: point))
                }),
                range: yearRange,
                today: today,
                caption: { result in periodText(for: result) }))

            // Eine Ablesung verschiebt den nächsten Termin. Ohne dieses
            // Nachziehen käme die Erinnerung zu einem Zeitpunkt, an dem längst
            // nichts mehr fällig ist — und der Hinweis verlöre seinen Wert.
            // Ohne erteilte Erlaubnis tut der Aufruf nichts.
            Task { await rescheduleReminders() }
        } catch {
            problem = "Die Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    private func rescheduleReminders() async {
        guard !points.isEmpty else { return }
        do {
            let repository = PulseRepository(context: context)
            var byMeter: [MeteringPoint.ID: [Reading]] = [:]
            for point in points {
                guard let register = point.primaryRegister else { continue }
                byMeter[point.id] = try repository.readings(for: register.id)
            }
            await Reminders.reschedule(meteringPoints: points, readings: byMeter,
                                       today: today,
                                       darfErinnern: purchase.policy.canRemind)
        } catch {
            // Erinnerungen sind Beiwerk. Wenn sie sich nicht planen lassen,
            // darf das die Übersicht nicht mit einer Fehlermeldung belegen.
        }
    }

    /// Kosten des Zeitraums — oder der Grund, warum es keine gibt.
    ///
    /// Ohne Tarif ist beides `nil`: Das ist kein Fehler, sondern der
    /// Normalfall, solange niemand Preise eingetragen hat. Ein hinterlegter
    /// Tarif, der nicht reicht, ist dagegen etwas, das der Nutzer beheben kann
    /// — und dann muss dastehen, was fehlt.
    private func cost(point: MeteringPoint, readings: [Reading], tariffs: [Tariff],
                      in range: DayRange) -> (value: Money?, isApproximate: Bool, problem: String?) {
        guard !tariffs.isEmpty else { return (nil, false, nil) }
        do {
            guard let result = try CostEngine.cost(meteringPoint: point, readings: readings,
                                                   tariffs: tariffs, in: range)
            else { return (nil, false, nil) }
            // Der Rechenkern reicht die Verlässlichkeit vom Verbrauch bis in
            // den Betrag durch. Sie hier fallen zu lassen hieße, eine
            // geschätzte Zahl als gemessene auszugeben.
            return (result.total, result.confidence != .measured, nil)
        } catch CostEngine.CostError.missingConversion {
            return (nil, false, "Für die Kosten fehlen Zustandszahl und Brennwert von deiner Rechnung.")
        } catch CostEngine.CostError.noTariff {
            return (nil, false, nil)
        } catch {
            return (nil, false, "Die Kosten ließen sich nicht berechnen.")
        }
    }

    /// Was ins Netz zurückgegangen ist — und was es eingebracht hat.
    ///
    /// Nur die Menge, wenn kein Einspeisepreis hinterlegt ist. Eine Null wäre
    /// dort eine Aussage über Geld, die niemand gemacht hat (Produktprinzip 7).
    private func feedIn(point: MeteringPoint, readings: [Reading], tariffs: [Tariff],
                        in range: DayRange) -> MeterRow.FeedIn? {
        guard let register = point.registers.first(where: { $0.direction == .feedIn })
        else { return nil }

        let result = ConsumptionEngine.consumption(register: register,
                                                   readings: readings, in: range)
        guard result.hasData else { return nil }

        // Der Arbeitspreisanteil, **nicht** der Gesamtbetrag: In `total` steckt
        // auch der Grundpreis, und der gehört zum Anschluss, nicht zu einer
        // Richtung. Mit `total` stand auf dem Bildschirmfoto „≈ 79,02 €
        // vergütet", wo 171 € richtig gewesen wären — der Grundpreisanteil war
        // von der Gutschrift abgezogen.
        //
        // Der Rechenkern gibt die Einspeisung als negativen Betrag zurück.
        // Auf der Karte steht sie als positive Zahl mit dem Wort „vergütet";
        // ein Minuszeichen neben „Einspeisung" läse sich wie ein Fehler.
        var credit: Money?
        if let money = try? CostEngine.cost(register: register, readings: readings,
                                            tariffs: tariffs, in: range).energyAmount,
           money.amount < 0 {
            credit = Money(-money.amount, money.currency)
        }
        return MeterRow.FeedIn(quantity: result.quantity.value,
                               unit: register.unit.symbol,
                               credit: credit)
    }

    /// Hochrechnung auf das Ende des Abrechnungszeitraums gegen die
    /// Abschläge.
    ///
    /// Nur für den *laufenden* Zeitraum: Ein abgeschlossener Zeitraum braucht
    /// keine Vorschau, sondern eine Abrechnung — und die ist etwas anderes.
    private func outlook(point: MeteringPoint, readings: [Reading],
                         tariffs: [Tariff], periods: [BillingPeriod])
    -> ForecastEngine.PrepaymentOutlook? {
        guard let running = point.currentBillingPeriod(on: today),
              let period = periods.first(where: { $0.range == running })
        else { return nil }
        return try? ForecastEngine.prepaymentOutlook(
            meteringPoint: point, readings: readings, tariffs: tariffs,
            period: period, today: today)
    }

    /// Die letzten zwölf abgeschlossenen Monate.
    ///
    /// Monate ohne vollständige Daten werden ausgelassen und nicht als Null
    /// gezeichnet — eine Datenlücke ist kein Nullverbrauch.
    private func monthlySeries(point: MeteringPoint, readings: [Reading], today: CalendarDay) -> [Double] {
        var values: [Double] = []
        for offset in stride(from: 12, through: 1, by: -1) {
            var month = today.month - offset
            var year = today.year
            while month < 1 { month += 12; year -= 1 }
            let nextMonth = month == 12 ? 1 : month + 1
            let nextYear = month == 12 ? year + 1 : year
            guard let from = CalendarDay(year: year, month: month, day: 1),
                  let to = CalendarDay(year: nextYear, month: nextMonth, day: 1),
                  let range = DayRange(start: from, end: to) else { continue }
            let result = ConsumptionEngine.consumption(meteringPoint: point, readings: readings, in: range)
            guard result.isComplete else { continue }
            values.append(NSDecimalNumber(decimal: result.quantity.value).doubleValue)
        }
        return values
    }
    /// Beispieldaten auf Wunsch — aus derselben Quelle wie der Ausgangszustand
    /// der Bildschirmfotos, damit beide dasselbe zeigen.
    private func seed() {
        do {
            try LaunchFixture.seedSamples(into: PulseRepository(context: context), today: today)
            datenstand.geaendert()
        } catch {
            problem = "Die Beispieldaten ließen sich nicht anlegen: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatierung

    /// Datum in der Sprache des Nutzers, nicht in der des Datenmodells.
    ///
    /// `CalendarDay.description` liefert `2026-08-04` — richtig für ein
    /// Protokoll, aber technisches Vokabular auf dem Schirm.
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

    /// Tag und Monat ohne Jahr — auf der Übersicht geht es immer um das
    /// laufende Jahr, und „1. Mai 2026" wäre in einer Beschriftung zu lang.
    private func shortDate(_ day: CalendarDay) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: components) else { return day.description }
        let format = day.year == today.year
            ? Date.FormatStyle.dateTime.day().month(.wide)
            : Date.FormatStyle.dateTime.day().month(.wide).year()
        return date.formatted(format.locale(Locale(identifier: "de_DE")))
    }

    /// Beträge immer mit zwei Nachkommastellen und Währungszeichen — eine
    /// Zahl ohne Einheit wäre auf einer Karte voller kWh und m³ mehrdeutig.
    private func money(_ money: Money) -> String {
        money.amount.formatted(.currency(code: money.currency.code)
            .locale(Locale(identifier: "de_DE")))
    }

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }
}

#Preview {
    RootView()
        .modelContainer(try! PulseStore.container(inMemory: true, cloudKit: false))
        .environment(Purchase())
        .environment(Datenstand())
}
