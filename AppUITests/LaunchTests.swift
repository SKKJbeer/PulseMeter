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

    /// Wie lange auf ein Element gewartet wird, das gleich erscheinen soll.
    ///
    /// **Zehn Sekunden, nicht fünf — und das ist gemessen, nicht geschätzt.**
    /// Mit 0.34.0 fiel `testAddingAMeterFromTheMetersTab` mit „Die Schaltfläche
    /// zum Anlegen fehlt", nach 55 Sekunden. Derselbe Commit, noch einmal
    /// gelaufen, war grün: Es lag nicht am Code, sondern an der Uhr.
    ///
    /// Die Oberflächenprüfungen laufen auf **drei geklonten Simulatoren
    /// gleichzeitig** (`-parallel-testing-enabled` in `scripts/pruefen.sh`).
    /// Unter dieser Last braucht ein Tabwechsel gelegentlich länger als fünf
    /// Sekunden — und eine Prüfung, die zufällig fällt, ist schlimmer als
    /// keine: Sie kostet einen Lauf von fünfzehn Minuten und, schlimmer, das
    /// Vertrauen in jeden roten Lauf danach.
    ///
    /// Der Preis ist gering: Länger gewartet wird nur dort, wo etwas
    /// **wirklich** fehlt, und dann sind fünf Sekunden mehr gegen eine
    /// verlorene Viertelstunde gerechnet.
    private let erscheint: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    /// Startet die App mit frisch angelegten Beispieldaten.
    ///
    /// Der Reset ist entscheidend: Ohne ihn hängt jeder Test davon ab, was der
    /// vorherige hinterlassen hat. Genau daran ist dieser Testsatz beim ersten
    /// Lauf gescheitert — der Erfassungstest trug beim obersten Zähler einen
    /// Stand ein und räumte damit die Fälligkeit weg, die der nächste erwartete.
    /// **Warum `-pulse-pro` überall dabeisteht.** Seit 0.35.0 gibt es eine
    /// Grenze zwischen Kostenlos und Pro, und die Beispieldaten liegen
    /// vollständig darüber: vier Zähler, Preise, Abschlag, Einspeisung, zwei
    /// Arbeitspreise. Ohne den Schalter prüften alle Abläufe hier die App
    /// hinter einem Schloss — und der dritte Zähler ließe sich gar nicht mehr
    /// anlegen. Der Zustand *vor* dem Kauf hat eigene Prüfungen, weiter unten.
    private func launchWithData() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset", "-pulse-pro"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: 15),
                      "Die Beispieldaten wurden nicht angelegt")
        return app
    }

    /// Schiebt ein Formular so weit, bis das Element antippbar ist.
    ///
    /// Ein Formular ist länger als der Bildschirm, und `tap()` auf etwas
    /// außerhalb des sichtbaren Bereichs scheitert — als läge ein Fehler in
    /// der App vor, obwohl nur gescrollt werden müsste.
    private func scroll(to element: XCUIElement, in app: XCUIApplication, swipes: Int = 8) -> Bool {
        // Gewischt wird auf dem Formular selbst, nicht auf der App: Ein Wisch
        // auf `app` landet unter Umständen auf der Tab-Leiste und bewegt
        // nichts. Ein `Form` ist unter der Haube eine Sammlung, ein
        // `ScrollView` eine Bildlaufansicht — beides kommt vor.
        //
        // **Und zwar die oberste, nicht die erste.** Ein vorgeblendetes
        // Formular legt eine zweite Sammlung über die Liste dahinter.
        // `firstMatch` trifft die hintere; ein Wisch darauf bewegt das
        // Formular nicht, das Feld bleibt außerhalb des Bildes, und der Test
        // meldet „Feld fehlt", obwohl es da ist und nur nicht sichtbar.
        // Genau so las sich der Fehlschlag von 0.32.2.
        let container: XCUIElement = {
            for query in [app.collectionViews, app.tables, app.scrollViews] {
                let anzahl = query.count
                if anzahl > 0 { return query.element(boundBy: anzahl - 1) }
            }
            return app
        }()
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            container.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Wechselt den Tab und **prüft nach, dass er auch gewechselt hat**.
    ///
    /// **Warum das nötig ist.** `testAddingAMeterFromTheMetersTab` ist zweimal
    /// gefallen — in 0.34.0 und in 0.36.0 —, beide Male mit „Die Schaltfläche
    /// zum Anlegen fehlt", beide Male als **erste** Prüfung des Laufs, beide
    /// Male nach knapp einer Minute. Beide Male war derselbe Commit im zweiten
    /// Anlauf grün.
    ///
    /// In 0.34.1 habe ich daraus geschlossen, es sei zu kurz gewartet, und
    /// alle Wartezeiten von fünf auf zehn Sekunden gesetzt. **Das war die
    /// falsche Erklärung**, denn es ist danach wieder gefallen. Das Protokoll
    /// des Laufs 31418692022 sagt, was wirklich passiert: Der Start dauerte
    /// 14 Sekunden („Setting up automation session", „Wait for app to idle"),
    /// und der Tipp auf den Tab fiel in genau dieses Fenster. Er ging
    /// verloren — die App blieb auf der Übersicht stehen. Danach hätte auch
    /// eine Wartezeit von einer Minute nichts gefunden, denn der Knopf war
    /// nicht langsam, sondern auf einem anderen Schirm.
    ///
    /// Deshalb hier keine längere Wartezeit, sondern eine Gegenprobe: Ist der
    /// Zielschirm nach dem Tipp nicht da, wird noch einmal getippt. Kommt er
    /// dann immer noch nicht, ist es ein echter Fehler — und die Meldung sagt,
    /// was stattdessen zu sehen war.
    @discardableResult
    private func wechsel(zu tab: String, in app: XCUIApplication) -> Bool {
        let knopf = app.tabBars.buttons[tab]
        guard knopf.waitForExistence(timeout: erscheint) else {
            XCTFail("Die Tab-Leiste kennt den Eintrag \(tab) nicht")
            return false
        }
        for versuch in 1...2 {
            knopf.tap()
            // **Über die Navigationsleiste, nicht über einen Text.** Der Tab
            // trägt denselben Namen wie der Schirm; ein `staticTexts[tab]`
            // könnte deshalb die Beschriftung des Tabs selbst treffen und
            // wäre auch dann erfüllt, wenn gar nichts gewechselt hat — die
            // Gegenprobe prüfte sich dann selbst.
            if app.navigationBars[tab].waitForExistence(timeout: erscheint) { return true }
            if versuch == 1 {
                // Ein verlorener Tipp während des Starts. Kein Grund zur
                // Aufregung, aber einer, der im Protokoll stehen soll.
                XCTContext.runActivity(named: "Tab \(tab) kam nicht — zweiter Versuch") { _ in }
            }
        }
        XCTFail("Der Schirm \(tab) kam auch nach zwei Versuchen nicht")
        return false
    }

    /// Startet die App ohne jeden Bestand.
    ///
    /// Der Zustand, in dem jeder neue Nutzer anfängt — und bis 0.16 der
    /// einzige, den weder ein Test noch ein Bildschirmfoto je gesehen hat.
    /// Zwei ernste Fehler saßen genau hier: Die Statuszeile meldete „Alles im
    /// Rahmen“ für einen nie abgelesenen Zähler, und der Verlauf zeigte „0“
    /// als wäre nichts verbraucht worden statt als wäre nichts bekannt.
    private func launchEmpty() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-empty", "-pulse-pro"]
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
        XCTAssertTrue(field.waitForExistence(timeout: erscheint), "Das Namensfeld fehlt")
        field.tap()
        field.typeText("Keller")
        app.buttons["Sichern"].tap()

        // Die Karte steht und sagt, dass noch nichts abgelesen wurde.
        XCTAssertTrue(app.staticTexts["Keller"].waitForExistence(timeout: erscheint),
                      "Der neue Zähler erscheint nicht auf der Übersicht")
        let never = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'noch nie abgelesen' OR label CONTAINS 'Noch nie abgelesen'")
        ).firstMatch
        XCTAssertTrue(never.waitForExistence(timeout: erscheint),
                      "Ein nie abgelesener Zähler muss als solcher gemeldet werden")

        // Erste Ablesung eintippen — es gibt keinen Vorgängerwert zum Übernehmen.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: erscheint), "Der Ziffernblock erschien nicht")
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
        XCTAssertTrue(needsSecond.waitForExistence(timeout: erscheint),
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
        XCTAssertTrue(comparison.waitForExistence(timeout: erscheint),
                      "Es wurde kein Vorjahresvergleich angezeigt")
    }

    /// Ein Zähler ohne aktuelle Ablesung wird gemeldet. Die Hinweiszeile ist
    /// der Retention-Motor der App — ohne sie kommt niemand zurück.
    func testStaleMeterIsReportedAsDue() {
        let app = launchWithData()
        let notice = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'nicht abgelesen'")
        ).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: erscheint),
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
        XCTAssertTrue(outlook.waitForExistence(timeout: erscheint),
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

        // Drei seit 0.31.0: Strom, Gas und die Wärmepumpe. Der Wasserzähler
        // hat bewusst keinen Abschlag und darf deshalb keine Vorschau zeigen.
        // Die Zahl steht hier fest und wird nicht aus den Daten abgeleitet —
        // ein Test, der seine Erwartung aus derselben Quelle holt wie die App,
        // prüft nichts.
        XCTAssertEqual(seen.count, 3,
                       "Genau die drei Zähler mit Abschlag dürfen eine Vorschau zeigen — gefunden: \(seen.sorted())")
    }

    /// Ein Preis lässt sich eintragen, ohne dass man vorher irgendetwas über
    /// Tarife wissen müsste — zwei Zahlen von der Jahresrechnung.
    func testEnteringAPriceOnANewMeter() {
        let app = launchEmpty()

        XCTAssertTrue(app.buttons["Ersten Zähler anlegen"].waitForExistence(timeout: 10))
        app.buttons["Ersten Zähler anlegen"].tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: erscheint))
        field.tap()
        // Mit Zeilenschaltung: Die Tastatur verdeckt sonst die untere Hälfte
        // des Formulars, und das Preisfeld ist genau dort.
        field.typeText("Strom\n")

        // Gescrollt, bevor geprüft wird: Ein `Form` baut nur, was sichtbar
        // ist. Was unten steht, existiert im Zugänglichkeitsbaum schlicht
        // nicht — und ein Test, der das nicht berücksichtigt, meldet einen
        // Fehler in der App, wo nur gescrollt werden müsste.
        let price = app.textFields["0,00"].firstMatch
        XCTAssertTrue(scroll(to: price, in: app), "Das Feld für den Arbeitspreis fehlt")
        price.tap()
        price.typeText("0,34")

        app.buttons["Sichern"].tap()
        XCTAssertTrue(app.staticTexts["Strom"].waitForExistence(timeout: erscheint),
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
        XCTAssertTrue(caption.waitForExistence(timeout: erscheint),
                      "Die Zahl des überfälligen Zählers nennt ihren Zeitraum nicht")
    }

    /// In der Tabelle lässt sich von Menge auf Kosten umschalten.
    ///
    /// Geprüft wird nicht nur, dass der Umschalter da ist, sondern dass sich
    /// die Spaltenüberschrift ändert — sonst stünden Euro-Beträge unter
    /// „Verbrauch".
    func testHistoryTableSwitchesToCosts() {
        let app = launchWithData()
        wechsel(zu: "Verlauf", in: app)
        XCTAssertTrue(app.buttons["Alle Zahlen"].waitForExistence(timeout: erscheint))
        app.buttons["Alle Zahlen"].tap()

        XCTAssertTrue(app.staticTexts["VERBRAUCH"].waitForExistence(timeout: erscheint),
                      "Die Mengenspalte fehlt")

        let costs = app.buttons["Kosten"]
        XCTAssertTrue(costs.waitForExistence(timeout: erscheint),
                      "Mit hinterlegtem Tarif muss sich auf Kosten umschalten lassen")
        costs.tap()

        XCTAssertTrue(app.staticTexts["KOSTEN"].waitForExistence(timeout: erscheint),
                      "Die Spaltenüberschrift ist nicht mitgewandert")
    }

    /// Der Verlauf steht und zeigt einen Zähler mit Diagramm.
    func testHistoryShowsAChartForTheSelectedMeter() {
        let app = launchWithData()
        wechsel(zu: "Verlauf", in: app)

        XCTAssertTrue(app.staticTexts["Verlauf"].waitForExistence(timeout: erscheint),
                      "Der Verlauf wurde nicht geöffnet")
        XCTAssertTrue(app.buttons["Monat"].waitForExistence(timeout: erscheint),
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
        wechsel(zu: "Verlauf", in: app)
        XCTAssertTrue(app.buttons["Monat"].waitForExistence(timeout: erscheint))

        // „F" ist der Februar — ein abgeschlossener Monat mit Vorjahr daneben.
        let february = app.buttons["F"].firstMatch
        XCTAssertTrue(february.waitForExistence(timeout: erscheint), "Kein Balken für Februar")
        february.tap()

        XCTAssertTrue(app.staticTexts["Februar"].waitForExistence(timeout: erscheint),
                      "Die Gegenüberstellung wurde nicht geöffnet")
    }

    /// Ein Zähler lässt sich anlegen, ohne dass vorher Beispieldaten nötig
    /// wären. Erst damit ist die App für einen echten Nutzer brauchbar —
    /// vorher kam man nur über „Beispieldaten anlegen" zu einem Zähler.
    func testAddingAMeterFromTheMetersTab() {
        let app = launchWithData()
        wechsel(zu: "Zähler", in: app)

        let add = app.buttons["Zähler hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: erscheint), "Die Schaltfläche zum Anlegen fehlt")
        add.tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: erscheint), "Das Namensfeld fehlt")
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
        XCTAssertTrue(neu.waitForExistence(timeout: erscheint),
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

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["7"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")

        // Über die Vorbelegung, weil sie einen garantiert plausiblen Wert
        // liefert — und damit auch gleich mitgeprüft wird.
        app.buttons["Vom letzten Stand übernehmen"].tap()

        let save = app.buttons["Sichern"]
        XCTAssertTrue(save.isEnabled, "Sichern blieb gesperrt, obwohl ein Wert übernommen wurde")
        save.tap()

        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: erscheint),
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
        empty.launchArguments = ["-pulse-empty", "-pulse-pro"]
        empty.launch()
        XCTAssertTrue(empty.staticTexts["Noch kein Zähler"].waitForExistence(timeout: 15))
        empty.terminate()

        // Derselbe Simulator, direkt in den Zähler-Schirm. Ohne die Verlagerung
        // in `LaunchFixture` stünde hier der leere Bestand des Laufs davor.
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset", "-pulse-pro", "-pulse-zaehler"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Zähler"].waitForExistence(timeout: 15),
                      "Der Zähler-Schirm wurde nicht geöffnet")
        for name in ["Strom", "Wasser", "Gas"] {
            // Ebenfalls über den Anfang: Die Zeile trägt seit 0.28.0 eine
            // zusammengesetzte Beschriftung.
            let zeile = app.descendants(matching: .any).containing(
                NSPredicate(format: "label BEGINSWITH %@", name)
            ).firstMatch
            XCTAssertTrue(zeile.waitForExistence(timeout: erscheint),
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
        app.launchArguments = ["-pulse-reset", "-pulse-pro", "-pulse-capture-pv"]
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
        XCTAssertTrue(zweiter.waitForExistence(timeout: erscheint),
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

        XCTAssertTrue(schritt.waitForExistence(timeout: erscheint),
                      "„Zurück“ hat nicht wieder zum ersten Zählwerk geführt")
        XCTAssertTrue(next.exists, "Beim ersten Zählwerk muss wieder „Weiter“ dastehen")
        // Der eingetippte Wert muss wieder dastehen. „Weiter" ist nur
        // freigeschaltet, wenn eine Zahl im Zählwerk steht — bliebe es
        // gesperrt, wäre der Wert verloren und der Weg zurück wertlos.
        XCTAssertTrue(next.isEnabled, "Nach dem Rücksprung war die Eingabe leer")
        next.tap()

        XCTAssertTrue(zweiter.waitForExistence(timeout: erscheint),
                      "Nach dem Rücksprung ging es nicht wieder vorwärts")
        app.buttons["Vom letzten Stand übernehmen"].tap()
        save.tap()

        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: erscheint),
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
        app.launchArguments = ["-pulse-reset", "-pulse-pro"]

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
        wechsel(zu: "Zähler", in: app)

        let add = app.buttons["Zähler hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: erscheint), "Die Schaltfläche zum Anlegen fehlt")
        add.tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: erscheint), "Das Namensfeld fehlt")
        field.tap()
        // Mit Zeilenschaltung: Sonst steht die Tastatur über dem Formular, und
        // der Schalter weiter unten ist nicht antippbar.
        field.typeText("Nachtspeicher\n")

        let toggle = app.switches["Zwei Preise: Tag und Nacht"]
        XCTAssertTrue(toggle.waitForExistence(timeout: erscheint),
                      "Der Schalter für Tag- und Nachtstrom fehlt")
        XCTAssertTrue(scroll(to: toggle, in: app), "Der Schalter ließ sich nicht erreichen")
        toggle.tap()

        // **Nachsehen, ob er wirklich umgelegt ist.** Ein `tap()` auf einen
        // Schalter in einem Formular geht still ins Leere, wenn die Zeile
        // gerade noch in Bewegung ist — hier, weil kurz zuvor die Tastatur
        // ausgeblendet wurde und das Formular zurückspringt.
        //
        // Genau das ist zweimal unentdeckt geblieben und hat zwei falsche
        // Diagnosen ausgelöst: Die Prüfung lief weiter, das Nachtpreis-Feld
        // fehlte, und der Fehlschlag las sich wie „die App zeigt es nicht" —
        // dabei hatte niemand den Schalter umgelegt. Die Messung hat es
        // gezeigt: Das erste Preisfeld hieß noch „Arbeitspreis" statt
        // „Arbeitspreis tagsüber", und im ganzen Baum lagen drei Felder statt
        // vier.
        //
        // Ein zweiter Tipper half nicht — gemessen: Der Wert blieb „0". Ein
        // `tap()` auf einen Schalter landet in dessen Mitte, und die liegt bei
        // einer Formularzeile auf der **Beschriftung**, nicht auf dem Knopf.
        // Deshalb der zweite Weg über den Rand: 90 % der Breite, also dort, wo
        // der Schalter tatsächlich sitzt.
        //
        // Beide Wege nacheinander statt eines geratenen: Sitzt der erste, kostet
        // die Abfrage nichts. Sitzt keiner, sagt die Meldung unten, woran es
        // liegt — statt wieder nur „ging nicht".
        if toggle.value as? String != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "1",
                       """
                       Der Schalter für Tag- und Nachtstrom ließ sich nicht umlegen.
                       bedienbar=\(toggle.isEnabled) sichtbar=\(toggle.isHittable) \
                       rahmen=\(toggle.frame) wert=\(String(describing: toggle.value))
                       """)

        // Zwei Arbeitspreise heißt: zwei Felder. Vorher gab es nur eines, und
        // der Nachtpreis hätte nirgends hingekonnt.
        //
        // **Gesucht wird das Feld, nicht die Beschriftung daneben.** Seit dem
        // Barrierefreiheits-Durchgang in 0.32.0 trägt das Eingabefeld seine
        // Beschriftung selbst, und der sichtbare Text ist für die Ansage
        // versteckt — sonst wären es drei Stationen für VoiceOver. Ein Test,
        // der nach dem sichtbaren Text sucht, findet ihn deshalb zu Recht
        // nicht mehr. Er hat damit eine echte Änderung gemeldet, nur die
        // falsche Schlussfolgerung nahegelegt.
        // `matching` und nicht `containing`: Die Beschriftung hängt am Feld
        // selbst, und `containing` sucht sie unter dessen Nachfahren. Bei den
        // Texten weiter oben fällt der Unterschied nicht auf, bei einem
        // Eingabefeld schon — es hat keine.
        let nachtPreis = app.textFields.matching(
            NSPredicate(format: "label BEGINSWITH 'Arbeitspreis nachts'")
        ).firstMatch

        if !scroll(to: nachtPreis, in: app) {
            // **Diagnose statt Vermutung.** Zwei Korrekturversuche sind hier
            // gescheitert — erst der Wechsel vom sichtbaren Text auf die
            // Beschriftung des Feldes, dann `matching` statt `containing` und
            // die oberste Sammlung beim Schieben. Beide waren plausibel, beide
            // waren falsch, und beide haben einen CI-Lauf von dreizehn Minuten
            // gekostet, der als Antwort nur „fehlt" sagte.
            //
            // Ein Fehlschlag, der nicht sagt, was stattdessen da ist, lässt
            // einem nur das Raten. Diese Aufstellung beendet es: Sie nennt
            // jedes Textfeld im Baum mit Kennung, Beschriftung, Platzhalter
            // und Sichtbarkeit. Danach ist die Korrektur eine Ablesung.
            let felder = app.textFields.allElementsBoundByIndex.map { feld -> String in
                // Der Platzhalter zuerst in eine eigene Konstante: Ein gerades
                // Anführungszeichen mitten in einer Zeichenkette — hier über
                // den Ersatzwert in der Auswertung — beendet für
                // `scripts/check-strings.py` das Literal an der falschen
                // Stelle. Die Prüfung hat recht, sie kann es nicht anders
                // sehen, und sie ist zu wertvoll, um sie dafür aufzuweichen.
                let platzhalter = feld.placeholderValue ?? "—"
                return "  id=„\(feld.identifier)“ label=„\(feld.label)“ "
                    + "platzhalter=„\(platzhalter)“ "
                    + "sichtbar=\(feld.isHittable)"
            }
            XCTFail("""
                Das Feld für den Nachtpreis fehlt.
                Sammlungen im Baum: \(app.collectionViews.count), \
                Textfelder: \(felder.count)
                \(felder.joined(separator: "\n"))
                """)
            return
        }

        XCTAssertTrue(app.textFields.matching(
            NSPredicate(format: "label BEGINSWITH 'Arbeitspreis tagsüber'")
        ).firstMatch.exists,
                      "Mit zwei Preisen muss der erste sagen, für wann er gilt")

        app.buttons["Sichern"].tap()

        wechsel(zu: "Übersicht", in: app)
        let karte = app.descendants(matching: .any).containing(
            NSPredicate(format: "label BEGINSWITH 'Nachtspeicher'")
        ).firstMatch
        XCTAssertTrue(karte.waitForExistence(timeout: erscheint),
                      "Der neue Zähler steht nicht auf der Übersicht")

        // **Nicht die Karte antippen, sondern ihren Knopf.** Die Karte selbst
        // öffnet nichts — die Erfassung hängt an „Stand eintragen“. Der Tipper
        // auf die Karte ging deshalb ins Leere, und alles Weitere suchte
        // Zählwerke auf einem Schirm, der noch die Übersicht war. Die
        // Aufstellung im Fehlschlag hat genau das gezeigt: lauter Texte der
        // Übersicht, kein einziger aus der Erfassung.
        //
        // Der Knopf trägt seit dieser Version den Zählernamen, deshalb ist er
        // eindeutig ansprechbar — bei mehreren fälligen Zählern gäbe es sonst
        // mehrere Knöpfe gleichen Namens.
        let eintragen = app.buttons["Stand eintragen für Nachtspeicher"]
        XCTAssertTrue(eintragen.waitForExistence(timeout: erscheint),
                      "Die Karte des neuen Zählers hat keinen Knopf zum Eintragen")
        XCTAssertTrue(scroll(to: eintragen, in: app),
                      "Der Knopf zum Eintragen ließ sich nicht erreichen")
        eintragen.tap()

        // Erst der Tagstrom, dann der Nachtstrom — in einem Vorgang, wie beim
        // Zweirichtungszähler.
        let erst = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Hochtarif'")
        ).firstMatch
        if !erst.waitForExistence(timeout: 10) {
            // Dieselbe Lehre wie beim Schalter: nicht raten, sondern den
            // Bildschirm berichten lassen. Ein selbst angelegter
            // Doppeltarifzähler kann sein erstes Zählwerk anders benennen als
            // der Zähler aus den Beispieldaten — welchen Namen die Erfassung
            // tatsächlich zeigt, steht danach hier.
            let texte = app.staticTexts.allElementsBoundByIndex
                .prefix(25)
                .map { "  „\($0.label)“" }
            XCTFail("""
                Die Erfassung nennt das erste Zählwerk nicht.
                Texte auf dem Schirm (\(app.staticTexts.count)):
                \(texte.joined(separator: "\n"))
                """)
            return
        }
        XCTAssertTrue(erst.label.contains("1 von 2"),
                      "Ohne den Fortschritt weiß niemand, dass noch etwas kommt — gelesen: \(erst.label)")

        for taste in ["1", "2", "3", "4"] { app.buttons[taste].firstMatch.tap() }
        app.buttons["Weiter"].tap()

        let zweit = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Niedertarif'")
        ).firstMatch
        XCTAssertTrue(zweit.waitForExistence(timeout: erscheint),
                      "Nach dem Tagstrom muss der Nachtstrom drankommen")
        XCTAssertTrue(app.buttons["Sichern"].exists,
                      "Beim letzten Zählwerk muss „Sichern“ dastehen")
    }

    /// Der Verbrauchsbericht: Zeitraum wählen, Dokument ansehen, teilen.
    ///
    /// **Warum das eine Prüfung braucht.** Ein Bericht ist das einzige, was
    /// diese App auf Papier verlässt. Er wird neben die Jahresabrechnung
    /// gelegt, und eine falsche oder fehlende Zahl darin wiegt schwerer als
    /// eine auf dem Bildschirm — sie ist ausgedruckt und weitergereicht.
    func testTheReportOffersPeriodsAndProducesADocument() {
        let app = launchWithData()
        wechsel(zu: "Verlauf", in: app)

        let entry = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Verbrauchsbericht'")
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10),
                      "Der Einstieg zum Bericht fehlt im Verlauf")
        XCTAssertTrue(scroll(to: entry, in: app), "Der Einstieg ließ sich nicht erreichen")
        entry.tap()

        // Das Abrechnungsjahr des Versorgers ist der Grund, aus dem es diese
        // Wahl gibt: Es beginnt selten am 1. Januar.
        let laufendes = app.staticTexts["Laufendes Jahr"]
        XCTAssertTrue(laufendes.waitForExistence(timeout: erscheint),
                      "Der Bericht bietet keinen Zeitraum an")
        XCTAssertTrue(app.staticTexts["Letzte 12 Monate"].exists)

        app.buttons["Bericht erstellen"].tap()

        // Das Dokument selbst — und der Weg, es aus der App zu bekommen.
        let titel = app.staticTexts["Verbrauchsbericht"].firstMatch
        XCTAssertTrue(titel.waitForExistence(timeout: 10),
                      "Das Dokument wurde nicht aufgebaut")
        XCTAssertTrue(app.staticTexts["Zusammenfassung"].waitForExistence(timeout: erscheint),
                      "Die Zusammenfassung fehlt auf der ersten Seite")
        XCTAssertTrue(app.buttons["Teilen"].exists,
                      "Ohne Teilen bleibt der Bericht in der App — und ist damit keiner")
        XCTAssertTrue(app.buttons["Zurück"].exists,
                      "Aus dem Dokument muss ein Weg zurück zur Wahl führen")
    }

    /// Ein Doppeltarifzähler steht mit **beiden** Zahlen im Bericht.
    func testTheReportCarriesBothTariffsOfADualTariffMeter() {
        let app = launchWithData()
        wechsel(zu: "Verlauf", in: app)

        let entry = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Verbrauchsbericht'")
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(scroll(to: entry, in: app))
        entry.tap()

        // `firstMatch`, weil der Name zweimal dasteht: einmal als Auswahl im
        // Bericht und einmal in der Zählerauswahl des Verlaufs darunter. Beide
        // sind gültig; gemeint ist die obere.
        let waermepumpe = app.buttons["Wärmepumpe"].firstMatch
        XCTAssertTrue(waermepumpe.waitForExistence(timeout: erscheint),
                      "Der Doppeltarifzähler steht nicht zur Wahl")
        waermepumpe.tap()
        app.buttons["Bericht erstellen"].tap()

        let hoch = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Arbeitspreis Hochtarif'")
        ).firstMatch
        XCTAssertTrue(hoch.waitForExistence(timeout: 10),
                      "Der Hochtarif fehlt im Bericht")
        // **`isHittable`, nicht nur `exists`** — und das ist der eigentliche
        // Wert dieser Zeile. Genau diese Prüfung lief grün, während die
        // Vorschau sechs leere Seiten zeigte: Der Text stand im Baum, wurde
        // aber vollständig weggeschnitten (siehe `ReportView`, Ausrichtung des
        // Rahmens unter `scaleEffect`). Ein Bericht, den man nicht sehen kann,
        // ist keiner — und `exists` allein merkt das nie.
        XCTAssertTrue(hoch.isHittable,
                      "Der Hochtarif steht im Baum, ist aber nicht zu sehen — "
                      + "die Vorschau schneidet ihren eigenen Inhalt weg")
        let nieder = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Arbeitspreis Niedertarif'")
        ).firstMatch
        XCTAssertTrue(nieder.exists,
                      "Der Niedertarif fehlt im Bericht — genau der Fehler, den es zu vermeiden gilt")
    }

    // MARK: - Vor dem Kauf

    /// Startet mit den Beispieldaten, aber **ohne** Pro.
    ///
    /// Genau der Zustand, in dem ein Nutzer nach zwei Wochen steht, wenn ihm
    /// die App gefällt: Zahlen da, Nutzen erkannt, Grenze erreicht.
    private func launchFree(_ extra: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pulse-reset", "-pulse-frei"] + extra
        app.launch()
        return app
    }

    /// Die Grenze führt zur Kaufseite, nicht in eine Sackgasse.
    ///
    /// Der Knopf „Zähler hinzufügen" bleibt sichtbar und bedienbar; er
    /// erklärt, warum es nicht weitergeht. Ein ausgegrauter Knopf hätte
    /// dasselbe verhindert und nichts erklärt — Produktprinzip 4.
    func testTheMeterLimitLeadsToThePurchasePage() {
        let app = launchFree("-pulse-zaehler")

        let hinzu = app.buttons["Zähler hinzufügen"]
        XCTAssertTrue(hinzu.waitForExistence(timeout: 15),
                      "Der Knopf zum Anlegen fehlt — er muss auch an der Grenze dastehen")

        let hinweis = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Kostenlos sind'")
        ).firstMatch
        XCTAssertTrue(hinweis.waitForExistence(timeout: erscheint),
                      "Die Grenze muss dastehen, bevor jemand dagegenläuft")

        hinzu.tap()
        XCTAssertTrue(app.staticTexts["PulseMeter Pro"].waitForExistence(timeout: erscheint),
                      "Die Kaufseite kam nicht")
        // Der Grund steht zuerst: Wer am dritten Zähler hängt, will nicht
        // über PDF-Berichte lesen.
        XCTAssertTrue(app.staticTexts["Unbegrenzt viele Zähler"].exists,
                      "Die Leistung, an der es gerade hakte, fehlt auf der Kaufseite")
        XCTAssertFalse(app.staticTexts["Neuer Zähler"].exists,
                       "Ohne Pro darf sich kein weiteres Formular öffnen")
    }

    /// **Die wichtigste Prüfung dieser Gruppe.** Was schon da ist, bleibt
    /// benutzbar — auch wenn es über der Grenze liegt.
    ///
    /// Die Beispieldaten führen vier Zähler mit Preisen und zwei
    /// Arbeitspreisen. Ein Bestand über der Grenze ist real: über iCloud, über
    /// die Beispieldaten, über einen Kauf auf einem anderen Gerät, der noch
    /// nicht angekommen ist. Nähme die App dem Nutzer dann seine eigenen
    /// Zahlen weg, wäre das ein Vertrauensbruch und kein Verkaufsargument
    /// (Produktprinzip 5).
    func testExistingMetersStayUsableWithoutPro() {
        let app = launchFree()

        // Alle vier Karten stehen, mit Zahlen.
        for name in ["Strom", "Wasser", "Gas", "Wärmepumpe"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: erscheint),
                          "\(name) fehlt — ohne Pro wird nichts weggenommen")
        }

        // Und ablesen geht auch.
        let eintragen = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Stand eintragen'")
        ).firstMatch
        XCTAssertTrue(eintragen.waitForExistence(timeout: erscheint),
                      "Ablesen ist nie Pro — es ist der Zweck der App")
        eintragen.tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")
    }

    /// Der Bericht ist Pro, der Export nicht — und beide stehen untereinander.
    ///
    /// Diese Prüfung ist die Bremse gegen den Tag, an dem jemand den Export
    /// „auch noch" hinter die Schranke zieht. Er ist Produktprinzip 5 und das
    /// stärkste Argument gegen die Angst, die Menschen bei Excel hält.
    func testTheReportIsProAndTheExportNeverIs() {
        let app = launchFree("-pulse-verlauf")

        let bericht = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Verbrauchsbericht'")
        ).firstMatch
        XCTAssertTrue(bericht.waitForExistence(timeout: 15),
                      "Die Berichtszeile fehlt im Verlauf")

        // Der Export steht darüber und ist offen.
        XCTAssertTrue(app.buttons["Ablesungen"].exists || app.buttons["Auswertung"].exists,
                      "Der Export muss ohne Pro erreichbar sein — dauerhaft")

        bericht.tap()
        XCTAssertTrue(app.staticTexts["PulseMeter Pro"].waitForExistence(timeout: erscheint),
                      "Der Bericht muss ohne Pro zur Kaufseite führen")
        XCTAssertTrue(app.staticTexts["Bericht als PDF"].exists,
                      "Die Kaufseite nennt die Leistung nicht, an der es hakte")
    }

    /// Die Kaufseite verspricht nichts, was es noch nicht gibt.
    ///
    /// Foto-Belege und Siri-Kurzbefehle sind aus 1.0 gestrichen
    /// (`docs/07-v1-plan.md`). Ein verkauftes Merkmal, das es nicht gibt, ist
    /// eine Rückerstattung, eine schlechte Bewertung und im Zweifel eine
    /// Ablehnung durch die Prüfung. Der Rechenkern hält das schon fest; hier
    /// wird geprüft, dass auch der fertige Schirm nichts anderes zeigt.
    func testThePurchasePagePromisesOnlyWhatExists() {
        let app = launchFree("-pulse-kaufen")

        XCTAssertTrue(app.staticTexts["PulseMeter Pro"].waitForExistence(timeout: 15),
                      "Die Kaufseite kam nicht")
        for verboten in ["Foto", "Beleg", "Siri", "Kurzbefehl", "Abo"] {
            let treffer = app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", verboten)
            ).firstMatch
            // „Kein Abo" darf dastehen — das Wort allein aber nur so.
            if verboten == "Abo" {
                if treffer.exists {
                    XCTAssertTrue(treffer.label.contains("Kein Abo"),
                                  "Das Wort Abo darf nur in der Zusage stehen, dass es keins ist")
                }
                continue
            }
            XCTAssertFalse(treffer.exists,
                           "\(verboten) steht auf der Kaufseite, kommt aber erst mit 1.1")
        }
    }

    // MARK: - Barrierefreiheit

    /// Auf dem Ziffernblock stand eine Taste, die nichts tat.
    ///
    /// Ein Kamerasymbol als Platzhalter für Belegfotos, für VoiceOver
    /// angekündigt als „Belegfoto" — angetippt passierte nichts. Wer die
    /// Tasten sieht, probiert es einmal und lässt es. Wer sie nur hört, hat
    /// einen Knopf gefunden, der eine Funktion verspricht, die es nicht gibt:
    /// eine Sackgasse mitten im wichtigsten Schirm der App.
    ///
    /// Belegfotos sind für 1.0 gestrichen (`docs/07-v1-plan.md`). Diese
    /// Prüfung hält fest, dass die Taste erst mit ihnen zurückkommt.
    func testTheKeypadHasNoDeadKey() {
        let app = launchWithData()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")

        XCTAssertFalse(app.buttons["Belegfoto"].exists,
                       "Eine Taste, die nichts tut, darf nicht angekündigt werden")
        // Die übrigen Tasten stehen weiter, und zwar alle.
        for key in ["0", "1", "9", "Löschen"] {
            XCTAssertTrue(app.buttons[key].exists, "Die Taste \(key) fehlt")
        }
    }

    /// Das Zählwerk sagt, was es zeigt — auch wenn niemand hinsieht.
    ///
    /// Die Anzeige ist ein Bild aus Rollen, kein Textfeld. Ohne eigene
    /// Beschriftung läse VoiceOver sie als Folge einzelner Ziffern vor, und
    /// „vier, sieben, drei, vier, sieben, null" ist keine Zahl, die sich
    /// jemand merkt.
    func testTheCounterAnnouncesItsValue() {
        let app = launchWithData()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")

        let counter = app.otherElements["Zählerstand"]
        XCTAssertTrue(counter.waitForExistence(timeout: erscheint),
                      "Das Zählwerk trägt keine Beschriftung")

        for digit in ["1", "2", "3"] { app.buttons[digit].tap() }
        let value = counter.value as? String ?? ""
        XCTAssertTrue(value.contains("123"),
                      "Der eingetippte Wert muss sich vorlesen lassen, gelesen wurde: \(value)")
    }
}
