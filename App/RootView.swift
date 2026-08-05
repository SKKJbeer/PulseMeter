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
            .onAppear(perform: reload)
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
            value: number(row.yearToDate?.quantity.value ?? 0, digits: 0),
            unit: row.unit,
            detail: detailText(for: row),
            badge: row.isDue ? "Fällig" : nil,
            series: row.monthlySeries
        ) {
            if let value = row.lastValue, let day = row.lastDay {
                CardFooterRow("Stand \(number(value, digits: 1)) \(row.unit)") {
                    Text(germanDate(day))
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkTertiary)
                }
            }
        }
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

    private func reload() {
        problem = nil
        do {
            let repository = PulseRepository(context: context)
            let points = try repository.meteringPoints()
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

    /// Legt einen Stromzähler mit gut zwei Jahren Historie an.
    ///
    /// So viel Vergangenheit braucht es, damit Verlaufslinie und
    /// Vorjahresvergleich überhaupt etwas zeigen können — mit zwei Ablesungen
    /// sähe die Karte fertig aus und wäre doch leer.
    private func seed() {
        do {
            let repository = PulseRepository(context: context)
            let property = try repository.ensureDefaultProperty()
            let point = MeteringPoint(propertyID: property.id, name: "Strom", kind: .electricity)
            try repository.save(point)
            guard let register = point.primaryRegister else { return }

            // Jahresverlauf eines Haushalts: im Winter mehr, im Sommer weniger.
            let monthly: [Decimal] = [312, 286, 268, 241, 218, 205, 198, 204, 226, 258, 289, 315]
            var value = Decimal(41_230)
            let today = self.today

            for offset in stride(from: 25, through: 0, by: -1) {
                var month = today.month - offset
                var year = today.year
                while month < 1 { month += 12; year -= 1 }
                guard let day = CalendarDay(year: year, month: month, day: 1) else { continue }
                try repository.save(
                    Reading(registerID: register.id, day: day, value: value),
                    fractionDigits: register.fractionDigits
                )
                // Das laufende Jahr liegt sieben Prozent unter dem Vorjahr.
                let seasonal = monthly[month - 1]
                value += year == today.year ? seasonal * Decimal(string: "0.93")! : seasonal
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

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }
}

#Preview {
    RootView()
        .modelContainer(try! PulseStore.container(inMemory: true, cloudKit: false))
}
