import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PulseCore
import PulseData
import PulseUI

/// Stände aus einer Tabelle einlesen.
///
/// **Ein Blatt, kein Assistent.** Oben kommt die Tabelle hinein, eingefügt
/// oder als Datei, darunter steht sofort, was daraus wird: welche Zähler,
/// wie viele Stände, wohin, und was nicht passt. Wer etwas anders will,
/// stellt es dort um, wo es steht. Vom Gründer am 13. Oktober verlangt:
/// „mache es dynamisch und so benutzerfreundlich wie möglich."
///
/// Erkannt wird in ``TableImport`` (Rechenkern), dieselben Regeln wie im
/// Klick-Dummy. Gespeichert wird in einem Zug: alle Stände oder keiner.
struct ImportView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Purchase.self) private var purchase

    /// Vorbelegung, nur für Prüfungen und Bildschirmfotos.
    var startText: String = ""
    var onDone: () -> Void = {}

    enum Ziel: Hashable {
        case neu
        case vorhanden(MeteringPoint.ID, Register.ID)
        case nicht
    }

    /// Ein vorhandenes Zählwerk als Ziel.
    struct Option: Hashable {
        let ziel: Ziel
        let name: String
        let zaehlwerk: Register
    }

    struct Fertig {
        let anzahl: Int
        let namen: [String]
        let neueZaehler: [MeteringPoint.ID]
        let staende: [Reading.ID]
    }

    @State private var text = ""
    @State private var draft: TableImport.Draft?
    @State private var result: TableImport.Result?
    @State private var ziele: [String: Ziel] = [:]
    @State private var arten: [String: ResourceKind] = [:]
    @State private var zaehler: [MeteringPoint] = []
    @State private var gesamtZahl = 0
    @State private var vorhandene: [Register.ID: [Reading]] = [:]
    @State private var dateiWaehlen = false
    @State private var fertig: Fertig?
    @State private var problem: String?
    @State private var kaufen = false
    @State private var alleHinweise = false

    static let beispiel = """
    Datum;Strom;Gas;Wasser
    03.01.2025;12.345,6;4.567,890;123,456
    02.02.2025;12.601,2;4.689,120;126,001
    01.03.2025;12.850,0;4.790,005;129,370
    05.04.2025;13.071,4;4.851,330;132,904
    03.05.2025;13.262,9;4.880,412;136,210
    """

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    }
                    eingabe
                    if let fertig {
                        fertigAnsicht(fertig)
                    } else {
                        vorschau
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Einlesen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(fertig == nil ? "Abbrechen" : "Fertig") { dismiss() }
                }
            }
            .fileImporter(isPresented: $dateiWaehlen,
                          allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text],
                          allowsMultipleSelection: false) { auswahl in
                dateiGewaehlt(auswahl)
            }
            .sheet(isPresented: $kaufen) { UnlockSheet(product: .additionalMeters) }
            .onAppear {
                laden()
                if text.isEmpty, !startText.isEmpty { text = startText }
            }
            // Erkannt wird, kurz nachdem das Tippen aufhört, und abseits der
            // Oberfläche: Zehn Jahre täglicher Stände brauchen einen Moment.
            .task(id: text) {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                let eingabe = text
                let erkannt = await Task.detached { TableImport.analyse(eingabe) }.value
                guard !Task.isCancelled else { return }
                draft = eingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : erkannt
                ziele = [:]
                neuRechnen()
            }
        }
    }

    // MARK: - Eingabe

    private var eingabe: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In Excel oder Numbers die Zellen markieren, kopieren und hier einfügen. Eine Datei geht auch.")
                .font(.subheadline)
                .foregroundStyle(PulseColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 120, maxHeight: 220)
                    .padding(8)
                    .accessibilityLabel("Tabelle")
                    .accessibilityIdentifier("import-text")
                if text.isEmpty {
                    Text("Datum       Strom      Gas\n03.01.2025  12.345,6   4.567,890")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(PulseColor.inkTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PulseColor.hairline))

            PulseCard {
                VStack(spacing: 0) {
                    // Der Knopf des Systems fragt nicht nach, ob die App die
                    // Zwischenablage lesen darf: Antippen ist die Erlaubnis.
                    HStack {
                        PasteButton(payloadType: String.self) { werte in
                            if let erster = werte.first {
                                text = erster
                                fertig = nil
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        .tint(PulseColor.tint)
                        Spacer()
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    Divider().overlay(PulseColor.hairline)
                    quelle("Datei wählen", "CSV oder Text, auch aus Excel", kennung: "import-datei") {
                        dateiWaehlen = true
                    }
                    Divider().overlay(PulseColor.hairline)
                    quelle("Beispiel einfügen", "So sieht eine Liste aus, die passt", kennung: "import-beispiel") {
                        text = Self.beispiel
                        fertig = nil
                    }
                }
            }
        }
    }

    private func quelle(_ titel: String, _ zusatz: String, kennung: String,
                        aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.system(.body, weight: .medium)).foregroundStyle(PulseColor.ink)
                    Text(zusatz).font(PulseText.caption).foregroundStyle(PulseColor.inkTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PulseColor.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(kennung)
    }

    // MARK: - Vorschau

    @ViewBuilder
    private var vorschau: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else if draft == nil {
            hinweisKasten("Darin steht keine Tabelle. Gebraucht wird eine Spalte mit dem Datum und eine mit dem Zählerstand, getrennt durch Tabulator, Semikolon oder Komma.")
                .accessibilityIdentifier("import-keine-tabelle")
        } else if let result, !result.series.isEmpty {
            gefunden(result)
        } else {
            let fehlt = !(draft?.columns.contains { $0.role == .date } ?? false) ? "eine Spalte mit dem Datum"
                : !(draft?.columns.contains { $0.role == .reading } ?? false) ? "eine Spalte mit dem Zählerstand"
                : "ein lesbarer Zählerstand"
            hinweisKasten("Es fehlt \(fehlt). Stell unten ein, welche Spalte was ist.")
            spalten
            hinweise(result?.issues ?? [])
        }
    }

    private func gefunden(_ result: TableImport.Result) -> some View {
        let plan = self.plan
        let anzahl = plan.reduce(0) { $0 + $1.merge.readings.count }
        let gleich = plan.reduce(0) { $0 + $1.merge.alreadyThere }
        let alle = result.series.flatMap(\.entries).map(\.day)
        let namen = Set(result.series.map(\.meterName)).count
        let summe = "\(namen == 1 ? "1 Zähler" : "\(namen) Zähler") · \(alle.count == 1 ? "1 Stand" : "\(alle.count) Stände")"
            + (alle.isEmpty ? "" : " · \(deutsch(alle.min()!)) bis \(deutsch(alle.max()!))")
        let alleHinweise = result.issues + result.series.flatMap(\.issues) + plan.flatMap(\.merge.conflicts)

        return VStack(alignment: .leading, spacing: 14) {
            Text(summe)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(PulseColor.ink)
                .padding(.top, 8)
                .accessibilityIdentifier("import-summe")

            Text("WOHIN").font(PulseText.sectionLabel).tracking(0.8).foregroundStyle(PulseColor.inkTertiary)
            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(result.series.enumerated()), id: \.element.id) { index, reihe in
                        if index > 0 { Divider().overlay(PulseColor.hairline) }
                        zeile(reihe, plan: plan)
                    }
                }
            }

            if grenzeVerhindert(result) {
                hinweisKasten("Kostenlos sind \(AccessPolicy.freeMeterLimit) Zähler. Für weitere bleibt die Liste hier draußen.")
                Button("Mehr Zähler freischalten") { kaufen = true }
                    .font(.system(.subheadline, weight: .semibold))
                    .tint(PulseColor.tintInk)
                    .frame(minHeight: 44)
            }

            Button(action: einlesen) {
                Text(anzahl > 0 ? (anzahl == 1 ? "1 Stand einlesen" : "\(anzahl.formatted(.number.locale(Locale(identifier: "de_DE")))) Stände einlesen")
                                : (gleich > 0 ? "Alles schon da" : "Nichts einzulesen"))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(PulseColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PulseColor.tint.opacity(anzahl > 0 ? 1 : 0.4),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(anzahl == 0)
            .accessibilityIdentifier("import-einlesen")

            Text("Eingelesene Stände tragen den Vermerk „eingelesen“. Was schon da ist, bleibt, wie es ist.")
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            hinweise(alleHinweise)

            DisclosureGroup("Spalten anders zuordnen") { spalten }
                .font(.system(.subheadline, weight: .semibold))
                .tint(PulseColor.tintInk)
        }
    }

    private func zeile(_ reihe: TableImport.Series, plan: [Schritt]) -> some View {
        let ziel = ziele[reihe.id] ?? .nicht
        let schritt = plan.first { $0.reihe.id == reihe.id }
        let darfNeu = darfNeuenZaehler(fuer: reihe)
        var zusatz = "\(reihe.entries.count == 1 ? "1 Stand" : "\(reihe.entries.count) Stände") · \(spanne(reihe)) · \(reihe.unit.symbol)"
        if let schritt, schritt.merge.alreadyThere > 0 { zusatz += " · \(schritt.merge.alreadyThere) schon da" }

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reihe.meterName + (reihe.registerLabel.map { " · \($0)" } ?? ""))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PulseColor.ink)
                    Text(zusatz).font(PulseText.caption).foregroundStyle(PulseColor.inkTertiary)
                }
                Spacer(minLength: 8)
                Picker("Wohin mit \(reihe.meterName)", selection: Binding(
                    get: { ziele[reihe.id] ?? .nicht },
                    set: { ziele[reihe.id] = $0 })) {
                    Text(darfNeu ? "Neuer Zähler" : "Neuer Zähler (Zählergrenze)").tag(Ziel.neu)
                        .selectionDisabled(!darfNeu)
                    ForEach(moeglicheZiele(fuer: reihe), id: \.ziel) { option in
                        Text("in „\(option.name)“").tag(option.ziel)
                    }
                    Text("Nicht einlesen").tag(Ziel.nicht)
                }
                .pickerStyle(.menu)
                .tint(PulseColor.tintInk)
                .accessibilityIdentifier("import-ziel-\(reihe.meterName)")
            }
            if ziel == .neu {
                Picker("Art", selection: Binding(
                    get: { arten[reihe.id] ?? reihe.kind },
                    set: { arten[reihe.id] = $0 })) {
                    ForEach(MeterEditor.kinds, id: \.storageID) { art in
                        Text("Art: \(MeterEditor.kindName(art))").tag(art)
                    }
                }
                .pickerStyle(.menu)
                .tint(PulseColor.tintInk)
                .font(PulseText.caption)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    private var spalten: some View {
        PulseCard {
            VStack(spacing: 0) {
                ForEach(Array((draft?.columns ?? []).enumerated()), id: \.element.id) { index, spalte in
                    if index > 0 { Divider().overlay(PulseColor.hairline) }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spalte.header ?? "Spalte \(spalte.index + 1)")
                                .font(.system(.body, weight: .medium)).foregroundStyle(PulseColor.ink)
                            Text(spalte.samples.isEmpty ? "leer" : spalte.samples.joined(separator: " · "))
                                .font(PulseText.caption).foregroundStyle(PulseColor.inkTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Picker("Spalte \(spalte.header ?? "\(spalte.index + 1)") ist", selection: Binding(
                            get: { spalte.role },
                            set: { rolleSetzen($0, fuer: spalte.index) })) {
                            ForEach(TableImport.Role.allCases, id: \.self) { rolle in
                                Text(Self.rollenName(rolle)).tag(rolle)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PulseColor.tintInk)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func hinweise(_ liste: [TableImport.Issue]) -> some View {
        if !liste.isEmpty {
            let zeigen = alleHinweise ? liste : Array(liste.prefix(4))
            VStack(alignment: .leading, spacing: 6) {
                Text(liste.count == 1 ? "1 HINWEIS" : "\(liste.count) HINWEISE")
                    .font(PulseText.sectionLabel).tracking(0.8).foregroundStyle(PulseColor.inkTertiary)
                ForEach(Array(zeigen.enumerated()), id: \.offset) { _, hinweis in
                    Label(hinweis.text, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(PulseColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if liste.count > zeigen.count {
                    Button("Alle \(liste.count) zeigen") { alleHinweise = true }
                        .font(.system(.footnote, weight: .semibold))
                        .tint(PulseColor.tintInk)
                        .frame(minHeight: 44)
                }
            }
            .padding(.top, 6)
            .accessibilityIdentifier("import-hinweise")
        }
    }

    private func hinweisKasten(_ satz: String) -> some View {
        Text(satz)
            .font(.footnote)
            .foregroundStyle(PulseColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulseColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func fertigAnsicht(_ f: Fertig) -> some View {
        VStack(spacing: 8) {
            Text(f.anzahl == 1 ? "1 Stand eingelesen" : "\(f.anzahl.formatted(.number.locale(Locale(identifier: "de_DE")))) Stände eingelesen")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(PulseColor.ink)
                .accessibilityIdentifier("import-fertig")
            Text("in \(f.namen.joined(separator: ", "))"
                 + (f.neueZaehler.isEmpty ? "" : " · \(f.neueZaehler.count == 1 ? "1 Zähler" : "\(f.neueZaehler.count) Zähler") neu angelegt"))
                .font(.subheadline)
                .foregroundStyle(PulseColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Rückgängig machen", action: rueckgaengig)
                .font(.system(.subheadline, weight: .semibold))
                .tint(PulseColor.tintInk)
                .frame(minHeight: 44)
                .accessibilityIdentifier("import-rueckgaengig")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    // MARK: - Rechnen

    struct Schritt {
        let reihe: TableImport.Series
        let ziel: Ziel
        let merge: TableImport.Merge
    }

    /// Was beim Einlesen geschähe, je Reihe.
    private var plan: [Schritt] {
        guard let result else { return [] }
        return result.series.compactMap { reihe in
            switch ziele[reihe.id] ?? .nicht {
            case .nicht: return nil
            case .neu:
                return Schritt(reihe: reihe, ziel: .neu,
                               merge: TableImport.readings(from: reihe, register: UUID(), existing: []))
            case .vorhanden(let zaehler, let zaehlwerk):
                return Schritt(reihe: reihe, ziel: .vorhanden(zaehler, zaehlwerk),
                               merge: TableImport.readings(from: reihe, register: zaehlwerk,
                                                           existing: vorhandene[zaehlwerk] ?? []))
            }
        }
    }

    private func neuRechnen() {
        guard let draft, draft.columns.contains(where: { $0.role == .date }) else {
            result = nil
            return
        }
        result = TableImport.series(from: draft)
        zieleVorbelegen()
    }

    private func rolleSetzen(_ rolle: TableImport.Role, fuer index: Int) {
        guard var d = draft else { return }
        // Datum, Uhrzeit, Zähler und die anderen gibt es nur einmal: Wer eine
        // andere Spalte dazu macht, nimmt der bisherigen die Rolle.
        if rolle != .reading && rolle != .ignored {
            for i in d.columns.indices where i != index && d.columns[i].role == rolle {
                d.columns[i].role = .ignored
            }
        }
        d.columns[index].role = rolle
        draft = d
        ziele = [:]
        neuRechnen()
    }

    /// Vorhandene Zählwerke mit derselben Einheit.
    private func moeglicheZiele(fuer reihe: TableImport.Series) -> [Option] {
        zaehler.flatMap { punkt in
            punkt.registers.filter { $0.unit == reihe.unit }.map { zaehlwerk in
                let name = punkt.registers.count > 1
                    ? "\(punkt.name) · \(zaehlwerk.label ?? Self.richtung(zaehlwerk.direction))" : punkt.name
                return Option(ziel: .vorhanden(punkt.id, zaehlwerk.id), name: name, zaehlwerk: zaehlwerk)
            }
        }
    }

    /// Wie viele neue Zähler noch gehen. `nil` heißt: beliebig viele.
    private var freieZaehler: Int? {
        purchase.policy.remainingMeters(existingCount: gesamtZahl)
    }

    private var neueGruppen: [String] {
        guard let result else { return [] }
        var namen: [String] = []
        for reihe in result.series where ziele[reihe.id] == .neu && !namen.contains(reihe.meterName) {
            namen.append(reihe.meterName)
        }
        return namen
    }

    private func darfNeuenZaehler(fuer reihe: TableImport.Series) -> Bool {
        guard let frei = freieZaehler else { return true }
        return neueGruppen.contains(reihe.meterName) || neueGruppen.count < frei
    }

    private func grenzeVerhindert(_ result: TableImport.Result) -> Bool {
        guard let frei = freieZaehler else { return false }
        return result.series.contains { ziele[$0.id] == .nicht && !neueGruppen.contains($0.meterName) }
            && neueGruppen.count >= frei
    }

    /// Gleicher Name allein reicht nicht: Die Reihe muss auch zwischen die
    /// vorhandenen Stände passen. Sonst landete eine Liste wegen des Namens
    /// „Strom" in einem Zähler, dessen Stände viermal so hoch sind.
    private func zieleVorbelegen() {
        guard let result else { return }
        var frei = freieZaehler ?? .max
        var neu: [String] = []
        for reihe in result.series where ziele[reihe.id] == nil {
            let passend = moeglicheZiele(fuer: reihe).first { option in
                guard let punkt = zaehler.first(where: { if case .vorhanden(let id, _) = option.ziel { return $0.id == id }; return false })
                else { return false }
                let gleicherName = punkt.name.lowercased() == reihe.meterName.lowercased()
                let gleichesZaehlwerk = reihe.registerLabel.map { ($0.lowercased() == (option.zaehlwerk.label ?? "").lowercased()) } ?? true
                return gleicherName && gleichesZaehlwerk
                    && TableImport.readings(from: reihe, register: option.zaehlwerk.id,
                                            existing: vorhandene[option.zaehlwerk.id] ?? []).misfits == 0
            }
            if let passend {
                ziele[reihe.id] = passend.ziel
            } else if neu.contains(reihe.meterName) || frei > 0 {
                if !neu.contains(reihe.meterName) { neu.append(reihe.meterName); frei -= 1 }
                ziele[reihe.id] = .neu
            } else {
                ziele[reihe.id] = .nicht
            }
        }
    }

    // MARK: - Speichern

    private func einlesen() {
        let plan = self.plan
        guard !plan.isEmpty else { return }
        do {
            let repository = PulseRepository(context: context)
            let property = try repository.ensureDefaultProperty()
            var neuNachName: [String: MeteringPoint] = [:]
            var reihenfolge: [String] = []
            var zuSichern: [(reading: Reading, fractionDigits: Int)] = []
            var namen: [String] = []
            let jetzt = Date()

            for schritt in plan where !schritt.merge.readings.isEmpty {
                let reihe = schritt.reihe
                let zaehlwerk: Register
                switch schritt.ziel {
                case .neu:
                    var punkt: MeteringPoint
                    if let schon = neuNachName[reihe.meterName] {
                        punkt = schon
                    } else {
                        let art = arten[reihe.id] ?? reihe.kind
                        let name = reihe.meterName == "Zähler" ? MeterEditor.kindName(art) : reihe.meterName
                        reihenfolge.append(reihe.meterName)
                        punkt = MeteringPoint(propertyID: property.id, name: name, kind: art, registers: [])
                    }
                    let art = punkt.kind
                    zaehlwerk = Register(label: reihe.registerLabel, unit: reihe.unit, direction: reihe.direction,
                                         accumulation: art.defaultAccumulation,
                                         integerDigits: reihe.integerDigits, fractionDigits: reihe.fractionDigits)
                    punkt.registers.append(zaehlwerk)
                    neuNachName[reihe.meterName] = punkt
                    if !namen.contains(punkt.name) { namen.append(punkt.name) }
                case .vorhanden(let id, let zaehlwerkID):
                    guard let punkt = zaehler.first(where: { $0.id == id }),
                          let vorhanden = punkt.registers.first(where: { $0.id == zaehlwerkID }) else { continue }
                    zaehlwerk = vorhanden
                    if !namen.contains(punkt.name) { namen.append(punkt.name) }
                case .nicht:
                    continue
                }
                let staende = TableImport.readings(from: reihe, register: zaehlwerk.id,
                                                   existing: vorhandene[zaehlwerk.id] ?? [], createdAt: jetzt)
                let stellen = zaehlwerk.fractionDigits
                for stand in staende.readings {
                    zuSichern.append((reading: stand, fractionDigits: stellen))
                }
            }

            let neue = reihenfolge.compactMap { neuNachName[$0] }
            for punkt in neue { try repository.save(punkt) }
            do {
                try repository.save(zuSichern)
            } catch {
                // Alle oder keiner: Ohne Stände blieben leere Zähler zurück.
                for punkt in neue { try? repository.deletePermanently(meteringPointID: punkt.id) }
                throw error
            }
            fertig = Fertig(anzahl: zuSichern.count, namen: namen,
                            neueZaehler: neue.map { $0.id }, staende: zuSichern.map { $0.reading.id })
            problem = nil
            onDone()
        } catch {
            problem = "Die Stände ließen sich nicht sichern: \(error.localizedDescription)"
        }
    }

    private func rueckgaengig() {
        guard let fertig else { return }
        do {
            let repository = PulseRepository(context: context)
            for id in fertig.staende { try repository.delete(readingID: id) }
            for id in fertig.neueZaehler { try repository.deletePermanently(meteringPointID: id) }
            self.fertig = nil
            laden()
            ziele = [:]
            neuRechnen()
            onDone()
        } catch {
            problem = "Das ließ sich nicht zurücknehmen: \(error.localizedDescription)"
        }
    }

    private func laden() {
        do {
            let repository = PulseRepository(context: context)
            zaehler = try repository.meteringPoints()
            gesamtZahl = try repository.meteringPoints(includeArchived: true).count
            var staende: [Register.ID: [Reading]] = [:]
            for punkt in zaehler {
                for zaehlwerk in punkt.registers {
                    staende[zaehlwerk.id] = try repository.readings(for: zaehlwerk.id)
                }
            }
            vorhandene = staende
        } catch {
            problem = "Die vorhandenen Zähler ließen sich nicht laden: \(error.localizedDescription)"
        }
    }

    private func dateiGewaehlt(_ auswahl: Result<[URL], Error>) {
        guard case .success(let urls) = auswahl, let url = urls.first else { return }
        let freigegeben = url.startAccessingSecurityScopedResource()
        defer { if freigegeben { url.stopAccessingSecurityScopedResource() } }
        guard let daten = try? Data(contentsOf: url), let inhalt = TableImport.text(from: daten) else {
            problem = "Die Datei ließ sich nicht lesen."
            return
        }
        problem = nil
        fertig = nil
        text = inhalt
    }

    // MARK: - Text

    static func rollenName(_ rolle: TableImport.Role) -> String {
        switch rolle {
        case .date: return "Datum"
        case .time: return "Uhrzeit"
        case .reading: return "Zählerstand"
        case .meter: return "Zähler"
        case .register: return "Zahl am Zähler"
        case .unit: return "Einheit"
        case .note: return "Notiz"
        case .ignored: return "Nicht einlesen"
        }
    }

    static func richtung(_ richtung: FlowDirection) -> String {
        switch richtung {
        case .consumption: return "Bezug"
        case .feedIn: return "Einspeisung"
        case .production: return "Erzeugung"
        case .charge: return "Ladung"
        case .discharge: return "Entladung"
        }
    }

    private func spanne(_ reihe: TableImport.Series) -> String {
        guard let erster = reihe.first, let letzter = reihe.last else { return "" }
        return erster == letzter ? deutsch(erster) : "\(deutsch(erster)) bis \(deutsch(letzter))"
    }

    private func deutsch(_ tag: CalendarDay) -> String {
        String(format: "%02d.%02d.%04d", tag.day, tag.month, tag.year)
    }
}
