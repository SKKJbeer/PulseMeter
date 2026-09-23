import Foundation

/// Die Adressen, unter denen die App von außen an eine Stelle springt.
///
/// **Warum es das gibt.** Bis 1.2 führte kein Eingang zu einem bestimmten
/// Zähler. Die Erinnerung „Strom — Zeit für eine Ablesung" öffnete die App dort,
/// wo sie zuletzt stand, das Feld auf dem Sperrbildschirm ebenso. Wer darauf
/// tippte, musste den Zähler danach noch einmal suchen — ausgerechnet in dem
/// Moment, in dem er am Zähler steht und eine Hand frei hat.
///
/// **Warum hier und nicht in der App.** Dieselbe Adresse schreibt das Widget und
/// liest die App. Zwei Ziele, zwei Stellen, an denen `zaehlora://erfassen`
/// stünde, und die laufen auseinander. Hier steht sie einmal, und der Teil, der
/// eine Adresse zerlegt, ist ohne Xcode prüfbar.
///
/// **Warum der Ziffernblock und nie die Eingabe selbst.** Geplant war einmal, die
/// Zahl direkt in die Mitteilung zu tippen. Das umginge die Rückfrage, die die
/// App vor dem Sichern stellt, wenn ein Wert unter dem letzten Stand oder weit
/// über dem Üblichen liegt. Jeder Eingang endet deshalb im selben Ziffernblock.
public enum AppAddress: Equatable, Sendable {

    /// Den Ziffernblock öffnen.
    ///
    /// Mit Kennung für genau diesen Zähler — so kommt die Erinnerung an. Ohne
    /// Kennung für den, der am längsten nicht abgelesen wurde — so kommt das
    /// Widget an, das den Stand aller Zähler zusammenfasst und keinen einzelnen
    /// kennt.
    case capture(UUID?)

    public static let scheme = "zaehlora"

    /// Der Schlüssel, unter dem eine Mitteilung ihren Zähler mitträgt.
    public static let meterKey = "zaehler"

    public var url: URL {
        switch self {
        case .capture(nil):
            return URL(string: "\(Self.scheme)://erfassen")!
        case .capture(let id?):
            return URL(string: "\(Self.scheme)://erfassen/\(id.uuidString)")!
        }
    }

    /// Zerlegt eine Adresse, oder `nil`, wenn sie nicht von uns ist.
    ///
    /// **Eine fremde oder verstümmelte Adresse öffnet nichts.** Eine unbekannte
    /// Kennung wird nicht stillschweigend zu „irgendeinem Zähler" — das
    /// entscheidet die App, die weiß, welche Zähler es gibt. Hier wird nur
    /// gelesen, was dasteht.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              url.host?.lowercased() == "erfassen" else { return nil }
        let teile = url.pathComponents.filter { $0 != "/" }
        switch teile.count {
        case 0:
            self = .capture(nil)
        case 1:
            guard let id = UUID(uuidString: teile[0]) else { return nil }
            self = .capture(id)
        default:
            return nil
        }
    }

    /// Liest den Zähler aus dem, was eine Mitteilung mitträgt.
    ///
    /// Ohne passenden Eintrag bleibt es beim Ziffernblock ohne Kennung: Eine
    /// Erinnerung aus einer älteren Fassung, die noch keinen Zähler mitgab, soll
    /// trotzdem dort ankommen, wo abgelesen wird.
    public init(notificationInfo info: [AnyHashable: Any]) {
        let kennung = (info[Self.meterKey] as? String).flatMap(UUID.init(uuidString:))
        self = .capture(kennung)
    }
}
