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

    /// Startet die App und legt bei Bedarf die Beispieldaten an.
    private func launchWithData() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let seedButton = app.buttons["Beispieldaten anlegen"]
        if seedButton.waitForExistence(timeout: 10) {
            seedButton.tap()
        }
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 10),
                      "Nach dem Anlegen fehlt der Stromzähler")
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

    /// Der Fluss, an dem das Produkt hängt: eintragen, Ziffern tippen, sichern.
    func testCapturingAReadingReturnsToTheOverview() {
        let app = launchWithData()

        app.buttons["Stand eintragen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["7"].waitForExistence(timeout: 5),
                      "Der Ziffernblock erschien nicht")

        // Ein plausibler Folgestand für den Stromzähler.
        for digit in ["4", "7", "6", "0", "0", "0"] {
            app.buttons[digit].firstMatch.tap()
        }

        let save = app.buttons["Sichern"]
        XCTAssertTrue(save.isEnabled, "Sichern blieb gesperrt, obwohl Ziffern eingegeben wurden")
        save.tap()

        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5),
                      "Nach dem Sichern wurde die Übersicht nicht wieder angezeigt")
    }
}
