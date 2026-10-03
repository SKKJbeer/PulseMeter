import Foundation

/// Der Rundgang: Nach dem Sichern geht es mit dem nächsten fälligen Zähler
/// weiter, bis keiner mehr wartet.
///
/// **Warum es das gibt.** Wer am Monatsanfang abliest, liest meist alles ab:
/// Strom im Flur, Wasser im Bad, Gas am Heizungsraum. Bis 1.3 hieß das je
/// Zähler: Blatt zu, Karte suchen, „Stand eintragen", Blatt auf. Drei Zähler
/// waren drei Wege durch die Übersicht, mit kalten Fingern und einer Hand frei.
///
/// **Welche Reihenfolge.** Die der Übersicht, ab dem Zähler, mit dem es
/// anfing, und im Kreis weiter. Die Übersicht ordnet der Nutzer nicht, sie ist
/// aber die Reihenfolge, die er jeden Tag sieht; eine zweite Ordnung nur für
/// den Rundgang müsste er lernen. Nach Dringlichkeit zu sortieren klingt
/// klüger, schickte ihn aber kreuz und quer durchs Haus, sobald zwei Zähler
/// fast gleich lange warten.
///
/// **Was zählt, wird einmal festgelegt, am Anfang.** Wer Strom sichert, macht
/// Strom nicht fällig, aber ein Zähler, der während des Rundgangs fällig wird,
/// soll auch nicht unterwegs hinzukommen. Der Rundgang ist die Liste, die beim
/// ersten Tipp galt.
///
/// **Ohne einen weiteren fälligen Zähler gibt es keinen Rundgang.** Dann
/// schließt das Blatt nach dem Sichern wie bisher, und an den drei
/// Berührungen bis zur gesicherten Ablesung (Produktprinzip 2) ändert sich
/// nichts.
public struct ReadingRound: Equatable, Sendable {

    /// Was noch kommt, in dieser Reihenfolge. Der Zähler, mit dem es anfing,
    /// steht nie darin.
    public private(set) var remaining: [UUID]

    /// - Parameters:
    ///   - start: der Zähler, dessen Ziffernblock gerade aufgeht
    ///   - order: alle Zähler in der Reihenfolge der Übersicht
    ///   - due: welche davon fällig sind
    public init(start: UUID, order: [UUID], due: Set<UUID>) {
        let kreis: [UUID]
        if let stelle = order.firstIndex(of: start) {
            kreis = Array(order[order.index(after: stelle)...]) + Array(order[..<stelle])
        } else {
            // Ein Zähler, den die Übersicht nicht kennt, etwa einer, der eben
            // gelöscht wurde: Dann gilt die Reihenfolge von vorn.
            kreis = order
        }
        var gesehen: Set<UUID> = [start]
        remaining = kreis.filter { due.contains($0) && gesehen.insert($0).inserted }
    }

    /// Fällig nach derselben Regel wie Karte, Widget und Erinnerung.
    ///
    /// Eine eigene Fälligkeit für den Rundgang hieße: Die Karte sagt
    /// „Fällig", und der Rundgang geht daran vorbei.
    public init(start: UUID, meteringPoints: [MeteringPoint],
                primaryReadings: [UUID: [Reading]], today: CalendarDay) {
        let faellig = meteringPoints.filter {
            ConsumptionEngine.isReadingDue(meteringPoint: $0,
                                           readings: primaryReadings[$0.id] ?? [],
                                           today: today)
        }
        self.init(start: start, order: meteringPoints.map(\.id),
                  due: Set(faellig.map(\.id)))
    }

    /// Der nächste Zähler, oder `nil`, wenn der Rundgang hier endet.
    public var next: UUID? { remaining.first }

    /// Weiter zum nächsten, ob gesichert oder übersprungen. Gibt ihn zurück.
    @discardableResult
    public mutating func advance() -> UUID? {
        remaining.isEmpty ? nil : remaining.removeFirst()
    }
}
