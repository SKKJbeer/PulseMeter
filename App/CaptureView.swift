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

    private var register: Register? { meteringPoint.primaryRegister }
    private var accent: Color { PulseColor.resource(meteringPoint.appearance.colorToken) }
    private var today: CalendarDay { CalendarDay.containing(Date(), in: .current) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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
                    NumberPad(onKey: handle)
                        .padding(.top, 14)
                    saveButton
                    Text("Datum: heute, \(germanDate(today))")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                        .padding(.top, 9)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
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
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(spacing: 8) {
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

    private var saveButton: some View {
        Button(action: save) {
            Text("Sichern")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(PulseColor.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(accent.opacity(digits.isEmpty ? 0.32 : 1),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(digits.isEmpty)
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

    private func save() {
        guard let register, let value = currentValue else { return }
        do {
            try PulseRepository(context: context).save(
                Reading(registerID: register.id, day: today, value: value),
                fractionDigits: register.fractionDigits
            )
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
