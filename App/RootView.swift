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
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-pulse-verlauf") { return 1 }
        if arguments.contains("-pulse-zaehler") { return 2 }
        return 0
    }()

    var body: some View {
        TabView(selection: $tab) {
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "house") }
                .tag(0)
            HistoryView()
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
    /// Warum keine Kosten dastehen, wenn ein Tarif zwar da ist, aber nicht
    /// reicht — bei Gas ohne Zustandszahl und Brennwert etwa. Ein leeres Feld
    /// erklärt sich nicht; ein Satz schon.
    let costProblem: String?
}

struct OverviewView: View {

    @Environment(\.modelContext) private var context
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
            .sheet(item: $capturing) { point in
                CaptureView(meteringPoint: point, onSaved: reload)
            }
            .sheet(isPresented: $addingMeter) {
                MeterEditor(draft: MeterDraft(), readingCount: 0, onDone: reload)
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
            series: row.monthlySeries
        ) {
            VStack(spacing: 0) {
                if let value = row.lastValue, let day = row.lastDay {
                    CardFooterRow("Stand \(number(value, digits: row.fractionDigits)) \(row.unit)") {
                        Text(germanDate(day))
                            .font(PulseText.detail)
                            .foregroundStyle(PulseColor.inkTertiary)
                    }
                }
                if let cost = row.cost {
                    CardFooterRow("Kosten seit Jahresbeginn") {
                        Text(money(cost))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PulseColor.ink)
                    }
                } else if let costProblem = row.costProblem {
                    CardFooterRow(costProblem) { EmptyView() }
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
    private func periodCaption(for row: MeterRow) -> String {
        guard let result = row.yearToDate else { return "Noch keine Ablesung" }
        if case .none = result.coverage {
            return row.readingCount == 0 ? "Noch keine Ablesung" : "Seit der ersten Ablesung"
        }

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

    /// Beim Start. Setzt auf Wunsch alles zurück und legt Beispieldaten an.
    ///
    /// Die Oberflächentests brauchen einen bekannten Ausgangszustand — sonst
    /// hängt jeder Test davon ab, was der vorherige hinterlassen hat, und ein
    /// grüner Lauf sagt nichts über den einzelnen Fall.
    private func start() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-pulse-empty") {
            // Der Zustand, in dem jeder neue Nutzer anfängt — und der einzige,
            // den bis 0.16 kein Test und kein Bild je gesehen hat.
            try? PulseRepository(context: context).deleteEverything()
            rows = []
            points = []
        } else if arguments.contains("-pulse-reset") {
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
                                    lastValue: nil, lastDay: nil, readingCount: 0,
                                    fractionDigits: 0, yearToDate: nil,
                                    changeVersusLastYear: nil, monthlySeries: [],
                                    daysSinceReading: nil, isDue: false,
                                    cost: nil, costProblem: nil)
                }
                let readings = try repository.readings(for: register.id)
                let last = readings.last
                let costs = cost(register: register, readings: readings,
                                 tariffs: try repository.tariffs(for: point.id),
                                 in: yearRange)
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
                    readingCount: readings.count,
                    fractionDigits: register.fractionDigits,
                    yearToDate: result,
                    changeVersusLastYear: comparison?.relativeChange,
                    monthlySeries: monthlySeries(register: register, readings: readings, today: today),
                    daysSinceReading: last.map { today.days(since: $0.day) },
                    isDue: ConsumptionEngine.isReadingDue(meteringPoint: point,
                                                          readings: readings, today: today),
                    cost: costs.value,
                    costProblem: costs.problem
                )
            }
        } catch {
            problem = "Die Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    /// Kosten des Zeitraums — oder der Grund, warum es keine gibt.
    ///
    /// Ohne Tarif ist beides `nil`: Das ist kein Fehler, sondern der
    /// Normalfall, solange niemand Preise eingetragen hat. Ein hinterlegter
    /// Tarif, der nicht reicht, ist dagegen etwas, das der Nutzer beheben kann
    /// — und dann muss dastehen, was fehlt.
    private func cost(register: Register, readings: [Reading], tariffs: [Tariff],
                      in range: DayRange) -> (value: Money?, problem: String?) {
        guard !tariffs.isEmpty else { return (nil, nil) }
        do {
            let result = try CostEngine.cost(register: register, readings: readings,
                                             tariffs: tariffs, in: range)
            return (result.total, nil)
        } catch CostEngine.CostError.missingConversion {
            return (nil, "Für die Kosten fehlen Zustandszahl und Brennwert von deiner Rechnung.")
        } catch CostEngine.CostError.noTariff {
            return (nil, nil)
        } catch {
            return (nil, "Die Kosten ließen sich nicht berechnen.")
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
        // Preise nach den Größenordnungen einer deutschen Jahresrechnung 2026.
        // Gas rechnet in kWh ab, obwohl der Zähler m³ misst — deshalb dort die
        // Umrechnung, ohne die der Rechenkern zu Recht keinen Betrag bildet.
        let profiles: [(name: String, kind: ResourceKind, start: Decimal,
                        monthly: [Decimal], staleMonths: Int,
                        price: Decimal, base: Decimal, gas: Bool)] = [
            ("Strom", .electricity, 41_230,
             [312, 286, 268, 241, 218, 205, 198, 204, 226, 258, 289, 315], 0,
             Decimal(string: "0.34")!, Decimal(string: "12.90")!, false),
            ("Wasser", .water, 998,
             [10.8, 9.9, 11.2, 10.6, 12.4, 13.1, 13.8, 13.2, 11.6, 10.9, 10.4, 11.1], 0,
             Decimal(string: "2.15")!, Decimal(string: "8.40")!, false),
            ("Gas", .gas, 3_579,
             [418, 376, 298, 178, 92, 41, 36, 39, 84, 192, 308, 402], 3,
             Decimal(string: "0.11")!, Decimal(string: "14.50")!, true)
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

                guard let yearStart = CalendarDay(year: today.year - 2, month: 1, day: 1) else { continue }
                try repository.save(Tariff(
                    meteringPointID: point.id,
                    validFrom: yearStart,
                    pricePerUnit: profile.price,
                    monthlyBasePrice: profile.base,
                    billingUnit: profile.gas ? .kilowattHour : profile.kind.defaultUnit,
                    gasConversion: profile.gas ? .typical : nil
                ))
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
}
