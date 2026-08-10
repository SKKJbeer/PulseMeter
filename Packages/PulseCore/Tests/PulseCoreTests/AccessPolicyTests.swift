import XCTest
@testable import PulseCore

/// Die Grenze zwischen Kostenlos und Pro.
///
/// Sie hat bis 0.35.0 nur in `docs/04-monetarisierung.md` gestanden; in der App
/// war alles kostenlos. Weil eine Grenze, die nur beschrieben ist, beim ersten
/// Umbau verrutscht, steht sie jetzt an einer Stelle im Rechenkern — und diese
/// Prüfungen sind die Beschreibung.
final class AccessPolicyTests: XCTestCase {

    private let free = AccessPolicy(.free)
    private let pro = AccessPolicy(.pro)

    // MARK: - Zähler

    func testFreeAllowsExactlyTwoMeters() {
        XCTAssertTrue(free.canAddMeter(existingCount: 0), "Der erste Zähler ist kostenlos")
        XCTAssertTrue(free.canAddMeter(existingCount: 1), "Der zweite auch")
        XCTAssertFalse(free.canAddMeter(existingCount: 2), "Der dritte ist die Grenze")
    }

    func testProHasNoMeterLimit() {
        XCTAssertTrue(pro.canAddMeter(existingCount: 2))
        XCTAssertTrue(pro.canAddMeter(existingCount: 50))
        XCTAssertNil(pro.remainingMeters(existingCount: 7),
                     "Ohne Grenze gibt es keinen Rest, der sich nennen ließe")
    }

    func testRemainingCountsDown() {
        XCTAssertEqual(free.remainingMeters(existingCount: 0), 2)
        XCTAssertEqual(free.remainingMeters(existingCount: 1), 1)
        XCTAssertEqual(free.remainingMeters(existingCount: 2), 0)
    }

    /// Ein Bestand über der Grenze ist möglich — über die Beispieldaten und
    /// über einen Bestand, der aus iCloud zurückkommt. „Noch −1 frei" wäre
    /// dann keine Auskunft, sondern ein Fehler auf dem Schirm.
    func testRemainingNeverGoesNegative() {
        XCTAssertEqual(free.remainingMeters(existingCount: 4), 0)
        XCTAssertEqual(free.remainingMeters(existingCount: 99), 0)
    }

    // MARK: - Die Regel, auf die es ankommt

    /// **Was schon da ist, bleibt.** Die Grenze greift beim Anlegen, nie beim
    /// Benutzen. Andernfalls nähme ein Wechsel des Kaufzustands dem Nutzer
    /// seine eigenen Zahlen weg — Produktprinzip 5.
    func testExistingDataStaysUsableBeyondTheLimit() {
        XCTAssertTrue(free.canUse(existingMeterCount: 4))
        XCTAssertTrue(free.canUse(existingMeterCount: 99))
        XCTAssertFalse(free.canAddMeter(existingCount: 4),
                       "Benutzen ja, einen weiteren anlegen nein")
    }

    // MARK: - Leistungen

    func testFreeAllowsNoProFeature() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(free.allows(feature), "\(feature) darf kostenlos nicht offenstehen")
        }
    }

    func testProAllowsEveryFeature() {
        for feature in ProFeature.allCases {
            XCTAssertTrue(pro.allows(feature))
        }
    }

    /// Der Export steht bewusst **nicht** in der Aufzählung. Diese Prüfung ist
    /// die Bremse gegen den Tag, an dem jemand ihn „auch noch" zu Pro nimmt:
    /// Er ist Produktprinzip 5 und das stärkste Argument gegen die Angst, die
    /// Menschen bei Excel hält.
    func testExportIsNeverAProFeature() {
        let names = ProFeature.allCases.map { $0.rawValue.lowercased() }
        for name in names {
            XCTAssertFalse(name.contains("export"),
                           "Der CSV-Export bleibt dauerhaft kostenlos")
            XCTAssertFalse(name.contains("reading"),
                           "Ablesungen und Historie bleiben unbegrenzt")
        }
    }

    /// Jede Leistung braucht Worte, die auf der Kaufseite stehen können — und
    /// keine, die aus dem Datenmodell stammen (Produktprinzip 6).
    func testEveryFeatureSpeaksGerman() {
        let forbidden = ["Messstelle", "Zählwerk", "Register", "OBIS", "Entität",
                         "Datensatz", "Synchronisation"]
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty)
            XCTAssertFalse(feature.explanation.isEmpty)
            XCTAssertNotEqual(feature.title, feature.rawValue,
                              "Der Bezeichner ist keine Beschriftung")
            for word in forbidden {
                XCTAssertFalse(feature.title.contains(word), "\(word) gehört nicht auf den Schirm")
                XCTAssertFalse(feature.explanation.contains(word), "\(word) gehört nicht auf den Schirm")
            }
        }
    }

    /// Zum Verkaufsstart gestrichen und deshalb auch nicht zu bewerben:
    /// Foto-Belege und Siri-Kurzbefehle kommen erst mit 1.1
    /// (docs/07-v1-plan.md). Ein verkauftes Merkmal, das es nicht gibt, ist
    /// eine Rückerstattung und eine schlechte Bewertung.
    func testNothingIsPromisedThatDoesNotExistYet() {
        for feature in ProFeature.allCases {
            let text = feature.title + " " + feature.explanation
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Foto"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Beleg"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Siri"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Kurzbefehl"))
        }
    }

    // MARK: - Speicherform

    /// Der Kaufzustand wird gesichert und wieder gelesen. Ein umbenannter Fall
    /// wäre ein stiller Rückfall auf „kostenlos" bei jedem, der schon gekauft
    /// hat.
    func testEntitlementSurvivesStorage() {
        for entitlement in Entitlement.allCases {
            XCTAssertEqual(Entitlement(rawValue: entitlement.rawValue), entitlement)
        }
        XCTAssertEqual(Entitlement.pro.rawValue, "pro")
        XCTAssertEqual(Entitlement.free.rawValue, "free")
    }
}
