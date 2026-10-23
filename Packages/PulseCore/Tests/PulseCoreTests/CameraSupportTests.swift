import XCTest
@testable import PulseCore

/// Sucher, Bildqualität und die Einigung über mehrere Kamerabilder.
final class CameraSupportTests: XCTestCase {

    // MARK: Sucher

    func testGuideHasTheNetsAspectAndSitsInsideTheView() {
        let g = Viewfinder.guide(inViewWidth: 390, height: 844)
        XCTAssertEqual(g.width / g.height, Viewfinder.aspect, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(g.x, 0)
        XCTAssertLessThanOrEqual(g.x + g.width, 390)
        XCTAssertGreaterThan(g.y, 0)
        XCTAssertLessThan(g.y + g.height, 844)
    }

    func testBufferRectUndoesAspectFill() {
        // Ansicht 400×800 (1:2), Bild 1080×1920 (9:16). Skala = max(0,370; 0,417) = 0,4167, das Bild ist
        // 450 breit und ragt links und rechts je 25 Punkte über.
        let guide = PixelRect(x: 20, y: 300, width: 360, height: 72)
        let r = Viewfinder.bufferRect(guide: guide, viewWidth: 400, viewHeight: 800, bufferWidth: 1080, bufferHeight: 1920)
        let scale = 800.0 / 1920.0
        XCTAssertEqual(r.width, 360 / scale, accuracy: 1e-6)
        XCTAssertEqual(r.height, 72 / scale, accuracy: 1e-6)
        XCTAssertEqual(r.x, (20 + 25) / scale, accuracy: 1e-6)
        XCTAssertEqual(r.y, 300 / scale, accuracy: 1e-6)
        // Das Verhältnis bleibt erhalten, sonst würde das Netz gestreckte Ziffern sehen.
        XCTAssertEqual(r.width / r.height, 5, accuracy: 1e-9)
    }

    func testBufferRectWhenTheImageIsWiderThanTheView() {
        // Ansicht höher als das Bild verhältnismäßig: oben und unten passt es, seitlich ragt es über.
        let r = Viewfinder.bufferRect(guide: PixelRect(x: 0, y: 0, width: 100, height: 20),
                                      viewWidth: 100, viewHeight: 200, bufferWidth: 400, bufferHeight: 400)
        XCTAssertEqual(r.x, 100, accuracy: 1e-9)      // (0 - (100 - 400*0,5)/2) / 0,5 = 100
        XCTAssertEqual(r.y, 0, accuracy: 1e-9)
        XCTAssertEqual(r.width, 200, accuracy: 1e-9)
    }

    // MARK: Bildqualität

    private func image(width: Int = 240, height: Int = 48, _ f: (Int, Int) -> Float) -> [Float] {
        var out: [Float] = []
        for y in 0..<height { for x in 0..<width { out.append(f(x, y)) } }
        return out
    }

    func testDarkFlatAndBlurryFramesAreNamed() {
        let dark = FrameQuality(pixels: image { x, _ in x % 12 < 6 ? 0.02 : 0.08 }, width: 240, height: 48)
        XCTAssertEqual(dark.hint, .tooDark)
        let flat = FrameQuality(pixels: image { x, _ in 0.55 + (x % 12 < 6 ? 0.01 : -0.01) }, width: 240, height: 48)
        XCTAssertEqual(flat.hint, .flat)
        // Weicher Verlauf statt Kanten: Kontrast ist da, Schärfe nicht.
        let blurry = FrameQuality(pixels: image { x, _ in 0.3 + 0.4 * Float(x) / 240 }, width: 240, height: 48)
        XCTAssertEqual(blurry.hint, .blurry)
        // Streifen mit steilen Kanten, hell genug und deutlich: gut.
        let sharp = FrameQuality(pixels: image { x, _ in x % 24 < 12 ? 0.25 : 0.75 }, width: 240, height: 48)
        XCTAssertEqual(sharp.hint, .ok)
    }

    // MARK: Einigung

    private func proposal(_ v: Decimal) -> MeterTextReader.Outcome {
        .proposal(.init(value: v, text: "\(v)", confidence: 0.9, fractionMissing: false))
    }

    func testAgreementNeedsThreeIdenticalFrames() {
        var c = ReadingConsensus(required: 3, window: 6)
        XCTAssertNil(c.add(proposal(14426)))
        XCTAssertNil(c.add(proposal(14426)))
        let a = c.add(proposal(14426))
        XCTAssertEqual(a?.proposal.value, 14426)
        XCTAssertEqual(a?.frames, 3)
    }

    func testCompetingNumbersMeanNoAgreement() {
        var c = ReadingConsensus(required: 3, window: 6)
        _ = c.add(proposal(14426)); _ = c.add(proposal(19426)); _ = c.add(proposal(14426))
        _ = c.add(proposal(19426))
        XCTAssertNil(c.add(proposal(14426)), "Zwei Zahlen mit je zwei Stimmen: Die Kamera ist sich nicht einig")
    }

    func testOneStrayReadingDoesNotBlockAgreement() {
        var c = ReadingConsensus(required: 3, window: 6)
        _ = c.add(proposal(14426)); _ = c.add(proposal(19426)); _ = c.add(proposal(14426))
        XCTAssertEqual(c.add(proposal(14426))?.proposal.value, 14426)
    }

    func testGapsPushOldEvidenceOutOfTheWindow() {
        var c = ReadingConsensus(required: 3, window: 4)
        _ = c.add(proposal(100)); _ = c.add(proposal(100))
        for _ in 0..<3 { _ = c.add(.none(.noCandidate)) }
        XCTAssertNil(c.add(proposal(100)), "Zwei Treffer von früher und einer jetzt sind keine Einigkeit")
    }

    func testResetForgets() {
        var c = ReadingConsensus(required: 2, window: 3)
        _ = c.add(proposal(5)); c.reset()
        XCTAssertNil(c.add(proposal(5)))
    }

    /// Dieselben Folgen wie im Klick-Dummy (`docs/kamera/vektoren.json`, Abschnitt „einigung“).
    func testSharedAgreementSequencesMatchPrototype() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/kamera/vektoren.json"))
        let file = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let sequences = file["einigung"] as! [[String: Any]]
        XCTAssertGreaterThan(sequences.count, 5)
        for s in sequences {
            var c = ReadingConsensus(required: s["required"] as! Int, window: s["window"] as! Int)
            var result: ReadingConsensus.Agreement?
            for step in s["folge"] as! [Any] {
                if let text = step as? String { result = c.add(proposal(Decimal(string: text)!)) } else { result = c.add(.none(.noCandidate)) }
            }
            let want = (s["erwartet"] as? String).map { Decimal(string: $0)! }
            XCTAssertEqual(result?.proposal.value, want, s["name"] as! String)
        }
    }
}
