import XCTest

/// Bedienung am Zähler: Was passiert, wenn sich jemand vertippt, abbricht oder
/// noch gar nichts eingetippt hat?
///
/// **Warum eine eigene Klasse.** `LaunchTests` prüft, ob die Hauptwege
/// funktionieren. Hier steht, ob die App den Nutzer auffängt, wenn er vom Weg
/// abkommt — der Teil, den das Testkonzept (`docs/15-testkonzept.md`,
/// Abschnitt „Bedienung“) bis 0.164.0 als Lücke führte: Die Rückfragen im
/// Ziffernblock („Stimmt die Zahl?“, „unter dem letzten Wert“) rechnete
/// PulseCore geprüft aus, aber kein Oberflächentest hat sie je gesehen.
///
/// Dieselben Ausgangsdaten wie in `LaunchTests` (`-pulse-reset -pulse-pro`):
/// Gas steht oben und ist überfällig.
@MainActor
final class BedienungTests: XCTestCase {

    /// Siehe `LaunchTests.erscheint`: gemessen, nicht geschätzt.
    private let erscheint: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    private func startMitDaten() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset", "-pulse-pro"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 15),
                      "Die Beispieldaten wurden nicht angelegt")
        return app
    }

    /// Öffnet den Ziffernblock beim obersten fälligen Zähler (Gas).
    private func ziffernblock(_ app: XCUIApplication) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["7"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")
    }

    /// Der Hinweis unter der Zahl. `VerdictBanner` fasst Zeichen und Satz zu
    /// einem Element zusammen; gesucht wird über alle Arten, weil SwiftUI
    /// es je nach Version als Text oder als Gruppe meldet.
    private func hinweis(_ app: XCUIApplication, enthaelt text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private var ueberfaellig: NSPredicate {
        NSPredicate(format: "label CONTAINS 'nicht abgelesen'")
    }

    /// Ohne Zahl ist „Sichern“ gesperrt, und der Hinweis sagt, was fehlt.
    /// Ein gesperrter Knopf ohne Grund ist eine Sackgasse (Prinzip 4).
    func testSaveWaitsForANumberAndSaysWhy() {
        let app = startMitDaten()
        ziffernblock(app)

        let sichern = app.buttons["Sichern"]
        XCTAssertTrue(sichern.exists, "„Sichern“ fehlt im Ziffernblock")
        XCTAssertFalse(sichern.isEnabled, "„Sichern“ war ohne eingetippte Zahl antippbar")
        XCTAssertTrue(hinweis(app, enthaelt: "Zählerstand eintippen").exists,
                      "Ohne Zahl sagt der Ziffernblock nicht, was er erwartet")

        app.buttons["7"].tap()
        XCTAssertTrue(sichern.isEnabled, "Nach der ersten Ziffer blieb „Sichern“ gesperrt")
    }

    /// Der häufigste Tippfehler nach der Stelle zu viel: eine zu wenig. Die
    /// App fragt sofort nach, nennt den letzten Stand und bietet beide
    /// Antworten an — den Zählerwechsel und das Korrigieren. Wer abbricht,
    /// hat nichts gesichert.
    func testATooSmallNumberIsQuestionedRightAwayAndCancellingKeepsNothing() {
        let app = startMitDaten()
        XCTAssertTrue(app.staticTexts.containing(ueberfaellig).firstMatch.waitForExistence(timeout: erscheint),
                      "Ausgangslage fehlt: Gas sollte überfällig sein")
        ziffernblock(app)

        app.buttons["1"].tap()
        let frage = hinweis(app, enthaelt: "unter dem letzten Wert")
        XCTAssertTrue(frage.waitForExistence(timeout: erscheint),
                      "Ein Stand unter dem letzten Wert wurde nicht beanstandet")
        XCTAssertTrue(frage.label.contains("Ziffer verirrt"),
                      "Die Rückfrage nennt den Tippfehler nicht als Möglichkeit: \(frage.label)")
        XCTAssertTrue(app.buttons["Der Zähler wurde gewechselt"].exists,
                      "Die Rückfrage hat keine Antwort für den Zählerwechsel")
        // Nachfragen, nicht verbieten: Der Nutzer steht vor dem Zähler und weiß
        // es im Zweifel besser.
        XCTAssertTrue(app.buttons["Sichern"].isEnabled,
                      "Ein beanstandeter Stand ließ sich gar nicht mehr sichern")

        app.buttons["Abbrechen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: erscheint),
                      "Nach „Abbrechen“ kam die Übersicht nicht zurück")
        XCTAssertTrue(app.staticTexts.containing(ueberfaellig).firstMatch.waitForExistence(timeout: erscheint),
                      "Nach „Abbrechen“ war Gas nicht mehr überfällig — es wurde also doch gesichert")
    }

    /// Den letzten Stand unverändert übernehmen: Die Rückfrage spricht in
    /// Tagen, nicht in einem Faktor. Bis 0.148 stand hier „rund 0× dein
    /// üblicher Verbrauch“.
    func testAnUnchangedReadingIsQuestionedInPlainWords() {
        let app = startMitDaten()
        ziffernblock(app)

        app.buttons["Vom letzten Stand übernehmen"].tap()
        let frage = hinweis(app, enthaelt: "Derselbe Stand wie vor")
        XCTAssertTrue(frage.waitForExistence(timeout: erscheint),
                      "Der unveränderte Stand wurde nicht in Worten beanstandet")
        XCTAssertFalse(frage.label.contains("×"), "Im Hinweis steht wieder ein Faktor: \(frage.label)")
        XCTAssertTrue(frage.label.contains("Stimmt die Zahl?"), "Die Rückfrage fehlt: \(frage.label)")
    }
}
