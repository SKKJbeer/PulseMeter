import Foundation

/// Der Wechsel von Gas oder Heizöl auf eine Wärmepumpe (1.9).
///
/// Verbindet den alten Zähler mit dem Stromzähler der Wärmepumpe. Beide
/// Zähler bleiben, wie sie sind: Der Wechsel ist nur die Verbindung, und ihn
/// zu löschen nimmt keinem Zähler etwas weg.
public struct HeatingChange: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    /// Ab diesem Tag heizt die Wärmepumpe. Danach erwartet der alte Zähler
    /// keine Ablesung mehr.
    public var day: CalendarDay
    public var oldMeterID: MeteringPoint.ID
    public var newMeterID: MeteringPoint.ID
    /// Anteil des Brennstoffs, der als Wärme im Haus ankam, 0…1. Eine Annahme,
    /// sichtbar und änderbar: Ohne Wärmemengenzähler kennt niemand die Zahl.
    public var boilerEfficiency: Decimal

    public init(
        id: UUID = UUID(),
        day: CalendarDay,
        oldMeterID: MeteringPoint.ID,
        newMeterID: MeteringPoint.ID,
        boilerEfficiency: Decimal
    ) {
        self.id = id
        self.day = day
        self.oldMeterID = oldMeterID
        self.newMeterID = newMeterID
        self.boilerEfficiency = Swift.min(1, Swift.max(0, boilerEfficiency))
    }

    /// Vorbelegung: 90 % für einen Brennwertkessel (Gas), 85 % für Öl.
    public static func defaultEfficiency(for kind: ResourceKind) -> Decimal {
        kind == .heatingOil ? Decimal(string: "0.85")! : Decimal(string: "0.9")!
    }

    /// Ob ein Zähler als alter Zähler eines Wechsels taugt.
    public static func canBeOldMeter(_ meter: MeteringPoint) -> Bool {
        meter.kind == .gas || meter.kind == .heatingOil
    }
}
