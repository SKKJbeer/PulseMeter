import Foundation

/// Woher ein erfasster Wert stammt.
///
/// Die Herkunft ist Teil des Datensatzes, damit die Oberfläche eine geschätzte
/// Zahl nie wie eine gemessene darstellen kann (Produktprinzip 7).
public enum ReadingOrigin: String, Hashable, Codable, Sendable, CaseIterable {
    /// Vom Nutzer eingetippt.
    case manual
    /// Per Kamera erkannt und vom Nutzer bestätigt. Ein unbestätigter
    /// Kamerawert wird nie gespeichert.
    case camera
    /// Aus einem Export oder einer anderen App importiert.
    case imported
    /// Vom Nutzer bewusst als Schätzung markiert, z. B. rückwirkend.
    case estimated
}

/// Eine Ablesung.
///
/// `value` ist immer der **abgelesene Zählerstand**, nie ein Verbrauch
/// (Ausnahme: Zählwerke im Modus ``AccumulationMode/interval``, dort ist
/// `value` die Menge des Zeitraums).
///
/// Verbräuche werden ausschließlich berechnet und nie gespeichert. Damit gibt es
/// genau eine Wahrheit, und eine nachträgliche Korrektur wirkt automatisch auf
/// alle abgeleiteten Werte. Gespeicherte Verbräuche wären Redundanz und damit
/// eine Quelle stiller Inkonsistenz.
public struct Reading: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var registerID: Register.ID
    /// Gerät, an dem abgelesen wurde. `nil`, wenn keine Wechselhistorie geführt wird.
    public var deviceID: MeterDevice.ID?
    public var day: CalendarDay
    /// Die Uhrzeit, zu der abgelesen wurde — `nil` bei allem, was vor 0.64.0
    /// erfasst wurde, und bei allem, wo sie niemand angegeben hat.
    ///
    /// **Sie entscheidet die Reihenfolge, nicht die Rechnung.** Verbräuche
    /// entstehen zwischen Tagen (ADR-004); zwei Ablesungen desselben Tages
    /// tragen beide bei, und die Uhrzeit sagt nur, welche die spätere ist. Wer
    /// morgens und abends abliest, bekommt damit zwei brauchbare Einträge statt
    /// zweier, deren Reihenfolge am Erfassungszeitpunkt hängt.
    public var time: TimeOfDay?
    public var value: Decimal
    public var origin: ReadingOrigin
    public var note: String?
    public var photoID: UUID?

    /// Zeitpunkt der Erfassung — für Beweiszwecke und zur Sortierung mehrerer
    /// Ablesungen am selben Tag. Wird **nie** für Verbrauchsberechnungen verwendet.
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        registerID: Register.ID,
        deviceID: MeterDevice.ID? = nil,
        day: CalendarDay,
        time: TimeOfDay? = nil,
        value: Decimal,
        origin: ReadingOrigin = .manual,
        note: String? = nil,
        photoID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.registerID = registerID
        self.deviceID = deviceID
        self.day = day
        self.time = time
        self.value = value
        self.origin = origin
        self.note = note
        self.photoID = photoID
        self.createdAt = createdAt
    }

    /// Ob der Wert gemessen oder vom Nutzer geschätzt wurde.
    public var isEstimated: Bool { origin == .estimated }
}

extension Array where Element == Reading {
    /// Chronologisch sortiert.
    ///
    /// Bei gleichem Tag entscheidet die **angegebene Uhrzeit**, wenn beide
    /// Ablesungen eine tragen. Sonst der Erfassungszeitpunkt — das ist der Fall
    /// am Tag eines Zählerwechsels und bei allem, was vor 0.64.0 gespeichert
    /// wurde.
    ///
    /// **Warum nicht die Uhrzeit gegen den Erfassungszeitpunkt.** Eine
    /// nachgetragene Ablesung von gestern Abend wurde heute erfasst; ihre
    /// Uhrzeit und ihr Erfassungszeitpunkt beschreiben verschiedene Dinge, und
    /// beide gegeneinander zu vergleichen wäre wieder das Gegenüberstellen
    /// zweier verschiedener Zeitausschnitte. Trägt nur eine Ablesung eine
    /// Uhrzeit, ist der Erfassungszeitpunkt das Einzige, was beide haben.
    public func chronological() -> [Reading] {
        sorted { lhs, rhs in
            guard lhs.day == rhs.day else { return lhs.day < rhs.day }
            if let links = lhs.time, let rechts = rhs.time, links != rechts {
                return links < rechts
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public func forRegister(_ id: Register.ID) -> [Reading] {
        filter { $0.registerID == id }
    }
}
