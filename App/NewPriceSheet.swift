import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

/// „Neuer Preis ab …“ (1.7).
///
/// Wer den Anbieter wechselt oder eine Preiserhöhung bekommt, trägt den neuen
/// Preis mit dem Tag ein, ab dem er gilt. Die Kosten davor bleiben, wie sie
/// waren. Bis 1.6 änderte das Feld im Zähler den einen Tarif, und die App
/// rechnete die Vergangenheit rückwirkend mit dem neuen Preis.
///
/// Die Rechnung steht in `TariffHistory.startingNewPrice`; dieses Blatt
/// sammelt nur die Eingaben und sichert, was zurückkommt. Spiegelt
/// `openNewPrice` im Klick-Dummy.
struct NewPriceSheet: View {

    let meteringPoint: MeteringPoint
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var feldbreite: CGFloat = 110

    @State private var tag = Date()
    @State private var tarife: [Tariff] = []
    @State private var juengste: TariffHistory.Generation?
    @State private var letzteAblesung: CalendarDay?
    // Als Text wie im Zähler: Ein leeres Feld heißt „wie bisher“, nicht null.
    @State private var preis = ""
    @State private var nachtpreis = ""
    @State private var grundpreis = ""
    @State private var verguetung = ""
    @State private var zustandszahl = ""
    @State private var brennwert = ""
    @State private var heizwert = ""
    @State private var problem: String?

    private var draws: [Register] { meteringPoint.registers.filter { $0.direction == .consumption } }
    private var einspeisung: Register? { meteringPoint.registers.first { $0.direction == .feedIn } }
    private var istGas: Bool { meteringPoint.kind == .gas }
    private var istOel: Bool { meteringPoint.kind == .heatingOil }
    private var einheit: String { istGas ? "kWh" : meteringPoint.kind.defaultUnit.symbol }

    private var gewaehlterTag: CalendarDay { CalendarDay.containing(tag, in: .current) }

    /// Frühestens der Tag nach dem Beginn des jüngsten Preises. Ab dem gilt
    /// schon der jetzige; davor einzufügen hieße, ihn zu zerteilen.
    private var fruehesterTag: Date {
        guard let start = juengste?.validFrom else { return .distantPast }
        return datum(start.adding(days: 1)) ?? .distantPast
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Tag", selection: $tag, in: fruehesterTag..., displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                        .accessibilityIdentifier("neuer-preis-tag")
                } header: {
                    Text("Gilt ab")
                } footer: {
                    Text(hinweis)
                        .accessibilityIdentifier("neuer-preis-hinweis")
                }

                Section {
                    if draws.count > 1 {
                        zeile("Arbeitspreis tagsüber (brutto)", einheit: "€/\(einheit)", text: $preis)
                        zeile("Arbeitspreis nachts (brutto)", einheit: "€/\(einheit)", text: $nachtpreis)
                    } else {
                        zeile("Arbeitspreis (brutto)", einheit: "€/\(einheit)", text: $preis)
                    }
                    zeile("Grundpreis (brutto)", einheit: "€/Monat", text: $grundpreis)
                    if einspeisung != nil {
                        zeile("Einspeisevergütung", einheit: "€/kWh", text: $verguetung)
                    }
                    if istGas {
                        zeile("Zustandszahl", einheit: nil, text: $zustandszahl)
                        zeile("Brennwert", einheit: "kWh/m³", text: $brennwert)
                    }
                    if istOel {
                        zeile("Heizwert", einheit: "kWh/l", text: $heizwert)
                    }
                } header: {
                    Text("Neuer Preis")
                } footer: {
                    Text("Vorbelegt mit dem bisherigen Preis. Ändere nur, was sich ändert.")
                }

                if let problem {
                    Section { Text(problem).foregroundStyle(PulseColor.adverse) }
                }
            }
            .navigationTitle("Neuer Preis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: sichern)
                        .accessibilityIdentifier("neuer-preis-sichern")
                }
            }
            .onAppear(perform: laden)
        }
    }

    /// Was der Tag bewirkt, in einem Satz. Rückdatieren ist erlaubt; dann
    /// rechnen sich Kosten neu, und das soll niemanden überraschen.
    private var hinweis: String {
        let tag = gewaehlterTag
        let vortag = datumLang(tag.adding(days: -1))
        if let letzte = letzteAblesung, letzte >= tag {
            return "Kosten ab dem \(datumLang(tag)) werden mit dem neuen Preis neu berechnet."
        }
        if tag > CalendarDay.containing(Date(), in: .current) {
            return "Bis zum \(vortag) gilt der bisherige Preis."
        }
        return "Der bisherige Preis gilt bis zum \(vortag)."
    }

    private func zeile(_ titel: String, einheit: String?, text: Binding<String>) -> some View {
        HStack {
            Text(titel).accessibilityHidden(true)
            Spacer(minLength: 10)
            TextField("0,00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: feldbreite)
                .accessibilityLabel(titel)
            if let einheit {
                Text(einheit)
                    .foregroundStyle(PulseColor.inkTertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Daten

    private func laden() {
        let repository = PulseRepository(context: context)
        tarife = (try? repository.tariffs(for: meteringPoint.id)) ?? []
        juengste = TariffHistory.generations(of: tarife, meteringPointID: meteringPoint.id).first
        letzteAblesung = (try? repository.readings(for: meteringPoint))?.map(\.day).max()
        // Vorschlag heute, außer der jüngste Preis beginnt erst später.
        if tag < fruehesterTag { tag = fruehesterTag }

        guard let juengste else { return }
        let haupt = juengste.tariff(for: draws.first?.id)
        if let haupt {
            preis = text(haupt.pricePerUnit)
            if let umrechnung = haupt.gasConversion {
                if istOel {
                    heizwert = text(EnergyDisplay.kWhPerLitre(umrechnung))
                } else {
                    zustandszahl = text(umrechnung.stateNumber)
                    brennwert = text(umrechnung.calorificValue)
                }
            }
        }
        let grund = juengste.tariffs.map(\.monthlyBasePrice).max() ?? 0
        grundpreis = grund > 0 ? text(grund) : ""
        if draws.count > 1, let nacht = juengste.tariff(for: draws[1].id) {
            nachtpreis = text(nacht.pricePerUnit)
        }
        if let vergütung = juengste.tariffs.compactMap(\.feedInPricePerUnit).first {
            verguetung = text(vergütung)
        }
    }

    private func sichern() {
        let tag = gewaehlterTag
        let einspeisungID = einspeisung?.id
        let nachtID = draws.count > 1 ? draws[1].id : nil
        let hauptID = draws.first?.id
        do {
            let repository = PulseRepository(context: context)
            let vorher = try repository.tariffs(for: meteringPoint.id)
            let nachher = try TariffHistory.startingNewPrice(
                on: tag, tariffs: vorher, meteringPointID: meteringPoint.id
            ) { tarif in
                if let einspeisungID, tarif.registerID == einspeisungID {
                    tarif.feedInPricePerUnit = wert(verguetung) ?? tarif.feedInPricePerUnit
                    return
                }
                if let nachtID, tarif.registerID == nachtID {
                    tarif.pricePerUnit = wert(nachtpreis) ?? tarif.pricePerUnit
                } else {
                    tarif.pricePerUnit = wert(preis) ?? tarif.pricePerUnit
                }
                // Der Grundpreis steht nur am ersten Tarif, wie beim Sichern
                // im Zähler: Er gehört zum Anschluss, und der ist einer.
                if tarif.registerID == nil || tarif.registerID == hauptID {
                    tarif.monthlyBasePrice = wert(grundpreis) ?? tarif.monthlyBasePrice
                }
                if tarif.registerID == nil, einspeisungID != nil {
                    tarif.feedInPricePerUnit = wert(verguetung) ?? tarif.feedInPricePerUnit
                }
                if istGas, let alt = tarif.gasConversion {
                    tarif.gasConversion = GasConversion(
                        stateNumber: wert(zustandszahl) ?? alt.stateNumber,
                        calorificValue: wert(brennwert) ?? alt.calorificValue)
                }
                if istOel {
                    tarif.gasConversion = EnergyDisplay.heatingOilConversion(
                        kWhPerLitre: wert(heizwert) ?? EnergyDisplay.typicalHeatingOilKWhPerLitre)
                }
            }
            try speichereTarife(vorher: vorher, nachher: nachher, in: repository)
            onSaved()
            dismiss()
        } catch TariffHistory.HistoryError.notAfterNewestStart(let start) {
            problem = "Der neue Preis muss nach dem \(datumLang(start)) beginnen. Ab dann gilt schon der jetzige."
        } catch {
            problem = "Der Preis ließ sich nicht sichern: \(error.localizedDescription)"
        }
    }

    private func wert(_ text: String) -> Decimal? {
        let bereinigt = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !bereinigt.isEmpty else { return nil }
        return Decimal(string: bereinigt, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func text(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)).grouping(.never)
            .locale(Locale(identifier: "de_DE")))
    }

    private func datum(_ day: CalendarDay) -> Date? {
        var teile = DateComponents()
        teile.year = day.year
        teile.month = day.month
        teile.day = day.day
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = .current
        return kalender.date(from: teile)
    }
}

/// Schreibt eine Tarifliste, wie `TariffHistory` sie zurückgibt: geänderte
/// und neue sichern, verschwundene löschen. Ein Weg für das Blatt und für
/// „Löschen“ im Zähler.
func speichereTarife(vorher: [Tariff], nachher: [Tariff], in repository: PulseRepository) throws {
    let alt = Dictionary(uniqueKeysWithValues: vorher.map { ($0.id, $0) })
    for tarif in nachher where alt[tarif.id] != tarif {
        try repository.save(tarif)
    }
    let bleiben = Set(nachher.map(\.id))
    for tarif in vorher where !bleiben.contains(tarif.id) {
        try repository.delete(tariffID: tarif.id)
    }
}

/// „1. September 2026“: Tag, Monat ausgeschrieben, Jahr.
func datumLang(_ day: CalendarDay) -> String {
    var teile = DateComponents()
    teile.year = day.year
    teile.month = day.month
    teile.day = day.day
    var kalender = Calendar(identifier: .gregorian)
    kalender.timeZone = .current
    guard let date = kalender.date(from: teile) else { return day.description }
    return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE")))
}
