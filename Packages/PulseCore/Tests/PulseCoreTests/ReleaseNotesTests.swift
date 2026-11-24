import XCTest
@testable import PulseCore

/// „Neu in dieser Fassung“: einmal nach einem Update, nie nach einer
/// Neuinstallation, und nach dem Wegtippen erst wieder mit der nächsten Fassung.
final class ReleaseNotesTests: XCTestCase {

    private let neunzehn = ReleaseNote(version: "1.9", title: "Neu", points: ["Eins"])

    // MARK: - Die Regel

    /// Wer von 1.8 kommt, hat nie eine Fassung gesehen und hat Zähler: zeigen.
    func testShownAfterAnUpdateFromBeforeTheFeature() {
        XCTAssertEqual(ReleaseNotes.decide(latest: neunzehn, lastSeen: nil, usedBefore: true),
                       .show(neunzehn))
    }

    /// Frisch installiert: nicht zeigen, aber merken. Sonst käme das Blatt
    /// beim zweiten Start, sobald der erste Zähler angelegt ist.
    func testFreshInstallIsRememberedNotShown() {
        XCTAssertEqual(ReleaseNotes.decide(latest: neunzehn, lastSeen: nil, usedBefore: false),
                       .remember("1.9"))
    }

    /// Weggetippt heißt gesehen: beim nächsten Start nichts mehr.
    func testNotAgainOnceSeen() {
        XCTAssertEqual(ReleaseNotes.decide(latest: neunzehn, lastSeen: "1.9", usedBefore: true),
                       .nothing)
    }

    /// Die nächste Fassung zeigt sich wieder, auch für jemanden, der beim
    /// Installieren nichts gesehen hat.
    func testShownAgainForTheNextVersion() {
        let zehn = ReleaseNote(version: "1.10", title: "Neu", points: ["Zwei"])
        XCTAssertEqual(ReleaseNotes.decide(latest: zehn, lastSeen: "1.9", usedBefore: true), .show(zehn))
        XCTAssertEqual(ReleaseNotes.decide(latest: zehn, lastSeen: "1.9", usedBefore: false), .show(zehn))
    }

    /// Zurückgespielt (TestFlight) zeigt nichts und vergisst nichts.
    func testNothingForAnOlderVersion() {
        XCTAssertEqual(ReleaseNotes.decide(latest: neunzehn, lastSeen: "2.0", usedBefore: true), .nothing)
    }

    /// Ohne Text für die laufende Fassung gibt es nichts zu zeigen.
    func testNothingWithoutNotes() {
        XCTAssertEqual(ReleaseNotes.decide(latest: nil, lastSeen: nil, usedBefore: true), .nothing)
        XCTAssertEqual(ReleaseNotes.decide(latest: nil, lastSeen: "1.9", usedBefore: true), .nothing)
    }

    /// Ein kaputter Eintrag im Speicher zählt wie keiner.
    func testUnreadableLastSeenCountsAsNone() {
        XCTAssertEqual(ReleaseNotes.decide(latest: neunzehn, lastSeen: "kaputt", usedBefore: true),
                       .show(neunzehn))
    }

    func testVersionsCompareAsNumbers() {
        XCTAssertEqual(ReleaseNotes.compare("1.10", "1.9"), .orderedDescending)
        XCTAssertEqual(ReleaseNotes.compare("1.9", "1.9.0"), .orderedSame)
        XCTAssertEqual(ReleaseNotes.compare("1.9.1", "1.9"), .orderedDescending)
        XCTAssertEqual(ReleaseNotes.compare("2.0", "1.12"), .orderedDescending)
    }

    func testLatestPicksTheHighestVersion() {
        let notes = ["1.9", "1.10", "1.9.1"].map { ReleaseNote(version: $0, title: "t", points: ["p"]) }
        XCTAssertEqual(ReleaseNotes.latest(notes)?.version, "1.10")
        XCTAssertNil(ReleaseNotes.latest([]))
    }

    // MARK: - Die Datei

    func testDecodesTheAppBlock() throws {
        let json = #"{"fassung":"1.9","weg":{"titel":"W","text":"T"},"app":{"titel":" Titel ","punkte":["A"," ","B","C","D"]}}"#
        let note = try XCTUnwrap(ReleaseNote.decode(Data(json.utf8)))
        XCTAssertEqual(note.version, "1.9")
        XCTAssertEqual(note.title, "Titel")
        XCTAssertEqual(note.points, ["A", "B", "C"], "Leere fallen weg, höchstens drei")
    }

    /// Fassungen vor 1.9 haben keinen Block `app` und zeigen nichts.
    func testFileWithoutAppBlockHasNothingToShow() {
        let json = #"{"fassung":"1.8","weg":{"titel":"W","text":"T"},"start":null}"#
        XCTAssertNil(ReleaseNote.decode(Data(json.utf8)))
        XCTAssertNil(ReleaseNote.decode(Data(#"{"fassung":"1.9","app":{"titel":"","punkte":["A"]}}"#.utf8)))
        XCTAssertNil(ReleaseNote.decode(Data(#"{"fassung":"1.9","app":{"titel":"T","punkte":[]}}"#.utf8)))
        XCTAssertNil(ReleaseNote.decode(Data(#"{"fassung":"neu","app":{"titel":"T","punkte":["A"]}}"#.utf8)))
        XCTAssertNil(ReleaseNote.decode(Data("kein json".utf8)))
    }

    /// **Die echten Dateien**, dieselben, die die App als Ressource mitbringt.
    /// Jede liest sich, und die neueste mit Block `app` ist auch die neueste
    /// überhaupt: Sonst zeigte eine neue Fassung ohne eigenen Text die
    /// Neuigkeiten der vorigen ein zweites Mal als neu an.
    func testTheShippedFilesAreReadable() throws {
        let ordner = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fassungen")
        let dateien = try FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertFalse(dateien.isEmpty, "docs/fassungen nicht gefunden: \(ordner.path)")
        let notes = try dateien.compactMap { ReleaseNote.decode(try Data(contentsOf: $0)) }
        let neueste = try XCTUnwrap(dateien.map { $0.deletingPathExtension().lastPathComponent }
            .max { ReleaseNotes.compare($0, $1) == .orderedAscending })
        if ReleaseNotes.compare(neueste, "1.9") != .orderedAscending {
            XCTAssertEqual(ReleaseNotes.latest(notes)?.version, neueste,
                           "Fassung \(neueste) hat keinen Block „app“ in docs/fassungen/\(neueste).json")
        }
        for note in notes {
            XCTAssertLessThanOrEqual(note.points.count, ReleaseNotes.maxPoints)
        }
    }
}
