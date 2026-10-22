import Foundation

/// Sammelt die Vorschläge aufeinanderfolgender Kamerabilder und meldet erst,
/// wenn dieselbe Zahl **mehrfach** gelesen wurde.
///
/// **Warum.** Ein einzelnes Bild kann falsch lesen: Ein Reflex, eine Hand im
/// Bild, eine Ziffer, die halb verdeckt ist. Dieselbe Zahl in drei von sechs
/// Bildern hintereinander ist ein ganz anderes Zeichen — der gleiche Fehler
/// müsste jedes Mal an derselben Stelle auftreten. Die Kamera liefert dreißig
/// Bilder in der Sekunde; die kurze Wartezeit ist umsonst, ein falscher
/// Vorschlag nicht (Produktprinzip 7).
///
/// Ein Bild ohne Vorschlag zählt als Lücke: Es schiebt ältere Bilder aus dem
/// Fenster, damit eine Zahl von vor zehn Sekunden nicht mit einer von jetzt
/// zusammenfindet.
public struct ReadingConsensus: Sendable {

    public struct Agreement: Hashable, Sendable {
        public var proposal: MeterTextReader.Proposal
        /// In wie vielen der letzten Bilder diese Zahl vorkam.
        public var frames: Int
    }

    public let required: Int
    public let window: Int
    private var recent: [MeterTextReader.Proposal?] = []

    public init(required: Int = 3, window: Int = 6) {
        precondition(required >= 1 && window >= required)
        self.required = required
        self.window = window
    }

    /// Nimmt das Ergebnis eines Bildes auf und sagt, ob jetzt Einigkeit besteht.
    public mutating func add(_ outcome: MeterTextReader.Outcome) -> Agreement? {
        switch outcome {
        case .proposal(let p): recent.append(p)
        case .none: recent.append(nil)
        }
        if recent.count > window { recent.removeFirst(recent.count - window) }
        return agreement
    }

    public mutating func reset() { recent.removeAll() }

    /// Gewinner ist eine Zahl, die `required`-mal vorkommt, **und** neben der keine
    /// andere mehr als einmal vorkommt. Zwei konkurrierende Zahlen heißen: Die
    /// Kamera ist sich nicht einig, und dann sagt sie nichts.
    public var agreement: Agreement? {
        var counts: [Decimal: Int] = [:]
        for p in recent.compactMap({ $0 }) { counts[p.value, default: 0] += 1 }
        guard let best = counts.max(by: { $0.value < $1.value }), best.value >= required else { return nil }
        guard counts.filter({ $0.key != best.key }).allSatisfy({ $0.value <= 1 }) else { return nil }
        let latest = recent.reversed().compactMap { $0 }.first { $0.value == best.key }!
        return Agreement(proposal: latest, frames: best.value)
    }
}
