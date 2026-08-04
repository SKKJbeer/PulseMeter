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
    /// Chronologisch sortiert. Bei gleichem Tag entscheidet der Erfassungszeitpunkt —
    /// das ist der Fall am Tag eines Zählerwechsels, an dem zwei Ablesungen
    /// zulässig und notwendig sind.
    public func chronological() -> [Reading] {
        sorted { lhs, rhs in
            lhs.day == rhs.day ? lhs.createdAt < rhs.createdAt : lhs.day < rhs.day
        }
    }

    public func forRegister(_ id: Register.ID) -> [Reading] {
        filter { $0.registerID == id }
    }
}
