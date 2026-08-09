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
    /// Schiebt ein Formular so weit, bis das Element antippbar ist.
    ///
    /// Ein Formular ist länger als der Bildschirm, und `tap()` auf etwas
    /// außerhalb des sichtbaren Bereichs scheitert — als läge ein Fehler in
    /// der App vor, obwohl nur gescrollt werden müsste.
    private func scroll(to element: XCUIElement, in app: XCUIApplication, swipes: Int = 6) -> Bool {
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

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
        //
        // Über `CONTAINS` statt über den genauen Text: Seit 0.27.0 fasst die
        // Karte Zeitraum, Zahl und Erläuterung für VoiceOver zu **einem**
        // Element zusammen, damit sie als ein Satz vorgelesen werden. Der
        // Einzeltext existiert dann nicht mehr als eigenes Element. Geprüft
        // wird die Aussage, nicht die Bauform — sonst hält der Test wieder
        // eine Struktur fest statt einer Zusage.
        let needsSecond = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'ergibt sich aus zwei Ablesungen'")
        ).firstMatch
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

    /// Kosten stehen auf der Karte — und die Beschriftung nennt den Zeitraum,
    /// den der Betrag abdeckt.
    ///
    /// Prüft die ganze Kette: Tarif im Speicher, `CostEngine`, Anzeige. Beim
    /// Gaszähler zusätzlich die Umrechnung von m³ in kWh — ohne Zustandszahl
    /// und Brennwert verweigert der Rechenkern die Auskunft, und zwar zu Recht.
    ///
    /// Der Test stand vorher auf dem festen Wort „Kosten seit Jahresbeginn"
    /// und hat damit in 0.21.4 zu Recht angeschlagen: Genau diese Formulierung
    /// war beim überfälligen Gaszähler falsch, weil die Ablesungen im Mai
    /// enden und drei Monate fehlen. Er prüft jetzt die Eigenschaft statt der
    /// Formulierung — sonst hält er wieder den Wortlaut fest statt der Aussage.
    func testCostIsLabelledWithThePeriodItCovers() {
        let app = launchWithData()

        let costs = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Kosten'")
        )
        XCTAssertGreaterThan(costs.count, 0,
                             "Mit hinterlegtem Tarif müssen Kosten auf der Karte stehen")

        // Ein Betrag in Euro, nicht bloß die Beschriftung.
        let amount = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '€'")).firstMatch
        XCTAssertTrue(amount.exists, "Es steht keine Zahl mit Währung auf der Karte")

        // Der Gaszähler ist im Ausgangszustand bewusst drei Monate überfällig,
        // seine Kostenzeile muss also ein Enddatum nennen. Bewusst als
        // vorhandene Aussage geprüft und nicht als fehlende: Am Ersten eines
        // Monats ist der Stromzähler taggenau vollständig, und dort wäre
        // „seit Jahresbeginn" dann richtig. Eine Verneinung hinge am Kalender.
        let bounded = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Kosten bis '")
        )
        XCTAssertGreaterThan(bounded.count, 0,
                             "Beim überfälligen Zähler muss die Kostenzeile ihr Enddatum nennen")
    }

    /// Mit Abschlag steht die Vorschau auf dem Jahresende auf der Karte.
    ///
    /// Die Kette dahinter ist die längste der App: Ablesungen → Hochrechnung
    /// des restlichen Zeitraums → Kosten je Abschnitt → gegen die Abschläge.
    /// Ein Fehler an irgendeiner Stelle fällt hier als falsches Vorzeichen auf.
    func testPrepaymentOutlookAppearsOnTheCard() {
        let app = launchWithData()
        let outlook = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Guthaben' OR label CONTAINS 'Nachzahlung'")
        ).firstMatch
        XCTAssertTrue(outlook.waitForExistence(timeout: 5),
                      "Mit hinterlegtem Abschlag muss eine Vorschau dastehen")

        // Der Wasserzähler hat bewusst keinen Abschlag — dort darf nichts
        // stehen, statt einer Null.
        //
        // **Über die verschiedenen Beschriftungen, nicht über die Anzahl der
        // Elemente.** Seit 0.27.0 fasst die Fußzeile Text und Betrag für
        // VoiceOver zu einem Element zusammen; XCUITest sieht daraufhin beides
        // — das zusammengefasste Element und seinen Text — und zählte vier
        // statt zwei. Die Aussage, um die es geht, ist aber nicht „vier
        // Elemente", sondern „genau zwei Zähler zeigen eine Vorschau". Über
        // die Menge der Beschriftungen gezählt bleibt sie richtig, egal wie
        // die Oberfläche innen aufgebaut ist.
        let prepayLabels = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Abschlag'")
        )
        // Gezählt wird über den **Abschlagsbetrag**, nicht über den Anfang der
        // Beschriftung. Das Protokoll des vorigen Laufs hat gezeigt, warum:
        //
        //   ["Abschlag 1.200,00 € im Jahr", "Abschlag 1.200,00 € im Jahr, ≈",
        //    "Abschlag 2.760,00 € im Jahr", "Abschlag 2.760,00 € im Jahr, ≈"]
        //
        // Je Zeile stehen zwei Einträge: der reine Text und das zusammengefasste
        // Element, das ihn enthält. Das Zusammenfassen wirkt also wie gewollt —
        // XCUITest zeigt zusätzlich die darunterliegende Ansicht, VoiceOver
        // benutzt den Zugänglichkeitsbaum. Der Jahresbetrag ist das, was eine
        // Abschlagszeile ausmacht; über ihn gezählt fallen die beiden
        // Erscheinungsformen derselben Zeile zusammen.
        var seen = Set<String>()
        for index in 0..<prepayLabels.count {
            let label = prepayLabels.element(boundBy: index).label
            let key = label.range(of: " im Jahr").map { String(label[..<$0.lowerBound]) } ?? label
            seen.insert(key)
        }
        // Damit ein Fehlschlag nicht wieder raten lässt, was gefunden wurde.
        print("ABSCHLAG-BESCHRIFTUNGEN: \(seen.sorted())")

        XCTAssertEqual(seen.count, 2,
                       "Genau die zwei Zähler mit Abschlag dürfen eine Vorschau zeigen — gefunden: \(seen.sorted())")
    }

    /// Ein Preis lässt sich eintragen, ohne dass man vorher irgendetwas über
    /// Tarife wissen müsste — zwei Zahlen von der Jahresrechnung.
    func testEnteringAPriceOnANewMeter() {
        let app = launchEmpty()

        XCTAssertTrue(app.buttons["Ersten Zähler anlegen"].waitForExistence(timeout: 10))
        app.buttons["Ersten Zähler anlegen"].tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Strom")

        let price = app.textFields["0,00"].firstMatch
        XCTAssertTrue(price.exists, "Das Feld für den Arbeitspreis fehlt")
        price.tap()
        price.typeText("0,34")

        app.buttons["Sichern"].tap()
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 5),
                      "Der Zähler wurde nicht gesichert")
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

    /// In der Tabelle lässt sich von Menge auf Kosten umschalten.
    ///
    /// Geprüft wird nicht nur, dass der Umschalter da ist, sondern dass sich
    /// die Spaltenüberschrift ändert — sonst stünden Euro-Beträge unter
    /// „Verbrauch".
    func testHistoryTableSwitchesToCosts() {
        let app = launchWithData()
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Alle Zahlen"].waitForExistence(timeout: 5))
        app.buttons["Alle Zahlen"].tap()

        XCTAssertTrue(app.staticTexts["VERBRAUCH"].waitForExistence(timeout: 5),
                      "Die Mengenspalte fehlt")

        let costs = app.buttons["Kosten"]
        XCTAssertTrue(costs.waitForExistence(timeout: 5),
                      "Mit hinterlegtem Tarif muss sich auf Kosten umschalten lassen")
        costs.tap()

        XCTAssertTrue(app.staticTexts["KOSTEN"].waitForExistence(timeout: 5),
                      "Die Spaltenüberschrift ist nicht mitgewandert")
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

        // Über den Anfang der Beschriftung: Seit 0.28.0 liest sich eine
        // Zeile im Zähler-Schirm für VoiceOver als ein Satz — „Gartenwasser,
        // noch keine Ablesung" —, und der Name allein ist kein eigenes
        // Element mehr. Geprüft wird, dass der Zähler in der Liste steht,
        // nicht wie die Liste innen gebaut ist.
        let neu = app.descendants(matching: .any).containing(
            NSPredicate(format: "label BEGINSWITH 'Gartenwasser'")
        ).firstMatch
        XCTAssertTrue(neu.waitForExistence(timeout: 5),
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

    /// Der Ausgangszustand gilt unabhängig davon, welcher Schirm zuerst
    /// erscheint.
    ///
    /// Bis 0.21.3 wertete `OverviewView` die Startschalter aus, und SwiftUI
    /// baut einen Tab erst, wenn er sichtbar wird: Ein Start direkt im
    /// Zähler-Schirm erreichte diese Stelle nie. Übrig blieb, was der
    /// vorherige Start hinterlassen hatte — nach einem leeren Lauf also nichts.
    /// Aufgefallen ist es an einem Bildschirmfoto, das „Noch kein Zähler"
    /// zeigte, während die Übersicht drei Zähler führte. Kein Test hätte das
    /// gesehen, weil jeder von ihnen in der Übersicht beginnt.
    func testFixtureAppliesRegardlessOfTheOpeningScreen() {
        let empty = XCUIApplication()
        empty.launchArguments = ["-pulse-empty"]
        empty.launch()
        XCTAssertTrue(empty.staticTexts["Noch kein Zähler"].waitForExistence(timeout: 15))
        empty.terminate()

        // Derselbe Simulator, direkt in den Zähler-Schirm. Ohne die Verlagerung
        // in `LaunchFixture` stünde hier der leere Bestand des Laufs davor.
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset", "-pulse-zaehler"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Zähler"].waitForExistence(timeout: 15),
                      "Der Zähler-Schirm wurde nicht geöffnet")
        for name in ["Strom", "Wasser", "Gas"] {
            // Ebenfalls über den Anfang: Die Zeile trägt seit 0.28.0 eine
            // zusammengesetzte Beschriftung.
            let zeile = app.descendants(matching: .any).containing(
                NSPredicate(format: "label BEGINSWITH %@", name)
            ).firstMatch
            XCTAssertTrue(zeile.waitForExistence(timeout: 5),
                          "\(name) fehlt im Zähler-Schirm — der Ausgangszustand kam nicht an")
        }
    }

    /// Der Zweirichtungszähler wird in einem Vorgang abgelesen — erst Bezug,
    /// dann Einspeisung.
    ///
    /// Bis 0.22.2 gab es für diesen Ablauf weder eine Prüfung noch ein Bild:
    /// `-pulse-capture` öffnet den ersten Zähler, und das ist Gas mit einem
    /// einzigen Zählwerk. Ein Ablauf, den niemand ansieht, ist ein Ablauf, in
    /// dem sich ein Fehler beliebig lange hält.
    func testCapturingBothDirectionsInOneGo() {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset", "-pulse-capture-pv"]
        app.launch()

        // Über den Anfang der Beschriftung: Seit 0.29.0 stehen Zählwerkname und
        // Fortschritt für VoiceOver als ein Satz da — „Bezug, Zählwerk 1 von 2".
        // Geprüft wird, dass beides gesagt wird, nicht in wie vielen Elementen.
        let schritt = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Bezug'")
        ).firstMatch
        XCTAssertTrue(schritt.waitForExistence(timeout: 15),
                      "Der Erfassungsschirm nennt das erste Zählwerk nicht")
        XCTAssertTrue(schritt.label.contains("Zählwerk 1 von 2"),
                      "Ohne den Fortschritt weiß niemand, dass noch etwas kommt — gelesen: \(schritt.label)")

        // „Weiter", nicht „Sichern": Es fehlt noch eine Zahl, und ein Knopf,
        // der etwas anderes tut als er sagt, ist schlimmer als ein Umweg.
        let next = app.buttons["Weiter"]
        XCTAssertTrue(next.exists, "Beim ersten von zwei Zählwerken muss „Weiter“ dastehen")

        app.buttons["Vom letzten Stand übernehmen"].tap()
        next.tap()

        let zweiter = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Einspeisung'")
        ).firstMatch
        XCTAssertTrue(zweiter.waitForExistence(timeout: 5),
                      "Nach dem Bezug muss die Einspeisung drankommen")
        XCTAssertTrue(zweiter.label.contains("Zählwerk 2 von 2"),
                      "gelesen: \(zweiter.label)")

        let save = app.buttons["Sichern"]
        XCTAssertTrue(save.exists, "Beim letzten Zählwerk muss „Sichern“ dastehen")

        // Prinzip 4 — keine Sackgasse. Vom Gründer gefunden: Wer beim zweiten
        // Zählwerk den Tippfehler im ersten bemerkt, kam bis 0.30.1 nicht mehr
        // zurück; der einzige Ausweg war Abbrechen, also alles noch einmal.
        let back = app.buttons["Zurück"]
        XCTAssertTrue(back.exists, "Aus dem zweiten Zählwerk muss ein Weg zurück führen")
        XCTAssertTrue(app.buttons["Abbrechen"].exists,
                      "„Abbrechen“ muss neben „Zurück“ erreichbar bleiben")
        back.tap()

        XCTAssertTrue(schritt.waitForExistence(timeout: 5),
                      "„Zurück“ hat nicht wieder zum ersten Zählwerk geführt")
        XCTAssertTrue(next.exists, "Beim ersten Zählwerk muss wieder „Weiter“ dastehen")
        // Der eingetippte Wert muss wieder dastehen. „Weiter" ist nur
        // freigeschaltet, wenn eine Zahl im Zählwerk steht — bliebe es
        // gesperrt, wäre der Wert verloren und der Weg zurück wertlos.
        XCTAssertTrue(next.isEnabled, "Nach dem Rücksprung war die Eingabe leer")
        next.tap()

        XCTAssertTrue(zweiter.waitForExistence(timeout: 5),
                      "Nach dem Rücksprung ging es nicht wieder vorwärts")
        app.buttons["Vom letzten Stand übernehmen"].tap()
        save.tap()

        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5),
                      "Nach dem Sichern wurde die Übersicht nicht wieder angezeigt")
    }

    /// Die Einspeisung steht auf der Karte, und zwar über den Kosten.
    ///
    /// Der Betrag darunter ist bereits netto. Stünde die Gutschrift hinterher,
    /// zöge sie jeder Leser ein zweites Mal ab.
    func testFeedInAppearsOnTheCard() {
        let app = launchWithData()

        let feedIn = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Einspeisung'")
        ).firstMatch
        XCTAssertTrue(feedIn.waitForExistence(timeout: 10),
                      "Beim Zweirichtungszähler muss die Einspeisung auf der Karte stehen")

        let credit = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'vergütet'")
        ).firstMatch
        XCTAssertTrue(credit.exists,
                      "Mit hinterlegter Vergütung muss ein Betrag dabeistehen")
    }

    /// Wie lange es vom Start bis zur ersten lesbaren Zahl dauert.
    ///
    /// **Was diese Messung nicht kann.** In `00-produktstrategie.md` steht
    /// „Kaltstart bis interaktiv unter 800 ms" — auf einem Gerät. Hier läuft
    /// ein Simulator auf einem geteilten Läufer; die Zahl schwankt um ein
    /// Vielfaches und taugt nicht, um eine Gerätezusage zu prüfen. Wer sie
    /// dafür hielte, hätte eine grüne Prüfung und keine Gewissheit.
    ///
    /// Wofür sie taugt: Sie schreibt die Zeit ins Protokoll, sodass ein
    /// Verlauf entsteht, und sie schlägt an, wenn der Start *hängt* statt
    /// langsam zu sein. Die Grenze ist deshalb bewusst weit — sie fängt einen
    /// Zusammenbruch, keine Verschlechterung um Millisekunden.
    ///
    /// Die eigentliche Messung gehört auf ein Gerät und ist offen.
    func testLaunchReachesTheFirstFigureQuickly() {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset"]

        let started = Date()
        app.launch()
        let card = app.staticTexts["Strom"]
        XCTAssertTrue(card.waitForExistence(timeout: 20),
                      "Die Übersicht kam nicht hoch")
        let elapsed = Date().timeIntervalSince(started)

        // Landet im Protokoll und damit im Artefakt — daraus wird ein Verlauf.
        print("STARTZEIT bis zur ersten Zahl: \(String(format: "%.2f", elapsed)) s")

        // **Keine Schranke auf die Zeit.** Hier stand `XCTAssertLessThan(elapsed, 15)`
        // mit der Begründung, die Grenze sei „bewusst weit" und fange nur einen
        // hängenden Start. Sie fiel beim ersten Lauf mit 15,57 s — mitten im
        // Rauschband eines ausgelasteten Läufers, dessen Schwankung ich im
        // selben Kommentar beschrieben hatte.
        //
        // Der Denkfehler war nicht die Zahl, sondern die zweite Schranke: Ein
        // hängender Start heißt, dass die Übersicht **nie** kommt — und genau
        // das prüft `waitForExistence` oben bereits, mit einer verständlichen
        // Meldung. Eine zweite Prüfung derselben Bedingung fügt nichts hinzu
        // außer Flattern. Was bleibt, ist die Zahl im Protokoll; sie ergibt
        // einen Verlauf, und ein Verlauf zeigt Verschlechterungen, die keine
        // einzelne Schranke je zuverlässig gefunden hätte.
    }

    /// Ein Zähler mit getrennten Preisen für Tag und Nacht, von Hand angelegt.
    ///
    /// **Warum über die Oberfläche und nicht über den Ausgangszustand.** Der
    /// Rechenkern kann den Doppeltarif seit dem ersten Tag; was bis 0.31.0
    /// fehlte, war die Möglichkeit, so einen Zähler *anzulegen*. Ein Test auf
    /// vorbereiteten Daten hätte genau diese Lücke nicht bemerkt.
    func testCreatingADualTariffMeterAsksForBothNumbers() {
        let app = launchWithData()
        app.tabBars.buttons["Zähler"].tap()

        let add = app.buttons["Zähler hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Die Schaltfläche zum Anlegen fehlt")
        add.tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Das Namensfeld fehlt")
        field.tap()
        // Mit Zeilenschaltung: Sonst steht die Tastatur über dem Formular, und
        // der Schalter weiter unten ist nicht antippbar.
        field.typeText("Nachtspeicher\n")

        let toggle = app.switches["Zwei Preise: Tag und Nacht"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5),
                      "Der Schalter für Tag- und Nachtstrom fehlt")
        XCTAssertTrue(scroll(to: toggle, in: app), "Der Schalter ließ sich nicht erreichen")
        toggle.tap()

        // Zwei Arbeitspreise heißt: zwei Felder. Vorher gab es nur eines, und
        // der Nachtpreis hätte nirgends hingekonnt.
        let nachtPreis = app.staticTexts["Arbeitspreis nachts"]
        XCTAssertTrue(scroll(to: nachtPreis, in: app), "Das Feld für den Nachtpreis fehlt")
        XCTAssertTrue(app.staticTexts["Arbeitspreis tagsüber"].exists,
                      "Mit zwei Preisen muss der erste sagen, für wann er gilt")

        app.buttons["Sichern"].tap()

        app.tabBars.buttons["Übersicht"].tap()
        let karte = app.descendants(matching: .any).containing(
            NSPredicate(format: "label BEGINSWITH 'Nachtspeicher'")
        ).firstMatch
        XCTAssertTrue(karte.waitForExistence(timeout: 5),
                      "Der neue Zähler steht nicht auf der Übersicht")
        karte.tap()

        // Erst der Tagstrom, dann der Nachtstrom — in einem Vorgang, wie beim
        // Zweirichtungszähler.
        let erst = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Hochtarif'")
        ).firstMatch
        XCTAssertTrue(erst.waitForExistence(timeout: 10),
                      "Die Erfassung nennt das erste Zählwerk nicht")
        XCTAssertTrue(erst.label.contains("1 von 2"),
                      "Ohne den Fortschritt weiß niemand, dass noch etwas kommt — gelesen: \(erst.label)")

        for taste in ["1", "2", "3", "4"] { app.buttons[taste].firstMatch.tap() }
        app.buttons["Weiter"].tap()

        let zweit = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Niedertarif'")
        ).firstMatch
        XCTAssertTrue(zweit.waitForExistence(timeout: 5),
                      "Nach dem Tagstrom muss der Nachtstrom drankommen")
        XCTAssertTrue(app.buttons["Sichern"].exists,
                      "Beim letzten Zählwerk muss „Sichern“ dastehen")
    }
}
