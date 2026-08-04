import XCTest

/// Rauchtest: Startet die App und prüft, dass die Navigation steht.
///
/// Bewusst schmal. Sein Zweck ist, dass eine Sitzung ohne Bildschirm feststellen
/// kann, ob die App überhaupt hochkommt — ein Übersetzungsfehler fällt beim
/// Bauen auf, ein Absturz beim Start nicht.
/// Am Hauptakteur, weil die XCUITest-Schnittstellen es unter Swift 6 sind:
/// Fenster und Bedienelemente gehören dem Hauptthread, und der Compiler
/// besteht darauf.
@MainActor
final class LaunchTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Übersicht"].waitForExistence(timeout: 10),
                      "Die Tab-Leiste fehlt — die App ist vermutlich beim Start gescheitert")
        XCTAssertTrue(app.tabBars.buttons["Verlauf"].exists)
        XCTAssertTrue(app.tabBars.buttons["Zähler"].exists)
    }

    /// Belegt, dass Persistenz und Rechenkern zusammenspielen: Nach dem Anlegen
    /// der Beispieldaten steht ein berechneter Verbrauch auf dem Schirm.
    func testSeedingProducesACalculatedValue() {
        let app = XCUIApplication()
        app.launch()

        let seedButton = app.buttons["Beispieldaten anlegen"]
        guard seedButton.waitForExistence(timeout: 10) else {
            // Beim zweiten Lauf liegen die Daten schon vor.
            XCTAssertTrue(app.staticTexts["Strom"].exists)
            return
        }
        seedButton.tap()

        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 5))
        let consumption = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'seit Jahresbeginn'")
        ).firstMatch
        XCTAssertTrue(consumption.waitForExistence(timeout: 5),
                      "Es wurde kein berechneter Verbrauch angezeigt")
    }
}
