import SwiftUI
import SwiftData
import PulseCore
import PulseData
import PulseUI

// 1.9: Heizung gewechselt, vorher und nachher.
//
// Konzept: docs/konzepte/1.9-heizungswechsel.md. Gerechnet wird nur in
// `HeatingComparison` (PulseCore); hier stehen Eingabe und Anzeige. Spiegelt
// `heatingComparison`, `heizungsKarten` und `openHeizungsWechsel` im
// Klick-Dummy (Regel 2).

// MARK: - Was die Übersicht zeigt

/// Ein Wechsel mit allem, was Karte und Ansicht brauchen. In der Übersicht
/// einmal je Neuladen gerechnet, nicht in der Ansicht.
struct HeizungsKarte: Identifiable {
    let change: HeatingChange
    let alt: MeteringPoint
    let neu: MeteringPoint
    let outcome: HeatingComparison.Outcome
    /// Beträge nur mit „Kosten und Preise“. Ohne den Kauf zeigt die Karte kWh.
    let mitBetraegen: Bool

    var id: HeatingChange.ID { change.id }
    var altArt: String { alt.kind == .heatingOil ? "Heizöl" : "Gas" }
    var titel: String { "\(altArt) und Wärmepumpe" }

    var result: HeatingComparison.Result? {
        if case .compared(let r) = outcome { return r }
        return nil
    }
    /// Unterschied in Euro, nur wenn beide Seiten einen Betrag haben.
    var euroUnterschied: Money? { mitBetraegen ? result?.costDifference : nil }
}

enum HeizungsText {

    static let wetter = "Das Wetter ist nicht herausgerechnet. War der Winter nach dem Wechsel kälter, sieht die Wärmepumpe schlechter aus, als sie ist."

    private static let monate = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
                                 "August", "September", "Oktober", "November", "Dezember"]
    private static let kurz = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul",
                               "Aug", "Sep", "Okt", "Nov", "Dez"]

    /// „Oktober bis Juli“: der Ausschnitt, auf beiden Seiten gleich. Das Ende
    /// ist halboffen, bis zum 1. August heißt „bis Juli“.
    static func ausschnitt(_ r: HeatingComparison.Result) -> String {
        if r.monthCount == 12 { return "Ein ganzes Jahr" }
        let letzter = r.after.range.end.adding(days: -1)
        let a = monate[r.after.range.start.month - 1], b = monate[letzter.month - 1]
        return r.monthCount == 1 ? a : "\(a) bis \(b)"
    }

    static func spanne(_ range: DayRange) -> String {
        let letzter = range.end.adding(days: -1)
        let a = "\(kurz[range.start.month - 1]) \(range.start.year)"
        let b = "\(kurz[letzter.month - 1]) \(letzter.year)"
        return a == b ? a : "\(a) – \(b)"
    }

    static func tag(_ day: CalendarDay) -> String {
        let heute = CalendarDay.containing(Date(), in: .current)
        return "\(day.day). \(monate[day.month - 1])" + (day.year == heute.year ? "" : " \(day.year)")
    }

    static func euro(_ betrag: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 0
        return f.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag) €"
    }

    static func zahl(_ wert: Decimal, runden: Int = 1) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let d = NSDecimalNumber(decimal: wert).doubleValue
        let gerundet = (d / Double(runden)).rounded() * Double(runden)
        return f.string(from: NSNumber(value: gerundet)) ?? "\(gerundet)"
    }

    static func prozent(_ anteil: Decimal) -> String {
        zahl(anteil * 100) + " %"
    }

    /// Was vorher gekauft wurde: kWh, wenn bekannt, sonst m³ oder l.
    static func vorherMenge(_ r: HeatingComparison.Result, kind: ResourceKind) -> String {
        if let kwh = r.before.kilowattHours {
            // Öl auf zehn gerundet, wie die Karte in 1.7: Der Heizwert ist
            // angenommen, eine Zahl auf die Kilowattstunde genau täuschte.
            return kind == .heatingOil ? "≈ \(zahl(kwh.value, runden: 10)) kWh" : "\(zahl(kwh.value)) kWh"
        }
        return "\(zahl(r.before.quantity.value)) \(r.before.quantity.unit.symbol)"
    }
}

// MARK: - Karte in der Übersicht

struct HeizungsKarteView: View {

    let karte: HeizungsKarte
    let onOpen: () -> Void
    let onUnlock: () -> Void
    let darf: Bool

    var body: some View {
        if !darf {
            gesperrt
        } else if let r = karte.result {
            verglichen(r)
        } else {
            wartend
        }
    }

    private var kopf: some View {
        HStack(spacing: 10) {
            Image(systemName: "heat.waves")
                .foregroundStyle(PulseColor.favourable)
                .accessibilityHidden(true)
            Text(karte.titel)
                .font(PulseText.cardTitle)
                .foregroundStyle(PulseColor.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PulseColor.inkTertiary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func verglichen(_ r: HeatingComparison.Result) -> some View {
        let caption = "\(HeizungsText.ausschnitt(r)), gegen ein Jahr davor"
        if let diff = karte.euroUnterschied, let vorher = r.before.cost, let nachher = r.after.cost {
            ValueCard(
                title: karte.titel,
                symbolName: "heat.waves",
                accent: PulseColor.favourable,
                caption: caption,
                value: HeizungsText.euro(abs(diff.amount)),
                unit: diff.amount <= 0 ? "weniger bezahlt" : "mehr bezahlt",
                detail: Text("\(karte.altArt) \(HeizungsText.euro(vorher.amount)) · Wärmepumpe \(HeizungsText.euro(nachher.amount))"),
                onOpen: onOpen
            ) {
                CardFooterRow("Wetter nicht herausgerechnet") { EmptyView() }
            }
            .accessibilityIdentifier("heizung-karte")
        } else {
            ValueCard(
                title: karte.titel,
                symbolName: "heat.waves",
                accent: PulseColor.favourable,
                caption: caption,
                value: HeizungsText.zahl(r.after.quantity.value),
                unit: "kWh Strom",
                detail: Text("statt \(HeizungsText.vorherMenge(r, kind: karte.alt.kind)) \(karte.altArt)"),
                onOpen: onOpen
            ) {
                CardFooterRow("Wetter nicht herausgerechnet") { EmptyView() }
            }
            .accessibilityIdentifier("heizung-karte")
        }
    }

    private var wartend: some View {
        Button(action: onOpen) {
            PulseCard(accent: PulseColor.favourable) {
                VStack(alignment: .leading, spacing: 8) {
                    kopf
                    switch karte.outcome {
                    case .waiting(let ab):
                        Text("Vorher und nachher")
                            .font(PulseText.caption).foregroundStyle(PulseColor.inkSecondary)
                        Text("Ab \(HeizungsText.tag(ab)) steht hier der Vergleich")
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(PulseColor.ink)
                        Text("Dann ist der erste ganze Monat mit der Wärmepumpe gemessen.")
                            .font(PulseText.detail).foregroundStyle(PulseColor.inkSecondary)
                    case .earlierYearMissing(let range):
                        Text("Vom \(karte.altArt)zähler fehlt \(HeizungsText.spanne(range))")
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(PulseColor.ink)
                        Text("Verglichen wird nur mit denselben Monaten ein Jahr früher.")
                            .font(PulseText.detail).foregroundStyle(PulseColor.inkSecondary)
                    case .compared:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("heizung-karte")
    }

    /// Der Wechsel kam etwa über iCloud, der Kauf fehlt auf diesem Gerät.
    /// Die Karte führt aufs Kaufblatt, wie der Kameraknopf.
    private var gesperrt: some View {
        Button(action: onUnlock) {
            PulseCard(accent: PulseColor.favourable) {
                VStack(alignment: .leading, spacing: 8) {
                    kopf
                    Text("Vorher und nachher")
                        .font(PulseText.caption).foregroundStyle(PulseColor.inkSecondary)
                    Text("Mit dem Kauf „Wärmepumpe“")
                        .font(PulseText.detail).foregroundStyle(PulseColor.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("heizung-karte")
    }
}

// MARK: - Die Ansicht dahinter

struct HeizungsVergleichView: View {

    let karte: HeizungsKarte
    let onBearbeiten: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var bild: Image?

    var body: some View {
        NavigationStack {
            Form {
                if let r = karte.result {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(HeizungsText.ausschnitt(r)), gegen ein Jahr davor")
                                .font(PulseText.caption).foregroundStyle(PulseColor.inkSecondary)
                            if let diff = karte.euroUnterschied {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(HeizungsText.euro(abs(diff.amount)))
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .accessibilityIdentifier("heizung-unterschied")
                                    Text(diff.amount <= 0 ? "weniger bezahlt" : "mehr bezahlt")
                                        .font(.headline)
                                }
                                .foregroundStyle(PulseColor.ink)
                            }
                            if let e = r.energyDifference {
                                Text("\(HeizungsText.zahl(abs(e.value))) kWh \(e.value <= 0 ? "weniger" : "mehr") gekauft")
                                    .font(PulseText.detail).foregroundStyle(PulseColor.inkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }

                    Section {
                        zeile("Zeitraum", HeizungsText.spanne(r.before.range), HeizungsText.spanne(r.after.range))
                        zeile("Gekauft", HeizungsText.vorherMenge(r, kind: karte.alt.kind),
                              "\(HeizungsText.zahl(r.after.quantity.value)) kWh Strom")
                        zeile("Wärme", r.heatBefore.map { "≈ \(HeizungsText.zahl($0.value, runden: 10)) kWh" } ?? "–",
                              "unbekannt",
                              klein: "\(karte.altArt) × \(HeizungsText.prozent(r.boilerEfficiency))")
                        zeile("Kosten", karte.mitBetraegen ? r.before.cost.map { HeizungsText.euro($0.amount) } ?? "–" : "–",
                              karte.mitBetraegen ? r.after.cost.map { HeizungsText.euro($0.amount) } ?? "–" : "–",
                              klein: "mit Grundpreis")
                    } header: {
                        HStack {
                            Text("")
                            Spacer()
                            Text(karte.altArt).frame(minWidth: 90, alignment: .trailing)
                            Text("Wärmepumpe").frame(minWidth: 90, alignment: .trailing)
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(HeizungsText.wetter)
                            Text("Die Wärme der Wärmepumpe misst nur ein Wärmemengenzähler. Beim \(karte.altArt) ist sie aus dem Wirkungsgrad des Kessels geschätzt, \(HeizungsText.prozent(r.boilerEfficiency)). Ändern lässt er sich beim Wechsel.")
                        }
                    }

                    if let bild {
                        Section {
                            ShareLink(item: bild, preview: SharePreview("Vorher und nachher", image: bild)) {
                                Label("Als Bild teilen", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("heizung-teilen")
                        } footer: {
                            Text("Ohne Zählerstände, ohne Namen und ohne Anschrift.")
                        }
                    }
                } else {
                    Section {
                        Text(wartetText)
                            .foregroundStyle(PulseColor.inkSecondary)
                    }
                }

                Section {
                    Button(action: onBearbeiten) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wechsel am \(HeizungsText.tag(karte.change.day))").foregroundStyle(PulseColor.ink)
                            Text("\(karte.altArt): \(karte.alt.name) · Wärmepumpe: \(karte.neu.name)")
                                .font(PulseText.caption).foregroundStyle(PulseColor.inkSecondary)
                        }
                    }
                    .accessibilityIdentifier("heizung-bearbeiten")
                }
            }
            .navigationTitle("Vorher und nachher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear(perform: bildMalen)
        }
    }

    private var wartetText: String {
        switch karte.outcome {
        case .waiting(let ab):
            return "Ab \(HeizungsText.tag(ab)) steht hier der Vergleich. Dann ist der erste ganze Monat mit der Wärmepumpe gemessen."
        case .earlierYearMissing(let range):
            return "Vom \(karte.altArt)zähler fehlt \(HeizungsText.spanne(range)). Verglichen wird nur mit denselben Monaten ein Jahr früher."
        case .compared:
            return ""
        }
    }

    private func zeile(_ titel: String, _ vorher: String, _ nachher: String, klein: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(titel)
                if let klein {
                    Text(klein).font(PulseText.caption).foregroundStyle(PulseColor.inkTertiary)
                }
            }
            Spacer(minLength: 8)
            Text(vorher).frame(minWidth: 90, alignment: .trailing)
            Text(nachher).frame(minWidth: 90, alignment: .trailing)
        }
        .font(.subheadline.monospacedDigit())
        .accessibilityElement(children: .combine)
    }

    /// Das Bild entsteht auf dem Gerät (Teil D). 360 × 450 Punkt, dreifach
    /// gerendert: 1080 × 1350, das Hochformat, das Nachrichten und WhatsApp
    /// ohne Beschnitt zeigen.
    @MainActor
    private func bildMalen() {
        guard let r = karte.result else { return }
        let renderer = ImageRenderer(content: HeizungsBild(karte: karte, result: r))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 450)
        if let ui = renderer.uiImage { bild = Image(uiImage: ui) }
    }
}

/// Das geteilte Bild. **Nichts darauf, was jemanden verrät:** keine
/// Zählerstände, keine Zählernamen, keine Anschrift. Kein Link und keine
/// Werbung, nur „Gemessen mit Zählora“ (Gründer, 11. November).
struct HeizungsBild: View {
    let karte: HeizungsKarte
    let result: HeatingComparison.Result

    var body: some View {
        let r = result
        VStack(alignment: .leading, spacing: 0) {
            Text("Heizung gewechselt")
                .font(.system(size: 22, weight: .bold))
            Text("\(HeizungsText.ausschnitt(r)), gegen ein Jahr davor")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.35))
                .padding(.top, 4)
            if let diff = karte.euroUnterschied {
                Text(HeizungsText.euro(abs(diff.amount)))
                    .font(.system(size: 58, weight: .heavy))
                    .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.29))
                    .padding(.top, 26)
                Text(diff.amount <= 0 ? "weniger bezahlt" : "mehr bezahlt")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.29))
            } else {
                Text(HeizungsText.zahl(r.after.quantity.value) + " kWh")
                    .font(.system(size: 50, weight: .heavy))
                    .padding(.top, 26)
                Text("Strom statt \(HeizungsText.vorherMenge(r, kind: karte.alt.kind)) \(karte.altArt)")
                    .font(.system(size: 15, weight: .semibold))
            }
            Rectangle().fill(Color(white: 0.85)).frame(height: 1).padding(.vertical, 22)
            HStack(alignment: .top) {
                spalte(karte.altArt, HeizungsText.spanne(r.before.range),
                       karte.mitBetraegen ? r.before.cost.map { HeizungsText.euro($0.amount) } : nil,
                       HeizungsText.vorherMenge(r, kind: karte.alt.kind))
                Spacer()
                spalte("Wärmepumpe", HeizungsText.spanne(r.after.range),
                       karte.mitBetraegen ? r.after.cost.map { HeizungsText.euro($0.amount) } : nil,
                       "\(HeizungsText.zahl(r.after.quantity.value)) kWh Strom")
                Spacer()
            }
            Text(HeizungsText.wetter)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(white: 0.35))
                .padding(.top, 26)
            Spacer(minLength: 0)
            Text("Gemessen mit Zählora")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.11, green: 0.106, blue: 0.098))
        .padding(30)
        .frame(width: 360, height: 450, alignment: .topLeading)
        .background(Color(red: 0.957, green: 0.945, blue: 0.918))
        .environment(\.colorScheme, .light)
    }

    private func spalte(_ kopf: String, _ zeit: String, _ betrag: String?, _ menge: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(kopf).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(white: 0.35))
            Text(zeit).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Color(white: 0.35))
            if let betrag {
                Text(betrag).font(.system(size: 26, weight: .bold)).padding(.top, 8)
            }
            Text(menge).font(.system(size: 12, weight: .medium)).foregroundStyle(Color(white: 0.35))
        }
    }
}

// MARK: - „Heizung gewechselt am …“

/// Am alten Zähler (Gas oder Heizöl). Wählt Tag, Zähler der Wärmepumpe und
/// Wirkungsgrad. Spiegelt `openHeizungsWechsel` im Klick-Dummy.
struct HeizungsWechselSheet: View {

    let alt: MeteringPoint
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Purchase.self) private var purchase

    @State private var tag = Date()
    @State private var bestehend: HeatingChange?
    @State private var kandidaten: [(MeteringPoint, HeatingComparison.Eligibility)] = []
    /// `nil` heißt: neuen Zähler „Heizstrom“ anlegen.
    @State private var gewaehlt: MeteringPoint.ID?
    @State private var wirkungsgrad = ""
    @State private var alleZaehler = 0
    @State private var fragtLoeschen = false
    @State private var kaufblatt: ProductID?
    @State private var problem: String?
    @State private var ablesungen: [MeteringPoint.ID: [Reading]] = [:]

    private var gewaehlterTag: CalendarDay { CalendarDay.containing(tag, in: .current) }
    private var darfNeuenZaehler: Bool { purchase.policy.canAddMeter(existingCount: alleZaehler) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Tag", selection: $tag, in: ...Date(), displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                        .accessibilityIdentifier("heizung-tag")
                } header: {
                    Text("Seit wann heizt die Wärmepumpe?")
                }

                Section {
                    Button {
                        if darfNeuenZaehler { gewaehlt = nil } else { kaufblatt = .additionalMeters }
                    } label: {
                        wahlZeile(titel: "Neuer Zähler „Heizstrom“",
                                  klein: darfNeuenZaehler ? "Wird angelegt, du trägst dann den ersten Stand ein"
                                                          : "Braucht „Unbegrenzt viele Zähler“",
                                  an: gewaehlt == nil && darfNeuenZaehler, aus: false)
                    }
                    .accessibilityIdentifier("heizung-neuer-zaehler")
                    ForEach(kandidaten, id: \.0.id) { meter, eignung in
                        let tauglich = eignung == .eligible
                        Button { gewaehlt = meter.id } label: {
                            wahlZeile(titel: meter.name, klein: grund(eignung, meter: meter),
                                      an: gewaehlt == meter.id, aus: !tauglich)
                        }
                        .disabled(!tauglich)
                        .accessibilityIdentifier("heizung-zaehler-\(meter.name)")
                    }
                } header: {
                    Text("Zähler der Wärmepumpe")
                } footer: {
                    Text("Nur ein eigener Zähler für die Wärmepumpe. Zählt er auch das Haus mit, stünde der Haushaltsstrom auf der Seite der Wärmepumpe.")
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Wirkungsgrad")
                            Text("angenommen").font(PulseText.caption).foregroundStyle(PulseColor.inkTertiary)
                        }
                        .accessibilityHidden(true)
                        Spacer()
                        TextField("90", text: $wirkungsgrad)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 70)
                            .accessibilityLabel("Wirkungsgrad in Prozent, angenommen")
                            .accessibilityIdentifier("heizung-wirkungsgrad")
                        Text("%").foregroundStyle(PulseColor.inkTertiary).accessibilityHidden(true)
                    }
                } header: {
                    Text("Wirkungsgrad des alten Kessels")
                } footer: {
                    Text("Ein Brennwertkessel nutzt rund 90 % vom \(altArt), ein älterer Kessel weniger. Damit wird aus dem \(altArt) die Wärme, die im Haus ankam.")
                }

                if let problem {
                    Section { Text(problem).foregroundStyle(PulseColor.adverse) }
                }

                if bestehend != nil {
                    Section {
                        Button("Wechsel löschen", role: .destructive) { fragtLoeschen = true }
                            .accessibilityIdentifier("heizung-loeschen")
                    } footer: {
                        Text("Die Zähler und ihre Ablesungen bleiben.")
                    }
                }
            }
            .navigationTitle("Heizungswechsel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: sichern)
                        .accessibilityIdentifier("heizung-sichern")
                }
            }
            .confirmationDialog("Wechsel löschen?", isPresented: $fragtLoeschen, titleVisibility: .visible) {
                Button("Wechsel löschen", role: .destructive, action: loeschen)
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Die Zähler und ihre Ablesungen bleiben.")
            }
            .sheet(item: $kaufblatt) { UnlockSheet(product: $0) }
            .onAppear(perform: laden)
            .onChange(of: tag) { _, _ in pruefen() }
        }
    }

    private var altArt: String { alt.kind == .heatingOil ? "Heizöl" : "Gas" }

    private func wahlZeile(titel: String, klein: String?, an: Bool, aus: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: an ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(aus ? PulseColor.inkTertiary : PulseColor.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).foregroundStyle(aus ? PulseColor.inkTertiary : PulseColor.ink)
                if let klein {
                    Text(klein).font(PulseText.caption).foregroundStyle(PulseColor.inkTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private func grund(_ eignung: HeatingComparison.Eligibility, meter: MeteringPoint) -> String? {
        switch eignung {
        case .eligible: return meter.measuresHeatPump ? "Misst eine Wärmepumpe" : nil
        case .measuredBefore(let erste): return "Seit \(HeizungsText.tag(erste)) abgelesen, also schon vor dem Wechsel"
        case .notElectricity: return nil
        }
    }

    // MARK: - Daten

    private func laden() {
        let repository = PulseRepository(context: context)
        let alle = (try? repository.meteringPoints()) ?? []
        alleZaehler = alle.count
        bestehend = (try? repository.heatingChanges())?.first { $0.oldMeterID == alt.id }
        for m in alle where m.kind == .electricity {
            ablesungen[m.id] = (try? repository.readings(for: m)) ?? []
        }
        if let b = bestehend {
            tag = datum(b.day) ?? Date()
            gewaehlt = b.newMeterID
            wirkungsgrad = HeizungsText.zahl(b.boilerEfficiency * 100)
        } else {
            // Vorschlag: der Erste des laufenden Monats.
            tag = datum(CalendarDay.containing(Date(), in: .current).startOfMonth) ?? Date()
            wirkungsgrad = HeizungsText.zahl(HeatingChange.defaultEfficiency(for: alt.kind) * 100)
        }
        pruefen()
    }

    /// Eignung neu, wenn sich der Tag ändert. Eine gewählte, jetzt gesperrte
    /// Wahl fällt auf „neuer Zähler“ zurück.
    private func pruefen() {
        let repository = PulseRepository(context: context)
        let alle = (try? repository.meteringPoints()) ?? []
        kandidaten = alle.filter { $0.kind == .electricity }.map { m in
            (m, HeatingComparison.eligibility(of: m, readings: ablesungen[m.id] ?? [], changeDay: gewaehlterTag))
        }
        if let g = gewaehlt, !kandidaten.contains(where: { $0.0.id == g && $0.1 == .eligible }) {
            gewaehlt = nil
        }
    }

    private func sichern() {
        let repository = PulseRepository(context: context)
        // Ein Wirkungsgrad über 100 % oder unter 50 % ist ein Tippfehler,
        // keine Annahme. Dann bleibt die Vorgabe.
        let eingabe = Decimal(string: wirkungsgrad.replacingOccurrences(of: ",", with: "."),
                              locale: Locale(identifier: "en_US_POSIX"))
        let anteil: Decimal = {
            if let e = eingabe, e >= 50, e <= 100 { return e / 100 }
            return HeatingChange.defaultEfficiency(for: alt.kind)
        }()
        do {
            var neu: MeteringPoint
            if let g = gewaehlt, let m = try repository.meteringPoint(g) {
                neu = m
            } else {
                guard darfNeuenZaehler else { kaufblatt = .additionalMeters; return }
                let property = try repository.ensureDefaultProperty()
                neu = MeteringPoint(propertyID: property.id, name: "Heizstrom", kind: .electricity,
                                    sortIndex: alleZaehler, measuresHeatPump: true)
            }
            // Der Wechsel setzt den Schalter aus Teil C von selbst.
            neu.measuresHeatPump = true
            try repository.save(neu)
            let change = HeatingChange(id: bestehend?.id ?? UUID(), day: gewaehlterTag,
                                       oldMeterID: alt.id, newMeterID: neu.id,
                                       boilerEfficiency: anteil)
            try repository.save(change)
            onDone()
            dismiss()
        } catch {
            problem = "Der Wechsel ließ sich nicht sichern: \(error.localizedDescription)"
        }
    }

    private func loeschen() {
        guard let b = bestehend else { return }
        try? PulseRepository(context: context).delete(heatingChangeID: b.id)
        onDone()
        dismiss()
    }

    private func datum(_ day: CalendarDay) -> Date? {
        var c = DateComponents()
        c.year = day.year; c.month = day.month; c.day = day.day
        return Calendar(identifier: .gregorian).date(from: c)
    }
}
