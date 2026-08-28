import XCTest
@testable import PulseCore

/// Die Grenze zwischen Kostenlos und Gekauft.
///
/// Seit 0.40.0 wird **einzeln** freigeschaltet: vier Stücke zu ein paar Euro
/// und ein Bündel. Diese Prüfungen sind die Beschreibung des Modells — eine
/// Grenze, die nur in einem Dokument steht, verrutscht beim ersten Umbau.
final class AccessPolicyTests: XCTestCase {

    private let nothing = AccessPolicy(.none)
    private let all = AccessPolicy(.everything)

    // MARK: - Zähler

    func testFreeAllowsExactlyTwoMeters() {
        XCTAssertTrue(nothing.canAddMeter(existingCount: 0), "Der erste Zähler ist kostenlos")
        XCTAssertTrue(nothing.canAddMeter(existingCount: 1), "Der zweite auch")
        XCTAssertFalse(nothing.canAddMeter(existingCount: 2), "Der dritte ist die Grenze")
    }

    /// Wer nur die Zähler freischaltet, bekommt die Zähler — und sonst nichts.
    /// Das ist der ganze Sinn der Einzelkäufe.
    func testBuyingOneThingUnlocksOnlyThatThing() {
        let policy = AccessPolicy(Entitlement([.additionalMeters]))
        XCTAssertTrue(policy.canAddMeter(existingCount: 9))
        XCTAssertFalse(policy.allows(.costsAndTariffs))
        XCTAssertFalse(policy.allows(.pdfReport))
        XCTAssertFalse(policy.allows(.multipleRegisters))
    }

    /// Das Bündel schaltet alles frei, ohne dass die einzelnen Kennungen im
    /// Bestand liegen müssen. Sonst müsste jeder Kauf des Bündels vier
    /// Einträge schreiben — und ein vergessener wäre ein bezahltes, aber
    /// gesperrtes Merkmal.
    func testTheBundleUnlocksEverythingWithoutListingIt() {
        let policy = AccessPolicy(Entitlement([.everything]))
        for product in ProductID.individually {
            XCTAssertTrue(policy.allows(product), "\(product) muss im Bündel enthalten sein")
        }
        XCTAssertTrue(policy.canAddMeter(existingCount: 99))
        XCTAssertFalse(policy.reportIsWatermarked)
    }

    func testRemainingCountsDown() {
        XCTAssertEqual(nothing.remainingMeters(existingCount: 0), 2)
        XCTAssertEqual(nothing.remainingMeters(existingCount: 1), 1)
        XCTAssertEqual(nothing.remainingMeters(existingCount: 2), 0)
        XCTAssertNil(all.remainingMeters(existingCount: 7),
                     "Ohne Grenze gibt es keinen Rest, der sich nennen ließe")
    }

    /// Ein Bestand über der Grenze ist möglich — über die Beispieldaten und
    /// über iCloud. „Noch −1 frei" wäre dann keine Auskunft, sondern ein
    /// Fehler auf dem Schirm.
    func testRemainingNeverGoesNegative() {
        XCTAssertEqual(nothing.remainingMeters(existingCount: 4), 0)
        XCTAssertEqual(nothing.remainingMeters(existingCount: 99), 0)
    }

    // MARK: - Die Regel, auf die es ankommt

    /// **Was schon da ist, bleibt.** Die Grenze greift beim Anlegen, nie beim
    /// Benutzen. Andernfalls nähme ein Wechsel des Kaufzustands dem Nutzer
    /// seine eigenen Zahlen weg — Produktprinzip 5.
    func testExistingDataStaysUsableBeyondTheLimit() {
        XCTAssertTrue(nothing.canUse(existingMeterCount: 4))
        XCTAssertTrue(nothing.canUse(existingMeterCount: 99))
        XCTAssertFalse(nothing.canAddMeter(existingCount: 4),
                       "Benutzen ja, einen weiteren anlegen nein")
    }

    /// **Der Bericht ist nie gesperrt.** Ungekauft trägt er ein Wasserzeichen;
    /// ansehen, blättern und drucken lässt er sich immer. Das ist ehrlicher
    /// als eine Sperre — man sieht vorher, was man bekommt.
    func testTheReportIsWatermarkedButNeverLocked() {
        XCTAssertTrue(nothing.reportIsWatermarked)
        XCTAssertFalse(AccessPolicy(Entitlement([.pdfReport])).reportIsWatermarked)
        XCTAssertFalse(all.reportIsWatermarked)
    }

    // MARK: - Der Export

    /// Der Export steht in **keinem** Produkt. Diese Prüfung ist die Bremse
    /// gegen den Tag, an dem jemand ihn „auch noch" verkauft: Er ist
    /// Produktprinzip 5 und das stärkste Argument gegen die Angst, die
    /// Menschen bei Excel hält.
    ///
    /// Die Frage stand am 11. August ausdrücklich zur Entscheidung — drei Euro
    /// für den CSV-Export — und wurde bewusst verneint.
    func testExportIsNeverForSale() {
        for product in ProductID.allCases {
            let text = (product.rawValue + product.title + product.explanation).lowercased()
            XCTAssertFalse(text.contains("export"), "Der CSV-Export bleibt dauerhaft kostenlos")
            XCTAssertFalse(text.contains("csv"), "Der CSV-Export bleibt dauerhaft kostenlos")
            XCTAssertFalse(text.contains("tabelle"), "Der CSV-Export bleibt dauerhaft kostenlos")
        }
    }

    /// Und die Ablesungen selbst sind ebenfalls unverkäuflich — weder Anzahl
    /// noch Historie.
    func testReadingsAndHistoryAreNeverForSale() {
        for product in ProductID.allCases {
            let text = (product.rawValue + product.title).lowercased()
            XCTAssertFalse(text.contains("ablesung"))
            XCTAssertFalse(text.contains("historie"))
            XCTAssertFalse(text.contains("reading"))
        }
    }

    // MARK: - Preise und Kennungen

    /// Das Bündel muss billiger sein als die Summe, sonst ist es keins.
    func testTheBundleIsCheaperThanBuyingEverythingSeparately() {
        let einzeln = ProductID.individually.reduce(Decimal(0)) { $0 + $1.suggestedPrice }
        XCTAssertGreaterThan(approx(einzeln), approx(ProductID.everything.suggestedPrice),
                             "Ein Bündel, das nicht spart, kauft niemand")
        // Und zwar spürbar. Gerechnet: 2,99 + 2,99 + 3,99 + 2,99 = 12,96 €
        // einzeln gegen 9,99 € im Bündel — knapp **23 %**. Die Schranke steht
        // bei 20 %, nicht bei 25: Die Preise hat der Gründer gesetzt, und eine
        // Prüfung, die seine Entscheidung überstimmt, ist keine Prüfung,
        // sondern eine Meinung.
        let ersparnis = 1 - approx(ProductID.everything.suggestedPrice) / approx(einzeln)
        XCTAssertGreaterThan(ersparnis, 0.20)
        XCTAssertLessThan(ersparnis, 0.60, "Ein zu billiges Bündel entwertet die Einzelkäufe")
    }

    /// Jedes Stück kostet ein paar Euro, keines mehr.
    ///
    /// Der Grund für die Umstellung: Ein einzelner Kauf über fünfzehn Euro ist
    /// eine Entscheidung, die man vertagt. Drei Euro sind ein Tipp.
    func testEveryPieceCostsAFewEuros() {
        for product in ProductID.individually {
            XCTAssertGreaterThan(approx(product.suggestedPrice), 0.99)
            XCTAssertLessThan(approx(product.suggestedPrice), 5,
                              "\(product) ist kein kleiner Kauf mehr")
        }
    }

    /// **Stichpunkte, keine Absätze.** Vom Gründer verlangt: „nicht so viel
    /// Fließtext, sondern einfach nur die klaren Stichpunkte, was alles
    /// enthalten ist."
    ///
    /// Die Prüfung hält die Form, nicht den Wortlaut: höchstens drei Zeilen,
    /// jede kurz genug für eine Zeile auf einem Telefon, und keine, die mit
    /// einem Punkt endet — eine Aufzählung ist kein Satz.
    func testEveryProductListsWhatItContainsInShortLines() {
        for product in ProductID.allCases {
            let zeilen = product.includes
            XCTAssertFalse(zeilen.isEmpty, "\(product) sagt nicht, was enthalten ist")
            XCTAssertLessThanOrEqual(zeilen.count, 4,
                                     "\(product) zählt mehr auf, als jemand überfliegt")
            for zeile in zeilen {
                XCTAssertFalse(zeile.isEmpty)
                XCTAssertLessThanOrEqual(zeile.count, 52,
                                         "Zu lang für eine Zeile: \(zeile)")
                XCTAssertFalse(zeile.hasSuffix("."), "Kein Satzpunkt in einer Liste: \(zeile)")
            }
        }
    }

    /// Das Bündel nennt genau die vier Stücke, die es ersetzt.
    ///
    /// Sonst steht dort eine Liste, die nicht mit dem übereinstimmt, was
    /// gekauft wird — und das merkt jemand erst nach dem Kauf.
    func testTheBundleListsExactlyTheFourPiecesItReplaces() {
        XCTAssertEqual(ProductID.everything.includes,
                       ProductID.individually.map(\.title))
    }

    /// Was kostenlos bleibt, wird genannt — sonst bemerkt es niemand.
    ///
    /// Der Abgleich zwischen Geräten läuft von selbst und kostet nichts; er
    /// stand deshalb nirgends. Der Export ist Produktprinzip 5 und das
    /// stärkste Argument gegen die Angst, später nicht mehr an die eigenen
    /// Zahlen zu kommen.
    func testTheFreeListNamesSyncAndExport() {
        let frei = ProductID.alwaysFree.joined(separator: " ")
        XCTAssertTrue(frei.contains("iCloud"), "Der Abgleich gehört genannt")
        XCTAssertTrue(frei.contains("Export"), "Der freie Export ist Produktprinzip 5")
        XCTAssertFalse(ProductID.alwaysFree.contains { $0.count > 60 })
    }

    /// **Die Kennungen im Store dürfen sich nie ändern.** Ein umbenanntes
    /// Produkt ist für jeden, der es gekauft hat, ein verlorener Kauf — und
    /// eine Erstattung mit schlechter Bewertung obendrauf.
    func testStoreIdentifiersAreStableAndUnique() {
        var seen: Set<String> = []
        for product in ProductID.allCases {
            XCTAssertTrue(product.storeIdentifier.hasPrefix("de.karjoth.pulsemeter."))
            XCTAssertTrue(seen.insert(product.storeIdentifier).inserted,
                          "Zwei Produkte mit derselben Kennung")
        }
        XCTAssertEqual(ProductID.pdfReport.storeIdentifier, "de.karjoth.pulsemeter.pdfreport")
        XCTAssertEqual(ProductID.everything.storeIdentifier, "de.karjoth.pulsemeter.everything")
    }

    // MARK: - Sprache

    /// Jede Leistung braucht Worte, die auf der Kaufseite stehen können — und
    /// keine, die aus dem Datenmodell stammen (Produktprinzip 6).
    func testEveryProductSpeaksGerman() {
        let forbidden = ["Messstelle", "Zählwerk", "Register", "OBIS", "Entität",
                         "Datensatz", "Synchronisation"]
        for product in ProductID.allCases {
            XCTAssertFalse(product.title.isEmpty)
            XCTAssertFalse(product.explanation.isEmpty)
            XCTAssertNotEqual(product.title, product.rawValue,
                              "Der Bezeichner ist keine Beschriftung")
            for word in forbidden {
                XCTAssertFalse(product.title.contains(word), "\(word) gehört nicht auf den Schirm")
                XCTAssertFalse(product.explanation.contains(word), "\(word) gehört nicht auf den Schirm")
            }
        }
    }

    /// Zum Verkaufsstart gestrichen und deshalb auch nicht zu bewerben:
    /// Foto-Belege und Siri-Kurzbefehle kommen erst mit 1.1
    /// (docs/07-v1-plan.md).
    func testNothingIsPromisedThatDoesNotExistYet() {
        for product in ProductID.allCases {
            let text = product.title + " " + product.explanation
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Foto"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Beleg"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Siri"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Kurzbefehl"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Abo"),
                           "Ein Abo kommt erst für Vermieter und wird hier nicht angedeutet")
        }
    }

    // MARK: - Speicherform

    /// Der Bestand wird gesichert und wieder gelesen. Ein umbenannter Fall
    /// wäre ein stiller Verlust bei jedem, der schon gekauft hat.
    func testEntitlementSurvivesStorage() {
        let bestand = Entitlement([.pdfReport, .additionalMeters])
        let zurueck = Entitlement(storageValue: bestand.storageValue)
        XCTAssertEqual(zurueck, bestand)
        XCTAssertTrue(zurueck.owns(.pdfReport))
        XCTAssertFalse(zurueck.owns(.costsAndTariffs))
    }

    /// Die Zeichenkette ist sortiert — sonst ergäbe derselbe Bestand mal die
    /// eine und mal die andere Form, und man sähe nicht, ob sich etwas
    /// geändert hat.
    func testStorageValueIsStable() {
        XCTAssertEqual(Entitlement([.pdfReport, .additionalMeters]).storageValue,
                       Entitlement([.additionalMeters, .pdfReport]).storageValue)
    }

    /// **Ein unbekannter Eintrag darf nicht den ganzen Bestand kosten.** Wer
    /// mit einer neueren Fassung etwas gekauft hat und die ältere startet,
    /// behält den Rest.
    func testUnknownEntriesAreSkippedNotFatal() {
        let bestand = Entitlement(storageValue: "pdfReport,zukunftsprodukt,additionalMeters")
        XCTAssertTrue(bestand.owns(.pdfReport))
        XCTAssertTrue(bestand.owns(.additionalMeters))
        XCTAssertEqual(bestand.owned.count, 2)
    }

    func testNothingOwnedIsTheStartingPoint() {
        XCTAssertFalse(Entitlement.none.ownsAnything)
        XCTAssertEqual(Entitlement(storageValue: "").owned, [])
    }
}
