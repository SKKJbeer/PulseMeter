import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Der Verlauf: ein Zähler, ein Zeitraum.
///
/// Bewusst kein Übersichtsschirm mit allen Zählern gleichzeitig — kWh und m³
/// lassen sich nicht addieren, und ein Diagramm, das es doch tut, ist eine
/// Lüge. Wer vergleichen will, wählt einen Zähler (docs/03-ux-konzept.md).
struct HistoryView: View {

    @Environment(\.modelContext) private var context

    @State private var meters: [MeteringPoint] = []
    @State private var selectedMeterID: MeteringPoint.ID?
    @State private var granularity: PeriodEngine.Granularity = .month
    @State private var buckets: [PeriodEngine.Bucket] = []
    @State private var previousYear: [PeriodEngine.Bucket] = []
    @State private var selectedSlot: Int?
    @State private var comparison: PeriodEngine.SlotComparison?
    @State private var readings: [Reading] = []
    @State private var showingReadings = false
    @State private var problem: String?

    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }
    private var meter: MeteringPoint? { meters.first { $0.id == selectedMeterID } }
    private var register: Register? { meter?.primaryRegister }
    private var accent: Color { PulseColor.resource(meter?.appearance.colorToken ?? "amber") }
    private var unit: String { register?.unit.symbol ?? "" }

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
                        chartCard
                        if let comparison {
                            comparisonCard(comparison)
                        }
                        readingsRow
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Verlauf")
            .onAppear(perform: load)
            .sheet(isPresented: $showingReadings) {
                ReadingsList(readings: readings, unit: unit,
                             fractionDigits: register?.fractionDigits ?? 1)
            }
        }
    }

    // MARK: - Bausteine

    private var emptyState: some View {
        PulseCard {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar")
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
                }
            }
            .padding(.vertical, 1)
        }
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

    private var chartCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(totalCaption)
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(number(total, digits: 0))
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(PulseColor.ink)
                        Text(unit)
                            .font(PulseText.unit)
                            .foregroundStyle(PulseColor.inkSecondary)
                    }
                }

                PeriodBars(columns: chartColumns, accent: accent, selection: selectedSlot) { slot in
                    selectedSlot = selectedSlot == slot ? nil : slot
                    recomputeComparison()
                }

                HStack(spacing: 14) {
                    legendDot(color: accent, text: "\(today.year)")
                    legendLine(text: "\(today.year - 1)")
                    legendDot(color: accent.opacity(0.4), text: "unvollständig")
                }
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)

                Text(selectedSlot == nil
                     ? "Tippe einen Abschnitt an, um ihn mit den Vorjahren zu vergleichen"
                     : "Noch einmal antippen hebt die Auswahl auf")
                    .font(PulseText.caption)
                    .foregroundStyle(PulseColor.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(15)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func legendLine(text: String) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(PulseColor.inkTertiary).frame(width: 10, height: 2)
            Text(text)
        }
    }

    private func comparisonCard(_ comparison: PeriodEngine.SlotComparison) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slotName(comparison.slot))
                        .font(PulseText.cardTitle)
                        .foregroundStyle(PulseColor.ink)
                    Spacer(minLength: 8)
                    if let change = comparison.relativeChange {
                        Text(percentText(change))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(change < 0 ? PulseColor.favourable : PulseColor.adverse)
                    } else {
                        Text("Kein Vergleich möglich")
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkTertiary)
                    }
                }

                YearBars(rows: comparisonRows(comparison), accent: accent)

                // Der Satz ist der Grund, warum diese Karte überhaupt richtig
                // rechnet: Läuft der Abschnitt noch, sind alle Jahre auf
                // denselben Ausschnitt beschnitten — und das muss dastehen,
                // sonst hält der Leser die Zahl für einen ganzen Monat.
                if comparison.isPartial {
                    Text("Verglichen wird \(germanDate(comparison.window.start)) bis \(germanDate(comparison.window.end)) — in jedem Jahr derselbe Ausschnitt.")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkSecondary)
                        .padding(.top, 2)
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PulseColor.inkTertiary)
                }
                .padding(15)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Daten

    private func load() {
        do {
            let repository = PulseRepository(context: context)
            meters = try repository.meteringPoints()
            if selectedMeterID == nil || !meters.contains(where: { $0.id == selectedMeterID }) {
                selectedMeterID = meters.first?.id
            }
            recompute()
        } catch {
            problem = "Der Verlauf ließ sich nicht laden: \(error.localizedDescription)"
        }
    }

    private func recompute() {
        guard let register else {
            buckets = []; previousYear = []; readings = []; comparison = nil
            return
        }
        do {
            readings = try PulseRepository(context: context).readings(for: register.id)
            buckets = PeriodEngine.buckets(register: register, readings: readings,
                                           year: today.year, granularity: granularity)
            previousYear = PeriodEngine.buckets(register: register, readings: readings,
                                                year: today.year - 1, granularity: granularity)
            recomputeComparison()
        } catch {
            problem = "Die Ablesungen ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    private func recomputeComparison() {
        guard let register, let slot = selectedSlot else {
            comparison = nil
            return
        }
        comparison = PeriodEngine.compareAcrossYears(
            register: register, readings: readings,
            slot: slot, granularity: granularity,
            referenceYear: today.year, yearsBack: 2
        )
    }

    // MARK: - Aufbereitung

    private var chartColumns: [PeriodBars.Column] {
        buckets.map { bucket in
            let reference = previousYear.first { $0.slot == bucket.slot }
            return PeriodBars.Column(
                id: bucket.slot,
                label: shortSlotName(bucket.slot),
                value: bucket.hasData ? double(bucket.value) : nil,
                reference: (reference?.hasData ?? false) ? double(reference!.value) : nil,
                isPartial: bucket.hasData && !bucket.isComplete
            )
        }
    }

    private func comparisonRows(_ comparison: PeriodEngine.SlotComparison) -> [YearBars.Row] {
        // `isComparable` statt `hasData`: Ein Jahr, das den Ausschnitt nur
        // halb abdeckt, bekäme sonst einen halben Balken und sähe sparsam aus,
        // statt unvollständig.
        comparison.entries.map { entry in
            YearBars.Row(
                id: entry.year,
                year: String(entry.year),
                value: entry.isComparable ? double(entry.value) : nil,
                text: entry.isComparable ? "\(number(entry.value, digits: 0)) \(unit)" : "keine Daten",
                isCurrent: entry.year == comparison.entries.first?.year
            )
        }
    }

    /// Summe der Abschnitte, die tatsächlich Daten haben.
    private var total: Decimal {
        buckets.filter(\.hasData).reduce(Decimal(0)) { $0 + $1.value }
    }

    /// Sagt, was die Summe umfasst — und wenn sie unvollständig ist, dass sie
    /// es ist. Eine Jahressumme, die im Mai endet, sieht sonst aus wie ein Jahr.
    private var totalCaption: String {
        let complete = buckets.filter(\.hasData).allSatisfy(\.isComplete)
        let base = granularity == .year ? "\(today.year)" : "\(today.year), zusammen"
        return complete ? base : base + " · unvollständig"
    }

    // MARK: - Beschriftung

    private static let monthsShort = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private static let monthsLong = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                                     "Juli", "August", "September", "Oktober", "November", "Dezember"]

    private func shortSlotName(_ slot: Int) -> String {
        switch granularity {
        case .month: return Self.monthsShort[safe: slot - 1] ?? "\(slot)"
        case .quarter: return "Q\(slot)"
        case .year: return "\(today.year)"
        }
    }

    private func slotName(_ slot: Int) -> String {
        switch granularity {
        case .month: return Self.monthsLong[safe: slot - 1] ?? "\(slot)"
        case .quarter: return "\(slot). Quartal"
        case .year: return "Gesamtes Jahr"
        }
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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(readings.reversed()) { reading in
                    HStack {
                        Text(germanDate(reading.day))
                            .font(PulseText.detail)
                            .foregroundStyle(PulseColor.inkSecondary)
                        Spacer(minLength: 10)
                        Text("\(number(reading.value)) \(unit)")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(PulseColor.ink)
                    }
                }
            }
            .navigationTitle("Ablesungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
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
