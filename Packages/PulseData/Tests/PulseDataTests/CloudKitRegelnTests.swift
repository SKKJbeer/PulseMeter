#if canImport(CoreData)
import CoreData
import XCTest
@testable import PulseData

/// Das Datenmodell hält die Regeln von CloudKit ein.
///
/// In der CI läuft der Speicher ohne iCloud, und damit würde ein Verstoß dort
/// nie auffallen, sondern erst auf dem Gerät: als iPad, das leer bleibt. Der
/// zweite Test baut absichtlich ein Modell, das jede Regel einmal bricht —
/// eine Prüfung, die nie anschlägt, ist keine.
final class CloudKitRegelnTests: XCTestCase {

    func testTheModelFollowsTheRulesOfCloudKit() throws {
        let verstoesse = PulseStore.cloudKitRegelVerstoesse(in: try PulseStore.cloudKitModell())
        XCTAssertEqual(verstoesse, [],
                       "Das Modell bricht Regeln von CloudKit, der Abgleich zwischen Geräten liefe nicht:\n"
                       + verstoesse.joined(separator: "\n"))
    }

    func testEachRuleIsSeenWhenBroken() {
        let zaehler = NSEntityDescription()
        zaehler.name = "Zaehler"
        let stand = NSEntityDescription()
        stand.name = "Stand"

        // Regel 1: Pflichtfeld ohne Vorgabewert.
        let wert = NSAttributeDescription()
        wert.name = "wert"
        wert.attributeType = .integer64AttributeType
        wert.isOptional = false
        // Ein Feld mit Vorgabewert ist erlaubt und darf nicht gemeldet werden.
        let tag = NSAttributeDescription()
        tag.name = "tag"
        tag.attributeType = .integer64AttributeType
        tag.isOptional = false
        tag.defaultValue = 0
        stand.properties = [wert, tag]

        // Regel 2: Eindeutigkeit.
        let kennung = NSAttributeDescription()
        kennung.name = "kennung"
        kennung.attributeType = .stringAttributeType
        kennung.isOptional = true
        // Regel 3: Pflichtbeziehung ohne Umkehrung, die das Löschen verweigert.
        let staende = NSRelationshipDescription()
        staende.name = "staende"
        staende.destinationEntity = stand
        staende.isOptional = false
        staende.deleteRule = .denyDeleteRule
        zaehler.properties = [kennung, staende]
        zaehler.uniquenessConstraints = [["kennung"]]

        let modell = NSManagedObjectModel()
        modell.entities = [zaehler, stand]

        let verstoesse = PulseStore.cloudKitRegelVerstoesse(in: modell)
        XCTAssertEqual(verstoesse, [
            "Stand.wert: weder optional noch mit Vorgabewert",
            "Zaehler: eindeutige Felder (@Attribute(.unique)) kennt CloudKit nicht",
            "Zaehler.staende: Beziehung muss optional sein",
            "Zaehler.staende: Beziehung ohne Umkehrung",
            "Zaehler.staende: Löschregel „verweigern“ kennt CloudKit nicht"
        ])
    }
}
#endif
