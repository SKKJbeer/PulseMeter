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
    @State private var remindersOn = false
    @State private var reminderNote: String?
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

                    if !meters.isEmpty { reminderSection }

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



    /// Erinnerungen — der Grund, warum jemand in drei Monaten noch da ist.
    ///
    /// Der Schalter steht auf dem Zähler-Schirm und nicht in Einstellungen:
    /// Hier denkt der Nutzer ohnehin gerade über Ableserhythmen nach, und die
    /// Systemfrage nach Erlaubnis wird nur einmal gestellt — sie soll in einem
    /// Moment kommen, in dem klar ist, wofür.
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erinnerungen")
                .font(PulseText.sectionLabel)
                .textCase(.uppercase)
                .foregroundStyle(PulseColor.inkTertiary)
                .padding(.top, 6)

            PulseCard {
                VStack(spacing: 0) {
                    Toggle(isOn: $remindersOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("An fällige Ablesungen erinnern")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(PulseColor.ink)
                            Text("Abends um \(Reminders.hour) Uhr, im Rhythmus jedes Zählers")
                                .font(PulseText.caption)
                                .foregroundStyle(PulseColor.inkTertiary)
                        }
                    }
                    .tint(PulseColor.tint)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .onChange(of: remindersOn) { _, wanted in
                        Task { await toggleReminders(wanted) }
                    }

                    if let reminderNote {
                        Divider().overlay(PulseColor.hairline)
                        Text(reminderNote)
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
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

    // MARK: - Erinnerungen

    private func toggleReminders(_ wanted: Bool) async {
        guard wanted else {
            Reminders.cancelAll()
            reminderNote = nil
            return
        }

        let status = await Reminders.authorizationStatus()
        if status == .notDetermined {
            guard await Reminders.requestPermission() else {
                remindersOn = false
                reminderNote = "Ohne Erlaubnis für Mitteilungen geht das nicht."
                return
            }
        } else if status == .denied {
            remindersOn = false
            // Ehrlich benennen, was zu tun ist: iOS fragt kein zweites Mal,
            // und ein Schalter, der wortlos zurückspringt, sieht kaputt aus.
            reminderNote = "Mitteilungen sind für PulseMeter ausgeschaltet. Das lässt sich nur in den Einstellungen des Geräts ändern."
            return
        }

        await scheduleReminders()
    }

    private func scheduleReminders() async {
        do {
            let repository = PulseRepository(context: context)
            var byMeter: [MeteringPoint.ID: [Reading]] = [:]
            for point in meters {
                guard let register = point.primaryRegister else { continue }
                byMeter[point.id] = try repository.readings(for: register.id)
            }
            await Reminders.reschedule(meteringPoints: meters, readings: byMeter,
                                       today: CalendarDay.containing(Date(), in: .current))
            let count = await Reminders.pendingCount()
            reminderNote = count == 1 ? "Eine Erinnerung steht bereit."
                                      : "\(count) Erinnerungen stehen bereit."
        } catch {
            reminderNote = "Die Erinnerungen ließen sich nicht planen."
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
    // Preise. Als Text, nicht als Zahl: Ein leeres Feld ist etwas anderes als
    // eine Null, und `TextField` mit `Decimal` macht daraus stillschweigend
    // dasselbe.
    @State private var pricePerUnit = ""
    @State private var monthlyBasePrice = ""
    @State private var stateNumber = ""
    @State private var calorificValue = ""
    @State private var existingTariff: Tariff?
    @State private var prepayment = ""
    @State private var billingMonth = 1
    @State private var existingPeriod: BillingPeriod?
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

                priceSection

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

    /// Preise sind freiwillig.
    ///
    /// Ohne sie funktioniert die App vollständig — Verbrauch braucht keinen
    /// Tarif. Wer die Kosten sehen will, trägt zwei Zahlen von seiner Rechnung
    /// ab. Deshalb steht dieser Abschnitt unten und nicht oben, und deshalb
    /// blockiert ein leeres Feld nichts.
    @ViewBuilder
    private var priceSection: some View {
        Section {
            HStack {
                Text("Arbeitspreis")
                Spacer(minLength: 10)
                TextField("0,00", text: $pricePerUnit)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                Text("€/\(billingUnitSymbol)")
                    .foregroundStyle(PulseColor.inkTertiary)
            }
            HStack {
                Text("Grundpreis")
                Spacer(minLength: 10)
                TextField("0,00", text: $monthlyBasePrice)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                Text("€/Monat")
                    .foregroundStyle(PulseColor.inkTertiary)
            }

            // Gas wird in m³ gemessen und in kWh abgerechnet. Ohne diese
            // beiden Zahlen von der Rechnung lässt sich aus dem Zählerstand
            // kein Betrag bilden — und die App rät nicht.
            if needsGasConversion {
                HStack {
                    Text("Zustandszahl")
                    Spacer(minLength: 10)
                    TextField("0,95", text: $stateNumber)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                }
                HStack {
                    Text("Brennwert")
                    Spacer(minLength: 10)
                    TextField("10,5", text: $calorificValue)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                    Text("kWh/m³")
                        .foregroundStyle(PulseColor.inkTertiary)
                }
            }
            HStack {
                Text("Abschlag")
                Spacer(minLength: 10)
                TextField("0,00", text: $prepayment)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                Text("€/Monat")
                    .foregroundStyle(PulseColor.inkTertiary)
            }
            if !prepayment.isEmpty {
                Picker("Abrechnungsjahr ab", selection: $billingMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Self.monthNames[month - 1]).tag(month)
                    }
                }
            }
        } header: {
            Text("Preise")
        } footer: {
            Text(needsGasConversion
                 ? "Freiwillig — ohne Preise zeigt die App nur den Verbrauch. Zustandszahl und Brennwert stehen auf deiner Gasrechnung; ohne sie lässt sich aus m³ kein Betrag bilden. Mit dem Abschlag rechnet die App aus, ob am Jahresende ein Guthaben oder eine Nachzahlung zu erwarten ist."
                 : "Freiwillig — ohne Preise zeigt die App nur den Verbrauch. Alle Zahlen stehen auf deiner Jahresrechnung. Mit dem Abschlag rechnet die App aus, ob am Jahresende ein Guthaben oder eine Nachzahlung zu erwarten ist.")
        }
    }

    /// Der Abrechnungsrhythmus aus der Auswahl — nur, wenn ein Abschlag
    /// hinterlegt ist. Ohne Abschlag gibt es nichts gegenzurechnen, und ein
    /// gesetzter Rhythmus würde in der Übersicht Zeiträume erzeugen, die
    /// niemand angefordert hat.
    private var billingCycleFromInput: BillingCycle? {
        guard decimalValue(prepayment) != nil else { return nil }
        return BillingCycle(anchorMonth: billingMonth, anchorDay: 1)
    }

    /// Zähler, die in m³ messen und in kWh abgerechnet werden.
    private var needsGasConversion: Bool { kind == .gas }

    private var billingUnitSymbol: String {
        needsGasConversion ? "kWh" : kind.defaultUnit.symbol
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
        fillBilling(existing)

        // Der zuletzt gültige Tarif. Mehrere Tarife über die Zeit kann der
        // Rechenkern längst; die Oberfläche bearbeitet vorerst nur den
        // aktuellen — ein Preisverlauf ist eine eigene Ansicht.
        let tariff = (try? PulseRepository(context: context).tariffs(for: existing.id))?.last
        existingTariff = tariff
        guard let tariff else { return }
        pricePerUnit = decimalText(tariff.pricePerUnit)
        monthlyBasePrice = decimalText(tariff.monthlyBasePrice)
        if let conversion = tariff.gasConversion {
            stateNumber = decimalText(conversion.stateNumber)
            calorificValue = decimalText(conversion.calorificValue)
        }
    }

    /// Der laufende Abrechnungszeitraum mit seinem Abschlag.
    private func fillBilling(_ existing: MeteringPoint) {
        billingMonth = existing.billingCycle?.anchorMonth ?? 1
        let today = CalendarDay.containing(Date(), in: .current)
        guard let running = existing.currentBillingPeriod(on: today),
              let periods = try? PulseRepository(context: context).billingPeriods(for: existing.id)
        else { return }
        let period = periods.first { $0.range == running }
        existingPeriod = period
        if let amount = period?.monthlyPrepayment {
            prepayment = decimalText(amount)
        }
    }

    /// Legt den laufenden Abrechnungszeitraum an oder ändert ihn.
    ///
    /// Der Zeitraum ergibt sich aus dem Abrechnungsrhythmus des Zählers — der
    /// muss deshalb zuerst gesetzt sein. Ohne Abschlag wird gar keiner
    /// angelegt: Ein Zeitraum ohne Zahl sagt nichts und stünde nur im Weg.
    private func saveBilling(for point: MeteringPoint, in repository: PulseRepository) throws {
        guard let amount = decimalValue(prepayment), amount > 0 else { return }
        let today = CalendarDay.containing(Date(), in: .current)
        guard let running = point.currentBillingPeriod(on: today) else { return }

        try repository.save(BillingPeriod(
            id: existingPeriod?.id ?? UUID(),
            meteringPointID: point.id,
            range: running,
            monthlyPrepayment: amount
        ))
    }

    /// Zahl als Text, mit Komma — so, wie sie eingetippt wird.
    private func decimalText(_ value: Decimal) -> String {
        value == 0 ? "" : "\(value)".replacingOccurrences(of: ".", with: ",")
    }

    /// Text als Zahl. Komma und Punkt gelten beide: Auf einer deutschen
    /// Tastatur kommt das Komma, auf mancher Zehnertastatur der Punkt.
    private func decimalValue(_ text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
                          .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    /// Legt den Tarif an oder ändert ihn — oder entfernt ihn, wenn der Nutzer
    /// die Preise wieder löscht.
    private func saveTariff(for point: MeteringPoint, in repository: PulseRepository) throws {
        let price = decimalValue(pricePerUnit)
        let base = decimalValue(monthlyBasePrice)
        guard price != nil || base != nil else { return }

        let conversion: GasConversion? = needsGasConversion
            ? GasConversion(
                stateNumber: decimalValue(stateNumber) ?? GasConversion.typical.stateNumber,
                calorificValue: decimalValue(calorificValue) ?? GasConversion.typical.calorificValue)
            : nil

        // Gültig ab dem ersten Tag des laufenden Jahres, damit die Kosten des
        // laufenden Jahres sofort einen Tarif haben. Preisänderungen mit
        // eigenem Startdatum folgen mit der Preisverlauf-Ansicht.
        let from = existingTariff?.validFrom
            ?? CalendarDay(year: CalendarDay.containing(Date(), in: .current).year, month: 1, day: 1)
            ?? CalendarDay.containing(Date(), in: .current)

        let tariff = Tariff(
            id: existingTariff?.id ?? UUID(),
            meteringPointID: point.id,
            validFrom: from,
            pricePerUnit: price ?? 0,
            monthlyBasePrice: base ?? 0,
            billingUnit: needsGasConversion ? .kilowattHour : kind.defaultUnit,
            gasConversion: conversion
        )
        try repository.save(tariff)
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
                existing.billingCycle = billingCycleFromInput
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
                try saveTariff(for: existing, in: repository)
                try saveBilling(for: existing, in: repository)
            } else {
                var register = Register.standard(for: kind)
                register.integerDigits = integerDigits
                register.fractionDigits = fractionDigits
                let point = MeteringPoint(
                    propertyID: property.id,
                    name: trimmed,
                    kind: kind,
                    registers: [register],
                    readingInterval: interval,
                    billingCycle: billingCycleFromInput
                )
                try repository.save(point)
                try saveTariff(for: point, in: repository)
                try saveBilling(for: point, in: repository)
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
    static let monthNames = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                             "Juli", "August", "September", "Oktober", "November", "Dezember"]

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
