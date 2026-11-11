import Foundation
import Testing
@testable import PulseCore

/// `docs/kamera/stufe-2.md`: Bezug und Einspeisung auf einem Display.
struct RegisterChoiceTests {

    @Test func aMeterWithOneRegisterAlwaysKeepsTheReading() {
        #expect(RegisterChoice.check(12_345, others: []) == .own)
    }

    @Test func aValueFarFromTheOtherRegisterBelongsToTheAskedOne() {
        // Bezug 12 345 kWh, Einspeisung bei etwa 980 kWh.
        #expect(RegisterChoice.check(12_345, others: [980...1_100]) == .own)
    }

    @Test func aValueInsideTheOtherRegistersRangeIsNotProposed() {
        // Solaranlage: Bezug und Einspeisung liegen nah beieinander.
        #expect(RegisterChoice.check(5_210, others: [5_100...5_400]) == .couldBeOther(0))
    }

    @Test func anOtherRegisterWithoutReadingExcludesNothing() {
        // Die Einspeisung wurde nie abgelesen: Ob die Zahl ihre ist, weiß niemand.
        #expect(RegisterChoice.check(12_345, others: [nil]) == .couldBeOther(0))
    }

    @Test func theFirstMatchingRegisterIsNamed() {
        #expect(RegisterChoice.check(500, others: [10_000...11_000, 450...600]) == .couldBeOther(1))
    }

    @Test func theRangeEdgesCountAsInside() {
        #expect(RegisterChoice.check(1_100, others: [980...1_100]) == .couldBeOther(0))
        #expect(RegisterChoice.check(1_100.1, others: [980...1_100]) == .own)
    }
}

/// Dieselben Fälle wie im Klick-Dummy (`docs/kamera/vektoren.json`, Abschnitt
/// `zuordnung`; `scripts/check-kamera-js.mjs` lässt sie gegen die JavaScript-Fassung laufen).
struct RegisterChoiceSharedVectorTests {

    @Test func sharedVectorsMatchPrototype() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/kamera/vektoren.json"))
        let file = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try #require(file["zuordnung"] as? [[String: Any]])
        #expect(cases.count >= 5)
        for c in cases {
            let name = c["name"] as? String ?? "?"
            let value = try #require(Decimal(string: c["wert"] as? String ?? "", locale: Locale(identifier: "en_US_POSIX")))
            let others: [ClosedRange<Decimal>?] = (c["andere"] as? [Any] ?? []).map { eintrag in
                guard let paar = eintrag as? [String],
                      let a = Decimal(string: paar[0], locale: Locale(identifier: "en_US_POSIX")),
                      let b = Decimal(string: paar[1], locale: Locale(identifier: "en_US_POSIX")) else { return nil }
                return a...b
            }
            let expected: RegisterChoice = (c["erwartet"] as? Int).map { .couldBeOther($0) } ?? .own
            #expect(RegisterChoice.check(value, others: others) == expected, "\(name)")
        }
    }
}
