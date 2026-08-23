import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// Eine bereits erfasste Ablesung ändern oder löschen.
///
/// **Warum es das gibt.** Wer sich vertippt, hat es bis 0.75.0 gemerkt und
/// nichts machen können: Der Wert stand in der Liste und blieb dort. Eine
/// falsche Ziffer verschiebt aber nicht nur eine Zeile — sie verfälscht beide
/// angrenzenden Zeiträume, und der Verlauf zeigt sie für immer. Ein Produkt,
/// das Zahlen sammelt, muss sie auch berichtigen lassen (Produktprinzip 4).
///
/// **Warum derselbe Ziffernblock wie beim Erfassen.** Eine Zahl vom Gerät
/// abzulesen und einzutippen ist derselbe Vorgang, ob sie neu ist oder
/// berichtigt wird. Ein Textfeld daneben wäre ein zweiter Weg für dieselbe
/// Sache — und der einzige Ort in der App, an dem ein Zählerstand nicht wie
/// ein Zählwerk aussieht.
struct ReadingEditor: View {

    let reading: Reading
    let meteringPoint: MeteringPoint
    /// Die übrigen Ablesungen **desselben Zählwerks**, ohne diese hier.
    ///
    /// Ohne das „ohne diese hier" vergliche sich die Ablesung mit sich selbst:
    /// Die Plausibilitätsprüfung fände als Vorgänger den Wert, der gerade
    /// geändert wird, und meldete jede Korrektur als Rücksprung.
    let others: [Reading]
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var digits: String
    @State private var moment: Date
    @State private var verdict: ConsumptionEngine.Plausibility = .noReference
    @State private var confirmingDelete = false
    @State private var problem: String?

    init(reading: Reading, meteringPoint: MeteringPoint, others: [Reading],
         onDone: @escaping () -> Void) {
        self.reading = reading
        self.meteringPoint = meteringPoint
        self.others = others
        self.onDone = onDone
        let register = meteringPoint.registers.first { $0.id == reading.registerID }
        let scale = register?.fractionDigits ?? 1
        _digits = State(initialValue: String(abs(ScaledDecimal(reading.value, scale: scale).scaled)))
        _moment = State(initialValue: Self.zeitpunkt(of: reading))
    }

    private var register: Register? {
        meteringPoint.registers.first { $0.id == reading.registerID }
    }
    private var accent: Color { PulseColor.resource(meteringPoint.appearance.colorToken) }
    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }
    private var chosenDay: CalendarDay { CalendarDay.containing(moment, in: .current) }
    private var chosenTime: TimeOfDay { TimeOfDay.containing(moment, in: .current) }

    private var currentValue: Decimal? {
        guard let register, !digits.isEmpty, let raw = Int(digits) else { return nil }
        return ScaledDecimal(scaled: raw, scale: register.fractionDigits).value
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        // Der Name des Zählwerks nur bei mehr als einem —
                        // dieselbe Regel wie im Erfassungsschirm. Sonst stünde
                        // „Bezug" an einer Zeile, die keine Wahl anbietet.
                        if meteringPoint.registers.count > 1, let label = register?.label {
                            Text(label)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(accent)
                        }
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

                        Spacer(minLength: 18)
                        NumberPad(onKey: handle)
                        saveButton
                        momentPicker

                        deleteButton

                        if let problem {
                            Text(problem)
                                .font(PulseText.caption)
                                .foregroundStyle(PulseColor.adverse)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(PulseColor.ground)
            .navigationTitle("Ablesung ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .confirmationDialog("Diese Ablesung löschen?",
                                isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive, action: entfernen)
                Button("Abbrechen", role: .cancel) { }
            } message: {
                // Nicht „unwiderruflich" als Wort, sondern die Folge: Was
                // danach anders ist, kann niemand mehr rückgängig machen.
                Text("Der Stand vom \(germanDate(reading.day)) wird entfernt. Der Verbrauch davor und danach wird neu gerechnet.")
            }
            .onAppear(perform: judge)
        }
    }

    // MARK: - Bausteine

    private var saveButton: some View {
        let ready = currentValue != nil && etwasGeaendert
        return Button(action: sichern) {
            Text("Sichern")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(ready ? PulseColor.onAccent : PulseColor.inkTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(ready ? accent : PulseColor.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .disabled(!ready)
        // Ein abgeblendeter Knopf sagt nicht, warum. Solange nichts geändert
        // wurde, gibt es nichts zu sichern — und das gehört an den Knopf.
        .accessibilityHint(ready ? "Sichert die geänderte Ablesung"
                                 : "Erst den Stand oder den Zeitpunkt ändern")
        .padding(.top, 14)
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmingDelete = true } label: {
            Text("Diese Ablesung löschen")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PulseColor.adverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var momentPicker: some View {
        DatePicker("Abgelesen", selection: $moment, in: ...Date(),
                   displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "de_DE"))
            .font(PulseText.caption)
            .foregroundStyle(PulseColor.inkTertiary)
            .tint(accent)
            .padding(.top, 12)
            .onChange(of: moment) { _, _ in judge() }
    }

    /// Ob überhaupt etwas anders ist als vorher.
    private var etwasGeaendert: Bool {
        guard let value = currentValue else { return false }
        return value != reading.value
            || chosenDay != reading.day
            || chosenTime != (reading.time ?? chosenTime)
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
        }
        judge()
    }

    /// Beurteilt den eingetippten Stand gegen die **anderen** Ablesungen.
    private func judge() {
        guard let register, let value = currentValue else {
            verdict = .noReference
            return
        }
        verdict = ConsumptionEngine.plausibility(of: value, on: chosenDay, register: register,
                                                 readings: others, today: today)
    }

    // MARK: - Sichern und Löschen

    private func sichern() {
        guard let register, let value = currentValue else { return }
        var berichtigt = reading
        berichtigt.value = value
        berichtigt.day = chosenDay
        berichtigt.time = chosenTime
        // Das Gerät, das **am gewählten Tag** verbaut war. Wer eine Ablesung
        // über einen Zählerwechsel hinweg verschiebt, hängt sie sonst an das
        // falsche Gerät — und der Rechenkern hielte den erklärten Rücksprung
        // wieder für einen Fehler.
        berichtigt.deviceID = meteringPoint.device(on: chosenDay)?.id
        do {
            try PulseRepository(context: context).save(berichtigt,
                                                       fractionDigits: register.fractionDigits)
            onDone()
            dismiss()
        } catch {
            problem = "Die Ablesung ließ sich nicht sichern: \(error.localizedDescription)"
        }
    }

    private func entfernen() {
        do {
            try PulseRepository(context: context).delete(readingID: reading.id)
            onDone()
            dismiss()
        } catch {
            problem = "Die Ablesung ließ sich nicht löschen: \(error.localizedDescription)"
        }
    }

    // MARK: - Beschriftung

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
                : "Die einzige Ablesung dieses Zählwerks — es gibt nichts zu vergleichen.")

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
            // Ohne den Weg zum Zählerwechsel, den der Erfassungsschirm hier
            // anbietet: Wer eine alte Ablesung berichtigt, korrigiert eine
            // Ziffer — ein Wechsel wird beim Ablesen erfasst, nicht rückwirkend
            // an einer einzelnen Zeile.
            return AttributedString("Der Stand liegt unter dem Wert davor: \(number(value, digits: register.fractionDigits)) \(register.unit.symbol). Hat sich eine Ziffer verirrt?")

        case .futureDate:
            return AttributedString("Das Datum liegt in der Zukunft.")
        }
    }

    private static func zeitpunkt(of reading: Reading) -> Date {
        var components = DateComponents()
        components.year = reading.day.year
        components.month = reading.day.month
        components.day = reading.day.day
        components.hour = reading.time?.hour ?? 12
        components.minute = reading.time?.minute ?? 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: components) ?? reading.createdAt
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

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }
}
