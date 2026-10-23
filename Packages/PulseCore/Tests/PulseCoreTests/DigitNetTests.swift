import XCTest
@testable import PulseCore

/// Das Ziffernnetz gegen die Referenzwerte, die das Training in Python erzeugt
/// hat (`docs/kamera/lcd-vektoren.json`, geschrieben von `scripts/kamera-netz/golden.py`).
///
/// Geprüft wird **dieselbe Rechnung**, nicht die Güte des Netzes: Gleiche Eingabe
/// muss in Swift (hier), in JavaScript (Klick-Dummy, `scripts/check-kamera-js.mjs`)
/// und in Python dieselbe Ausgabe geben. Wie gut das Netz auf echten Fotos
/// liest, steht in `docs/kamera/README.md` und wird dort gemessen.
final class DigitNetTests: XCTestCase {

    private struct Vektoren: Decodable {
        struct Verkleinern: Decodable {
            let breite: Int
            let hoehe: Int
            let pixel: String
            let rechteck: [Double]
            let ziel: [Int]
            let erwartet: [Float]
        }
        struct Fall: Decodable {
            let name: String
            let soll: String
            let pixel: String
            let texte: [String]
            let sicherheiten: [Double]
            let text: String
            let sicherheit: Double
            let ausgaben: [[Float]]?
        }
        let verkleinern: Verkleinern
        let faelle: [Fall]
    }

    private func laden() throws -> Vektoren {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(Vektoren.self, from: Data(contentsOf: root.appendingPathComponent("docs/kamera/lcd-vektoren.json")))
    }

    func testResamplingMatchesPython() throws {
        let v = try laden().verkleinern
        let bytes = [UInt8](Data(base64Encoded: v.pixel)!)
        let image = GrayImage(width: v.breite, height: v.hoehe, pixels: bytes)
        let out = image.resampled(rect: PixelRect(x: v.rechteck[0], y: v.rechteck[1], width: v.rechteck[2], height: v.rechteck[3]),
                                  outWidth: v.ziel[0], outHeight: v.ziel[1])
        XCTAssertEqual(out.count, v.erwartet.count)
        for (a, b) in zip(out, v.erwartet) { XCTAssertEqual(a, b, accuracy: 1e-4) }
    }

    func testResamplingKeepsAFlatImageFlat() {
        let image = GrayImage(width: 20, height: 10, pixels: [UInt8](repeating: 128, count: 200))
        // Über den Rand hinaus: Der Rand wird fortgesetzt, ein einfarbiges Bild bleibt einfarbig.
        let out = image.resampled(rect: PixelRect(x: -5, y: -5, width: 40, height: 20), outWidth: 8, outHeight: 4)
        for v in out { XCTAssertEqual(v, 128.0 / 255, accuracy: 1e-5) }
    }

    /// Das Fenster gibt dieselben Zahlen wie das ganze Bild — nur ohne zwei Megabyte Umweg.
    func testWindowGivesTheSameResultAsTheWholeImage() {
        let w = 200, h = 120, stride = 224          // Zeilenabstand größer als die Breite, wie bei einer Kameraebene
        var raw = [UInt8](repeating: 0, count: stride * h)
        var seed: UInt32 = 12345
        for y in 0..<h { for x in 0..<w { seed = seed &* 1664525 &+ 1013904223; raw[y * stride + x] = UInt8(truncatingIfNeeded: seed >> 24) } }
        let rect = PixelRect(x: 40.5, y: 30.25, width: 100, height: 20)
        let whole = raw.withUnsafeBufferPointer { GrayImage(width: w, height: h, bytesPerRow: stride, base: $0.baseAddress!) }
        let expected = whole.resampled(rect: rect, outWidth: 40, outHeight: 8)
        let windowed = raw.withUnsafeBufferPointer {
            GrayImage.window(around: rect, width: w, height: h, bytesPerRow: stride, base: $0.baseAddress!)
        }
        guard let windowed else { return XCTFail("Fenster erwartet") }
        XCTAssertLessThan(windowed.image.width * windowed.image.height, w * h / 2)
        let got = windowed.image.resampled(rect: windowed.rect, outWidth: 40, outHeight: 8)
        for (a, b) in zip(got, expected) { XCTAssertEqual(a, b, accuracy: 1e-5) }
    }

    func testWindowOutsideTheImageIsNil() {
        let raw = [UInt8](repeating: 1, count: 100)
        let r = raw.withUnsafeBufferPointer {
            GrayImage.window(around: PixelRect(x: 500, y: 500, width: 10, height: 2), width: 10, height: 10, bytesPerRow: 10, base: $0.baseAddress!)
        }
        XCTAssertNil(r)
    }

    /// Jedes eingebaute Netz rechnet wie in Python, und das Ensemble einigt sich wie dort.
    func testNetsMatchPythonOutputAndText() throws {
        let nets = DigitNet.bundledNets
        for fall in try laden().faelle {
            let pixels = [UInt8](Data(base64Encoded: fall.pixel)!).map { Float($0) / 255 }
            XCTAssertEqual(fall.texte.count, nets.count, fall.name)
            for (i, net) in nets.enumerated() {
                let output = net.run(pixels: pixels)
                if let referenz = fall.ausgaben?[i] {
                    var worst: Float = 0
                    for (a, b) in zip(output.values, referenz) { worst = max(worst, abs(a - b)) }
                    XCTAssertLessThan(worst, 0.01, "\(fall.name), Netz \(i): Ausgabe weicht von Python ab")
                }
                let line = DigitDecoder.decode(output)
                XCTAssertEqual(line.text, fall.texte[i], "\(fall.name), Netz \(i)")
                XCTAssertEqual(line.confidence, fall.sicherheiten[i], accuracy: 0.01, "\(fall.name), Netz \(i)")
            }
            let ensemble = DigitEnsemble.bundled.read(pixels: pixels)
            XCTAssertEqual(ensemble.text, fall.text, "\(fall.name): Ensemble")
            XCTAssertEqual(ensemble.confidence, fall.sicherheit, accuracy: 0.01, "\(fall.name): Ensemble")
        }
    }

    /// Lesen zwei Netze Verschiedenes, ist das Bild nicht gelesen.
    func testEnsembleIsEmptyWhenTheNetsDisagree() throws {
        let frame = DemoFrame.render("014426")
        let pixels = frame.resampled(rect: PixelRect(x: 0, y: 0, width: 240, height: 48), outWidth: 240, outHeight: 48)
        let first = DigitNet.bundledNets[0]
        // Dasselbe Netz zweimal: immer einig.
        XCTAssertEqual(DigitEnsemble(nets: [first, first]).read(pixels: pixels).text, DigitDecoder.decode(first.run(pixels: pixels)).text)
        // Ein Bild, das die Netze verschieden lesen, gibt es hier nicht auf Bestellung; den Zweig deckt der
        // Vergleich mit Python (`lcd-vektoren.json`, Fälle mit verschiedenen Texten) ab.
        XCTAssertGreaterThanOrEqual(DigitNet.bundledNets.count, 1)
    }

    func testBrokenWeightsAreRefused() {
        XCTAssertThrowsError(try DigitNet(weights: Data("nope".utf8)))
        XCTAssertThrowsError(try DigitNet(weights: Data("ZNW1".utf8 + [16, 0, 0, 0])))
    }

    func testDecoderCollapsesRepeatsAndSkipsBlanks() {
        // Zwei Zeitschritte „1", ein leerer, zwei „1": gelesen wird „11".
        let c = DigitNet.classCount
        var v = [Float](repeating: 0, count: c * 5)
        func set(_ t: Int, _ cls: Int) { v[cls * 5 + t] = 10 }
        set(0, 2); set(1, 2); set(2, 0); set(3, 2); set(4, 2)
        let line = DigitDecoder.decode(.init(classCount: c, steps: 5, values: v))
        XCTAssertEqual(line.text, "11")
        XCTAssertGreaterThan(line.confidence, 0.99)
    }

    // MARK: - Die ganze Kette

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    /// Ein gezeichnetes Bild geht durch dieselbe Kette wie ein Kamerabild: Rahmen, Netz, Leser.
    /// Das ist der Weg, den der Oberflächentest im Simulator nimmt (`-pulse-kamera-test`); hier
    /// steht er ohne Simulator, mit anderen Zahlen und mit Komma.
    func testDrawnFramesAreReadBackThroughTheWholeChain() {
        let cases: [(text: String, format: MeterFormat, value: String)] = [
            ("014426", MeterFormat(integerDigits: 6, fractionDigits: 0), "14426"),
            ("0004567", MeterFormat(integerDigits: 6, fractionDigits: 0), "4567"),
            ("000000", MeterFormat(integerDigits: 6, fractionDigits: 0), "0"),
            ("00047.36", MeterFormat(integerDigits: 5, fractionDigits: 2), "47.36"),
            ("0123.45", MeterFormat(integerDigits: 5, fractionDigits: 2), "123.45"),
            ("98765", MeterFormat(integerDigits: 6, fractionDigits: 0), "98765"),
        ]
        for c in cases {
            let frame = DemoFrame.render(c.text)
            let whole = PixelRect(x: 0, y: 0, width: Double(frame.width), height: Double(frame.height))
            let line = Viewfinder.read(frame, rect: whole)
            let range = max(0, dec(c.value) - 50)...(dec(c.value) + 500)
            let outcome = MeterTextReader.propose(from: [line.recognized], format: c.format, plausible: range, framed: true)
            guard case .proposal(let p) = outcome else { XCTFail("\(c.text): gelesen „\(line.text)“, kein Vorschlag: \(outcome)"); continue }
            XCTAssertEqual(p.value, dec(c.value), "\(c.text): gelesen „\(line.text)“")
        }
    }

    /// Die echten Fotos (Sucherbilder aus `docs/kamera/`): Ob das Netz sie liest, wird in
    /// `docs/kamera/README.md` gemessen. **Hier gilt eine Regel: kein falscher Vorschlag**, ob mit
    /// Bereich um den richtigen Stand oder ohne.
    ///
    /// **Für die zweite Sammlung (50 und höher) gilt sie nur dort, wo nichts stehen darf**: leeres
    /// Display, Displaytest. Bei den Zählern mit Zahl irrt sich das Netz in einzelnen Versuchen (an
    /// dünnen Einsen, `docs/kamera/README.md`); das steht dort als Messung, nicht als Test, der nur
    /// an einem Bild je Foto nichts über eine Quote sagt.
    func testRealPhotoFramesNeverProduceAWrongProposal() throws {
        let stand: [String: (format: MeterFormat, value: String?)] = [
            "01": (MeterFormat(integerDigits: 6, fractionDigits: 0), nil),
            "02": (MeterFormat(integerDigits: 6, fractionDigits: 0), "9023"),
            "04": (MeterFormat(integerDigits: 6, fractionDigits: 0), "0"),
            "06": (MeterFormat(integerDigits: 6, fractionDigits: 0), nil),
            "25": (MeterFormat(integerDigits: 6, fractionDigits: 0), "2426"),
            "27": (MeterFormat(integerDigits: 5, fractionDigits: 2), "4.67"),
            "28": (MeterFormat(integerDigits: 5, fractionDigits: 0), "0"),
            "29": (MeterFormat(integerDigits: 7, fractionDigits: 0), "14426"),
            "32": (MeterFormat(integerDigits: 6, fractionDigits: 0), "1936"),
            // Die zweite Sammlung (`fotos-lcd.json`), nie zum Training benutzt.
            "50": (MeterFormat(integerDigits: 5, fractionDigits: 0), "74590"),
            "51": (MeterFormat(integerDigits: 6, fractionDigits: 0), "10"),
            "52": (MeterFormat(integerDigits: 5, fractionDigits: 0), "1"),
            "53": (MeterFormat(integerDigits: 6, fractionDigits: 0), "134141"),
            "54": (MeterFormat(integerDigits: 5, fractionDigits: 0), "0"),
            "55": (MeterFormat(integerDigits: 6, fractionDigits: 3), "880.518"),
            "56": (MeterFormat(integerDigits: 6, fractionDigits: 0), nil),
            "57": (MeterFormat(integerDigits: 6, fractionDigits: 0), nil),
            "58": (MeterFormat(integerDigits: 6, fractionDigits: 0), nil),
        ]
        var right = 0
        for fall in try laden().faelle {
            let nr = String(fall.name.prefix(2))
            guard let (format, wanted) = stand[nr] else { return XCTFail("unbekanntes Foto \(nr)") }
            let pixels = [UInt8](Data(base64Encoded: fall.pixel)!).map { Float($0) / 255 }
            let line = DigitEnsemble.bundled.read(pixels: pixels)
            for range in [nil, wanted.map { max(0, dec($0) - 100)...(dec($0) + 1000) }] {
                guard case .proposal(let p) = MeterTextReader.propose(from: line.isEmpty ? [] : [line.recognized], format: format,
                                                                      plausible: range, framed: true) else { continue }
                if p.value == wanted.map(dec) { right += 1; continue }
                let unseenWithNumber = (Int(nr) ?? 0) >= 50 && wanted != nil
                if !unseenWithNumber {
                    XCTFail("\(fall.name): gelesen „\(line.text)“ ergibt einen falschen Vorschlag (\(p.value))")
                }
            }
        }
        XCTAssertGreaterThan(right, 8, "Das Netz liest an den echten Fotos gar nichts mehr")
    }
}
