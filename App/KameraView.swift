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
    let farbe: Color
    /// Der gelesene Stand und ob nur die Stellen vor dem Komma gelesen wurden.
    let uebernehmen: (Decimal, Bool) -> Void

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
        .onDisappear { modell.beenden() }
        .task { await modell.vorbereiten(format: format, bereich: bereich) }
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
    var drehung: CGFloat = 90

    private var konsens = ReadingConsensus()
    private var format = MeterFormat(integerDigits: 6, fractionDigits: 0)
    private var bereich: ClosedRange<Decimal>?
    private var gestartet = Date()
    private var vorfuehrung: Task<Void, Never>?

    func vorbereiten(format: MeterFormat, bereich: ClosedRange<Decimal>?) async {
        self.format = format
        self.bereich = bereich
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
        sitzung.setzeVorgaben {
            $0.format = formatKopie
            $0.bereich = bereichKopie
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
    }

    /// Ein Bild ist ausgewertet.
    func aufnehmen(_ befund: KameraBefund) {
        guard treffer == nil else { return }
        gelesen = befund.gelesen
        qualitaet = befund.qualitaet
        langeOhneTreffer = Date().timeIntervalSince(gestartet) > 12
        if let einig = konsens.add(befund.ergebnis) {
            withAnimation(.snappy) { treffer = einig }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "Zählerstand gefunden")
        }
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
        let text: String
        if let untere = bereich?.lowerBound {
            let stellen = format.fractionDigits
            let scaled = NSDecimalNumber(decimal: untere * pow(10, stellen)).intValue
            var ziffern = String(scaled)
            if stellen > 0 {
                while ziffern.count <= stellen { ziffern = "0" + ziffern }
                ziffern.insert(".", at: ziffern.index(ziffern.endIndex, offsetBy: -stellen))
            }
            text = ziffern
        } else {
            text = "1936"
        }
        let bild = DemoFrame.render(text)
        let ganz = PixelRect(x: 0, y: 0, width: Double(bild.width), height: Double(bild.height))
        let formatKopie = self.format
        let bereichKopie = self.bereich
        vorfuehrung = Task { [weak self] in
            while !Task.isCancelled {
                // Gerechnet wird abseits des Hauptthreads: Im Debug-Bau braucht das Netz
                // Sekunden, und der Oberflächentest soll die Oberfläche währenddessen bedienen können.
                let befund = await Task.detached(priority: .userInitiated) {
                    KameraSitzung.auswerten(bild, rahmen: ganz, format: formatKopie, bereich: bereichKopie)
                }.value
                self?.aufnehmen(befund)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
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
