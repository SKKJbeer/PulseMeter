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

    /// Tippt einen Knopf und **prüft nach, dass sich das Blatt geöffnet hat**.
    ///
    /// **Dieselbe Geschichte wie beim Tabwechsel, eine Stufe später.** In
    /// 0.53.0 ist `testAddingAMeterFromTheMetersTab` gefallen, diesmal mit
    /// „Das Namensfeld fehlt" — obwohl der Commit **keine einzige Swift-Zeile**
    /// angefasst hat und dieselbe App eine Stunde vorher grün war. Der Tipp auf
    /// „Zähler hinzufügen" ging verloren, das Blatt kam nie, und danach hätte
    /// auch eine Wartezeit von einer Minute nichts gefunden: Das Feld war nicht
    /// langsam, es war nicht da.
    ///
    /// Für den Tabwechsel steht die Lehre seit 0.36.1 zwölf Zeilen weiter
    /// unten — ein verlorener Tipp braucht einen zweiten Tipp, keine längere
    /// Uhr. Sie galt nur für die Tab-Leiste, weil dort der erste Fehlschlag
    /// war. Hier ist sie verallgemeinert.
    ///
    /// - Parameter anker: Etwas, das es **nur** gibt, wenn das Blatt oben ist.
    ///   Die Navigationsleiste eignet sich; ein Textfeld nicht — das steckt im
    ///   Blatt und ist damit die Aussage, die geprüft werden soll.
    @discardableResult
    private func oeffne(_ knopf: XCUIElement,
                        bis anker: XCUIElement,
                        in app: XCUIApplication,
                        _ was: String,
                        datei: StaticString = #filePath,
                        zeile: UInt = #line) -> Bool {
        guard knopf.waitForExistence(timeout: erscheint) else {
            XCTFail("\(was): der Knopf ist nicht da", file: datei, line: zeile)
            return false
        }
        for versuch in 1...2 {
            knopf.tap()
            if anker.waitForExistence(timeout: erscheint) { return true }
            if versuch == 1 {
                print("\(was): der erste Tipp kam nicht an, zweiter Versuch.")
            }
        }
        XCTFail("\(was): das Blatt öffnet nicht. Zu sehen war: \(beschriftungen(in: app))",
                file: datei, line: zeile)
        return false
    }

    /// Tippt in ein Feld — und wartet, bis das Feld den Fokus wirklich hat.
    ///
    /// **Der siebte Fehlschlag von `testAddingAMeterFromTheMetersTab` hat
    /// endlich gesagt, woran es liegt:**
    ///
    /// ```
    /// Failed to synthesize event: Neither element nor any descendant has
    /// keyboard focus. TextField, placeholderValue: 'Name'
    /// ```
    ///
    /// Das Feld war da, der Tipp kam an — nur der Fokus stand noch nicht, als
    /// `typeText` losschrieb. Sechs Läufe lang stand als Vermutung „der Wechsel
    /// des Tabs hakt", und die offene Rechnung hieß „einen dritten Versuch beim
    /// Wechseln". Beides war falsch: Der Wechsel hat funktioniert, das Blatt
    /// stand offen, und die Meldung kam aus einer ganz anderen Zeile.
    ///
    /// Gewartet wird auf die **Tastatur**, nicht auf das Feld: Sie erscheint
    /// genau dann, wenn der Fokus steht. Kommt sie nicht, wird noch einmal
    /// getippt — mehr Wiederholungen helfen nicht, sondern verlängern nur den
    /// Fehlschlag.
    private func tippe(_ text: String,
                       in feld: XCUIElement,
                       app: XCUIApplication,
                       datei: StaticString = #filePath,
                       zeile: UInt = #line) -> Bool {
        guard feld.waitForExistence(timeout: erscheint) else {
            XCTFail("Das Feld ist nicht da", file: datei, line: zeile)
            return false
        }
        for versuch in 1...2 {
            feld.tap()
            if app.keyboards.element.waitForExistence(timeout: erscheint) {
                feld.typeText(text)
                return true
            }
            if versuch == 1 { print("Der Fokus stand noch nicht, zweiter Versuch.") }
        }
        XCTFail("Das Feld bekommt keinen Fokus — die Tastatur erscheint nicht",
                file: datei, line: zeile)
        return false
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

        // Zähler anlegen. Auch hier über `oeffne`: Es ist derselbe Griff auf
        // dasselbe Blatt, und derselbe Tipp kann verlorengehen.
        guard oeffne(app.buttons["Ersten Zähler anlegen"],
                     bis: app.navigationBars["Neuer Zähler"],
                     in: app,
                     "Ersten Zähler anlegen") else { return }

        let field = app.textFields["Name"]
        guard tippe("Keller", in: field, app: app) else { return }
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
        // Mit Zeilenschaltung: Die Tastatur verdeckt sonst die untere Hälfte
        // des Formulars, und das Preisfeld ist genau dort.
        guard tippe("Strom\n", in: field, app: app) else { return }

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

    /// Der laufende Monat sagt, worauf er voraussichtlich hinausläuft.
    ///
    /// Geprüft wird am Stromzähler und nicht an dem, der beim Öffnen vorn
    /// steht: Gas ist in den Beispieldaten absichtlich drei Monate überfällig,
    /// und an einem überfälligen Zähler gibt es nichts hochzurechnen. Das ist
    /// kein Umweg um den Fehler herum, sondern der Unterschied zwischen „keine
    /// Prognose" und „keine Daten".
    func testTheRunningMonthNamesItsExpectedTotal() {
        let app = launchWithData()
        wechsel(zu: "Verlauf", in: app)
        XCTAssertTrue(app.buttons["Monat"].waitForExistence(timeout: erscheint))

        let strom = app.buttons["Strom"].firstMatch
        XCTAssertTrue(strom.waitForExistence(timeout: erscheint),
                      "Der Stromzähler fehlt in der Auswahl")
        strom.tap()

        // Über die Kennung und nicht über den Text: Die Leiste ist für die
        // Bedienhilfen **ein** Element mit einem Satz als Beschriftung — vier
        // Bruchstücke einzeln vorgelesen ergäben keine Auskunft. Ein Test, der
        // am Wortlaut hängt, geht bei der nächsten Umformulierung kaputt; genau
        // das ist in 0.69.1 passiert, als die Leiste den Satz ersetzt hat.
        let vorschau = app.descendants(matching: .any)["forecast-strip"].firstMatch
        XCTAssertTrue(vorschau.waitForExistence(timeout: erscheint),
                      "Der laufende Monat nennt seinen voraussichtlichen Verbrauch nicht")

        // Produktprinzip 7: Die Zahl ist gerechnet, nicht gemessen, und muss
        // das auch sagen. Und sie muss dazusagen, aus wie vielen Tagen — eine
        // Hochrechnung aus drei Tagen liest sich sonst so fest wie eine
        // Ablesung. Und beide Zahlen müssen benannt sein, sonst weiß niemand,
        // welche feststeht.
        let text = vorschau.label
        XCTAssertTrue(text.contains("≈"),
                      "Der hochgerechneten Zahl fehlt das Ungefähr-Zeichen: \(text)")
        XCTAssertTrue(text.contains("gemessen"),
                      "Das schon Gemessene ist nicht als solches benannt: \(text)")
        XCTAssertTrue(text.contains(" von ") && text.contains("Tagen"),
                      "Die Prognose nennt ihre Tagesgrundlage nicht: \(text)")
    }

    /// Ein Zähler lässt sich anlegen, ohne dass vorher Beispieldaten nötig
    /// wären. Erst damit ist die App für einen echten Nutzer brauchbar —
    /// vorher kam man nur über „Beispieldaten anlegen" zu einem Zähler.
    func testAddingAMeterFromTheMetersTab() {
        let app = launchWithData()
        wechsel(zu: "Zähler", in: app)

        // Der Anker ist die Navigationsleiste des Blatts, nicht das Namensfeld:
        // Das Feld ist die Aussage dieses Tests und darf nicht zugleich die
        // Bedingung sein, unter der noch einmal getippt wird.
        guard oeffne(app.buttons["Zähler hinzufügen"],
                     bis: app.navigationBars["Neuer Zähler"],
                     in: app,
                     "Zähler anlegen") else { return }

        let field = app.textFields["Name"]
        guard tippe("Gartenwasser", in: field, app: app) else { return }

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

    /// Eine erfasste Ablesung lässt sich berichtigen und löschen.
    ///
    /// **Vom Nutzer verlangt:** „ich benötige noch eine Option dass man
    /// historische Zählerstände ändern und löschen kann. dies soll in der Liste
    /// alle Ablesungen möglich sein."
    ///
    /// Geprüft wird der Weg dorthin und die Wirkung: Nach dem Löschen steht
    /// eine Ablesung weniger in der Liste. Die Zahl selbst steht in der
    /// Überschrift der Zeile darüber — „N Einträge".
    func testAReadingCanBeCorrectedAndDeleted() {
        let app = launchWithData()
        guard wechsel(zu: "Verlauf", in: app) else { return }

        let liste = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alle Ablesungen'")
        ).firstMatch
        XCTAssertTrue(liste.waitForExistence(timeout: erscheint),
                      "Die Zeile für alle Ablesungen steht nicht im Verlauf")

        // **Gezählt wird an der Zeile, nicht an den sichtbaren Reihen.** Lauf
        // 222 ist genau daran gefallen: `app.cells.count` gab 19, weil eine
        // Liste nur zeichnet, was auf den Schirm passt — es waren 23. Die Zahl
        // steht in der Zeile darüber, und die stimmt immer.
        guard let vorher = eintraege(in: liste.label) else {
            XCTFail("Die Zeile nennt keine Zahl: \(liste.label)")
            return
        }
        XCTAssertGreaterThan(vorher, 1, "Die Beispieldaten haben zu wenige Ablesungen")

        guard oeffne(liste, bis: app.navigationBars["Ablesungen"], in: app,
                     "Ablesungen öffnen") else { return }

        // Die zweite Zeile, nicht die erste: Die oberste ist die jüngste, und
        // an ihr ließe sich nicht zeigen, dass auch ein alter Stand erreichbar
        // ist — genau darum ging die Bitte.
        app.cells.element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars["Ablesung ändern"].waitForExistence(timeout: erscheint),
                      "Eine Zeile öffnet die Ablesung nicht. Zu sehen war: "
                      + beschriftungen(in: app))

        let loeschen = app.buttons["Diese Ablesung löschen"]
        XCTAssertTrue(loeschen.waitForExistence(timeout: erscheint),
                      "Im Ändern-Schirm fehlt der Weg zum Löschen")
        loeschen.tap()

        // Gefragt wird vorher — eine gelöschte Ablesung ist nicht zurückzuholen.
        //
        // **Innerhalb der Rückfrage suchen, nicht in der ganzen App.** Der Lauf
        // 221 ist genau hier gefallen: „Löschen" heißt auch die Wischgeste an
        // jeder Zeile der Liste dahinter, und `app.buttons["Löschen"]` fand
        // deshalb mehrere. Kein Produktfehler — ein zu weit gefasster Griff.
        let rueckfrage = app.sheets.firstMatch.waitForExistence(timeout: erscheint)
            ? app.sheets.firstMatch
            : app.alerts.firstMatch
        XCTAssertTrue(rueckfrage.waitForExistence(timeout: erscheint),
                      "Gelöscht wird ohne Rückfrage")
        rueckfrage.buttons["Löschen"].tap()

        // Danach ist die Liste zu und der Verlauf neu gerechnet. Die Zeile
        // „Alle Ablesungen" sagt, wie viele es noch sind.
        let danach = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alle Ablesungen'")
        ).firstMatch
        XCTAssertTrue(danach.waitForExistence(timeout: erscheint),
                      "Nach dem Löschen ist der Verlauf nicht wieder da")
        XCTAssertEqual(eintraege(in: danach.label), vorher - 1,
                       "Nach dem Löschen sollten es \(vorher - 1) Einträge sein, "
                       + "die Zeile sagt: \(danach.label)")
    }

    /// Eine Änderung im Verlauf steht sofort auch auf der Übersicht und beim
    /// Zähler.
    ///
    /// **Vom Gerät verlangt:** „stelle sicher dass die Zahlen und Grafiken sich
    /// auch immer aktualisieren wenn neue Zähler eingaben kamen. egal ob einer
    /// aus der historie gelöscht oder geändert wurde oder ein ganz neuer
    /// zählerstand hinzu kommt."
    ///
    /// Bis 0.78.0 lud jeder Schirm nur für sich: in seinem eigenen `onAppear`
    /// und danach nur noch, wenn ein Blatt, das *er* aufgemacht hatte, sich
    /// schloss. Eine im Verlauf gelöschte Ablesung erreichte die Übersicht
    /// deshalb nie — die Karte zeigte einen Stand, den es nicht mehr gab, bis
    /// iOS die Ansicht von sich aus neu baute.
    ///
    /// Geprüft wird am **Stand** und nicht am Jahresverbrauch: Ein Zählwerk
    /// läuft vorwärts, also ist der vorletzte Wert zwangsläufig ein anderer als
    /// der letzte. Beim Jahresverbrauch wäre dasselbe nur wahrscheinlich.
    ///
    /// **Und an Gas, nicht an Strom.** Der erste Anlauf nahm Strom und fiel auf
    /// der CI: „Stand 47.481,68 kWh" vor und nach dem Löschen derselbe. Kein
    /// Produktfehler — Strom hat zwei Zählwerke, Bezug und Einspeisung, die
    /// Ablesungsliste zeigt beide, und die oberste Zeile war die der
    /// Einspeisung. Die Karte nennt den Stand des ersten Zählwerks, und der
    /// war zu Recht unverändert. Zwei Zählwerke gegeneinander gehalten ist
    /// dieselbe Fehlerklasse wie zwei verschiedene Zeiträume: Beide Seiten
    /// müssen dasselbe beschreiben. Gas hat ein Zählwerk, damit fällt der Fall
    /// weg.
    func testDeletingAReadingReachesTheOtherTabs() {
        let app = launchWithData()

        let stand = app.descendants(matching: .any)
            .matching(identifier: "kartenstand-Gas").firstMatch
        XCTAssertTrue(stand.waitForExistence(timeout: erscheint),
                      "Auf der Übersicht steht kein Stand für Gas. Zu sehen war: "
                      + beschriftungen(in: app))
        let standVorher = stand.label

        guard wechsel(zu: "Zähler", in: app) else { return }
        let zeileVorher = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Gas'")
        ).firstMatch
        XCTAssertTrue(zeileVorher.waitForExistence(timeout: erscheint),
                      "Die Zählerliste kennt Gas nicht")
        let zaehlerzeileVorher = zeileVorher.label

        // Löschen — im Verlauf, also in keinem der beiden Schirme oben.
        guard wechsel(zu: "Verlauf", in: app) else { return }
        let gas = app.buttons["Gas"]
        XCTAssertTrue(gas.waitForExistence(timeout: erscheint),
                      "Der Zählerwähler im Verlauf kennt Gas nicht")
        gas.tap()

        let liste = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alle Ablesungen'")
        ).firstMatch
        guard let eintraegeVorher = eintraege(in: liste.label) else {
            XCTFail("Die Zeile nennt keine Zahl: \(liste.label)")
            return
        }
        guard oeffne(liste, bis: app.navigationBars["Ablesungen"], in: app,
                     "Ablesungen öffnen") else { return }

        // Die oberste Zeile ist die jüngste — und bei einem Zähler mit **einem**
        // Zählwerk ist sie zugleich die, die den Stand auf der Karte bestimmt.
        app.cells.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Ablesung ändern"].waitForExistence(timeout: erscheint),
                      "Eine Zeile öffnet die Ablesung nicht")
        app.buttons["Diese Ablesung löschen"].tap()

        let rueckfrage = app.sheets.firstMatch.waitForExistence(timeout: erscheint)
            ? app.sheets.firstMatch
            : app.alerts.firstMatch
        XCTAssertTrue(rueckfrage.waitForExistence(timeout: erscheint),
                      "Gelöscht wird ohne Rückfrage")
        rueckfrage.buttons["Löschen"].tap()

        // **Erst prüfen, dass überhaupt gelöscht wurde.** Sonst spräche der
        // Fehlschlag unten von einer Ansicht, die nicht nachzieht, während in
        // Wahrheit nichts passiert ist — und dann sucht man tagelang an der
        // falschen Stelle.
        let danach = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alle Ablesungen'")
        ).firstMatch
        XCTAssertTrue(danach.waitForExistence(timeout: erscheint),
                      "Nach dem Löschen ist der Verlauf nicht wieder da")
        XCTAssertEqual(eintraege(in: danach.label), eintraegeVorher - 1,
                       "Gelöscht wurde nichts: \(danach.label)")

        // Und jetzt die eigentliche Frage: Wissen die anderen beiden davon?
        guard wechsel(zu: "Übersicht", in: app) else { return }
        let standNachher = app.descendants(matching: .any)
            .matching(identifier: "kartenstand-Gas").firstMatch
        XCTAssertTrue(standNachher.waitForExistence(timeout: erscheint),
                      "Nach dem Löschen steht auf der Übersicht kein Stand mehr")
        XCTAssertNotEqual(standNachher.label, standVorher,
                          "Die Übersicht zeigt weiter den gelöschten Stand: \(standVorher)")

        guard wechsel(zu: "Zähler", in: app) else { return }
        let zeileNachher = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Gas'")
        ).firstMatch
        XCTAssertTrue(zeileNachher.waitForExistence(timeout: erscheint),
                      "Nach dem Löschen fehlt Gas in der Zählerliste")
        XCTAssertNotEqual(zeileNachher.label, zaehlerzeileVorher,
                          "Die Zählerliste zeigt weiter den gelöschten Stand: \(zaehlerzeileVorher)")
    }

    /// Ein neu eingetragener Stand steht sofort auch im Verlauf.
    ///
    /// Die Gegenrichtung zur Prüfung darüber, und der Fall, den der Nutzer
    /// zuerst genannt hat: „ein ganz neuer zählerstand hinzu kommt."
    func testANewReadingReachesTheHistory() {
        let app = launchWithData()

        // **Gas, weil beide Seiten dann denselben Zähler meinen.** Die Zähler
        // stehen alphabetisch: Gas ist der erste, also sowohl der voreingestellte
        // im Verlauf als auch der, dessen „Stand eintragen" auf der Übersicht
        // zuerst kommt. Ohne diese Übereinstimmung prüfte der Test zwei
        // verschiedene Zähler gegeneinander — genau die Fehlerklasse, die in
        // CLAUDE.md steht.
        guard wechsel(zu: "Verlauf", in: app) else { return }
        let gas = app.buttons["Gas"]
        XCTAssertTrue(gas.waitForExistence(timeout: erscheint),
                      "Der Zählerwähler im Verlauf kennt Gas nicht")
        gas.tap()

        let liste = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alle Ablesungen'")
        ).firstMatch
        XCTAssertTrue(liste.waitForExistence(timeout: erscheint),
                      "Die Zeile für alle Ablesungen steht nicht im Verlauf")
        guard let vorher = eintraege(in: liste.label) else {
            XCTFail("Die Zeile nennt keine Zahl: \(liste.label)")
            return
        }

        // Eintragen auf der Übersicht, nicht hier.
        guard wechsel(zu: "Übersicht", in: app) else { return }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["7"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")

        // Über die Vorbelegung wie in `testCapturingAReadingClearsTheNotice`:
        // Sie liefert einen garantiert plausiblen Wert, und um den Wert geht es
        // hier nicht.
        app.buttons["Vom letzten Stand übernehmen"].tap()
        app.buttons["Sichern"].tap()

        // Der Verlauf hat nichts davon mitbekommen — außer über den Datenstand.
        guard wechsel(zu: "Verlauf", in: app) else { return }
        let danach = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alle Ablesungen'")
        ).firstMatch
        XCTAssertTrue(danach.waitForExistence(timeout: erscheint),
                      "Nach dem Eintragen ist der Verlauf nicht wieder da")
        XCTAssertEqual(eintraege(in: danach.label), vorher + 1,
                       "Der neue Stand fehlt im Verlauf: \(danach.label)")
    }

    /// Die Zahl aus „Alle Ablesungen, 23 Einträge".
    ///
    /// Über die Ziffern, nicht über eine feste Stelle: Die Beschriftung ist ein
    /// gesprochener Satz und darf sich ändern, ohne dass eine Prüfung fällt.
    private func eintraege(in label: String) -> Int? {
        let ziffern = label.split(whereSeparator: { !$0.isNumber })
        return ziffern.first.flatMap { Int($0) }
    }

    /// Ein angetippter Monat steht sofort über dem Diagramm.
    ///
    /// **Vom Gerät gemeldet:** „wenn ich hier oben im Monat die Balken anklicke
    /// will ich direkt oben sehen wie viel ich verbraucht habe. gerade wird das
    /// ganze Jahr angezeigt."
    ///
    /// Die Auswahl stand vorher nur im Balken selbst und in der Vergleichskarte
    /// unterhalb des Bildschirmrands. Die große Zahl blieb die Jahressumme.
    func testTappingAMonthPutsThatMonthAboveTheChart() {
        let app = launchWithData()
        guard wechsel(zu: "Verlauf", in: app) else { return }

        // Strom statt des voreingestellten Zählers: Gas ist der absichtlich
        // überfällige, seine Ablesungen enden im Mai — an einem Monat ohne
        // Zahl ließe sich nicht zeigen, dass die Zahl dem Finger folgt.
        let strom = app.buttons["Strom"]
        XCTAssertTrue(strom.waitForExistence(timeout: erscheint),
                      "Der Zählerwähler im Verlauf kennt Strom nicht")
        strom.tap()

        let kopf = app.descendants(matching: .any)
            .matching(identifier: "verlauf-kopfzahl").firstMatch
        XCTAssertTrue(kopf.waitForExistence(timeout: erscheint),
                      "Über dem Diagramm steht keine Zahl")
        XCTAssertFalse(kopf.label.contains("Juli"),
                       "Ohne Auswahl gehört dort die Summe hin, nicht ein Monat")

        let juli = app.descendants(matching: .any)
            .matching(identifier: "periodbar-7").firstMatch
        XCTAssertTrue(juli.waitForExistence(timeout: erscheint),
                      "Der Balken für Juli fehlt")
        juli.tap()

        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "Juli"),
                               evaluatedWith: kopf)],
             timeout: erscheint)

        // Und zurück: Noch einmal antippen hebt die Auswahl auf, dann steht
        // wieder die Summe da. Ohne diesen zweiten Teil wäre nur belegt, dass
        // sich die Zahl einmal ändert — nicht, dass sie der Auswahl folgt.
        juli.tap()
        wait(for: [expectation(for: NSPredicate(format: "NOT (label CONTAINS %@)", "Juli"),
                               evaluatedWith: kopf)],
             timeout: erscheint)
    }

    /// Von der Karte auf der Übersicht in den Verlauf desselben Zählers.
    ///
    /// **Vom Gerät gemeldet:** „wenn man auf der übersichtsseite … beim zähler
    /// irgendwo hinklickt passiert aktuell nichts. nur wenn man auf zähler
    /// eintragen geht."
    ///
    /// Getippt wird auf die große Zahl, nicht auf den Winkel daneben: Sie ist
    /// das, was jemand ansieht, wenn er mehr wissen will, und ein Test, der
    /// nur die eigens gebaute Schaltfläche trifft, beweist nichts über die
    /// Fläche darum herum (Produktprinzip 4).
    func testTappingAMeterCardOpensItsHistory() {
        let app = launchWithData()

        // **Strom, nicht der erste Zähler.** Die Zähler stehen alphabetisch,
        // vorn steht Gas — und genau den zeigt der Verlauf auch von sich aus.
        // An der ersten Karte ließe sich deshalb nicht unterscheiden, ob der
        // Sprung den Zähler mitgenommen hat oder nur den Tab gewechselt.
        let name = app.staticTexts["Strom"]
        XCTAssertTrue(name.waitForExistence(timeout: erscheint),
                      "Die Karte für Strom steht nicht auf der Übersicht")

        // Vierzig Punkt unter der Beschriftung liegt die große Zahl. Der
        // Abstand ist gerechnet, nicht geraten: Auf den Kopf folgen acht Punkt
        // Abstand, die Zeitraumzeile und dann die Zahl.
        let ziel = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: name.frame.midX, dy: name.frame.maxY + 40))
        ziel.tap()

        XCTAssertTrue(app.navigationBars["Verlauf"].waitForExistence(timeout: erscheint),
                      "Ein Tipp auf die Zahl führt nicht in den Verlauf. Zu sehen war: "
                      + beschriftungen(in: app))

        // Und zwar zu **diesem** Zähler. Der Zählerwähler zeigt alle Namen
        // nebeneinander; welcher gilt, sagt seine Auswahlmarke — dieselbe, an
        // der VoiceOver den gewählten Zähler erkennt.
        let gewaehlt = app.buttons["Strom"]
        XCTAssertTrue(gewaehlt.waitForExistence(timeout: erscheint),
                      "Der Zählerwähler im Verlauf kennt Strom nicht")
        XCTAssertTrue(gewaehlt.isSelected,
                      "Der Verlauf steht auf einem anderen Zähler als dem angetippten")
    }

    /// In der Jahresansicht steht das laufende Jahr, keine Summe darüber.
    ///
    /// **Vom Gerät gemeldet:** „auf Jahresbasis wie im Screenshot macht es
    /// keinen Sinn über alle Jahre die Summe. damit fängt ja keiner was an und
    /// daran werden ja keine Analysen gemacht."
    ///
    /// Dort stand „2024 bis 2026, zusammen · unvollständig" über ≈ 1.880 kWh.
    func testTheYearViewShowsTheRunningYearAndNotASumOverAllYears() {
        let app = launchWithData()
        guard wechsel(zu: "Verlauf", in: app) else { return }

        app.buttons["Jahr"].tap()

        let kopf = app.descendants(matching: .any)
            .matching(identifier: "verlauf-kopfzahl").firstMatch
        XCTAssertTrue(kopf.waitForExistence(timeout: erscheint),
                      "Über dem Diagramm steht keine Zahl")

        let jahr = Calendar(identifier: .gregorian).component(.year, from: Date())
        XCTAssertTrue(kopf.label.contains("\(jahr)"),
                      "Die Jahresansicht nennt nicht das laufende Jahr: \(kopf.label)")
        XCTAssertFalse(kopf.label.contains("zusammen"),
                       "Über die Jahre summiert wird nicht mehr: \(kopf.label)")
        XCTAssertFalse(kopf.label.contains("bis"),
                       "Eine Spanne über mehrere Jahre gehört da nicht hin: \(kopf.label)")

        // **Und die Leiste mit Ist und Erwartung steht auch hier.** Vom Gerät
        // verlangt: „immer den Ist darstellen und den Forecast." Bis 0.76.2 war
        // die Hochrechnung in der Jahresansicht ausdrücklich abgeschaltet.
        let leiste = app.descendants(matching: .any)
            .matching(identifier: "forecast-strip").firstMatch
        XCTAssertTrue(leiste.waitForExistence(timeout: erscheint),
                      "In der Jahresansicht fehlt die Leiste mit Ist und Erwartung")
        XCTAssertTrue(leiste.label.contains("gemessen") && leiste.label.contains("voraussichtlich"),
                      "Die Leiste benennt nicht beide Zahlen: \(leiste.label)")
        XCTAssertTrue(leiste.label.contains("\(jahr)"),
                      "Die Leiste spricht nicht vom laufenden Jahr: \(leiste.label)")
    }

    /// Eine Zeile geht überall auf, wo sie aussieht wie eine Zeile.
    ///
    /// **Vom Gerät gemeldet:** „wenn ich bei zähler auf zähler gehe ist da
    /// irgendwie ein hartes delay oder geht erst beim 3. mal tippen."
    ///
    /// Beides stimmte, und beides hatte dieselbe Ursache an zwei Stellen. Der
    /// Knopf war die ganze Zeile breit, aber `.buttonStyle(.plain)` reicht nur
    /// so weit wie das, was er zeichnet — zwischen „Strom" und dem Pfeil
    /// zeichnet er nichts. Wer dort tippt, tippt ins Leere, noch einmal, und
    /// beim dritten Mal trifft er den Namen.
    ///
    /// Deshalb wird hier **nicht** in die Mitte des Elements getippt, wie
    /// `tap()` es täte, sondern auf zwei Siebtel vor den rechten Rand: genau
    /// in die Fläche, die vorher tot war. Ein Test, der die Mitte trifft,
    /// hätte den gemeldeten Fehler nie gesehen.
    func testAMeterRowOpensWhereverItIsTapped() {
        let app = launchWithData()
        guard wechsel(zu: "Zähler", in: app) else { return }

        let zeile = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Strom'")
        ).firstMatch
        XCTAssertTrue(zeile.waitForExistence(timeout: erscheint),
                      "Die Zeile für Strom steht nicht im Zähler-Schirm")

        let begonnen = Date()
        zeile.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()

        // Anker ist „Abbrechen": Die Navigationsleiste des Blatts heißt
        // „Zähler" — genau wie der Schirm darunter — und wäre damit schon vor
        // dem Tipp da.
        let abbrechen = app.buttons["Abbrechen"]
        XCTAssertTrue(abbrechen.waitForExistence(timeout: erscheint),
                      "Ein Tipp neben den Namen öffnet den Zähler nicht — "
                      + "die Zeile ist nur dort antippbar, wo sie zeichnet")

        // Wie beim Startzeit-Test keine Schranke, sondern eine Zahl fürs
        // Protokoll: Sie ergibt einen Verlauf, und ein Verlauf zeigt eine
        // Verschlechterung, die keine einzelne Grenze auf einem ausgelasteten
        // Läufer zuverlässig fände.
        print("MESSUNG Öffnen eines Zählers: "
              + String(format: "%.2f", Date().timeIntervalSince(begonnen)) + " s")

        abbrechen.tap()
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

        // **`MESSUNG` ist kein Zierrat, sondern das Wort, auf das `test.sh`
        // filtert.** Ohne es stand diese Zahl nur in `build/xcodebuild-test.log`
        // und damit im Artefakt — sichtbar erst, wer den Lauf herunterlädt und
        // entpackt. Nachgesehen habe ich es, weil im Protokoll von Lauf 213
        // keine der beiden Zeiten stand; die Konsole zeigt nur, was der Filter
        // durchlässt.
        print("MESSUNG Startzeit bis zur ersten Zahl: \(String(format: "%.2f", elapsed)) s")

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
        // Mit Zeilenschaltung: Sonst steht die Tastatur über dem Formular, und
        // der Schalter weiter unten ist nicht antippbar.
        guard tippe("Nachtspeicher\n", in: field, app: app) else { return }

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

    /// Was gerade auf dem Schirm steht, für die Begründung eines Fehlschlags.
    ///
    /// **Warum das hier steht.** Zwei Prüfungen in 0.40.0 fielen mit „kam
    /// nicht", obwohl beides da war — einmal, weil ein Abschnittstitel durch
    /// `textCase(.uppercase)` als `DAUERHAFT KOSTENLOS` ankommt, einmal, weil
    /// ein Hinweis mit `accessibilityElement(children: .ignore)` als **Knopf**
    /// und nicht als Text erscheint. Beide Male hätte die Meldung die Antwort
    /// enthalten können und tat es nicht. Die Lehre aus `docs/08-baukasten.md`:
    /// nach dem zweiten Fehlversuch nicht raten, sondern die Ansicht ihre
    /// eigenen Beschriftungen berichten lassen.
    private func beschriftungen(in app: XCUIApplication, limit: Int = 40) -> String {
        let texte = app.staticTexts.allElementsBoundByIndex.prefix(limit).map { "T:\($0.label)" }
        let knoepfe = app.buttons.allElementsBoundByIndex.prefix(limit).map { "K:\($0.label)" }
        return (texte + knoepfe).joined(separator: " · ")
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
        // **Das Kaufblatt zeigt genau die eine Sache**, an der es hakte — seit
        // 0.40.0 wird einzeln freigeschaltet, und ein Regal mit allen
        // Produkten wäre an dieser Stelle eine Zumutung.
        XCTAssertTrue(app.staticTexts["Unbegrenzt viele Zähler"].waitForExistence(timeout: erscheint),
                      "Das Kaufblatt für den dritten Zähler kam nicht")
        XCTAssertTrue(app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Unbegrenzt viele Zähler freischalten'")
        ).firstMatch.exists, "Auf dem Kaufblatt fehlt der Knopf mit dem Preis")
        XCTAssertFalse(app.staticTexts["Neuer Zähler"].exists,
                       "Ohne Freischaltung darf sich kein weiteres Formular öffnen")
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

    /// **Der Bericht ist nie gesperrt, und der Export nie käuflich.**
    ///
    /// Seit 0.40.0 lässt sich der Bericht immer öffnen; ungekauft trägt er ein
    /// Wasserzeichen. Diese Prüfung hält beides fest — dass das Dokument
    /// zugänglich bleibt und dass der Export daneben offen ist. Der freie
    /// Export ist Produktprinzip 5 und das stärkste Argument gegen die Angst,
    /// die Menschen bei Excel hält; er stand am 11. August ausdrücklich zur
    /// Entscheidung und wurde bewusst nicht verkauft.
    func testTheReportIsWatermarkedAndTheExportNeverCosts() {
        let app = launchFree("-pulse-verlauf")

        let bericht = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Verbrauchsbericht'")
        ).firstMatch
        XCTAssertTrue(bericht.waitForExistence(timeout: 15),
                      "Die Berichtszeile fehlt im Verlauf")

        // Der Export steht darüber und ist offen — dauerhaft und ohne Kauf.
        //
        // **Seit 0.61.0 ist es ein Knopf mit Auswahl**, nicht mehr zwei Kacheln
        // „Ablesungen" und „Auswertung". Geprüft wird deshalb der Zugang, nicht
        // die Einträge dahinter: Was im Menü steht, entscheidet iOS in einem
        // eigenen Fenster, und eine Prüfung, die es aufklappt, prüft dann die
        // Menüdarstellung von iOS statt unsere App.
        XCTAssertTrue(app.buttons["Herunterladen"].exists,
                      "Der Export muss ohne Kauf erreichbar sein — dauerhaft")

        bericht.tap()

        // **Der Bericht entsteht erst auf Tippen.** Die erste Fassung dieser
        // Prüfung hielt sich an `staticTexts["Verbrauchsbericht"]` — das ist
        // aber schon der Titel der Navigationsleiste und steht da, bevor
        // irgendetwas aufgebaut ist. Die Zusicherung war damit erfüllt, ohne
        // etwas zu prüfen, und der Hinweis fehlte anschließend zu Recht: Ohne
        // Vorschau gibt es ihn nicht.
        XCTAssertTrue(app.staticTexts["Laufendes Jahr"].waitForExistence(timeout: erscheint),
                      "Der Bericht muss sich auch ohne Kauf öffnen lassen")
        app.buttons["Bericht erstellen"].tap()
        XCTAssertTrue(app.staticTexts["Zusammenfassung"].waitForExistence(timeout: 15),
                      "Das Dokument wurde ohne Kauf nicht aufgebaut — der Bericht ist nie gesperrt")

        // **Als Knopf, nicht als Text.** Der Hinweis fasst sich für VoiceOver
        // zu einem Element zusammen (`accessibilityElement(children: .ignore)`)
        // und führt angetippt zur Freischaltung. Über `staticTexts` ist er
        // deshalb nicht zu finden, obwohl er sichtbar dasteht.
        let hinweis = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Wasserzeichen'")
        ).firstMatch
        XCTAssertTrue(hinweis.waitForExistence(timeout: erscheint),
                      "Der Hinweis aufs Wasserzeichen fehlt — dann entdeckt es der Nutzer erst beim Teilen. Auf dem Schirm steht: \(beschriftungen(in: app))")
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

        // **Ohne Rücksicht auf Groß- und Kleinschreibung.** Abschnittstitel
        // tragen `pulseSectionLabel()` und damit `textCase(.uppercase)`; auf
        // dem Schirm — und für XCUITest — heißt der Absatz deshalb
        // `DAUERHAFT KOSTENLOS`. Eine Prüfung, die den Text so verlangt, wie er
        // im Quelltext steht, prüft die Gestaltung mit und fällt beim nächsten
        // Feinschliff wieder.
        let kostenlos = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'Dauerhaft kostenlos'")
        ).firstMatch
        XCTAssertTrue(kostenlos.waitForExistence(timeout: 15),
                      "Das Kaufblatt kam nicht. Auf dem Schirm steht: \(beschriftungen(in: app))")
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

        // **Nur die Ziffern vergleichen.** Vorgelesen wird „12 Komma 3" oder
        // „0 Komma 123", je nachdem, wie viele Nachkommastellen das Zählwerk
        // führt — und das ist je Art verschieden. Eine Prüfung, die auf „123"
        // in einer Zeichenkette besteht, prüft in Wahrheit die
        // Nachkommastellen des zuerst gefundenen Zählers und fällt, sobald
        // sich daran etwas ändert. Genau das stand hier bis 0.46.0.
        let ziffern = value.filter(\.isNumber)
        XCTAssertTrue(ziffern.hasSuffix("123"),
                      "Der eingetippte Wert muss sich vorlesen lassen, gelesen wurde: \(value)")
        XCTAssertTrue(value.contains("Komma") || ziffern == "123",
                      "Ein Zählwerk mit Nachkommastellen muss das Komma auch aussprechen: \(value)")
    }

    /// Die Zahl läuft von rechts ein, und die Stellen bleiben, wo sie sind.
    ///
    /// Seit 0.46.0 steht im Zählwerk eine Zahl statt sechs Walzen — der
    /// Gründer hat zwischen drei Entwürfen gewählt
    /// (`docs/entwuerfe/zaehlereingabe.html`). Der teuerste Fehler, den diese
    /// Ansicht machen kann, ist eine Zahl, die um eine Stelle verrutscht:
    /// Aus 41.312,74 würde 4.131,27, und das fiele erst bei der Abrechnung
    /// auf. Hier wird deshalb geprüft, dass die zuletzt getippte Ziffer
    /// hinten landet und die Zahl mit jedem Anschlag nach links wächst.
    func testTheCounterFillsFromTheRight() {
        let app = launchWithData()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stand eintragen'"))
            .firstMatch.tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: erscheint),
                      "Der Ziffernblock erschien nicht")

        let counter = app.otherElements["Zählerstand"]
        XCTAssertTrue(counter.waitForExistence(timeout: erscheint))

        var gesehen: [String] = []
        for digit in ["4", "1", "3", "1", "2", "7", "4"] {
            app.buttons[digit].tap()
            gesehen.append((counter.value as? String ?? "").filter(\.isNumber))
        }

        XCTAssertTrue(gesehen.last?.hasSuffix("4131274") == true,
                      "Zuletzt muss 4131274 dastehen, gelesen wurde: \(gesehen.last ?? "—")")
        // Jeder Anschlag macht die Zahl um höchstens eine Stelle länger und nie
        // kürzer. Sprünge dazwischen wären ein Zeichen dafür, dass die
        // Auffüllung von links her rechnet.
        for (vorher, nachher) in zip(gesehen, gesehen.dropFirst()) {
            XCTAssertTrue(nachher.count >= vorher.count,
                          "Die Zahl wurde beim Tippen kürzer: \(vorher) → \(nachher)")
        }
    }

    /// Am Preisfeld muss stehen, dass brutto gemeint ist.
    ///
    /// **Der Fehler, den die App nicht bemerken kann.** Der Rechenkern erwartet
    /// Bruttopreise; auf einer deutschen Rechnung steht der Nettopreis oft
    /// größer und weiter oben. Wer ihn abschreibt, bekommt dauerhaft rund ein
    /// Fünftel zu niedrige Kosten — nachgerechnet 163 € bei 3000 kWh —, und aus
    /// einer Zahl allein lässt sich nicht erkennen, ob Steuer darin steckt.
    /// Also muss es am Feld stehen, bevor jemand tippt.
    func testThePriceFieldSaysItWantsGrossPrices() {
        let app = launchEmpty()

        XCTAssertTrue(app.buttons["Ersten Zähler anlegen"].waitForExistence(timeout: erscheint))
        app.buttons["Ersten Zähler anlegen"].tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: erscheint))
        field.tap()
        field.typeText("Strom\n")

        // Das Feld trägt die Angabe in seiner Beschriftung — dort, wo VoiceOver
        // sie beim Betreten vorliest.
        let preisfeld = app.textFields.containing(
            NSPredicate(format: "label CONTAINS 'Arbeitspreis' AND label CONTAINS 'brutto'")
        ).firstMatch
        XCTAssertTrue(scroll(to: preisfeld, in: app),
                      "Am Arbeitspreis fehlt der Hinweis, dass brutto gemeint ist")

        let grundpreis = app.textFields.containing(
            NSPredicate(format: "label CONTAINS 'Grundpreis' AND label CONTAINS 'brutto'")
        ).firstMatch
        XCTAssertTrue(grundpreis.exists, "Am Grundpreis fehlt derselbe Hinweis")
    }
}
