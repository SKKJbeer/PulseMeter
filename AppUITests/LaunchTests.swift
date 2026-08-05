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

    /// Startet die App ohne jeden Bestand.
    ///
    /// Der Zustand, in dem jeder neue Nutzer anfängt — und bis 0.16 der
    /// einzige, den weder ein Test noch ein Bildschirmfoto je gesehen hat.
    /// Zwei ernste Fehler saßen genau hier: Die Statuszeile meldete „Alles im
    /// Rahmen" für einen nie abgelesenen Zähler, und der Verlauf zeigte „0"
    /// als wäre nichts verbraucht worden statt als wäre nichts bekannt.
    private func launchEmpty() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-empty"]
        app.launch()
        return app
    }

    func testColdStartOffersToCreateAMeter() {
        let app = launchEmpty()

        XCTAssertTrue(app.staticTexts["Noch kein Zähler"].waitForExistence(timeout: 10),
                      "Der leere Zustand fehlt")
        XCTAssertTrue(app.buttons["Ersten Zähler anlegen"].exists,
                      "Der erste Schritt muss zum eigenen Zähler führen, nicht zu Beispieldaten")
    }

    /// Der ganze Weg von der Installation bis zum ersten Verbrauch —
    /// Produktprinzip 1. Ohne diesen Test ist jede andere Prüfung eine
    /// Aussage über einen Bestand, den ein neuer Nutzer nie hat.
    func testFirstMeterThenFirstReadingThenConsumption() {
        let app = launchEmpty()

        // Zähler anlegen
        XCTAssertTrue(app.buttons["Ersten Zähler anlegen"].waitForExistence(timeout: 10))
        app.buttons["Ersten Zähler anlegen"].tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Das Namensfeld fehlt")
        field.tap()
        field.typeText("Keller")
        app.buttons["Sichern"].tap()

        // Die Karte steht und sagt, dass noch nichts abgelesen wurde.
        XCTAssertTrue(app.staticTexts["Keller"].waitForExistence(timeout: 5),
                      "Der neue Zähler erscheint nicht auf der Übersicht")
        let never = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'noch nie abgelesen' OR label CONTAINS 'Noch nie abgelesen'")
        ).firstMatch
        XCTAssertTrue(never.waitForExistence(timeout: 5),
                      "Ein nie abgelesener Zähler muss als solcher gemeldet werden")

        // Erste Ablesung eintippen — es gibt keinen Vorgängerwert zum Übernehmen.
        app.buttons["Stand eintragen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 5), "Der Ziffernblock erschien nicht")
        XCTAssertTrue(app.staticTexts["Erste Ablesung für diesen Zähler"].exists,
                      "Ohne Vorgänger muss das dastehen")
        for digit in ["1", "0", "0", "0", "0"] { app.buttons[digit].tap() }
        app.buttons["Sichern"].tap()

        // Mit genau einer Ablesung steht noch kein Verbrauch fest, und die
        // Karte sagt warum, statt eine Null zu zeigen.
        let needsSecond = app.staticTexts["Der Verbrauch ergibt sich aus zwei Ablesungen"]
        XCTAssertTrue(needsSecond.waitForExistence(timeout: 5),
                      "Nach der ersten Ablesung muss die Karte den zweiten Schritt nennen")
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

    /// Der Verlauf steht und zeigt einen Zähler mit Diagramm.
    func testHistoryShowsAChartForTheSelectedMeter() {
        let app = launchWithData()
        app.tabBars.buttons["Verlauf"].tap()

        XCTAssertTrue(app.staticTexts["Verlauf"].waitForExistence(timeout: 5),
                      "Der Verlauf wurde nicht geöffnet")
        XCTAssertTrue(app.buttons["Monat"].waitForExistence(timeout: 5),
                      "Die Zeitraumwahl fehlt")
        XCTAssertTrue(app.staticTexts["Alle Ablesungen"].exists,
                      "Der Zugang zu den Ablesungen fehlt")
    }

    /// Der Vergleich, für den es diese App gibt: derselbe Monat, andere Jahre.
    ///
    /// Der Verlauf listet die Monate als Balken; ein Tipp darauf öffnet die
    /// Gegenüberstellung. Geprüft wird über die Bedienhilfen-Beschriftung,
    /// weil ein Balken keinen Text trägt.
    func testTappingAMonthOpensTheYearComparison() {
        let app = launchWithData()
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Monat"].waitForExistence(timeout: 5))

        // „F" ist der Februar — ein abgeschlossener Monat mit Vorjahr daneben.
        let february = app.buttons["F"].firstMatch
        XCTAssertTrue(february.waitForExistence(timeout: 5), "Kein Balken für Februar")
        february.tap()

        XCTAssertTrue(app.staticTexts["Februar"].waitForExistence(timeout: 5),
                      "Die Gegenüberstellung wurde nicht geöffnet")
    }

    /// Ein Zähler lässt sich anlegen, ohne dass vorher Beispieldaten nötig
    /// wären. Erst damit ist die App für einen echten Nutzer brauchbar —
    /// vorher kam man nur über „Beispieldaten anlegen" zu einem Zähler.
    func testAddingAMeterFromTheMetersTab() {
        let app = launchWithData()
        app.tabBars.buttons["Zähler"].tap()

        let add = app.buttons["Zähler hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Die Schaltfläche zum Anlegen fehlt")
        add.tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Das Namensfeld fehlt")
        field.tap()
        field.typeText("Gartenwasser")

        app.buttons["Sichern"].tap()

        XCTAssertTrue(app.staticTexts["Gartenwasser"].waitForExistence(timeout: 5),
                      "Der neue Zähler taucht nicht in der Liste auf")
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
