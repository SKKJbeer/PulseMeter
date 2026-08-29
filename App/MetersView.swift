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
    @Environment(Purchase.self) private var purchase
    @Environment(Datenstand.self) private var datenstand

    @State private var meters: [MeteringPoint] = []
    @State private var showingPaywall = false
    @State private var showingStore = false
    @State private var readingCounts: [MeteringPoint.ID: Int] = [:]
    @State private var lastReadings: [MeteringPoint.ID: Reading] = [:]
    @State private var archived: [MeteringPoint] = []
    @State private var editing: MeterDraft?
    @State private var showingArchived = false
    @State private var remindersOn = false
    @State private var reminderNote: String?
    @State private var paywallErinnerung = false
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

                    // **Der Knopf bleibt derselbe, auch wenn die Grenze
                    // erreicht ist.** Er führt dann zur Kaufseite statt zum
                    // Formular. Ihn auszugrauen wäre die schlechtere Lösung:
                    // Der Nutzer sähe, dass es nicht geht, aber nicht, warum —
                    // und Produktprinzip 4 verbietet genau diese Sackgasse.
                    Button {
                        if canAddMeter {
                            editing = MeterDraft()
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("Zähler hinzufügen",
                              systemImage: canAddMeter ? "plus" : "lock")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(PulseColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PulseColor.tint,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(canAddMeter
                                       ? "Öffnet das Formular für einen neuen Zähler"
                                       : "Kostenlos sind \(AccessPolicy.freeMeterLimit) Zähler. Doppeltippen, um die Freischaltungen anzusehen")

                    if let note = limitNote {
                        Text(note)
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if !meters.isEmpty { reminderSection }

                    if !archived.isEmpty {
                        archivedSection
                    }

                    freischaltenSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Zähler")
            .onAppear {
                load()
                // Nur für die Bildschirmfotos: Die Kaufseite ist der einzige
                // Schirm, den ein automatischer Lauf nie erreicht — `simctl`
                // kann nicht tippen —, und zugleich der, bei dem am meisten
                // davon abhängt, wie er wirkt.
                if Startschalter.gesetzt("-pulse-kaufen") {
                    showingPaywall = true
                }
            }
            // Ein gelöschter oder umbenannter Zähler ändert die Übersicht
            // mit; ein hier eingetragener Stand ändert diese Liste.
            .onChange(of: datenstand.version) { _, _ in load() }
            .sheet(item: $editing) { draft in
                MeterEditor(draft: draft,
                            readingCount: draft.existing.flatMap { readingCounts[$0.id] } ?? 0,
                            onDone: { datenstand.geaendert() })
            }
            .sheet(isPresented: $showingPaywall) {
                UnlockSheet(product: .additionalMeters)
            }
            .sheet(isPresented: $paywallErinnerung) {
                UnlockSheet(product: .reminders)
            }
            .sheet(isPresented: $showingStore) {
                StoreView()
            }
        }
    }

    /// Ob noch ein Zähler dazu darf.
    ///
    /// **Archivierte zählen mit.** Sie sind nicht gelöscht, ihre Ablesungen
    /// liegen vollständig vor, und sie lassen sich mit einem Tipp zurückholen.
    /// Zählten sie nicht, wäre Archivieren ein Weg um die Grenze herum — und
    /// wer zwei archivierte zurückholt, stünde ohne Vorwarnung darüber.
    private var canAddMeter: Bool {
        purchase.canAddMeter(existingCount: meters.count + archived.count)
    }

    /// Der Satz unter dem Knopf, oder keiner.
    ///
    /// Erscheint erst ab dem ersten Zähler: Wer noch keinen hat, braucht keine
    /// Auskunft über eine Grenze, die er nicht sieht — er braucht seinen ersten
    /// Zähler (Produktprinzip 1).
    private var limitNote: String? {
        let total = meters.count + archived.count
        guard let remaining = purchase.policy.remainingMeters(existingCount: total),
              total > 0 else { return nil }
        switch remaining {
        case 0:  return "Kostenlos sind \(AccessPolicy.freeMeterLimit) Zähler. Freigeschaltet werden es beliebig viele."
        case 1:  return "Noch ein Zähler ist kostenlos."
        default: return "Noch \(remaining) Zähler sind kostenlos."
        }
    }

    // MARK: - Bausteine

    private var emptyState: some View {
        PulseCard {
            VStack(spacing: 12) {
                Image(systemName: "gauge.medium")
                    .accessibilityHidden(true)
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
                    .accessibilityHidden(true)
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
                    .accessibilityHidden(true)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PulseColor.inkTertiary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            // **Ohne das ist nur die Schrift antippbar.** Ein Knopf mit
            // `.plain` reicht so weit wie das, was er zeichnet — der Abstand
            // zwischen Name und Pfeil zeichnet nichts. Bei „Strom" sind das
            // zwei Drittel der Zeile, die nicht reagieren, und wer dort tippt,
            // tippt ein zweites und drittes Mal. Genau so gemeldet.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Name und letzter Stand als ein Satz; die beiden Symbole tragen
        // nichts bei, was der Text nicht schon sagt.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(point.name), \(subtitle(for: point))")
        .accessibilityHint("Öffnet die Einstellungen dieses Zählers")
        .accessibilityAddTraits(.isButton)
    }

    private func subtitle(for point: MeteringPoint) -> String {
        guard let register = point.primaryRegister else { return "Ohne Ablesestelle" }
        guard let last = lastReadings[point.id] else { return "Noch keine Ablesung" }
        return "\(number(last.value, digits: register.fractionDigits)) \(register.unit.symbol) am \(germanDate(last.day))"
    }



    /// Der Weg zur Kaufübersicht — eine Zeile, ganz unten, ohne Werbung.
    ///
    /// **Warum hier und nicht als vierter Tab.** Ein Tab ist ein Ort, an dem
    /// man ständig vorbeikommt; ein Laden gehört dorthin nicht. Diese Zeile
    /// steht am Ende des Zähler-Schirms, dort, wo ohnehin die Einstellungen
    /// stehen — sichtbar für den, der sucht, und stumm für alle anderen.
    ///
    /// Sie sagt außerdem, wie viel schon freigeschaltet ist. Wer alles hat,
    /// soll das sehen und nicht noch einmal auf ein Angebot stoßen.
    private var freischaltenSection: some View {
        // **Ohne Abschnittsüberschrift.** Über der Zeile stand „FREISCHALTEN",
        // in der Zeile steht seit 0.94.0 dasselbe Wort noch einmal. Zweimal
        // dasselbe ist nicht doppelt so deutlich, sondern nur doppelt. Die
        // Zeile sagt es jetzt in ganzen Worten und braucht niemanden mehr, der
        // sie ankündigt.
        VStack(alignment: .leading, spacing: 8) {
            PulseCard {
                Button {
                    showingStore = true
                } label: {
                    HStack(spacing: 11) {
                        // **Ein Einkaufssymbol, weil die Zeile ein Laden ist.**
                        // Vom Gründer verlangt. Ohne Zeichen liest sich die
                        // Zeile wie eine weitere Einstellung; mit dem Wagen
                        // sieht man in einer Zehntelsekunde, worum es geht.
                        Image(systemName: "cart")
                            .accessibilityHidden(true)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PulseColor.tintInk)
                            .frame(width: 20, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alle Funktionen freischalten")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(PulseColor.ink)
                            Text(freischaltStand)
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("freischalten-zeile")
            // Den Abstand, den vorher die Überschrift mitbrachte, behält die
            // Zeile: Sie soll weiter als eigener Block stehen, nicht als
            // vierte Zeile der Erinnerungen darüber.
            .padding(.top, 6)
            .accessibilityHint("Zeigt alle Freischaltungen mit Preisen")
        }
    }

    /// Wie viel schon freigeschaltet ist — gezählt, nicht behauptet.
    private var freischaltStand: String {
        let offen = ProductID.individually.filter { !purchase.allows($0) }
        if offen.isEmpty { return "Alles freigeschaltet" }
        if offen.count == ProductID.individually.count {
            return "\(offen.count) Freischaltungen ab \(guenstigste)"
        }
        return "Noch \(offen.count) von \(ProductID.individually.count) offen"
    }

    private var guenstigste: String {
        let kleinster = ProductID.individually.map(\.suggestedPrice).min() ?? 0
        return kleinster.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
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

            // **Ungekauft steht hier eine Zeile statt eines toten Schalters.**
            // Ein ausgegrauter Schalter sagt nur, dass etwas nicht geht; diese
            // Zeile sagt, was es ist und was es kostet — und führt dorthin.
            if !purchase.policy.canRemind {
                PulseCard {
                    ProLockRow(product: .reminders) {
                        paywallErinnerung = true
                    }
                }
            } else {
                reminderCard
            }
        }
    }

    private var reminderCard: some View {
        Group {
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
                        .accessibilityHidden(true)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PulseColor.inkTertiary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Ob die Klappe offen ist, sagte allein der Pfeil — und der ist
            // jetzt zu Recht für VoiceOver ausgeblendet, weil er sonst als
            // „chevron.down" vorgelesen würde. Die Auskunft gehört damit an
            // den Knopf selbst, sonst tippt man ins Ungewisse.
            .accessibilityValue(showingArchived ? "ausgeklappt" : "eingeklappt")
            .accessibilityHint(showingArchived
                               ? "Doppeltippen, um die archivierten Zähler zu verbergen"
                               : "Doppeltippen, um die archivierten Zähler zu zeigen")
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
            // Zählen und den letzten Stand holen, statt alles zu laden: Die
            // Liste zeigt je Zähler eine Zahl und ein Datum. Bis 0.72.1 lud
            // sie dafür jede Ablesung jedes Zählers — der Schirm wurde
            // langsamer, je länger jemand die App benutzt.
            for point in meters + archived {
                guard let register = point.primaryRegister else { continue }
                readingCounts[point.id] = try repository.readingCount(for: register.id)
                lastReadings[point.id] = try repository.lastReading(for: register.id)
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
            reminderNote = "Mitteilungen sind für Zählora ausgeschaltet. Das lässt sich nur in den Einstellungen des Geräts ändern."
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
                                       today: CalendarDay.containing(Date(), in: .current),
                                       darfErinnern: purchase.policy.canRemind)
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
    @Environment(Purchase.self) private var purchase

    /// Welche Sperre die Kaufseite geöffnet hat, oder `nil`.
    ///
    /// **Ein Zustand, nicht zwei.** Hier standen bis 0.93.2 ein Schalter und
    /// daneben das Produkt, mit der Begründung, `ProductID` liege im Rechenkern
    /// und dürfe von der Oberfläche nichts erben. Die Begründung trug nicht:
    /// `Identifiable` steht in der Standardbibliothek, nicht in SwiftUI.
    ///
    /// Und sie war teuer. In der gleichen Bauart im Verlauf ging das Blatt mit
    /// dem Produkt auf, das vor dem Tipp dastand — sichtbar der falsche Kauf.
    /// Zwei Zustände für eine Sache geraten aus dem Takt; einer kann das nicht.
    @State private var paywallReason: ProductID?

    @State private var name = ""
    @State private var kind: ResourceKind = .electricity
    @State private var interval: ReadingInterval = .monthly
    @State private var integerDigits = 6
    @State private var fractionDigits = 1
    @State private var confirmingDelete = false
    @State private var changingMeter = false
    // Preise. Als Text, nicht als Zahl: Ein leeres Feld ist etwas anderes als
    // eine Null, und `TextField` mit `Decimal` macht daraus stillschweigend
    // dasselbe.
    @State private var pricePerUnit = ""
    @State private var monthlyBasePrice = ""
    @State private var stateNumber = ""
    @State private var calorificValue = ""
    @State private var existingTariff: Tariff?
    /// Alle hinterlegten Tarife. Bei Doppeltarif hängt an jedem Zählwerk einer,
    /// und beim Sichern müssen ihre Kennungen erhalten bleiben — sonst entstünde
    /// bei jedem Speichern ein neuer Tarif neben dem alten.
    @State private var existingTariffs: [Tariff] = []
    /// Ob der Zähler auch in die andere Richtung zählt.
    ///
    /// Nur bei Strom sichtbar. Der Rechenkern kann Zweirichtungszähler seit
    /// dem ersten Tag — bis 0.22.0 gab es nur keine Möglichkeit, einen
    /// anzulegen, und ein Haushalt mit Photovoltaik konnte seinen Zähler
    /// deshalb gar nicht abbilden.
    @State private var hasFeedIn = false
    /// Ob für die Einspeisung schon Werte vorliegen. Dann darf sie nicht mehr
    /// abgeschaltet werden — die Ablesungen hingen sonst an einem Zählwerk,
    /// das es nicht mehr gibt.
    @State private var feedInHasReadings = false
    @State private var feedInPrice = ""
    /// Ob der Zähler zwei Arbeitspreise hat — Hochtarif und Niedertarif.
    ///
    /// Der klassische Nachtspeicher- oder Wärmepumpentarif. Ein Gerät, zwei
    /// Zahlen — dasselbe Modell wie beim Zweirichtungszähler, nur zählen hier
    /// beide Zählwerke Bezug. Der Rechenkern kann das seit dem ersten Tag; bis
    /// 0.31.0 gab es nur keine Möglichkeit, so einen Zähler anzulegen.
    @State private var hasDualTariff = false
    /// Ob für den Niedertarif schon Werte vorliegen. Dann darf er nicht mehr
    /// abgeschaltet werden — dieselbe Regel wie bei der Einspeisung.
    @State private var lowTariffHasReadings = false
    @State private var lowTariffPrice = ""
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

    /// Ob dieser Zähler zwei Zahlen führen darf.
    ///
    /// Pro darf immer. Ohne Pro darf, wer es **schon** tut: Ein Zähler mit
    /// Nachtstrom oder Einspeisung behält seine Schalter, sonst verschwände
    /// mit dem Schalter auch der Weg, die vorhandenen Werte zu verstehen.
    private var canUseMultipleRegisters: Bool {
        purchase.allows(.multipleRegisters) || (draft.existing?.registers.count ?? 0) > 1
    }

    /// Dieselbe Regel für die Preise: Wer schon einen Tarif hat, behält ihn.
    ///
    /// Sonst stünden auf der Übersichtskarte Beträge, die sich nicht mehr
    /// nachsehen und nicht mehr berichtigen ließen — eine Sackgasse
    /// (Produktprinzip 4).
    private var canUseTariffs: Bool {
        purchase.allows(.costsAndTariffs) || existingTariff != nil || !existingTariffs.isEmpty
    }

    private func openPaywall(_ product: ProductID) {
        paywallReason = product
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .font(.system(.body))
                } header: {
                    Text("Name")
                } footer: {
                    Text("So heißt der Zähler in der Übersicht: „Strom“, „Gas“, „Wohnung oben“.")
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
                    Text("So viele Stellen zeigt das Gerät. Die Eingabe sieht dann genauso aus wie der Zähler selbst.")
                }

                if kind == .electricity {
                    // **Ein Gerät mit zwei Zahlen darauf ist Pro** — es sei
                    // denn, es hat sie schon. Wer den Nachtstrom vor dem Kauf
                    // angelegt hat oder ihn aus iCloud zurückbekommt, behält
                    // ihn samt Schalter; die Grenze greift beim Anlegen, nie
                    // beim Behalten (Produktprinzip 5).
                    if canUseMultipleRegisters {
                        Section {
                            Toggle("Zwei Preise: Tag und Nacht", isOn: $hasDualTariff)
                                .disabled(hasDualTariff && lowTariffHasReadings)
                        } header: {
                            Text("Tag- und Nachtstrom")
                        } footer: {
                            // Weder „Doppeltarif" noch „HT/NT": Beides sind Wörter
                            // von der Rechnung, nicht aus dem Kopf des Nutzers.
                            // Er weiß, dass sein Strom nachts weniger kostet.
                            Text(hasDualTariff && lowTariffHasReadings
                                 ? "Für den Nachtstrom liegen bereits Ablesungen vor. Er lässt sich deshalb nicht mehr abschalten — die Werte gingen sonst verloren."
                                 : "Für Zähler mit getrennten Preisen für Tag und Nacht. Beim Eintragen fragt die App dann nach beiden Zahlen.")
                        }

                        Section {
                            Toggle("Einspeisung ins Netz", isOn: $hasFeedIn)
                                .disabled(hasFeedIn && feedInHasReadings)
                        } header: {
                            Text("Photovoltaik")
                        } footer: {
                            // Kein Wort über Zählwerke: Der Nutzer sieht ein Gerät
                            // mit zwei Zahlen darauf, und genau so wird es
                            // beschrieben (Produktprinzip 6).
                            Text(hasFeedIn && feedInHasReadings
                                 ? "Für die Einspeisung liegen bereits Ablesungen vor. Sie lässt sich deshalb nicht mehr abschalten — die Werte gingen sonst verloren."
                                 : "Für Zähler, die in beide Richtungen zählen. Beim Eintragen fragt die App dann nach beiden Zahlen — erst Bezug, dann Einspeisung.")
                        }
                    } else {
                        Section {
                            ProLockRow(product: .multipleRegisters) {
                                openPaywall(.multipleRegisters)
                            }
                        } header: {
                            Text("Tag- und Nachtstrom, Photovoltaik")
                        }
                    }
                }

                priceSection

                // Zweiter Einstieg zum Wechsel: Der erste sitzt im
                // Erfassungsschirm und erscheint erst, wenn der neue Stand
                // unter dem alten liegt. Wer den Wechsel vorher eintragen
                // will — etwa weil der Monteur gerade da war —, findet ihn
                // sonst nirgends.
                if let existing = draft.existing, readingCount > 0 {
                    Section {
                        Button("Zähler wurde gewechselt") { changingMeter = true }
                        if let device = existing.devices.first(where: \.isActive),
                           let serial = device.serialNumber {
                            HStack {
                                Text("Gerätenummer")
                                Spacer()
                                Text(serial).foregroundStyle(PulseColor.inkSecondary)
                            }
                        }
                    } footer: {
                        Text("Beim Wechsel werden Endstand und Anfangsstand erfasst. Der Verbrauch bis zum Wechseltag bleibt erhalten, und der Rücksprung gilt als erklärt.")
                    }
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
            .sheet(isPresented: $changingMeter) {
                if let existing = draft.existing {
                    MeterChangeView(meteringPoint: existing) {
                        onDone()
                        dismiss()
                    }
                }
            }
            .sheet(item: $paywallReason) { produkt in
                UnlockSheet(product: produkt)
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
        if !canUseTariffs {
            // **Eine Sperre statt eines fehlenden Abschnitts.** Versteckt man
            // „Preise" ganz, vermisst niemand sie — und niemand kauft. Die
            // Zeile sagt, was es gibt und was es bringt, und führt mit einem
            // Tipp zur Kaufseite.
            //
            // Der Abschlagsvergleich hängt mit dran: Ohne Preise gibt es
            // nichts, wogegen sich ein Abschlag rechnen ließe. Zwei getrennte
            // Sperren wären zwei Schlösser an derselben Tür.
            Section {
                ProLockRow(product: .costsAndTariffs) {
                    openPaywall(.costsAndTariffs)
                }
            } header: {
                Text("Preise")
            } footer: {
                Text("Ohne Preise zeigt die App den Verbrauch — vollständig und unbegrenzt. Beträge, Abschlagsvergleich und die Vorschau aufs Jahresende kommen mit Pro dazu.")
            }
        } else {
            tariffFields
        }
    }

    /// **Brutto, und das muss dastehen.**
    ///
    /// Der Rechenkern erwartet Bruttopreise. Auf einer deutschen Rechnung steht
    /// der **Netto**-Arbeitspreis oft größer und weiter oben als der Brutto —
    /// wer ihn abschreibt, bekommt dauerhaft rund ein Fünftel zu niedrige
    /// Kosten. Nachgerechnet: 3000 kWh zu 0,34 € brutto sind 1020 €; mit
    /// derselben Zahl netto (0,2857 €) nur 857 €. **163 € zu wenig**, ein Jahr
    /// lang, und die App kann es nicht bemerken — ihr fehlt jede Handhabe, aus
    /// einer Zahl zu erkennen, ob Steuer darin steckt.
    ///
    /// Deshalb steht es am Feld und nicht nur in der Fußzeile: Wer den Preis
    /// eintippt, hat die Fußzeile schon hinter sich.
    private var grossHint: String { " (brutto)" }

    @ViewBuilder
    private var tariffFields: some View {
        Section {
            numberRow((hasDualTariff && kind == .electricity ? "Arbeitspreis tagsüber" : "Arbeitspreis") + grossHint,
                      unit: "€/\(billingUnitSymbol)", spokenUnit: "Euro je \(billingUnitSymbol)",
                      text: $pricePerUnit)
            numberRow("Grundpreis" + grossHint, unit: "€/Monat", spokenUnit: "Euro je Monat",
                      text: $monthlyBasePrice)

            if hasDualTariff && kind == .electricity {
                numberRow("Arbeitspreis nachts" + grossHint,
                          unit: "€/kWh", spokenUnit: "Euro je Kilowattstunde",
                          text: $lowTariffPrice)
            }

            if hasFeedIn && kind == .electricity {
                // Ohne Zusatz: Die Einspeisevergütung ist für private Anlagen
                // in aller Regel ein Nettobetrag ohne Umsatzsteuer, und
                // „brutto" daneben wäre hier die falsche Ansage.
                numberRow("Einspeisevergütung", unit: "€/kWh", spokenUnit: "Euro je Kilowattstunde",
                          text: $feedInPrice)
            }

            // Gas wird in m³ gemessen und in kWh abgerechnet. Ohne diese
            // beiden Zahlen von der Rechnung lässt sich aus dem Zählerstand
            // kein Betrag bilden — und die App rät nicht.
            if needsGasConversion {
                numberRow("Zustandszahl", unit: nil, spokenUnit: nil,
                          placeholder: "0,95", text: $stateNumber)
                numberRow("Brennwert", unit: "kWh/m³", spokenUnit: "Kilowattstunden je Kubikmeter",
                          placeholder: "10,5", text: $calorificValue)
            }
            numberRow("Abschlag", unit: "€/Monat", spokenUnit: "Euro je Monat", text: $prepayment)
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
                 ? "Freiwillig — ohne Preise zeigt die App nur den Verbrauch. Nimm die Preise inklusive Mehrwertsteuer — der Nettopreis steht auf der Rechnung oft daneben und ist rund ein Fünftel kleiner. Zustandszahl und Brennwert stehen ebenfalls auf deiner Gasrechnung; ohne sie lässt sich aus m³ kein Betrag bilden. Mit dem Abschlag rechnet die App aus, ob am Jahresende ein Guthaben oder eine Nachzahlung zu erwarten ist."
                 : "Freiwillig — ohne Preise zeigt die App nur den Verbrauch. Nimm die Preise inklusive Mehrwertsteuer — der Nettopreis steht auf der Rechnung oft daneben und ist rund ein Fünftel kleiner. Mit dem Abschlag rechnet die App aus, ob am Jahresende ein Guthaben oder eine Nachzahlung zu erwarten ist.")
        }
    }

    /// Eine Zeile mit Beschriftung, Zahlenfeld und Einheit.
    ///
    /// **Warum die Beschriftung am Feld hängt und nicht daneben steht.** Für
    /// das Auge sind es drei Teile nebeneinander; für VoiceOver waren es drei
    /// Stationen — „Arbeitspreis", dann „0,00, Textfeld", dann „Euro je
    /// Kilowattstunde". Wer das Feld erreicht, hat die Beschriftung schon
    /// hinter sich und weiß nicht mehr, was er da eintippt. Beschriftung und
    /// Einheit gehören deshalb ans Feld, und die sichtbaren Texte sind für die
    /// Ansage Beiwerk.
    private func numberRow(
        _ title: String,
        unit: String?,
        spokenUnit: String?,
        placeholder: String = "0,00",
        text: Binding<String>
    ) -> some View {
        HStack {
            Text(title)
                .accessibilityHidden(true)
            Spacer(minLength: 10)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .accessibilityLabel(spokenUnit.map { "\(title) in \($0)" } ?? title)
            if let unit {
                Text(unit)
                    .foregroundStyle(PulseColor.inkTertiary)
                    .accessibilityHidden(true)
            }
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
        // Ein Zugriff für den ganzen Vorgang. Vier eigene kosteten nichts an
        // Rechenzeit, aber sie verdecken, dass hier alles aus derselben Quelle
        // kommt.
        let repository = PulseRepository(context: context)
        name = existing.name
        kind = existing.kind
        interval = existing.readingInterval
        if let register = existing.primaryRegister {
            integerDigits = register.integerDigits
            fractionDigits = register.fractionDigits
        }
        if let feed = existing.registers.first(where: { $0.direction == .feedIn }) {
            hasFeedIn = true
            // Gefragt ist nur, **ob** Werte vorliegen. Sie dafür zu laden hieß,
            // beim Öffnen eines Zählers mit Photovoltaik jede Einspeisezahl
            // aus drei Jahren durchzureichen — sichtbar als Verzögerung, bevor
            // der Schirm überhaupt erschien.
            feedInHasReadings = ((try? repository.readingCount(for: feed.id)) ?? 0) > 0
        }
        // Zwei Bezugs-Zählwerke heißen: Tag und Nacht getrennt.
        let draws = existing.registers.filter { $0.direction == .consumption }
        if draws.count > 1 {
            hasDualTariff = true
            lowTariffHasReadings = ((try? repository.readingCount(for: draws[1].id)) ?? 0) > 0
        }
        fillBilling(existing)

        // Der zuletzt gültige Tarif. Mehrere Tarife über die Zeit kann der
        // Rechenkern längst; die Oberfläche bearbeitet vorerst nur den
        // aktuellen — ein Preisverlauf ist eine eigene Ansicht.
        let all = (try? repository.tariffs(for: existing.id)) ?? []
        existingTariffs = all

        // Der Tarif des ersten Bezugs-Zählwerks führt Arbeitspreis, Grundpreis
        // und Umrechnung. Bei einem Zähler ohne Doppeltarif ist das der eine
        // Tarif ohne Zählwerk-Bindung — deshalb beide Fälle in einer Suche.
        let primaryID = draws.first?.id
        let tariff = all.last { $0.registerID == nil || $0.registerID == primaryID }
        existingTariff = tariff
        if draws.count > 1 {
            let low = draws[1]
            if let lowTariff = all.last(where: { $0.registerID == low.id }) {
                lowTariffPrice = decimalText(lowTariff.pricePerUnit)
            }
        }
        if let feed = existing.registers.first(where: { $0.direction == .feedIn }),
           let feedTariff = all.last(where: { $0.registerID == feed.id || $0.registerID == nil }),
           let price = feedTariff.feedInPricePerUnit {
            feedInPrice = decimalText(price)
        }
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

    /// Das Zählwerk für die Einspeisung, so wie es die Vorlage in `PulseCore`
    /// anlegt — dieselben Stellen wie der Bezug, weil es dasselbe Gerät ist.
    private var feedInRegister: Register {
        Register(label: "Einspeisung", unit: .kilowattHour, direction: .feedIn,
                 integerDigits: integerDigits, fractionDigits: fractionDigits,
                 obisCode: "2.8.0")
    }

    /// Das zweite Bezugs-Zählwerk — der Nachtstrom.
    ///
    /// Dieselben Stellen wie tagsüber, weil es dasselbe Gerät ist. Die
    /// OBIS-Kennzahlen 1.8.1 und 1.8.2 sind die üblichen für Hoch- und
    /// Niedertarif; sie stehen nur in den Daten und nirgends auf dem Schirm.
    private var lowTariffRegister: Register {
        Register(label: "Niedertarif", unit: .kilowattHour, direction: .consumption,
                 integerDigits: integerDigits, fractionDigits: fractionDigits,
                 obisCode: "1.8.2")
    }

    /// Nimmt den Nachtstrom dazu oder wieder weg.
    ///
    /// Eingefügt wird er direkt hinter dem Tagstrom und **vor** der
    /// Einspeisung: In der Erfassung kommen die Zählwerke in dieser Reihenfolge
    /// dran, und wer am Gerät steht, liest erst beide Bezugszahlen ab.
    private func applyDualTariff(to point: inout MeteringPoint) {
        guard kind == .electricity else { return }
        let draws = point.registers.enumerated().filter { $0.element.direction == .consumption }

        if hasDualTariff {
            guard draws.count < 2 else { return }
            if point.registers.indices.contains(0), point.registers[0].label == nil {
                point.registers[0].label = "Hochtarif"
            } else if point.registers.indices.contains(0), point.registers[0].label == "Bezug" {
                // „Bezug" neben „Niedertarif" wäre eine Gegenüberstellung, die
                // es nicht gibt: Beides ist Bezug.
                point.registers[0].label = "Hochtarif"
            }
            let insertAt = (draws.last?.offset).map { $0 + 1 } ?? point.registers.count
            point.registers.insert(lowTariffRegister, at: insertAt)
        } else if draws.count > 1, !lowTariffHasReadings {
            point.registers.remove(at: draws[1].offset)
            if point.registers.count == 1 {
                point.registers[0].label = nil
            } else if point.registers.contains(where: { $0.direction == .feedIn }) {
                point.registers[0].label = "Bezug"
            }
        }
    }

    /// Nimmt die Einspeisung dazu oder wieder weg.
    ///
    /// Weggenommen wird nur, wenn dafür keine Ablesungen vorliegen — der
    /// Schalter ist dann gesperrt, und diese Prüfung ist die zweite Reihe.
    /// Ein Zählwerk zu entfernen, an dem Werte hängen, hieße Daten zu
    /// verlieren, die der Nutzer selbst eingetragen hat.
    private func applyFeedIn(to point: inout MeteringPoint) {
        guard kind == .electricity else { return }
        let existingFeed = point.registers.firstIndex { $0.direction == .feedIn }

        if hasFeedIn {
            guard existingFeed == nil else { return }
            // Bei Doppeltarif heißt das erste Zählwerk schon „Hochtarif" — dann
            // bliebe „Bezug" daneben eine zweite Antwort auf dieselbe Frage.
            if point.registers.indices.contains(0), point.registers[0].label == nil {
                point.registers[0].label = "Bezug"
            }
            point.registers.append(feedInRegister)
        } else if let index = existingFeed, !feedInHasReadings {
            point.registers.remove(at: index)
            if point.registers.count == 1 { point.registers[0].label = nil }
        }
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

        let unit: MeasurementUnit = needsGasConversion ? .kilowattHour : kind.defaultUnit
        let draws = point.registers.filter { $0.direction == .consumption }

        // Ohne zweiten Bezug bleibt es bei **einem** Tarif für alle Zählwerke —
        // unverändert der Weg, den ein gewöhnlicher Zähler und der
        // Zweirichtungszähler seit jeher gehen.
        guard draws.count > 1 else {
            try repository.save(Tariff(
                id: existingTariff?.id ?? UUID(),
                meteringPointID: point.id,
                validFrom: from,
                pricePerUnit: price ?? 0,
                monthlyBasePrice: base ?? 0,
                billingUnit: unit,
                gasConversion: conversion,
                feedInPricePerUnit: hasFeedIn ? decimalValue(feedInPrice) : nil
            ))
            try removeOrphanedTariffs(keeping: [existingTariff?.id].compactMap { $0 },
                                      of: point, in: repository)
            return
        }

        // Kennungen erhalten: Ein neuer Tarif bei jedem Sichern hieße, dass die
        // Kosten des laufenden Jahres plötzlich aus zwei Abschnitten bestünden.
        // Der bisherige Tarif ohne Zählwerk-Bindung wird zum Tarif des ersten
        // Zählwerks — so bleibt sein Gültigkeitsbeginn erhalten.
        func identifier(for register: Register, isPrimary: Bool = false) -> UUID {
            if let match = existingTariffs.last(where: { $0.registerID == register.id }) { return match.id }
            if isPrimary, let unbound = existingTariffs.last(where: { $0.registerID == nil }) { return unbound.id }
            return UUID()
        }

        var written: [Tariff.ID] = []

        // **Der Grundpreis steht nur am ersten Tarif.** Er gehört zum
        // Anschluss, und der Anschluss ist einer. Stünde er an beiden, zählte
        // ihn der Rechenkern zweimal — er unterscheidet zwei eigene Tarife
        // nicht von zwei Anschlüssen, und das ist dort so gewollt.
        let high = draws[0]
        let highTariff = Tariff(
            id: identifier(for: high, isPrimary: true),
            meteringPointID: point.id,
            registerID: high.id,
            validFrom: from,
            pricePerUnit: price ?? 0,
            monthlyBasePrice: base ?? 0,
            billingUnit: unit,
            gasConversion: conversion
        )
        try repository.save(highTariff)
        written.append(highTariff.id)

        let low = draws[1]
        let lowTariff = Tariff(
            id: identifier(for: low),
            meteringPointID: point.id,
            registerID: low.id,
            validFrom: from,
            pricePerUnit: decimalValue(lowTariffPrice) ?? 0,
            monthlyBasePrice: 0,
            billingUnit: unit,
            gasConversion: conversion
        )
        try repository.save(lowTariff)
        written.append(lowTariff.id)

        if let feed = point.registers.first(where: { $0.direction == .feedIn }) {
            let feedTariff = Tariff(
                id: identifier(for: feed),
                meteringPointID: point.id,
                registerID: feed.id,
                validFrom: from,
                pricePerUnit: 0,
                monthlyBasePrice: 0,
                billingUnit: unit,
                feedInPricePerUnit: decimalValue(feedInPrice)
            )
            try repository.save(feedTariff)
            written.append(feedTariff.id)
        }

        try removeOrphanedTariffs(keeping: written, of: point, in: repository)
    }

    /// Räumt Tarife weg, die zu keinem Zählwerk mehr gehören.
    ///
    /// Ohne das bliebe nach dem Abschalten des Nachtstroms sein Tarif liegen.
    /// Der Rechenkern fände ihn weiterhin, fände aber kein Zählwerk dazu — und
    /// beim erneuten Einschalten stünde ein zweiter daneben.
    private func removeOrphanedTariffs(
        keeping ids: [Tariff.ID],
        of point: MeteringPoint,
        in repository: PulseRepository
    ) throws {
        let live = Set(point.registers.map(\.id))
        for tariff in try repository.tariffs(for: point.id) {
            guard !ids.contains(tariff.id) else { continue }
            guard let registerID = tariff.registerID, !live.contains(registerID) else { continue }
            try repository.delete(tariffID: tariff.id)
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
                // Erst der Nachtstrom, dann die Einspeisung: `applyDualTariff`
                // fügt hinter dem letzten Bezug ein, und die Einspeisung hängt
                // sich hinten an. Andersherum stünde sie in der Mitte.
                applyDualTariff(to: &existing)
                applyFeedIn(to: &existing)
                try repository.save(existing)
                try saveTariff(for: existing, in: repository)
                try saveBilling(for: existing, in: repository)
            } else {
                var register = Register.standard(for: kind)
                register.integerDigits = integerDigits
                register.fractionDigits = fractionDigits
                // Beim Zweirichtungszähler bekommt auch das erste Zählwerk
                // einen Namen. „Bezug" allein wäre nichtssagend, „Bezug" neben
                // „Einspeisung" sagt alles.
                if hasDualTariff && kind == .electricity {
                    register.label = "Hochtarif"
                } else if hasFeedIn && kind == .electricity {
                    register.label = "Bezug"
                }
                var registers = [register]
                if hasDualTariff && kind == .electricity {
                    registers.append(lowTariffRegister)
                }
                if hasFeedIn && kind == .electricity {
                    registers.append(feedInRegister)
                }
                let point = MeteringPoint(
                    propertyID: property.id,
                    name: trimmed,
                    kind: kind,
                    registers: registers,
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
