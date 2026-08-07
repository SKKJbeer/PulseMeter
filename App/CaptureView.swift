import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Der Screen, an dem das Produkt gewinnt oder verliert.
///
/// Der Nutzer steht im Keller: schlechtes Licht, kalt, vielleicht eine Lampe in
/// der anderen Hand. Entsteht hier Reibung, hört er nach drei Monaten auf — und
/// alle anderen Funktionen werden wertlos (docs/03-ux-konzept.md, Abschnitt 3).
///
/// Deshalb: Zählwerk-Optik statt Zahlenfeld, eigener Ziffernblock statt
/// Systemtastatur, Datum auf heute vorbelegt, Foto optional.
struct CaptureView: View {

    let meteringPoint: MeteringPoint
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var digits = ""
    @State private var previous: Reading?
    @State private var verdict: ConsumptionEngine.Plausibility = .noReference
    @State private var problem: String?
    @State private var changingMeter = false

    /// Welches Zählwerk gerade dran ist.
    ///
    /// **Nacheinander statt zur Auswahl.** Ein Zweirichtungszähler zeigt beide
    /// Zahlen auf demselben Gerät; wer davorsteht, liest sie in einem Zug ab.
    /// Eine Auswahl davor hieße: erst entscheiden, dann tippen, dann noch
    /// einmal öffnen — drei Berührungen mehr für einen Vorgang, der einer ist.
    @State private var index = 0

    /// Was in dieser Sitzung schon eingetippt wurde. Gesichert wird erst am
    /// Ende und dann alles zusammen: Ein Abbruch nach dem ersten Zählwerk darf
    /// keine halbe Ablesung hinterlassen, aus der der Rechenkern später einen
    /// Verbrauch bildet, den es nie gab.
    @State private var entered: [Register.ID: Decimal] = [:]

    private var registers: [Register] { meteringPoint.registers }
    private var register: Register? {
        registers.indices.contains(index) ? registers[index] : meteringPoint.primaryRegister
    }
    private var isLastRegister: Bool { index >= registers.count - 1 }
    private var accent: Color { PulseColor.resource(meteringPoint.appearance.colorToken) }
    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }

    var body: some View {
        NavigationStack {
            // Der Ziffernblock gehört an den unteren Rand, nicht an den oberen.
            // Der Nutzer steht im Keller und hält das Gerät in einer Hand; was
            // er antippt, muss der Daumen erreichen. Auf hohen Geräten schiebt
            // der Abstandhalter Block und Schaltfläche nach unten, auf kleinen
            // greift der Bildlauf.
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Zwei Abstandhalter statt einem: Mit nur einem unten
                        // klebte das Zählwerk oben und dazwischen stand eine
                        // handbreite Leere. Zwischen zwei gleich starken
                        // Abstandhaltern schwebt es über dem Ziffernblock —
                        // wie die Anzeige über den Tasten eines Rechners.
                        Spacer(minLength: 0)
                        header
                        if let register {
                            CounterDisplay(digits: digits,
                                           integerDigits: register.integerDigits,
                                           fractionDigits: register.fractionDigits)
                                .padding(.top, 4)
                            Text(register.unit.symbol)
                                .font(PulseText.caption)
                                .foregroundStyle(PulseColor.inkTertiary)
                                .padding(.top, 6)
                                .padding(.bottom, 12)
                        }
                        VerdictBanner(tone: verdictTone, message: verdictMessage)
                        // Die Rückfrage stand hier seit jeher — „Wurde der
                        // Zähler gewechselt, oder hat sich eine Ziffer
                        // verirrt?" —, und bis 0.23.0 gab es keine
                        // Möglichkeit, die erste Hälfte zu bejahen. Eine
                        // Frage ohne Antwort ist eine Sackgasse.
                        if case .belowPrevious = verdict {
                            Button("Der Zähler wurde gewechselt") { changingMeter = true }
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(accent)
                                .padding(.top, 10)
                        }
                        Spacer(minLength: 18)
                        NumberPad(onKey: handle)
                        saveButton
                        Text("Datum: heute, \(germanDate(today))")
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkTertiary)
                            .padding(.top, 9)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(PulseColor.ground)
            .navigationTitle(meteringPoint.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear(perform: loadPrevious)
            .sheet(isPresented: $changingMeter) {
                MeterChangeView(meteringPoint: meteringPoint) {
                    // Nach dem Wechsel ist der eingetippte Wert gegenstandslos:
                    // Er gehörte zum neuen Gerät und ist dort bereits als
                    // Anfangsstand erfasst.
                    onSaved()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(spacing: 8) {
            // Der Name des Zählwerks steht nur da, wenn es mehr als eines
            // gibt. Bei einem einzelnen wäre „Bezug" ein Wort, das der Nutzer
            // nie gebraucht hat und nun deuten müsste.
            if registers.count > 1, let label = register?.label {
                // Als ein Satz: „Einspeisung, Zählwerk 2 von 2". Getrennt
                // vorgelesen käme der Fortschritt als eigener Brocken nach dem
                // Namen — und wer nicht sieht, wie die beiden zusammenhängen,
                // hört zwei Angaben statt einer Ortsbestimmung.
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Zählwerk \(index + 1) von \(registers.count)")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                }
                .accessibilityElement(children: .combine)
            }
            if let previous, let register {
                Text("Letzter Stand \(number(previous.value, digits: register.fractionDigits)) \(register.unit.symbol) am \(germanDate(previous.day))")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .multilineTextAlignment(.center)
                Button("Vom letzten Stand übernehmen") {
                    adopt(previous.value, register: register)
                }
                .font(.system(.footnote, weight: .medium))
                .foregroundStyle(PulseColor.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(PulseColor.surfaceMuted, in: Capsule())
            } else {
                Text("Erste Ablesung für diesen Zähler")
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkSecondary)
            }
        }
        .padding(.bottom, 10)
    }

    /// Der gesperrte Zustand bekommt eigene Farben statt einer durchscheinenden
    /// Akzentfläche.
    ///
    /// Mit `accent.opacity(0.32)` hinter heller Schrift stand im dunklen
    /// Erscheinungsbild dunkelbraun auf braun — auf dem Bildschirmfoto kaum zu
    /// lesen. Eine gedämpfte Fläche mit gedämpfter Schrift trägt in beiden
    /// Erscheinungsbildern und sagt dasselbe: noch nicht so weit.
    private var saveButton: some View {
        let ready = !digits.isEmpty
        return Button(action: advance) {
            Text(isLastRegister ? "Sichern" : "Weiter")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(ready ? PulseColor.onAccent : PulseColor.inkTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(ready ? accent : PulseColor.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!ready)
        .padding(.top, 14)
    }

    // MARK: - Eingabe

    private func handle(_ key: NumberPad.Key) {
        guard let register else { return }
        switch key {
        case .digit(let value):
            let limit = register.integerDigits + register.fractionDigits
            if digits.count < limit { digits.append(String(value)) }
        case .delete:
            if !digits.isEmpty { digits.removeLast() }
        case .photo:
            // Belegfotos folgen mit der Kamera-Erfassung; die Taste steht
            // schon hier, damit der Platz im Raster nicht später wandert.
            break
        }
        judge()
    }

    private func adopt(_ value: Decimal, register: Register) {
        let scaled = ScaledDecimal(value, scale: register.fractionDigits)
        digits = String(abs(scaled.scaled))
        judge()
    }

    private var currentValue: Decimal? {
        guard let register, !digits.isEmpty, let raw = Int(digits) else { return nil }
        return ScaledDecimal(scaled: raw, scale: register.fractionDigits).value
    }

    // MARK: - Plausibilität

    /// Prüft im Moment der Eingabe, nicht Monate später im Diagramm.
    ///
    /// Der häufigste Datenfehler ist der Tippfehler, und er fällt sonst erst
    /// auf, wenn ein Verlauf absurd aussieht — dann traut der Nutzer der App
    /// nicht mehr.
    private func judge() {
        guard let register, let value = currentValue else {
            verdict = .noReference
            return
        }
        do {
            let readings = try PulseRepository(context: context).readings(for: register.id)
            verdict = ConsumptionEngine.plausibility(of: value, on: today, register: register,
                                                     readings: readings, today: today)
        } catch {
            verdict = .noReference
        }
    }

    private var verdictTone: VerdictBanner.Tone {
        switch verdict {
        case .noReference: return digits.isEmpty ? .neutral : .confirmed
        case .normal: return .confirmed
        case .unusual, .belowPrevious, .futureDate: return .questionable
        }
    }

    private var verdictMessage: AttributedString {
        guard let register else { return AttributedString("") }
        switch verdict {
        case .noReference:
            return AttributedString(digits.isEmpty
                ? "Zählerstand eintippen"
                : "Erste Ablesung — es gibt noch nichts zu vergleichen.")

        case .normal(let consumption, let days):
            var text = AttributedString("Entspricht ")
            var value = AttributedString("\(number(consumption.value, digits: 0)) \(register.unit.symbol)")
            value.font = .system(.subheadline, weight: .semibold)
            text.append(value)
            text.append(AttributedString(" in \(days) Tagen — normal für dich."))
            return text

        case .unusual(let consumption, let days, let factor):
            var text = AttributedString("Das wären ")
            var value = AttributedString("\(number(consumption.value, digits: 0)) \(register.unit.symbol)")
            value.font = .system(.subheadline, weight: .semibold)
            text.append(value)
            let times = number(factor, digits: factor < 10 ? 1 : 0)
            text.append(AttributedString(" in \(days) Tagen — rund \(times)× dein üblicher Verbrauch. Stimmt die Zahl?"))
            return text

        case .belowPrevious(let value):
            return AttributedString("Der Stand liegt unter dem letzten Wert von \(number(value, digits: register.fractionDigits)) \(register.unit.symbol). Wurde der Zähler gewechselt, oder hat sich eine Ziffer verirrt?")

        case .futureDate:
            return AttributedString("Das Datum liegt in der Zukunft.")
        }
    }

    // MARK: - Speichern

    private func loadPrevious() {
        guard let register else { return }
        previous = try? PulseRepository(context: context).lastReading(for: register.id)
    }

    /// Merkt sich den Wert und geht weiter — oder sichert, wenn es das letzte
    /// Zählwerk war.
    private func advance() {
        guard let register, let value = currentValue else { return }
        entered[register.id] = value

        guard isLastRegister else {
            index += 1
            digits = ""
            verdict = .noReference
            loadPrevious()
            return
        }
        save()
    }

    /// Alle Zählwerke in einem Vorgang.
    ///
    /// Und alle oder keines: Schlägt das zweite fehl, bliebe sonst ein
    /// einzelner Wert stehen. Beim Bezug allein sähe das aus wie eine
    /// vollständige Ablesung — und der Rechenkern bildete daraus einen
    /// Verbrauch für einen Zeitraum, in dem die Einspeisung fehlt.
    private func save() {
        // Die Kennung des verbauten Geräts gehört an jede Ablesung. Ohne sie
        // reißt die Kette nach einem Wechsel wieder: Der Rechenkern erkennt
        // den erklärten Rücksprung nur, wenn **beide** benachbarten Ablesungen
        // wissen, auf welchem Gerät sie entstanden sind. Vor dem ersten
        // Wechsel ist sie `nil`, und das ist richtig so.
        let deviceID = meteringPoint.device(on: today)?.id

        var batch: [(reading: Reading, fractionDigits: Int)] = []
        for register in registers {
            guard let value = entered[register.id] else { continue }
            batch.append((Reading(registerID: register.id, deviceID: deviceID,
                                  day: today, value: value),
                          register.fractionDigits))
        }
        do {
            try PulseRepository(context: context).save(batch)
            onSaved()
            dismiss()
        } catch {
            problem = error.localizedDescription
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
