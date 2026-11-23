import SwiftUI
import AVFoundation
import UIKit
import PulseCore
import PulseUI

/// Der Sucher: Die Kamera schaut auf den Zähler, ein Rahmen sagt, wo die Zahl
/// stehen soll, und sobald dieselbe Zahl mehrfach gelesen wurde, steht sie da —
/// zum Übernehmen, nicht zum Sichern.
///
/// **Warum ein Rahmen und kein Foto.** Ein ganzes Zählerfoto liest zuerst, was
/// nicht der Stand ist: Typenschild, Seriennummer, Baujahr (`docs/kamera/README.md`).
/// Im Rahmen steht nur, was der Nutzer dort hingehalten hat. Das ist auch die
/// Bedingung dafür, dass LCD-Anzeigen überhaupt gelesen werden: Das Netz bekommt
/// einen Ausschnitt mit den Ziffern, es sucht kein Display.
///
/// **Was angezeigt wird, ist, was gelesen wurde** (Produktprinzip 7). Unter dem
/// Rahmen steht live die Ziffernfolge, die das Netz sieht, auch wenn sie noch
/// nicht für einen Vorschlag reicht.
struct KameraView: View {

    let format: MeterFormat
    let einheit: String
    let bereich: ClosedRange<Decimal>?
    /// Alle Zählwerke des Zählers und welches gefragt ist. Das Display wechselt zwischen
    /// 1.8.0 und 2.8.0 (`docs/kamera/stufe-2.md`): Die Bereiche ordnen die Zahl dem richtigen
    /// Zählwerk zu.
    var zaehlwerke = KameraZaehlwerke.einzeln
    let farbe: Color
    /// Der gelesene Stand und ob nur die Stellen vor dem Komma gelesen wurden.
    let uebernehmen: (Decimal, Bool) -> Void
    /// Zahlen anderer Zählwerke, die die Kamera nebenbei gelesen hat (Index → Wert). Beim
    /// Schließen übergeben, ob mit oder ohne „Übernehmen“: So reicht ein Kamerabesuch für beide.
    var gemerkt: ([Int: Decimal]) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var modell = KameraModell()

    var body: some View {
        GeometryReader { geometry in
            let rahmen = Viewfinder.guide(inViewWidth: geometry.size.width, height: geometry.size.height)
            ZStack {
                Color.black.ignoresSafeArea()
                switch modell.zustand {
                case .pruefen:
                    ProgressView().tint(.white)
                case .bereit:
                    KameraVorschau(sitzung: modell.sitzung, drehung: modell.drehung)
                        .ignoresSafeArea()
                    Abdunkelung(loch: CGRect(x: rahmen.x, y: rahmen.y, width: rahmen.width, height: rahmen.height))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(modell.treffer == nil ? Color.white : farbe, lineWidth: modell.treffer == nil ? 2 : 4)
                        .frame(width: rahmen.width, height: rahmen.height)
                        .position(x: rahmen.x + rahmen.width / 2, y: rahmen.y + rahmen.height / 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    anweisung(rahmen: rahmen)
                case .keineErlaubnis:
                    hinweisBlatt(titel: "Zählora darf die Kamera nicht benutzen",
                                 text: "Du kannst das in den Einstellungen erlauben. Bis dahin tippst du den Stand einfach ein.",
                                 knopf: ("Einstellungen öffnen", einstellungen))
                case .keineKamera:
                    hinweisBlatt(titel: "Dieses Gerät hat keine Kamera",
                                 text: "Tipp den Stand einfach ein.", knopf: nil)
                }
                obenLeiste
                if let treffer = modell.treffer { ergebnisKarte(treffer) }
            }
            .onAppear { aufmachen(geometry.size, rahmen) }
            .onChange(of: geometry.size) { _, neu in
                modell.ansichtGeaendert(groesse: neu, rahmen: Viewfinder.guide(inViewWidth: neu.width, height: neu.height))
            }
        }
        .statusBarHidden()
        .onDisappear {
            modell.beenden()
            if !modell.gemerkt.isEmpty { gemerkt(modell.gemerkt) }
        }
        .task { await modell.vorbereiten(format: format, bereich: bereich, zaehlwerke: zaehlwerke) }
    }

    private func aufmachen(_ groesse: CGSize, _ rahmen: PixelRect) {
        modell.ansichtGeaendert(groesse: groesse, rahmen: rahmen)
    }

    private func einstellungen() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    // MARK: - Teile

    private var obenLeiste: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Schließen")
                .accessibilityIdentifier("kamera-schliessen")
                Spacer()
                if modell.zustand == .bereit, modell.sitzung.hatTaschenlampe {
                    Button { modell.lampeUmschalten() } label: {
                        Image(systemName: modell.lampeAn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(modell.lampeAn ? Color.yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .accessibilityLabel(modell.lampeAn ? "Taschenlampe ausschalten" : "Taschenlampe einschalten")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    /// Was über und unter dem Rahmen steht.
    private func anweisung(rahmen: PixelRect) -> some View {
        ZStack {
            Text(modell.treffer == nil ? "Halte die Zahl in den Rahmen" : "Gefunden")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())
                .position(x: rahmen.x + rahmen.width / 2, y: max(70, rahmen.y - 34))

            VStack(spacing: 8) {
                if let text = hinweisText {
                    Text(text)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !modell.gelesen.isEmpty, modell.treffer == nil {
                    // Was das Netz im Rahmen sieht, auch wenn es noch nicht reicht.
                    Text("Ich sehe \(modell.gelesen)")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityLabel("Ich sehe \(modell.gelesen)")
                }
            }
            .frame(maxWidth: rahmen.width)
            .position(x: rahmen.x + rahmen.width / 2, y: rahmen.y + rahmen.height + 56)
        }
    }

    /// Der Hinweis zum Bild: ein Satz, der sagt, was sich ändern lässt.
    private var hinweisText: String? {
        if modell.treffer != nil { return nil }
        if let hinweis = modell.zuordnungsHinweis { return hinweis }
        switch modell.qualitaet {
        case .tooDark: return modell.sitzung.hatTaschenlampe ? "Zu dunkel. Mit der Taschenlampe geht es besser." : "Zu dunkel."
        case .flat: return "Kaum Kontrast. Kipp das Telefon, bis die Spiegelung weg ist."
        case .blurry: return "Unscharf. Halte ruhig und etwas weiter weg."
        case .ok: return modell.langeOhneTreffer ? "Klappt nicht? Tipp den Stand einfach ein." : nil
        }
    }

    private func ergebnisKarte(_ treffer: ReadingConsensus.Agreement) -> some View {
        let p = treffer.proposal
        return VStack {
            Spacer()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("Ich lese")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkTertiary)
                    Text("\(zahl(p.value)) \(einheit)")
                        .font(PulseText.value)
                        .foregroundStyle(PulseColor.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if p.fractionMissing {
                        Text("Die Stellen nach dem Komma zeigt der Zähler hier nicht. Sie stehen mit 0 im Ziffernblock.")
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .accessibilityElement(children: .combine)
                ForEach(modell.gemerkt.keys.sorted(), id: \.self) { i in
                    // Was die Kamera für ein anderes Zählwerk schon gelesen hat. Es steht dort im
                    // Ziffernblock zum Prüfen, gesichert wird es erst mit „Sichern“.
                    Text("Auch gelesen: \(zaehlwerke.namen[i]) \(zahl(modell.gemerkt[i]!)) \(einheit)")
                        .font(PulseText.caption)
                        .foregroundStyle(PulseColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("kamera-gemerkt")
                }
                Button {
                    uebernehmen(p.value, p.fractionMissing)
                    dismiss()
                } label: {
                    Text("Übernehmen")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PulseColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(farbe, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityIdentifier("kamera-uebernehmen")
                Button("Weiter suchen") { modell.weiterSuchen() }
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PulseColor.inkSecondary)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("kamera-weiter-suchen")
            }
            .padding(18)
            .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func hinweisBlatt(titel: String, text: String, knopf: (String, () -> Void)?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityHidden(true)
            Text(titel)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.system(.body))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if let knopf {
                Button(knopf.0, action: knopf.1)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PulseColor.onAccent)
                    .padding(.horizontal, 20).padding(.vertical, 13)
                    .background(farbe, in: Capsule())
            }
            Button("Zurück zum Ziffernblock") { dismiss() }
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(minHeight: 44)
        }
        .padding(28)
    }

    private func zahl(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(format.fractionDigits)).locale(Locale(identifier: "de_DE")))
    }
}

// MARK: - Zählwerke

/// Was der Sucher über den Zähler wissen muss, um eine Zahl dem richtigen Zählwerk zuzuordnen.
struct KameraZaehlwerke {
    /// Name je Zählwerk für die Hinweise, etwa „„Einspeisung““.
    var namen: [String]
    /// Kennzahl je Zählwerk (``ObisCode/effectiveCodes(of:kind:)``), `nil` wo keine gilt.
    var kennzahlen: [String?]
    /// Bereich je Zählwerk, `nil` ohne letzten Stand.
    var bereiche: [ClosedRange<Decimal>?]
    /// Index des gefragten Zählwerks.
    var gefragt: Int

    static let einzeln = KameraZaehlwerke(namen: ["der Stand"], kennzahlen: [nil], bereiche: [nil], gefragt: 0)

    /// Die Bereiche der anderen Zählwerke, soweit es sie gibt: In sie darf eine Zahl auch fallen.
    var andereBereiche: [ClosedRange<Decimal>] {
        bereiche.indices.filter { $0 != gefragt }.compactMap { bereiche[$0] }
    }
}

// MARK: - Modell

@MainActor
@Observable
final class KameraModell {

    enum Zustand { case pruefen, bereit, keineErlaubnis, keineKamera }

    let sitzung = KameraSitzung()
    var zustand: Zustand = .pruefen
    /// Die Ziffernfolge, die das Netz gerade im Rahmen sieht.
    var gelesen = ""
    var qualitaet: FrameQuality.Hint = .ok
    var treffer: ReadingConsensus.Agreement?
    var lampeAn = false
    /// Nach einer Weile ohne Treffer sagt der Sucher, dass Tippen auch geht.
    var langeOhneTreffer = false
    /// Warum die zuletzt geeinigte Zahl nicht vorgeschlagen wurde, als Satz für den Sucher.
    var zuordnungsHinweis: String?
    /// Zahlen anderer Zählwerke, die die Kamera nebenbei gelesen hat (Index → Wert).
    var gemerkt: [Int: Decimal] = [:]
    var drehung: CGFloat = 90

    private var konsens = LabeledConsensus()
    private var format = MeterFormat(integerDigits: 6, fractionDigits: 0)
    private var bereich: ClosedRange<Decimal>?
    private var zaehlwerke = KameraZaehlwerke.einzeln
    private var gestartet = Date()
    private var vorfuehrung: Task<Void, Never>?

    func vorbereiten(format: MeterFormat, bereich: ClosedRange<Decimal>?,
                     zaehlwerke: KameraZaehlwerke = .einzeln) async {
        self.format = format
        self.bereich = bereich
        self.zaehlwerke = zaehlwerke
        gestartet = Date()
        // Im Simulator gibt es keine Kamera. Mit `-pulse-kamera-test` läuft ein
        // gezeichnetes Bild durch dieselbe Auswertung, damit der Weg bis in den
        // Ziffernblock trotzdem geprüft wird.
        if Startschalter.gesetzt("-pulse-kamera-test") {
            zustand = .bereit
            starteVorfuehrung()
            return
        }
        guard KameraSitzung.kameraVorhanden else { zustand = .keineKamera; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { zustand = .keineErlaubnis; return }
        default:
            zustand = .keineErlaubnis
            return
        }
        drehung = Self.drehungDerAnzeige()
        sitzung.setzeEmpfaenger { [weak self] befund in
            Task { @MainActor in self?.aufnehmen(befund) }
        }
        let formatKopie = self.format
        let bereichKopie = self.bereich
        let andereKopie = zaehlwerke.andereBereiche
        sitzung.setzeVorgaben {
            $0.format = formatKopie
            $0.bereich = bereichKopie
            $0.andereBereiche = andereKopie
        }
        zustand = .bereit
        sitzung.starten(drehung: drehung)
    }

    func beenden() {
        vorfuehrung?.cancel()
        sitzung.anhalten()
    }

    func ansichtGeaendert(groesse: CGSize, rahmen: PixelRect) {
        sitzung.setzeVorgaben {
            $0.ansicht = groesse
            $0.rahmen = rahmen
        }
        let neu = Self.drehungDerAnzeige()
        if neu != drehung {
            drehung = neu
            sitzung.drehen(neu)
        }
    }

    func lampeUmschalten() {
        lampeAn.toggle()
        sitzung.taschenlampe(lampeAn)
    }

    func weiterSuchen() {
        treffer = nil
        konsens.reset()
        gestartet = Date()
        langeOhneTreffer = false
        if Startschalter.gesetzt("-pulse-kamera-test") { starteVorfuehrung() }
    }

    /// Ein Bild ist ausgewertet.
    func aufnehmen(_ befund: KameraBefund) {
        // Die Kennzahl liest die App noch nicht: Das Netz dafür las sie auf echten Fotos zu selten
        // und manchmal falsch (`docs/kamera/stufe-2.md`, Messung). Die Bereiche ordnen zu.
        guard let einig = konsens.add(befund.ergebnis, code: nil) else {
            if treffer == nil { anzeigen(befund) }
            return
        }
        let wert = einig.reading.proposal.value
        let zuordnung = RegisterAssignment.decide(value: wert, code: einig.code, asked: zaehlwerke.gefragt,
                                                  codes: zaehlwerke.kennzahlen, ranges: zaehlwerke.bereiche)
        // Nach dem Treffer läuft die Kamera weiter, aber nur noch, um die Zahl eines anderen
        // Zählwerks zu merken. Der Vorschlag selbst ändert sich nicht mehr.
        if treffer != nil {
            if case .remember(let i) = zuordnung { gemerkt[i] = wert; konsens.reset() }
            return
        }
        anzeigen(befund)
        switch zuordnung {
        case .propose:
            zuordnungsHinweis = nil
            withAnimation(.snappy) { treffer = einig.reading }
            // Die Vorführung hört auf: Sie rechnet im Debug-Bau Sekunden je Bild und hielt die App
            // nach dem Treffer beschäftigt, auf dem langsameren iPad so lange, dass der Test
            // den Hinweis „Von der Kamera gelesen“ nicht rechtzeitig fand.
            vorfuehrung?.cancel()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "Zählerstand gefunden")
        case .remember(let i):
            // Die Zahl gehört sicher zu einem anderen Zählwerk: merken und auf die gefragte warten.
            gemerkt[i] = wert
            zuordnungsHinweis = "\(zaehlwerke.namen[i]) gelesen. Warte, bis \(zaehlwerke.namen[zaehlwerke.gefragt]) kommt."
            konsens.reset()
        case .foreign(let code):
            zuordnungsHinweis = "Im Display steht gerade \(code). Warte, bis \(zaehlwerke.namen[zaehlwerke.gefragt]) kommt."
            konsens.reset()
        case .ambiguous(let i):
            // Einig, aber vielleicht über die Zahl eines anderen Zählwerks: nichts vorschlagen und
            // von vorn zählen. Zeigt das Display gleich die andere Zahl, findet die Einigung sie.
            zuordnungsHinweis = "Diese Zahl kann auch \(zaehlwerke.namen[i]) sein. Warte, bis die andere Zahl kommt, oder tipp sie selbst ein."
            konsens.reset()
        case .mismatch:
            zuordnungsHinweis = nil
            konsens.reset()
        }
    }

    private func anzeigen(_ befund: KameraBefund) {
        gelesen = befund.gelesen
        qualitaet = befund.qualitaet
        langeOhneTreffer = Date().timeIntervalSince(gestartet) > 12
    }

    /// Wie das Bild gedreht werden muss, damit es so steht, wie die Anzeige steht.
    private static func drehungDerAnzeige() -> CGFloat {
        let szene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch szene?.effectiveGeometry.interfaceOrientation ?? .portrait {
        case .portrait: return 90
        case .portraitUpsideDown: return 270
        case .landscapeLeft: return 180
        case .landscapeRight: return 0
        default: return 90
        }
    }

    // MARK: Vorführung ohne Kamera

    /// Nur mit `-pulse-kamera-test` (Debug): Der letzte Stand, gezeichnet, geht durch
    /// die Auswertung wie ein Kamerabild.
    private func starteVorfuehrung() {
        let formatKopie = self.format
        let bereichKopie = self.bereich
        let andereKopie = zaehlwerke.andereBereiche
        // Mit `-pulse-kamera-wechsel` zeigt das gezeichnete Display erst die Zahl des anderen
        // Zählwerks, dann die gefragte, wie die moderne Messeinrichtung, die zwischen 1.8.0 und
        // 2.8.0 wechselt. Beide gehen durch dieselbe Auswertung wie ein Kamerabild, mit dem
        // eigenen Bereich und denen der anderen.
        var folge: [(text: String, bilder: Int)] = []
        if Startschalter.gesetzt("-pulse-kamera-wechsel"),
           let anderes = zaehlwerke.bereiche.indices.first(where: { $0 != zaehlwerke.gefragt && zaehlwerke.bereiche[$0] != nil }) {
            folge.append((Self.demoText(zaehlwerke.bereiche[anderes], format: formatKopie), 6))
        }
        folge.append((Self.demoText(bereich, format: formatKopie), .max))
        let schritte = folge
        vorfuehrung?.cancel()
        vorfuehrung = Task { [weak self] in
            // Gerechnet wird abseits des Hauptthreads und **einmal** je Bild: Das Bild ist immer
            // dasselbe, also auch der Befund. Vorher lief das Netz für jedes Bild neu,
            // im Debug-Bau eine halbe Minute je Bild auf dem iPad. Mit vier gleichen statt drei
            // kam der Vorschlag erst nach knapp zwei Minuten, und der Hinweis nach dem Übernehmen
            // erschien nicht mehr rechtzeitig (CI-Lauf 620, iPad) — vermutlich, weil die noch
            // laufende Rechnung den Simulator auslastete. Die Einigung selbst durchläuft der
            // Befund weiterhin Bild für Bild.
            // `.utility` statt `.userInitiated` (0.174.0): Im Debug-Bau rechnet das Netz lange, und
            // mit hohem Vorrang ließ es im Simulator keine Luft für die Fragen des Oberflächentests
            // („Timed out while evaluating UI query“ auf dem iPad, PR #13). Es geht nur um diesen
            // Vorführweg; die echte Kamera wertet in `KameraSitzung` aus.
            for schritt in schritte {
                let bild = DemoFrame.render(schritt.text)
                let ganz = PixelRect(x: 0, y: 0, width: Double(bild.width), height: Double(bild.height))
                let befund = await Task.detached(priority: .utility) {
                    KameraSitzung.auswerten(bild, rahmen: ganz, format: formatKopie, bereich: bereichKopie,
                                            andereBereiche: andereKopie)
                }.value
                var n = 0
                while !Task.isCancelled, n < schritt.bilder {
                    self?.aufnehmen(befund)
                    n += 1
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
        }
    }

    /// Die Zahl für das gezeichnete Display: die untere Grenze des Bereichs, so wie der Zähler sie zeigt.
    private static func demoText(_ bereich: ClosedRange<Decimal>?, format: MeterFormat) -> String {
        guard let untere = bereich?.lowerBound else { return "1936" }
        let stellen = format.fractionDigits
        let scaled = NSDecimalNumber(decimal: untere * pow(10, stellen)).intValue
        var ziffern = String(scaled)
        if stellen > 0 {
            while ziffern.count <= stellen { ziffern = "0" + ziffern }
            ziffern.insert(".", at: ziffern.index(ziffern.endIndex, offsetBy: -stellen))
        }
        return ziffern
    }
}

// MARK: - Vorschau und Abdunklung

/// Die Vorschau der Kamera. Ein eigenes `UIView`, weil die Ebene der Vorschau
/// eine `CALayer` ist und kein SwiftUI-Bild.
struct KameraVorschau: UIViewRepresentable {
    let sitzung: KameraSitzung
    let drehung: CGFloat

    func makeUIView(context: Context) -> VorschauView {
        let view = VorschauView()
        view.previewLayer.session = sitzung.session
        // Füllen, nicht einpassen: `Viewfinder.bufferRect` rechnet genau dieses Verhalten zurück.
        view.previewLayer.videoGravity = .resizeAspectFill
        view.drehung = drehung
        return view
    }

    func updateUIView(_ view: VorschauView, context: Context) {
        view.drehung = drehung
    }

    final class VorschauView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var drehung: CGFloat = 90 { didSet { anwenden() } }

        override func layoutSubviews() {
            super.layoutSubviews()
            anwenden()
        }

        private func anwenden() {
            guard let verbindung = previewLayer.connection, verbindung.isVideoRotationAngleSupported(drehung) else { return }
            verbindung.videoRotationAngle = drehung
        }
    }
}

/// Dunkelt alles außer dem Rahmen ab: Der Blick geht dorthin, wo die Zahl hin soll.
struct Abdunkelung: View {
    let loch: CGRect

    var body: some View {
        Canvas { context, size in
            var pfad = Path(CGRect(origin: .zero, size: size))
            pfad.addRoundedRect(in: loch, cornerSize: CGSize(width: 12, height: 12))
            context.fill(pfad, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
    }
}
