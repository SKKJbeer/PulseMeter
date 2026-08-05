import XCTest

/// Rauchtests: Startet die App und geht die Hauptflüsse durch.
///
/// Ihr Zweck ist, dass eine Sitzung ohne Bildschirm feststellen kann, ob die
/// App hochkommt und ob Speicher, Rechenkern und Oberfläche zusammenspielen.
/// Ein Übersetzungsfehler fällt beim Bauen auf, ein Absturz beim Start nicht —
/// und eine Zahl, die nie erscheint, schon gar nicht.
///
/// Am Hauptakteur, weil die XCUITest-Schnittstellen es unter Swift 6 sind:
/// Fenster und Bedienelemente gehören dem Hauptthread, und der Compiler
/// besteht darauf.
@MainActor
final class LaunchTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Startet die App mit frisch angelegten Beispieldaten.
    ///
    /// Der Reset ist entscheidend: Ohne ihn hängt jeder Test davon ab, was der
    /// vorherige hinterlassen hat. Genau daran ist dieser Testsatz beim ersten
    /// Lauf gescheitert — der Erfassungstest trug beim obersten Zähler einen
    /// Stand ein und räumte damit die Fälligkeit weg, die der nächste erwartete.
    private func launchWithData() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 15),
                      "Die Beispieldaten wurden nicht angelegt")
        return app
    }

    func testAppLaunchesAndShowsTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Übersicht"].waitForExistence(timeout: 10),
                      "Die Tab-Leiste fehlt — die App ist vermutlich beim Start gescheitert")
        XCTAssertTrue(app.tabBars.buttons["Verlauf"].exists)
        XCTAssertTrue(app.tabBars.buttons["Zähler"].exists)
    }

    /// Belegt, dass Speicher und Rechenkern über zwei Jahre Historie
    /// zusammenspielen: Der Vorjahresvergleich entsteht nur dann.
    func testSeedingProducesAYearOverYearComparison() {
        let app = launchWithData()
        let comparison = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'gegenüber Vorjahr'")
        ).firstMatch
        XCTAssertTrue(comparison.waitForExistence(timeout: 5),
                      "Es wurde kein Vorjahresvergleich angezeigt")
    }

    /// Ein Zähler ohne aktuelle Ablesung wird gemeldet. Die Hinweiszeile ist
    /// der Retention-Motor der App — ohne sie kommt niemand zurück.
    func testStaleMeterIsReportedAsDue() {
        let app = launchWithData()
        let notice = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'nicht abgelesen'")
        ).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5),
                      "Der überfällige Gaszähler wurde nicht gemeldet")
    }

    /// Die große Zahl auf einer Karte muss sagen, welchen Zeitraum sie
    /// abdeckt — sonst steht ein Jahreswert da, der im Mai endet.
    ///
    /// Genau das war zu sehen: „1.181 m³" beim Gaszähler, in derselben Form
    /// wie „1.607 kWh" beim Strom, obwohl die eine Zahl vier Monate und die
    /// andere sieben umfasst. Kein Test hat das gemeldet, weil beide Zahlen
    /// für sich richtig gerechnet waren.
    ///
    /// Der Erwartungswert ist bewusst gegen zwei Fassungen geprüft: Läuft der
    /// Test im Januar oder Februar, liegt die letzte Gasablesung noch im
    /// Vorjahr, und für das laufende Jahr gibt es dann gar keine Daten.
    func testStaleMeterSaysHowFarItsNumberReaches() {
        let app = launchWithData()
        let caption = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH '1. Januar bis' OR label == 'Noch keine Ablesung'")
        ).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 5),
                      "Die Zahl des überfälligen Zählers nennt ihren Zeitraum nicht")
    }

    /// Der Fluss, an dem das Produkt hängt: eintragen, Stand übernehmen,
    /// sichern — und der Hinweis auf den überfälligen Zähler ist weg.
    ///
    /// Die Zähler stehen alphabetisch, Gas also oben. Das ist genau der
    /// überfällige, und damit prüft dieser Test den Weg vom Hinweis zur
    /// erledigten Ablesung.
    func testCapturingAReadingClearsTheNotice() {
        let app = launchWithData()

        app.buttons["Stand eintragen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["7"].waitForExistence(timeout: 5),
                      "Der Ziffernblock erschien nicht")

        // Über die Vorbelegung, weil sie einen garantiert plausiblen Wert
        // liefert — und damit auch gleich mitgeprüft wird.
        app.buttons["Vom letzten Stand übernehmen"].tap()

        let save = app.buttons["Sichern"]
        XCTAssertTrue(save.isEnabled, "Sichern blieb gesperrt, obwohl ein Wert übernommen wurde")
        save.tap()

        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5),
                      "Nach dem Sichern wurde die Übersicht nicht wieder angezeigt")

        let notice = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'nicht abgelesen'")
        ).firstMatch
        XCTAssertFalse(notice.exists,
                       "Der Hinweis blieb stehen, obwohl der Zähler abgelesen wurde")
    }
}
