import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Der Zählerwechsel.
///
/// **Warum das kein Randfall ist.** Netzbetreiber tauschen turnusmäßig, und
/// beim Einbau eines digitalen Zählers fängt der Stand wieder bei null an.
/// Ohne diesen Schirm zeigte der Erfassungsschirm nur die Rückfrage „Wurde der
/// Zähler gewechselt, oder hat sich eine Ziffer verirrt?" — und nahm die
/// Antwort nicht entgegen. Eine Frage ohne Antwortmöglichkeit ist eine
/// Sackgasse, und Sackgassen sind in diesem Produkt ausgeschlossen
/// (Produktprinzip 4).
///
/// **Warum zwei Zahlen und nicht eine.** Ein Wechsel ist kein Nullsetzen. Der
/// alte Zähler hat einen Endstand, der neue einen Anfangsstand, und beide
/// beschreiben denselben Moment. Nur mit beiden bleibt der Verbrauch bis zum
/// Wechseltag erhalten; mit einer Zahl ginge er verloren oder würde negativ —
/// genau der Fehler, an dem verbreitete Zähler-Apps scheitern
/// (docs/02-datenmodell.md).
struct MeterChangeView: View {

    let meteringPoint: MeteringPoint
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var finalValue = ""
    @State private var initialValue = "0"
    @State private var serialNumber = ""
    @State private var previous: Reading?
    @State private var problem: String?

    private var register: Register? { meteringPoint.primaryRegister }
    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let previous, let register {
                        Text("Zuletzt \(number(previous.value, digits: register.fractionDigits)) \(register.unit.symbol) am \(germanDate(previous.day))")
                            .font(PulseText.detail)
                            .foregroundStyle(PulseColor.inkSecondary)
                    }
                    valueField("Endstand alter Zähler", text: $finalValue)
                } header: {
                    Text("Der alte Zähler")
                } footer: {
                    Text("Die Zahl, die beim Ausbau auf dem Gerät stand. Damit bleibt der Verbrauch bis zum Wechseltag erhalten.")
                }

                Section {
                    valueField("Anfangsstand neuer Zähler", text: $initialValue)
                    HStack {
                        Text("Gerätenummer")
                            .accessibilityHidden(true)
                        Spacer(minLength: 10)
                        // Ohne eigene Beschriftung sagte VoiceOver hier
                        // „optional, Textfeld“ — der Platzhalter wird zum
                        // Namen, und wofür das Feld da ist, stand nur daneben.
                        TextField("optional", text: $serialNumber)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Gerätenummer, optional")
                    }
                } header: {
                    Text("Der neue Zähler")
                } footer: {
                    // Null ist vorbelegt, weil es fast immer stimmt — aber
                    // eben nur fast: Manche Geräte werden mit einem
                    // Anfangsbestand eingebaut, und geraten wird hier nicht.
                    Text("Meist null. Steht auf dem neuen Gerät schon eine Zahl, gehört sie hierher. Die Gerätenummer hilft später beim Nachweis gegenüber dem Versorger.")
                }

                Section {
                    Text("Beide Stände werden auf heute, den \(germanDate(today)), gesetzt. Zwischen ihnen entsteht kein Verbrauch — sie beschreiben denselben Moment.")
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkSecondary)
                }

                if let problem {
                    Section {
                        // Vorher roter Text und sonst nichts. Farbe allein ist
                        // keine Aussage — nicht für VoiceOver, und nicht für
                        // die rund acht Prozent Männer mit einer Rotschwäche.
                        // `StatusBanner` trägt den Hinweis sichtbar **und**
                        // hörbar, so wie überall sonst in der App.
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    }
                }
            }
            .navigationTitle("Zähler gewechselt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).disabled(!isComplete)
                }
            }
            .onAppear(perform: load)
        }
    }

    /// Eine Zeile mit Beschriftung, Zahlenfeld und Einheit.
    ///
    /// **Beschriftung und Einheit hängen am Feld, nicht daneben.** Für das Auge
    /// sind es drei Teile nebeneinander; für VoiceOver waren es drei Stationen
    /// — „Endstand alter Zähler“, dann „0, Textfeld“, dann „kWh“. Wer das Feld
    /// erreicht, hat die Beschriftung schon hinter sich und weiß nicht mehr,
    /// welche der beiden Zahlen er gerade eintippt. Bei einem Zählerwechsel
    /// sind das die zwei Zahlen, an denen der ganze Verbrauch hängt.
    ///
    /// Dieselbe Form wie in `MetersView.numberRow`, aus derselben Begründung.
    private func valueField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .accessibilityHidden(true)
            Spacer(minLength: 10)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 130)
                .accessibilityLabel(register.map { "\(label) in \($0.unit.spokenName)" } ?? label)
            Text(register?.unit.symbol ?? "")
                .foregroundStyle(PulseColor.inkTertiary)
                .accessibilityHidden(true)
        }
    }

    private var isComplete: Bool {
        decimalValue(finalValue) != nil && decimalValue(initialValue) != nil
    }

    // MARK: - Daten

    private func load() {
        guard let register else { return }
        previous = try? PulseRepository(context: context).lastReading(for: register.id)
        // Der letzte bekannte Stand als Vorschlag: Wer den Zähler am Wechseltag
        // nicht mehr ablesen konnte, hat wenigstens diesen — und sieht sofort,
        // dass er ihn prüfen soll.
        //
        // Nur `previous` wird hier gebunden: `register` ist durch das `guard`
        // oben längst ausgepackt. Es noch einmal zu binden war der einzige
        // Übersetzungsfehler dieser Runde.
        if let previous {
            finalValue = decimalText(previous.value, digits: register.fractionDigits)
        }
    }

    /// Schreibt Gerätewechsel und beide Stände in einem Vorgang.
    ///
    /// Der Wechsel ist genau dann richtig erfasst, wenn **alles** ankommt:
    /// das ausgebaute Gerät mit Ausbaudatum, das neue mit Einbaudatum und
    /// beide Stände mit der jeweiligen Gerätekennung. Bliebe davon etwas
    /// liegen, entstünde ein Rücksprung ohne Erklärung — und der Rechenkern
    /// zählte den Abschnitt zu Recht als null.
    private func save() {
        guard let register,
              let endValue = decimalValue(finalValue),
              let startValue = decimalValue(initialValue)
        else { return }

        do {
            let repository = PulseRepository(context: context)
            var point = meteringPoint

            // Vor dem ersten Wechsel kennt die Messstelle noch gar kein Gerät.
            // Dann wird das ausgebaute nachgetragen — ab der ersten Ablesung,
            // damit sein Einbaudatum die Historie nicht zerschneidet.
            let outgoing: MeterDevice
            if let active = point.devices.first(where: \.isActive) {
                outgoing = active
            } else {
                let start = try repository.readings(for: register.id).first?.day ?? today
                outgoing = MeterDevice(installedOn: start)
                point.devices.append(outgoing)
            }
            if let index = point.devices.firstIndex(where: { $0.id == outgoing.id }) {
                point.devices[index].removedOn = today
            }

            let trimmed = serialNumber.trimmingCharacters(in: .whitespaces)
            let incoming = MeterDevice(serialNumber: trimmed.isEmpty ? nil : trimmed,
                                       installedOn: today)
            point.devices.append(incoming)
            try repository.save(point)

            // Beide Stände zusammen — dieselbe Regel wie beim
            // Zweirichtungszähler: halbe Wahrheiten sind hier schlimmer als
            // gar keine.
            //
            // **Die Zeitstempel werden von Hand gesetzt.** Beide Ablesungen
            // liegen am selben Tag, und dann entscheidet `createdAt` über die
            // Reihenfolge. Zweimal `Date()` kann denselben Augenblick liefern,
            // und Swifts `sorted` ist nicht stabil — die Reihenfolge wäre
            // undefiniert. Stünde der Anfangsstand vor dem Endstand, sähe der
            // Rechenkern einen Absturz von 50.600 auf 0 statt eines Wechsels.
            // Eine Sekunde Abstand macht daraus eine Zusage statt einer
            // Wahrscheinlichkeit.
            let moment = Date()
            try repository.save([
                (Reading(registerID: register.id, deviceID: outgoing.id,
                         day: today, value: endValue, createdAt: moment),
                 register.fractionDigits),
                (Reading(registerID: register.id, deviceID: incoming.id,
                         day: today, value: startValue,
                         createdAt: moment.addingTimeInterval(1)),
                 register.fractionDigits)
            ])

            onSaved()
            dismiss()
        } catch {
            problem = "Der Zählerwechsel ließ sich nicht sichern: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatierung

    private func decimalValue(_ text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    private func decimalText(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits))
            .grouping(.never).locale(Locale(identifier: "de_DE")))
    }

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
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
}
