import XCTest

/// „Neu in Zählora …“: einmal nach einem Update, weg mit einem Tipp, danach
/// nicht wieder, und nie nach einer Neuinstallation.
///
/// **Warum hier und nicht nur in PulseCore.** Die Regel prüft
/// `ReleaseNotesTests`. Ob die App den Ordner `fassungen` wirklich im Bündel
/// hat, ob das Blatt über der Übersicht aufgeht und ob „Weiter“ es auch als
/// gesehen merkt, sieht nur ein Lauf der echten App. Fehlt der Ordner im
/// Bündel (ein Fehler in `project.yml`), bliebe die Regel grün und das Blatt
/// käme nie.
///
/// Die Schalter: `-pulse-neuigkeiten` lässt das Blatt in einem Prüflauf
/// überhaupt zu, `-pulse-neuigkeiten-vergessen` löscht vorher, welche Fassung
/// zuletzt gesehen wurde. Zusammen mit `-pulse-reset` (Beispieldaten) ist das
/// der Zustand nach einem Update von 1.8, mit `-pulse-empty` der nach einer
/// Neuinstallation.
@MainActor
final class NeuigkeitenTests: XCTestCase {

    private let erscheint: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    private func start(_ argumente: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumente
        app.launch()
        return app
    }

    private func blatt(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["neuigkeiten-weiter"]
    }

    /// Nach einem Update: Blatt mit Fassung, Überschrift und „Weiter“; ein
    /// Tipp, und es ist weg. Beim nächsten Start kommt es nicht wieder.
    func testShownOnceAfterAnUpdateAndGoneForGoodAfterOneTap() {
        let app = start(["-pulse-reset", "-pulse-pro", "-pulse-neuigkeiten", "-pulse-neuigkeiten-vergessen"])
        XCTAssertTrue(blatt(app).waitForExistence(timeout: erscheint),
                      "Nach einem Update erschien „Neu in Zählora“ nicht")
        let fassung = app.staticTexts["neuigkeiten-fassung"].label
        XCTAssertTrue(fassung.hasPrefix("Neu in Zählora 1."), "Kopfzeile war „\(fassung)“")
        XCTAssertFalse(app.staticTexts["neuigkeiten-titel"].label.isEmpty, "Überschrift fehlt")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Neuigkeiten"
        shot.lifetime = .keepAlways
        add(shot)

        blatt(app).tap()
        XCTAssertTrue(blatt(app).waitForNonExistence(timeout: erscheint),
                      "„Weiter“ hat das Blatt nicht geschlossen")
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: erscheint),
                      "Nach dem Schließen steht die Übersicht nicht da")

        // Dieselben Daten, kein Vergessen: Das ist der nächste Start.
        app.terminate()
        let wieder = start(["-pulse-neuigkeiten"])
        XCTAssertTrue(wieder.staticTexts["Strom"].waitForExistence(timeout: 15),
                      "Die Übersicht erschien beim zweiten Start nicht")
        XCTAssertFalse(blatt(wieder).waitForExistence(timeout: 3),
                       "Einmal weggetippt, und es kam beim nächsten Start doch wieder")
    }

    /// Wegwischen zählt wie „Weiter“.
    func testSwipingItAwayCountsAsSeen() {
        let app = start(["-pulse-reset", "-pulse-pro", "-pulse-neuigkeiten", "-pulse-neuigkeiten-vergessen"])
        XCTAssertTrue(blatt(app).waitForExistence(timeout: erscheint))
        // **Von der Kopfzeile bis an den unteren Rand gezogen**, nicht
        // `swipeDown()` auf dem Text: Der erste CI-Lauf zeigte, dass der kurze
        // Wisch das Blatt nur zwischen halber und voller Höhe bewegt.
        wegziehen(app)
        if blatt(app).exists { wegziehen(app) }
        XCTAssertTrue(blatt(app).waitForNonExistence(timeout: erscheint), "Das Blatt ließ sich nicht wegwischen")

        app.terminate()
        let wieder = start(["-pulse-neuigkeiten"])
        XCTAssertTrue(wieder.staticTexts["Strom"].waitForExistence(timeout: 15))
        XCTAssertFalse(blatt(wieder).waitForExistence(timeout: 3),
                       "Weggewischt, und es kam beim nächsten Start wieder")
    }

    private func wegziehen(_ app: XCUIApplication) {
        let oben = app.staticTexts["neuigkeiten-fassung"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let unten = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99))
        oben.press(forDuration: 0.05, thenDragTo: unten, withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// Neu installiert: kein Blatt, auch nicht beim zweiten Start mit Zählern.
    /// Wer die App gerade erst hat, für den ist alles neu.
    func testNeverAfterAFreshInstall() {
        let app = start(["-pulse-empty", "-pulse-neuigkeiten", "-pulse-neuigkeiten-vergessen"])
        XCTAssertFalse(blatt(app).waitForExistence(timeout: 4),
                       "Nach einer Neuinstallation erschien „Neu in Zählora“")
        app.terminate()

        // Jetzt mit Zählern, aber ohne Vergessen: Die Fassung ist schon gemerkt.
        let spaeter = start(["-pulse-reset", "-pulse-pro", "-pulse-neuigkeiten"])
        XCTAssertTrue(spaeter.staticTexts["Strom"].waitForExistence(timeout: 15))
        XCTAssertFalse(blatt(spaeter).waitForExistence(timeout: 3),
                       "Beim zweiten Start nach der Installation erschien „Neu in Zählora“")
    }

    /// Prüfläufe ohne den Schalter sehen das Blatt nie, sonst läge es über
    /// jedem Schirm, den eine andere Prüfung sucht.
    func testOtherTestRunsNeverSeeIt() {
        let app = start(["-pulse-reset", "-pulse-pro", "-pulse-neuigkeiten-vergessen"])
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 15))
        XCTAssertFalse(blatt(app).waitForExistence(timeout: 3),
                       "Ohne -pulse-neuigkeiten erschien das Blatt in einem Prüflauf")
    }
}
