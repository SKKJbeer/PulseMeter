import AVFoundation
import CoreGraphics
import Synchronization
import Vision
import PulseCore

/// Was aus einem Kamerabild geworden ist, auf dem Weg zur Oberfläche.
struct KameraBefund: Sendable {
    /// Der Vorschlag dieses einen Bildes oder der Grund, warum es keinen gibt.
    var ergebnis: MeterTextReader.Outcome
    /// Was die Ziffernerkennung im Rahmen gelesen hat, für die Anzeige „Ich sehe …".
    var gelesen: String
    var qualitaet: FrameQuality.Hint
}

/// Die Kamera und die Auswertung ihrer Bilder.
///
/// **Alles außerhalb des Hauptthreads.** Die Kamera liefert Bilder auf einer
/// eigenen Warteschlange, das Netz rechnet etwa eine zehntel Sekunde je Bild, und
/// eine Oberfläche, die darauf wartet, ruckelt. Was hier entsteht, wandert als
/// ``KameraBefund`` zur Oberfläche; angefasst wird sie von hier aus nie.
///
/// **Warum `@unchecked Sendable`.** `AVCaptureSession` ist nicht als `Sendable`
/// gekennzeichnet, wird aber nur auf `queue` angefasst. Die Werte, die von der
/// Oberfläche hereinkommen (Rahmen, Zählwerk, Bereich), liegen hinter einem
/// `Mutex`. Das ist die Zusage, die der Übersetzer nicht prüfen kann.
final class KameraSitzung: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Was die Auswertung von der Oberfläche braucht. Hinter einem Schloss, weil
    /// beide Seiten es zu verschiedenen Zeiten ändern.
    struct Vorgaben: Sendable {
        /// Wo der Rahmen in der Ansicht liegt (Punkte der Ansicht).
        var rahmen = PixelRect(x: 0, y: 0, width: 1, height: 1)
        var ansicht = CGSize(width: 1, height: 1)
        var format = MeterFormat(integerDigits: 6, fractionDigits: 0)
        var bereich: ClosedRange<Decimal>?
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "de.karjoth.pulsemeter.kamera", qos: .userInitiated)
    private let vorgaben = Mutex(Vorgaben())
    private let befund = Mutex<(@Sendable (KameraBefund) -> Void)?>(nil)
    private let ausgabe = AVCaptureVideoDataOutput()
    private var geraet: AVCaptureDevice?
    private var konfiguriert = false
    /// Nur auf `queue` gelesen und geschrieben.
    private var letzteAuswertung = Date.distantPast
    /// Mindestabstand zwischen zwei Auswertungen. Fünf bis sechs je Sekunde
    /// reichen: Dieselbe Zahl in drei Bildern ist in einer halben Sekunde da, und
    /// das Telefon wird dabei nicht warm.
    private let abstand: TimeInterval = 0.17

    var hatTaschenlampe: Bool { geraet?.hasTorch ?? false }

    static var kameraVorhanden: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func setzeVorgaben(_ aendern: @Sendable (inout Vorgaben) -> Void) {
        vorgaben.withLock { aendern(&$0) }
    }

    func setzeEmpfaenger(_ empfaenger: @escaping @Sendable (KameraBefund) -> Void) {
        befund.withLock { $0 = empfaenger }
    }

    // MARK: - Start und Ende

    /// - Parameter drehung: Winkel, um den das Bild gedreht werden muss, damit es
    ///   aufrecht steht (90 im Hochformat). Die Ansicht und die Auswertung sehen
    ///   so dasselbe Bild.
    func starten(drehung: CGFloat) {
        queue.async { [self] in
            if !konfiguriert { konfigurieren() }
            drehen(drehung)
            if konfiguriert, !session.isRunning { session.startRunning() }
        }
    }

    func anhalten() {
        queue.async { [self] in
            schalteTaschenlampe(false)
            if session.isRunning { session.stopRunning() }
        }
    }

    func drehen(_ winkel: CGFloat) {
        queue.async { [self] in
            guard let verbindung = ausgabe.connection(with: .video),
                  verbindung.isVideoRotationAngleSupported(winkel) else { return }
            verbindung.videoRotationAngle = winkel
        }
    }

    func taschenlampe(_ an: Bool) {
        queue.async { [self] in schalteTaschenlampe(an) }
    }

    private func schalteTaschenlampe(_ an: Bool) {
        guard let geraet, geraet.hasTorch else { return }
        do {
            try geraet.lockForConfiguration()
            geraet.torchMode = an ? .on : .off
            geraet.unlockForConfiguration()
        } catch {
            // Ohne Taschenlampe geht es weiter; sie ist eine Hilfe, keine Voraussetzung.
        }
    }

    private func konfigurieren() {
        guard let geraet = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let eingang = try? AVCaptureDeviceInput(device: geraet) else { return }
        self.geraet = geraet
        session.beginConfiguration()
        // Voll-HD: Die Ziffern sind im Rahmen oft nur ein paar Dutzend Bildpunkte
        // hoch, und das Netz braucht sie scharf. Mehr kostet nur Wärme.
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
        if session.canAddInput(eingang) { session.addInput(eingang) }
        // Die Helligkeitsebene allein: Farbe hilft der Auswertung nicht.
        ausgabe.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        ausgabe.alwaysDiscardsLateVideoFrames = true
        ausgabe.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(ausgabe) { session.addOutput(ausgabe) }
        session.commitConfiguration()

        // Nah dran scharfstellen: Der Zähler ist eine Armlänge entfernt, nicht
        // der Horizont. Ohne die Einschränkung sucht die Kamera zwischen den
        // Ziffern und der Wand dahinter hin und her.
        do {
            try geraet.lockForConfiguration()
            if geraet.isFocusModeSupported(.continuousAutoFocus) { geraet.focusMode = .continuousAutoFocus }
            if geraet.isAutoFocusRangeRestrictionSupported { geraet.autoFocusRangeRestriction = .near }
            geraet.unlockForConfiguration()
        } catch {}
        konfiguriert = true
    }

    // MARK: - Bilder

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let jetzt = Date()
        guard jetzt.timeIntervalSince(letzteAuswertung) >= abstand,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        letzteAuswertung = jetzt

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let roh = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return }
        let breite = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let hoehe = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let zeile = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let v = vorgaben.withLock { $0 }
        let rahmen = Viewfinder.bufferRect(guide: v.rahmen, viewWidth: Double(v.ansicht.width), viewHeight: Double(v.ansicht.height),
                                           bufferWidth: Double(breite), bufferHeight: Double(hoehe))
        guard let fenster = GrayImage.window(around: rahmen, width: breite, height: hoehe, bytesPerRow: zeile,
                                             base: roh.assumingMemoryBound(to: UInt8.self)) else { return }
        let ergebnis = Self.auswerten(fenster.image, rahmen: fenster.rect, format: v.format, bereich: v.bereich)
        befund.withLock { $0 }?(ergebnis)
    }

    // MARK: - Auswertung

    /// Ein Bild, zwei Leser: das Ziffernnetz für Siebensegment-Anzeigen und die
    /// Texterkennung des Systems für Rollen und große Ziffern.
    ///
    /// **Jeder für sich durch den Leser, dann verglichen.** Sagt nur einer etwas,
    /// gilt das. Sagen beide etwas Verschiedenes, gilt nichts: Dann ist sich die
    /// Kamera nicht einig, und eine falsche Zahl ist schlimmer als keine.
    static func auswerten(_ bild: GrayImage, rahmen: PixelRect, format: MeterFormat, bereich: ClosedRange<Decimal>?) -> KameraBefund {
        let pixel = bild.resampled(rect: rahmen, outWidth: DigitNet.inputWidth, outHeight: DigitNet.inputHeight)
        let zeile = DigitDecoder.decode(DigitNet.bundled.run(pixels: pixel))
        let qualitaet = FrameQuality(pixels: pixel, width: DigitNet.inputWidth, height: DigitNet.inputHeight).hint

        let ausNetz = MeterTextReader.propose(from: zeile.isEmpty ? [] : [zeile.recognized], format: format,
                                              plausible: bereich, framed: true)
        // Ohne `framed`: Apples Texterkennung liest im Rahmen auch das Typenschild, wenn er daneben liegt.
        let ausTexterkennung = MeterTextReader.propose(from: texterkennung(bild, rahmen: rahmen), format: format,
                                                       plausible: bereich)
        return KameraBefund(ergebnis: Self.einigen(ausNetz, ausTexterkennung), gelesen: zeile.text, qualitaet: qualitaet)
    }

    /// Siehe ``auswerten(_:rahmen:format:bereich:)``.
    static func einigen(_ a: MeterTextReader.Outcome, _ b: MeterTextReader.Outcome) -> MeterTextReader.Outcome {
        switch (a, b) {
        case (.proposal(let x), .proposal(let y)):
            return x.value == y.value ? .proposal(x.confidence >= y.confidence ? x : y) : .none(.ambiguous)
        case (.proposal, .none), (.none, .proposal):
            if case .proposal = a { return a } else { return b }
        case (.none(let x), .none):
            return .none(x)
        }
    }

    /// Apples Texterkennung auf dem Rahmen, vergrößert: Sie braucht mehr Bildpunkte
    /// als das Netz (`docs/kamera/README.md`, Messung vom 21. Oktober).
    private static func texterkennung(_ bild: GrayImage, rahmen: PixelRect) -> [RecognizedLine] {
        let b = DigitNet.inputWidth * 4, h = DigitNet.inputHeight * 4
        let werte = bild.resampled(rect: rahmen, outWidth: b, outHeight: h)
        var bytes = werte.map { UInt8(max(0, min(255, ($0 * 255).rounded()))) }
        let bildDatei: CGImage? = bytes.withUnsafeMutableBytes { puffer in
            CGContext(data: puffer.baseAddress, width: b, height: h, bitsPerComponent: 8, bytesPerRow: b,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)?.makeImage()
        }
        guard let bildDatei else { return [] }
        let anfrage = VNRecognizeTextRequest()
        anfrage.recognitionLevel = .accurate
        // Eine Sprachkorrektur „verbessert" Ziffern zu Wörtern.
        anfrage.usesLanguageCorrection = false
        guard (try? VNImageRequestHandler(cgImage: bildDatei, options: [:]).perform([anfrage])) != nil else { return [] }
        return (anfrage.results ?? []).compactMap { $0.topCandidates(1).first }
            .map { RecognizedLine($0.string, confidence: Double($0.confidence)) }
    }
}
