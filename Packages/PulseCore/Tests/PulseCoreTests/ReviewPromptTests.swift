import XCTest
@testable import PulseCore

/// Die Bewertungsfrage kommt einmal, nach der dritten Ablesung, und nie wieder.
final class ReviewPromptTests: XCTestCase {

    func testNotBeforeTheThirdReading() {
        for n in 0..<3 {
            XCTAssertFalse(ReviewPrompt.shouldAsk(savedReadings: n, alreadyAsked: false), "\(n)")
        }
    }

    func testAtTheThirdReading() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(savedReadings: 3, alreadyAsked: false))
    }

    /// Wer schon gefragt wurde, wird es nicht wieder, egal wie oft er abliest.
    func testNeverAgainOnceAsked() {
        for n in [3, 4, 30] {
            XCTAssertFalse(ReviewPrompt.shouldAsk(savedReadings: n, alreadyAsked: true), "\(n)")
        }
    }

    /// Wer beim dritten Mal nicht gefragt werden konnte (etwa weil die App
    /// geschlossen wurde, bevor die Frage kam), wird beim vierten gefragt.
    func testCatchesUpIfTheThirdWasMissed() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(savedReadings: 4, alreadyAsked: false))
    }
}
