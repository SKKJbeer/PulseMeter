import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Der dritte Tab: die Zähler selbst anlegen, benennen und einordnen.
///
/// Bis hierher kam man nur über „Beispieldaten anlegen" zu einem Zähler — für
/// eine Vorführung genug, für einen echten Nutzer nicht. Erst mit diesem
/// Schirm ist Produktprinzip 1 erfüllt: 60 Sekunden von der Installation bis
/// zur ersten Ablesung, ohne Konto.
struct MetersView: View {

    @Environment(\.modelContext) private var context

    @State private var meters: [MeteringPoint] = []
    @State private var readingCounts: [MeteringPoint.ID: Int] = [:]
    @State private var lastReadings: [MeteringPoint.ID: Reading] = [:]
    @State private var archived: [MeteringPoint] = []
    @State private var editing: MeterDraft?
    @State private var showingArchived = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    }

                    if meters.isEmpty {
                        emptyState
                    } else {
                        PulseCard {
                            VStack(spacing: 0) {
                                ForEach(Array(meters.enumerated()), id: \.element.id) { index, point in
                                    if index > 0 { Divider().overlay(PulseColor.hairline) }
                                    row(for: point)
                                }
                            }
                        }
                    }

                    Button {
                        editing = MeterDraft()
                    } label: {
                        Label("Zähler hinzufügen", systemImage: "plus")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(PulseColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PulseColor.tint,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if !archived.isEmpty {
                        archivedSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Zähler")
            .onAppear(perform: load)
            .sheet(item: $editing) { draft in
                MeterEditor(draft: draft,
                            readingCount: draft.existing.flatMap { readingCounts[$0.id] } ?? 0,
                            onDone: { load() })
            }
        }
    }

    // MARK: - Bausteine

    private var emptyState: some View {
        PulseCard {
            VStack(spacing: 12) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 32))
                    .foregroundStyle(PulseColor.inkTertiary)
                Text("Noch kein Zähler")
                    .font(PulseText.cardTitle)
                    .foregroundStyle(PulseColor.ink)
                Text("Leg deinen ersten Zähler an — Name und Art genügen, alles andere ist schon passend voreingestellt.")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
        }
    }

    private func row(for point: MeteringPoint) -> some View {
        let accent = PulseColor.resource(point.appearance.colorToken)
        return Button {
            editing = MeterDraft(existing: point)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: point.appearance.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(point.name)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(PulseColor.ink)
                    Text(subtitle(for: point))
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PulseColor.inkTertiary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for point: MeteringPoint) -> String {
        guard let register = point.primaryRegister else { return "Ohne Ablesestelle" }
        guard let last = lastReadings[point.id] else { return "Noch keine Ablesung" }
        return "\(number(last.value, digits: register.fractionDigits)) \(register.unit.symbol) am \(germanDate(last.day))"
    }



    /// Archivierte Zähler bleiben erreichbar, nur nicht im Weg.
    ///
    /// Sie zu löschen nähme ihre gesamte Ablesehistorie mit — deshalb ist
    /// Archivieren der normale Weg und Löschen der ausdrückliche.
    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showingArchived.toggle()
            } label: {
                HStack {
                    Text("Archiviert (\(archived.count))")
                        .font(PulseText.sectionLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(PulseColor.inkTertiary)
                    Image(systemName: showingArchived ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PulseColor.inkTertiary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            if showingArchived {
                PulseCard {
                    VStack(spacing: 0) {
                        ForEach(Array(archived.enumerated()), id: \.element.id) { index, point in
                            if index > 0 { Divider().overlay(PulseColor.hairline) }
                            row(for: point)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Daten

    private func load() {
        do {
            let repository = PulseRepository(context: context)
            meters = try repository.meteringPoints()
            archived = try repository.meteringPoints(includeArchived: true).filter(\.isArchived)
            readingCounts = [:]
            lastReadings = [:]
            for point in meters + archived {
                guard let register = point.primaryRegister else { continue }
                let readings = try repository.readings(for: register.id)
                readingCounts[point.id] = readings.count
                lastReadings[point.id] = readings.last
            }
        } catch {
            problem = "Die Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatierung

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

/// Was gerade bearbeitet wird — ein neuer Zähler oder ein vorhandener.
struct MeterDraft: Identifiable {
    let id = UUID()
    var existing: MeteringPoint?

    init(existing: MeteringPoint? = nil) {
        self.existing = existing
    }
}

/// Anlegen und Bearbeiten eines Zählers.
///
/// Name und Art stehen oben und genügen; alles darunter ist bereits passend
/// vorbelegt. Wer nur schnell einen Stromzähler braucht, tippt zwei Felder und
/// ist fertig (Produktprinzip 1).
struct MeterEditor: View {

    let draft: MeterDraft
    let readingCount: Int
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: ResourceKind = .electricity
    @State private var interval: ReadingInterval = .monthly
    @State private var integerDigits = 6
    @State private var fractionDigits = 1
    @State private var confirmingDelete = false
    @State private var problem: String?

    /// Die Arten, die zur Auswahl stehen. `custom` fehlt bewusst: Ein eigener
    /// Zähler braucht eine Einheit, und die Auswahl einer Einheit ist ein
    /// eigener Schritt, der hier alles andere überlagern würde.
    private static let kinds: [ResourceKind] = [
        .electricity, .water, .hotWater, .gas, .districtHeating, .heatingOil,
        .solarProduction, .wallbox, .batteryStorage, .rainwater, .operatingHours
    ]

    private var isNew: Bool { draft.existing == nil }

    /// Die Art bestimmt Einheit und Stellen. Sie nachträglich zu ändern, wenn
    /// schon Ablesungen vorliegen, würde deren Einheit stillschweigend
    /// umdeuten — aus 8.285 m³ Gas würden 8.285 kWh Strom. Deshalb nur
    /// änderbar, solange nichts abgelesen wurde.
    private var canChangeKind: Bool { readingCount == 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .font(.system(.body))
                } header: {
                    Text("Name")
                } footer: {
                    Text("So heißt der Zähler in der Übersicht — „Strom“, „Gas Keller“, „Wohnung oben“.")
                }

                Section {
                    if canChangeKind {
                        Picker("Art", selection: $kind) {
                            ForEach(Self.kinds, id: \.storageID) { option in
                                Label(Self.kindName(option), systemImage: Appearance.standard(for: option).symbolName)
                                    .tag(option)
                            }
                        }
                        .onChange(of: kind) { _, newKind in
                            // Stellen an die neue Art anpassen, solange der
                            // Nutzer sie nicht selbst verstellt hat.
                            integerDigits = newKind.defaultIntegerDigits
                            fractionDigits = newKind.defaultFractionDigits
                        }
                    } else {
                        HStack {
                            Text("Art")
                            Spacer()
                            Text(Self.kindName(kind))
                                .foregroundStyle(PulseColor.inkSecondary)
                        }
                    }
                } header: {
                    Text("Art")
                } footer: {
                    Text(canChangeKind
                         ? "Legt Einheit und Aussehen fest."
                         : "Die Art lässt sich nicht mehr ändern, weil für diesen Zähler schon \(readingCount) Ablesungen vorliegen — sie sind in \(kind.defaultUnit.symbol) erfasst.")
                }

                Section {
                    Picker("Wie oft ablesen?", selection: $interval) {
                        Text("Wöchentlich").tag(ReadingInterval.weekly)
                        Text("Monatlich").tag(ReadingInterval.monthly)
                        Text("Vierteljährlich").tag(ReadingInterval.quarterly)
                        Text("Jährlich").tag(ReadingInterval.yearly)
                        Text("Ohne Erinnerung").tag(ReadingInterval.never)
                    }
                } footer: {
                    Text("Daraus ergibt sich, wann die Übersicht einen Zähler als fällig meldet.")
                }

                Section {
                    Stepper("Ziffern vor dem Komma: \(integerDigits)",
                            value: $integerDigits, in: 1...9)
                    Stepper("Ziffern nach dem Komma: \(fractionDigits)",
                            value: $fractionDigits, in: 0...4)
                } header: {
                    Text("Anzeige am Gerät")
                } footer: {
                    Text("So viele Stellen zeigt das Gerät. Die Eingabe sieht dann genauso aus wie der Zähler im Keller.")
                }

                if let existing = draft.existing {
                    Section {
                        Button(existing.isArchived ? "Aus dem Archiv holen" : "Archivieren") {
                            setArchived(!existing.isArchived, on: existing)
                        }
                        Button("Zähler und alle Ablesungen löschen", role: .destructive) {
                            confirmingDelete = true
                        }
                    } footer: {
                        Text("Archivieren nimmt den Zähler aus der Übersicht und behält alles. Löschen entfernt auch die \(readingCount) Ablesungen — das lässt sich nicht rückgängig machen.")
                    }
                }

                if let problem {
                    Section {
                        Text(problem).foregroundStyle(PulseColor.adverse)
                    }
                }
            }
            .navigationTitle(isNew ? "Neuer Zähler" : "Zähler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Wirklich löschen?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { deletePermanently() }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Der Zähler und seine \(readingCount) Ablesungen werden entfernt.")
            }
            .onAppear(perform: fill)
        }
    }

    // MARK: - Daten

    private func fill() {
        guard let existing = draft.existing else { return }
        name = existing.name
        kind = existing.kind
        interval = existing.readingInterval
        if let register = existing.primaryRegister {
            integerDigits = register.integerDigits
            fractionDigits = register.fractionDigits
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let repository = PulseRepository(context: context)
            let property = try repository.ensureDefaultProperty()

            if var existing = draft.existing {
                existing.name = trimmed
                existing.readingInterval = interval
                if canChangeKind {
                    existing.kind = kind
                    existing.appearance = .standard(for: kind)
                }
                // Die Kennung des Zählwerks bleibt erhalten — sie hängt an
                // jeder Ablesung. Nur die Darstellung ändert sich.
                if var register = existing.registers.first {
                    register.integerDigits = integerDigits
                    register.fractionDigits = fractionDigits
                    if canChangeKind { register.unit = kind.defaultUnit }
                    existing.registers[0] = register
                }
                try repository.save(existing)
            } else {
                var register = Register.standard(for: kind)
                register.integerDigits = integerDigits
                register.fractionDigits = fractionDigits
                let point = MeteringPoint(
                    propertyID: property.id,
                    name: trimmed,
                    kind: kind,
                    registers: [register],
                    readingInterval: interval
                )
                try repository.save(point)
            }
            onDone()
            dismiss()
        } catch {
            problem = "Der Zähler ließ sich nicht sichern: \(error.localizedDescription)"
        }
    }

    private func setArchived(_ archived: Bool, on point: MeteringPoint) {
        do {
            let repository = PulseRepository(context: context)
            if archived {
                try repository.archive(meteringPointID: point.id)
            } else {
                var restored = point
                restored.isArchived = false
                try repository.save(restored)
            }
            onDone()
            dismiss()
        } catch {
            problem = "Das ließ sich nicht ändern: \(error.localizedDescription)"
        }
    }

    private func deletePermanently() {
        guard let existing = draft.existing else { return }
        do {
            try PulseRepository(context: context).deletePermanently(meteringPointID: existing.id)
            onDone()
            dismiss()
        } catch {
            problem = "Der Zähler ließ sich nicht löschen: \(error.localizedDescription)"
        }
    }

    // MARK: - Beschriftung

    /// Deutsche Namen der Arten. Sie stehen hier und nicht in `PulseCore`,
    /// weil der Rechenkern keine Oberflächensprache kennt.
    static func kindName(_ kind: ResourceKind) -> String {
        switch kind {
        case .electricity:      return "Strom"
        case .water:            return "Wasser"
        case .hotWater:         return "Warmwasser"
        case .gas:              return "Gas"
        case .districtHeating:  return "Fernwärme"
        case .heatingOil:       return "Heizöl"
        case .solarProduction:  return "Photovoltaik"
        case .wallbox:          return "Wallbox"
        case .batteryStorage:   return "Batteriespeicher"
        case .operatingHours:   return "Betriebsstunden"
        case .rainwater:        return "Regenwasser"
        case .custom(let name, _): return name
        }
    }
}
