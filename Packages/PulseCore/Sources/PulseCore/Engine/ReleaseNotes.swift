import Foundation

/// Was eine Fassung in der App über sich selbst sagt: eine Überschrift und
/// höchstens drei kurze Punkte.
///
/// **Aus derselben Datei wie Website und Laden.** Die Punkte stehen im Block
/// `app` von `docs/fassungen/<fassung>.json`, gleich neben dem Text für die
/// Website (`weg`, `start`). Die App bringt den Ordner als Ressource mit und
/// liest ihn hier. Eine zweite Abschrift im Swift-Code wäre der Anfang davon,
/// dass App, Website und Versionshinweise im Laden Verschiedenes erzählen —
/// genau das hat der Gründer am 23. November verboten.
/// `scripts/check-neuigkeiten.py` hält die drei zusammen.
public struct ReleaseNote: Equatable, Sendable, Identifiable {

    /// Die Nummer im App Store, etwa „1.9“. **Nicht** die Version im Bündel:
    /// `CFBundleShortVersionString` trägt die Entwicklungsnummer (0.179.0),
    /// und die sagt einem Käufer nichts.
    public let version: String
    public let title: String
    public let points: [String]

    public var id: String { version }

    public init(version: String, title: String, points: [String]) {
        self.version = version
        self.title = title
        self.points = points
    }

    /// Liest eine Datei aus `docs/fassungen`. Ohne Block `app` gibt es für
    /// diese Fassung nichts zu zeigen — das ist bei allen Fassungen vor 1.9
    /// so und bei einer reinen Korrektur erlaubt. Dann `nil`, kein Fehler.
    public static func decode(_ data: Data) -> ReleaseNote? {
        struct Datei: Decodable {
            struct App: Decodable { let titel: String; let punkte: [String] }
            let fassung: String
            let app: App?
        }
        guard let datei = try? JSONDecoder().decode(Datei.self, from: data),
              let app = datei.app,
              ReleaseNotes.parts(datei.fassung) != nil else { return nil }
        let punkte = app.punkte
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let titel = app.titel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titel.isEmpty, !punkte.isEmpty else { return nil }
        return ReleaseNote(version: datei.fassung, title: titel,
                           points: Array(punkte.prefix(ReleaseNotes.maxPoints)))
    }
}

/// Wann die App nach einem Update einmal zeigt, was neu ist.
///
/// **Die Regel in drei Sätzen.** Neu ist, was die höchste Fassung mit einem
/// Block `app` mitbringt. Gezeigt wird es einmal, sobald die Fassung höher ist
/// als die zuletzt gesehene; danach erst wieder bei der nächsten. Wer die App
/// frisch installiert hat, sieht es nicht — für ihn ist alles neu, und eine
/// Liste der Änderungen gegenüber einer Fassung, die er nie hatte, ist Lärm
/// vor der ersten Ablesung (Produktprinzip 1: 60 Sekunden).
///
/// **Woran ein Update zu erkennen ist.** Die zuletzt gesehene Fassung gibt es
/// erst ab 1.9. Wer von 1.8 kommt, hat also keine — genau wie jemand, der neu
/// installiert. Unterschieden wird am Bestand: Wer schon Zähler hat, hat die
/// App vorher benutzt. Ein neues Gerät, auf das iCloud erst danach Zähler
/// spiegelt, gilt als neu; das ist die harmlose Seite des Irrtums.
public enum ReleaseNotes {

    /// Mehr Punkte liest niemand auf einem Blatt, das man wegtippen will.
    public static let maxPoints = 3

    public enum Decision: Equatable, Sendable {
        /// Zeigen. Gemerkt wird die Fassung erst, wenn das Blatt zu ist.
        case show(ReleaseNote)
        /// Nicht zeigen, aber diese Fassung als gesehen merken.
        case remember(String)
        /// Nichts tun.
        case nothing
    }

    /// Die neueste Fassung unter denen, die etwas zu sagen haben.
    public static func latest(_ notes: [ReleaseNote]) -> ReleaseNote? {
        notes.max { compare($0.version, $1.version) == .orderedAscending }
    }

    public static func decide(latest note: ReleaseNote?,
                              lastSeen: String?,
                              usedBefore: Bool) -> Decision {
        guard let note else { return .nothing }
        guard let lastSeen, parts(lastSeen) != nil else {
            return usedBefore ? .show(note) : .remember(note.version)
        }
        // Nur vorwärts. Wer eine ältere Fassung zurückspielt (TestFlight
        // erlaubt das), bekommt nichts gezeigt und behält, was er gesehen hat.
        return compare(note.version, lastSeen) == .orderedDescending ? .show(note) : .nothing
    }

    /// Fassungen der Zahl nach: 1.10 kommt nach 1.9, und 1.9 ist dasselbe wie
    /// 1.9.0. Als Zeichenkette verglichen stünde 1.10 vor 1.9.
    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let x = parts(a) ?? [], y = parts(b) ?? []
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    static func parts(_ version: String) -> [Int]? {
        let teile = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !teile.isEmpty else { return nil }
        var zahlen: [Int] = []
        for teil in teile {
            guard let n = Int(teil), n >= 0 else { return nil }
            zahlen.append(n)
        }
        return zahlen
    }
}
