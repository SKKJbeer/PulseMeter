import SwiftUI
import SwiftData
import PulseCore
import PulseData

/// Gerüst der Navigation aus docs/03-ux-konzept.md: drei Ziele, keine
/// Einstellungen als vierter Tab.
///
/// Bewusst noch ohne Design-System. Dieses Gerüst existiert, um zu belegen,
/// dass App, Persistenz und Rechenkern zusammenspielen. Die Gestaltung folgt
/// mit `PulseUI`.
struct RootView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "house") }
            PlaceholderView(title: "Verlauf", note: "Folgt, sobald PulseUI steht.")
                .tabItem { Label("Verlauf", systemImage: "chart.bar") }
            PlaceholderView(title: "Zähler", note: "Folgt, sobald PulseUI steht.")
                .tabItem { Label("Zähler", systemImage: "gauge.medium") }
        }
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

/// Ein Zähler, so weit für die Liste aufbereitet.
struct MeterRow: Identifiable {
    let id: UUID
    let name: String
    let unit: String
    let lastValue: Decimal?
    let lastDay: CalendarDay?
    let yearToDate: ConsumptionResult?
}

struct OverviewView: View {

    @Environment(\.modelContext) private var context
    @State private var rows: [MeterRow] = []
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                if let problem {
                    Section {
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("Noch kein Zähler", systemImage: "gauge.medium")
                    } description: {
                        Text("Lege Beispieldaten an, um das Zusammenspiel von Speicher und Rechenkern zu sehen.")
                    } actions: {
                        Button("Beispieldaten anlegen", action: seed)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.name).font(.headline)
                            if let result = row.yearToDate, result.hasData {
                                Text("\(format(result.quantity.value, digits: 0)) \(row.unit) seit Jahresbeginn")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let value = row.lastValue, let day = row.lastDay {
                                Text("Stand \(format(value, digits: 1)) \(row.unit) am \(germanDate(day))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Übersicht")
            .onAppear(perform: reload)
        }
    }

    // MARK: - Daten

    private func reload() {
        problem = nil
        do {
            let repository = PulseRepository(context: context)
            let points = try repository.meteringPoints()
            let today = CalendarDay.containing(Date(), in: .current)
            let yearStart = CalendarDay(year: today.year, month: 1, day: 1)

            rows = try points.map { point in
                guard let register = point.primaryRegister else {
                    return MeterRow(id: point.id, name: point.name, unit: "",
                                    lastValue: nil, lastDay: nil, yearToDate: nil)
                }
                let readings = try repository.readings(for: register.id)
                let last = readings.last
                let range = yearStart.flatMap { DayRange(start: $0, end: today) }
                let result = range.map {
                    ConsumptionEngine.consumption(register: register, readings: readings, in: $0)
                }
                return MeterRow(
                    id: point.id,
                    name: point.name,
                    unit: register.unit.symbol,
                    lastValue: last?.value,
                    lastDay: last?.day,
                    yearToDate: result
                )
            }
        } catch {
            problem = "Die Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    /// Legt einen Stromzähler mit zwei Ablesungen an — genug, damit der
    /// Rechenkern etwas zu rechnen hat.
    private func seed() {
        do {
            let repository = PulseRepository(context: context)
            let property = try repository.ensureDefaultProperty()
            let point = MeteringPoint(propertyID: property.id, name: "Strom", kind: .electricity)
            try repository.save(point)

            guard let register = point.primaryRegister else { return }
            let today = CalendarDay.containing(Date(), in: .current)
            let earlier = today.adding(days: -31)
            try repository.save(
                Reading(registerID: register.id, day: earlier, value: 44_530),
                fractionDigits: register.fractionDigits
            )
            try repository.save(
                Reading(registerID: register.id, day: today, value: 44_830),
                fractionDigits: register.fractionDigits
            )
            reload()
        } catch {
            problem = "Die Beispieldaten ließen sich nicht anlegen: \(error.localizedDescription)"
        }
    }

    /// Datum in der Sprache des Nutzers, nicht in der des Datenmodells.
    ///
    /// `CalendarDay.description` liefert `2026-08-04` — richtig für ein
    /// Protokoll, aber technisches Vokabular auf dem Schirm und damit ein
    /// Verstoß gegen Produktprinzip 6.
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

    private func format(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }
}

#Preview {
    RootView()
        .modelContainer(try! PulseStore.container(inMemory: true, cloudKit: false))
}
