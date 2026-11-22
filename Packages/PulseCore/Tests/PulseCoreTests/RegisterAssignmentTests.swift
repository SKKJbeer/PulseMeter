import Foundation
import Testing
@testable import PulseCore

/// `docs/kamera/stufe-2.md`, „Zuordnen statt raten“.
struct ObisCodeTests {

    @Test func readsTheUsualForms() {
        #expect(ObisCode.read("1.8.0") == "1.8.0")
        #expect(ObisCode.read("180") == "1.8.0")       // Display ohne Punkte
        #expect(ObisCode.read("18.0") == "1.8.0")      // ein Punkt verloren
        #expect(ObisCode.read("1.80") == "1.8.0")
        #expect(ObisCode.read("2.8.1") == "2.8.1")
        #expect(ObisCode.read("282") == "2.8.2")
    }

    @Test func ignoresWhatIsNoKnownCode() {
        #expect(ObisCode.read("004") == nil)           // Anzeigeindex
        #expect(ObisCode.read("1.8.3") == nil)
        #expect(ObisCode.read("16.7.0") == nil)
        #expect(ObisCode.read("1.7.0") == nil)
        #expect(ObisCode.read("1808") == nil)
        #expect(ObisCode.read("18") == nil)
        #expect(ObisCode.read("") == nil)
        #expect(ObisCode.read("1..80") == nil)
        #expect(ObisCode.read("18.0.") == "1.8.0")     // Punkt am Rand: der des Displays dahinter
    }

    @Test func fillsInTheMissingCodeOfTheFirstRegister() {
        let bezug = Register(label: "Bezug", unit: .kilowattHour)
        let einspeisung = Register(label: "Einspeisung", unit: .kilowattHour, direction: .feedIn, obisCode: "2.8.0")
        let nt = Register(label: "Niedertarif", unit: .kilowattHour, obisCode: "1.8.2")
        #expect(ObisCode.effectiveCodes(of: [bezug, einspeisung], kind: .electricity) == ["1.8.0", "2.8.0"])
        // Am Zweitarifzähler ist das erste Zählwerk der Hochtarif, nicht die Summe.
        #expect(ObisCode.effectiveCodes(of: [bezug, nt], kind: .electricity) == ["1.8.1", "1.8.2"])
        #expect(ObisCode.effectiveCodes(of: [bezug, nt, einspeisung], kind: .electricity) == ["1.8.1", "1.8.2", "2.8.0"])
        #expect(ObisCode.effectiveCodes(of: [bezug], kind: .electricity) == ["1.8.0"])
    }

    @Test func otherMetersHaveNoCodes() {
        let gas = Register(unit: .cubicMetre)
        #expect(ObisCode.effectiveCodes(of: [gas], kind: .gas) == [nil])
    }
}

struct RegisterAssignmentTests {

    let pv = ["1.8.0", "2.8.0"]
    let htnt = ["1.8.1", "1.8.2"]

    @Test func theAskedCodeProposesEvenWithoutAnyRange() {
        // Erste Ablesung: kein Bereich, aber die Kennzahl sagt, welche Zahl dasteht.
        #expect(RegisterAssignment.decide(value: 5_210, code: "1.8.0", asked: 0, codes: pv, ranges: [nil, nil]) == .propose)
    }

    @Test func theOtherCodeIsRememberedForTheOtherRegister() {
        #expect(RegisterAssignment.decide(value: 987.4, code: "2.8.0", asked: 0, codes: pv, ranges: [nil, nil]) == .remember(1))
        #expect(RegisterAssignment.decide(value: 987.4, code: "2.8.0", asked: 0, codes: pv, ranges: [nil, 950...1_100]) == .remember(1))
    }

    @Test func theOtherCodeOutsideItsRangeIsNeitherProposedNorRemembered() {
        #expect(RegisterAssignment.decide(value: 5_210, code: "2.8.0", asked: 0, codes: pv, ranges: [nil, 950...1_100]) == .mismatch)
    }

    @Test func theSumOnADualTariffMeterBelongsToNoRegister() {
        #expect(RegisterAssignment.decide(value: 8_000, code: "1.8.0", asked: 0, codes: htnt, ranges: [nil, nil]) == .foreign("1.8.0"))
        #expect(RegisterAssignment.decide(value: 3_000, code: "1.8.1", asked: 1, codes: htnt, ranges: [nil, nil]) == .remember(0))
    }

    @Test func aSingleRegisterRejectsOnlyTheOtherDirection() {
        #expect(RegisterAssignment.decide(value: 900, code: "2.8.0", asked: 0, codes: ["1.8.0"], ranges: [nil]) == .foreign("2.8.0"))
        #expect(RegisterAssignment.decide(value: 4_000, code: "1.8.1", asked: 0, codes: ["1.8.0"], ranges: [nil]) == .propose)
    }

    @Test func withoutCodeTheRangeDecidesAsBefore() {
        #expect(RegisterAssignment.decide(value: 12_345, code: nil, asked: 0, codes: pv, ranges: [nil, 980...1_100]) == .propose)
        #expect(RegisterAssignment.decide(value: 1_000, code: nil, asked: 0, codes: pv, ranges: [nil, 980...1_100]) == .ambiguous(1))
        #expect(RegisterAssignment.decide(value: 1_000, code: nil, asked: 1, codes: pv, ranges: [980...1_100, nil]) == .ambiguous(0))
        #expect(RegisterAssignment.decide(value: 1_000, code: nil, asked: 0, codes: pv, ranges: [nil, nil]) == .ambiguous(1))
    }

    @Test func withoutCodeTheRangesRememberTheOtherNumber() {
        // Zweite Ablesung am PV-Zähler: Bezug um 41.230, Einspeisung um 7.170. Das Display zeigt gerade
        // die Einspeisung. Sie passt nicht zum Bezug, aber zur Einspeisung: merken.
        let bereiche: [ClosedRange<Decimal>?] = [41_200...41_400, 7_150...7_250]
        #expect(RegisterAssignment.decide(value: 7_172, code: nil, asked: 0, codes: pv, ranges: bereiche) == .remember(1))
        #expect(RegisterAssignment.decide(value: 41_233, code: nil, asked: 0, codes: pv, ranges: bereiche) == .propose)
        #expect(RegisterAssignment.decide(value: 41_233, code: nil, asked: 1, codes: pv, ranges: bereiche) == .remember(0))
    }

    @Test func aNumberThatFitsNoRangeIsNeitherProposedNorRemembered() {
        let bereiche: [ClosedRange<Decimal>?] = [41_200...41_400, 7_150...7_250]
        #expect(RegisterAssignment.decide(value: 123_456, code: nil, asked: 0, codes: pv, ranges: bereiche) == .mismatch)
        // Das andere Zählwerk ohne Bereich: Wer nichts weiß, merkt nichts.
        #expect(RegisterAssignment.decide(value: 7_172, code: nil, asked: 0, codes: pv, ranges: [41_200...41_400, nil]) == .mismatch)
        // Passt zu zwei anderen: nicht eindeutig, nichts merken.
        #expect(RegisterAssignment.decide(value: 7_172, code: nil, asked: 0, codes: ["1.8.1", "1.8.2", "2.8.0"],
                                          ranges: [41_200...41_400, 7_000...7_300, 7_100...7_200]) == .mismatch)
    }

    @Test func aCodeDoesNotOverrideTheOwnRange() {
        #expect(RegisterAssignment.decide(value: 7_172, code: "1.8.0", asked: 0, codes: pv, ranges: [41_200...41_400, nil]) == .mismatch)
        #expect(RegisterAssignment.decide(value: 7_172, code: "1.8.1", asked: 0, codes: ["1.8.0"], ranges: [41_200...41_400]) == .mismatch)
    }

    @Test func metersWithoutCodesIgnoreARead() {
        #expect(RegisterAssignment.decide(value: 1_000, code: "1.8.0", asked: 0, codes: [nil], ranges: [nil]) == .propose)
    }
}

struct LabeledConsensusTests {

    func p(_ v: Decimal) -> MeterTextReader.Outcome {
        .proposal(MeterTextReader.Proposal(value: v, text: "\(v)", confidence: 0.9, fractionMissing: false))
    }

    @Test func theCodeNeedsThreeFramesWithoutContradiction() {
        var c = LabeledConsensus()
        #expect(c.add(p(5), code: "1.8.0") == nil)
        #expect(c.add(p(5), code: nil) == nil)
        #expect(c.add(p(5), code: "1.8.0") == nil)
        #expect(c.add(p(5), code: "1.8.0")?.code == "1.8.0")
    }

    @Test func twoFramesAreNotEnough() {
        var c = LabeledConsensus()
        _ = c.add(p(5), code: "1.8.0"); _ = c.add(p(5), code: nil); _ = c.add(p(5), code: nil)
        let a = c.add(p(5), code: "1.8.0")
        #expect(a != nil)
        #expect(a?.code == nil)
    }

    @Test func aContradictionDropsTheCode() {
        var c = LabeledConsensus()
        _ = c.add(p(5), code: "1.8.0"); _ = c.add(p(5), code: "2.8.0"); _ = c.add(p(5), code: "1.8.0")
        let a = c.add(p(5), code: "1.8.0")
        #expect(a != nil)
        #expect(a?.code == nil)
    }

    @Test func anotherCodeInAFrameWithoutNumberDropsTheCode() {
        var c = LabeledConsensus()
        _ = c.add(.none(.noCandidate), code: "2.8.0")
        _ = c.add(p(5), code: "1.8.0"); _ = c.add(p(5), code: "1.8.0"); _ = c.add(p(5), code: "1.8.0")
        let a = c.add(p(5), code: "1.8.0")
        #expect(a != nil)
        #expect(a?.code == nil)
    }
}

/// Dieselben Fälle wie im Klick-Dummy (`docs/kamera/vektoren.json`, Abschnitte `kennzahl`, `zuweisung`,
/// `kennzahl_einigung`; `scripts/check-kamera-js.mjs` lässt sie gegen die JavaScript-Fassung laufen).
struct RegisterAssignmentSharedVectorTests {

    func vektoren() throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/kamera/vektoren.json"))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func zahl(_ s: Any?) -> Decimal? {
        (s as? String).flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }

    @Test func codesMatchPrototype() throws {
        let cases = try #require(try vektoren()["kennzahl"] as? [[String: Any]])
        #expect(cases.count >= 10)
        for c in cases {
            let text = c["text"] as? String ?? ""
            #expect(ObisCode.read(text) == c["erwartet"] as? String, "\(text)")
        }
    }

    @Test func assignmentsMatchPrototype() throws {
        let cases = try #require(try vektoren()["zuweisung"] as? [[String: Any]])
        #expect(cases.count >= 10)
        for c in cases {
            let name = c["name"] as? String ?? "?"
            let value = try #require(zahl(c["wert"]))
            let codes = (c["kennzahlen"] as? [Any] ?? []).map { $0 as? String }
            let ranges: [ClosedRange<Decimal>?] = (c["bereiche"] as? [Any] ?? []).map { e in
                guard let p = e as? [String], let a = zahl(p[0]), let b = zahl(p[1]) else { return nil }
                return a...b
            }
            let ist = RegisterAssignment.decide(value: value, code: c["kennzahl"] as? String,
                                                asked: c["gefragt"] as? Int ?? 0, codes: codes, ranges: ranges)
            let text: String
            switch ist {
            case .propose: text = "propose"
            case .remember(let i): text = "remember:\(i)"
            case .foreign(let k): text = "foreign:\(k)"
            case .ambiguous(let i): text = "ambiguous:\(i)"
            case .mismatch: text = "mismatch"
            }
            #expect(text == c["erwartet"] as? String, "\(name)")
        }
    }

    @Test func labeledConsensusMatchesPrototype() throws {
        let cases = try #require(try vektoren()["kennzahl_einigung"] as? [[String: Any]])
        for c in cases {
            var k = LabeledConsensus()
            var last: LabeledConsensus.Agreement?
            for schritt in c["folge"] as? [[Any]] ?? [] {
                let outcome: MeterTextReader.Outcome = zahl(schritt[0]).map {
                    .proposal(MeterTextReader.Proposal(value: $0, text: "\($0)", confidence: 0.9, fractionMissing: false))
                } ?? .none(.noCandidate)
                last = k.add(outcome, code: schritt[1] as? String)
            }
            let ist = last.map { "\($0.reading.proposal.value)|\($0.code ?? "")" }
            #expect(ist == c["erwartet"] as? String, "\(c["name"] ?? "?")")
        }
    }
}
