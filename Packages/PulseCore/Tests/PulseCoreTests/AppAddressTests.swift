import XCTest
@testable import PulseCore

/// Eine Adresse, die sich falsch zerlegt, öffnet den falschen Zähler — und das
/// merkt niemand, weil der Ziffernblock trotzdem aufgeht.
final class AppAddressTests: XCTestCase {

    private let strom = UUID(uuidString: "6F1C2A34-0B7E-4D10-9A11-5C3E2B7D8F90")!

    func testWithoutIDOpensTheLongestUnread() {
        let adresse = AppAddress.capture(nil)
        XCTAssertEqual(adresse.url.absoluteString, "zaehlora://erfassen")
        XCTAssertEqual(AppAddress(url: adresse.url), .capture(nil))
    }

    func testWithIDRoundTrips() {
        let adresse = AppAddress.capture(strom)
        XCTAssertEqual(AppAddress(url: adresse.url), .capture(strom))
    }

    func testForeignAddressesOpenNothing() {
        for fremd in ["https://zaehlora.pages.dev/erfassen",
                      "zaehlora://verlauf",
                      "andere://erfassen"] {
            XCTAssertNil(AppAddress(url: URL(string: fremd)!), fremd)
        }
    }

    /// Eine unbekannte Kennung wird hier **nicht** zu „irgendeinem Zähler".
    /// Das entscheidet die App, die weiß, welche es gibt.
    func testMalformedIDOpensNothing() {
        XCTAssertNil(AppAddress(url: URL(string: "zaehlora://erfassen/keine-kennung")!))
        XCTAssertNil(AppAddress(url: URL(string: "zaehlora://erfassen/\(strom.uuidString)/mehr")!))
    }

    func testSchemeAndHostIgnoreCase() {
        XCTAssertEqual(AppAddress(url: URL(string: "ZAEHLORA://Erfassen")!), .capture(nil))
    }

    func testNotificationCarriesItsMeter() {
        let info: [AnyHashable: Any] = [AppAddress.meterKey: strom.uuidString]
        XCTAssertEqual(AppAddress(notificationInfo: info), .capture(strom))
    }

    /// Eine Erinnerung aus einer Fassung vor 1.3 trägt keinen Zähler mit. Sie
    /// soll trotzdem im Ziffernblock ankommen und nicht auf der Übersicht.
    func testOldNotificationStillLandsOnTheKeypad() {
        XCTAssertEqual(AppAddress(notificationInfo: [:]), .capture(nil))
        XCTAssertEqual(AppAddress(notificationInfo: [AppAddress.meterKey: 42]), .capture(nil))
    }
}
