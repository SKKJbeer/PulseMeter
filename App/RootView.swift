import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Gerüst der Navigation aus docs/03-ux-konzept.md: drei Ziele, keine
/// Einstellungen als vierter Tab.
struct RootView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "house") }
            PlaceholderView(title: "Verlauf", note: "Folgt als Nächstes.")
                .tabItem { Label("Verlauf", systemImage: "chart.bar") }
            PlaceholderView(title: "Zähler", note: "Folgt als Nächstes.")
                .tabItem { Label("Zähler", systemImage: "gauge.medium") }
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
    let yearToDate: ConsumptionResult?
    let changeVersusLastYear: Decimal?
    let monthlySeries: [Double]
    let daysSinceReading: Int?
    let isDue: Bool
}

struct OverviewView: View {

    @Environment(\.modelContext) private var context
    @State private var rows: [MeterRow] = []
    @State private var points: [MeteringPoint] = []
    @State private var capturing: MeteringPoint?
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
            .sheet(item: $capturing) { point in
                CaptureView(meteringPoint: point, onSaved: reload)
            }
        }
    }

    // MARK: - Bausteine

    private var emptyState: some View {
        PulseCard {
            VStack(spacing: 14) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 34))
                    .foregroundStyle(PulseColor.inkTertiary)
                Text("Noch kein Zähler")
                    .font(PulseText.cardTitle)
                    .foregroundStyle(PulseColor.ink)
                Text("Lege Beispieldaten an, um Speicher und Rechenkern im Zusammenspiel zu sehen.")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .multilineTextAlignment(.center)
                Button(action: seed) {
                    Text("Beispieldaten anlegen")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PulseColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(PulseColor.tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
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
            caption: periodCaption(for: row.yearToDate),
            value: valueText(for: row.yearToDate),
            isApproximate: isApproximate(row.yearToDate),
            unit: row.unit,
            detail: detailText(for: row),
            badge: row.isDue ? "Fällig" : nil,
            series: row.monthlySeries
        ) {
            VStack(spacing: 0) {
                if let value = row.lastValue, let day = row.lastDay {
                    CardFooterRow("Stand \(number(value, digits: 1)) \(row.unit)") {
                        Text(germanDate(day))
                            .font(PulseText.detail)
                            .foregroundStyle(PulseColor.inkTertiary)
                    }
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
                }
                .buttonStyle(.plain)
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
    private func periodCaption(for result: ConsumptionResult?) -> String {
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
        if row.isDue, let days = row.daysSinceReading {
            return Text("Seit \(days) Tagen fällig")
        }
        guard let change = row.changeVersusLastYear else {
            return Text("Noch kein Vergleichswert")
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
        if let due = rows.first(where: \.isDue), let days = due.daysSinceReading {
            var text = AttributedString("\(due.name) ist seit \(days) Tagen nicht abgelesen.")
            text.font = .system(.subheadline, weight: .semibold)
            var rest = AttributedString(" Ohne aktuellen Stand ist die Vorschau ungenau.")
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

    /// Beim Start. Setzt auf Wunsch alles zurück und legt Beispieldaten an.
    ///
    /// Die Oberflächentests brauchen einen bekannten Ausgangszustand — sonst
    /// hängt jeder Test davon ab, was der vorherige hinterlassen hat, und ein
    /// grüner Lauf sagt nichts über den einzelnen Fall.
    private func start() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-pulse-reset") {
            try? PulseRepository(context: context).deleteEverything()
            rows = []
            points = []
            seed()
        } else {
            reload()
        }

        // Öffnet den Erfassungsschirm gleich beim Start. Nur für die
        // Bildschirmfotos: Es ist der wichtigste Schirm der App und der
        // einzige, den ein automatischer Lauf sonst nie zu Gesicht bekommt —
        // `simctl` kann nicht tippen.
        if arguments.contains("-pulse-capture") {
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
                                    lastValue: nil, lastDay: nil, yearToDate: nil,
                                    changeVersusLastYear: nil, monthlySeries: [],
                                    daysSinceReading: nil, isDue: false)
                }
                let readings = try repository.readings(for: register.id)
                let last = readings.last
                let result = ConsumptionEngine.consumption(register: register,
                                                           readings: readings, in: yearRange)
                let comparison = ConsumptionEngine.yearOverYear(register: register,
                                                               readings: readings, in: yearRange)
                return MeterRow(
                    id: point.id,
                    name: point.name,
                    unit: register.unit.symbol,
                    symbolName: point.appearance.symbolName,
                    colorToken: point.appearance.colorToken,
                    lastValue: last?.value,
                    lastDay: last?.day,
                    yearToDate: result,
                    changeVersusLastYear: comparison?.relativeChange,
                    monthlySeries: monthlySeries(register: register, readings: readings, today: today),
                    daysSinceReading: last.map { today.days(since: $0.day) },
                    isDue: ConsumptionEngine.isReadingDue(meteringPoint: point,
                                                          readings: readings, today: today)
                )
            }
        } catch {
            problem = "Die Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    /// Die letzten zwölf abgeschlossenen Monate.
    ///
    /// Monate ohne vollständige Daten werden ausgelassen und nicht als Null
    /// gezeichnet — eine Datenlücke ist kein Nullverbrauch.
    private func monthlySeries(register: Register, readings: [Reading], today: CalendarDay) -> [Double] {
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
            let result = ConsumptionEngine.consumption(register: register, readings: readings, in: range)
            guard result.isComplete else { continue }
            values.append(NSDecimalNumber(decimal: result.quantity.value).doubleValue)
        }
        return values
    }

    /// Legt drei Zähler mit gut zwei Jahren Historie an.
    ///
    /// So viel Vergangenheit braucht es, damit Verlaufslinie und
    /// Vorjahresvergleich überhaupt etwas zeigen können. Und drei Zähler statt
    /// einem, weil der Gaszähler bewusst überfällig ist: Nur so lassen sich
    /// der Fällig-Zustand, die Hinweiszeile und der Erfassungsfluss prüfen.
    private func seed() {
        // Jahresverläufe: Strom flach mit Winterhügel, Gas stark saisonal,
        // Wasser fast gleichmäßig.
        let profiles: [(name: String, kind: ResourceKind, start: Decimal,
                        monthly: [Decimal], staleMonths: Int)] = [
            ("Strom", .electricity, 41_230,
             [312, 286, 268, 241, 218, 205, 198, 204, 226, 258, 289, 315], 0),
            ("Wasser", .water, 998,
             [10.8, 9.9, 11.2, 10.6, 12.4, 13.1, 13.8, 13.2, 11.6, 10.9, 10.4, 11.1], 0),
            ("Gas", .gas, 3_579,
             [418, 376, 298, 178, 92, 41, 36, 39, 84, 192, 308, 402], 3)
        ]

        do {
            let repository = PulseRepository(context: context)
            let property = try repository.ensureDefaultProperty()
            let today = self.today

            for profile in profiles {
                let point = MeteringPoint(propertyID: property.id, name: profile.name, kind: profile.kind)
                try repository.save(point)
                guard let register = point.primaryRegister else { continue }

                var value = profile.start
                for offset in stride(from: 25, through: profile.staleMonths, by: -1) {
                    var month = today.month - offset
                    var year = today.year
                    while month < 1 { month += 12; year -= 1 }
                    guard let day = CalendarDay(year: year, month: month, day: 1) else { continue }
                    try repository.save(
                        Reading(registerID: register.id, day: day, value: value),
                        fractionDigits: register.fractionDigits
                    )
                    // Das laufende Jahr liegt sieben Prozent unter dem Vorjahr.
                    let seasonal = profile.monthly[month - 1]
                    value += year == today.year ? seasonal * Decimal(string: "0.93")! : seasonal
                }
            }
            reload()
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

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }
}

#Preview {
    RootView()
        .modelContainer(try! PulseStore.container(inMemory: true, cloudKit: false))
}
