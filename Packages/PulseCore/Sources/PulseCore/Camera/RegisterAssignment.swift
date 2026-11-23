import Foundation

/// Die Kennzahl im Display: Welche Zahl zeigt der Zähler gerade?
///
/// **Der Anlass** (`docs/kamera/stufe-2.md`): Die moderne Messeinrichtung zeigt Bezug (1.8.0) und
/// Einspeisung (2.8.0), beim Zweitarifzähler Hoch- und Niedertarif (1.8.1, 1.8.2) und oft noch die
/// Summe (1.8.0) **abwechselnd auf einem Display**. Links neben oder über der Zahl steht klein die
/// Kennzahl. Wer sie liest, weiß, zu welchem Zählwerk die Zahl gehört, auch bei der ersten Ablesung,
/// wo es noch keinen Bereich gibt.
///
/// **Gelesen wird sie noch nicht.** Ein eigenes Netz dafür las sie auf echten Fotos zu selten und
/// manchmal falsch (Messung in `docs/kamera/stufe-2.md`). Die Regeln hier stehen trotzdem, geprüft und
/// gleich im Klick-Dummy, damit ein besseres Netz nur noch angeschlossen werden muss. Bis dahin
/// ordnen die Bereiche zu, und `code` ist in ``RegisterAssignment/decide(value:code:asked:codes:ranges:)`` `nil`.
public enum ObisCode {

    /// Nur diese Kennzahlen werden einem Zählwerk zugeordnet. Alles andere, was an der Stelle steht
    /// (Anzeigeindex „004“, Leistung 16.7.0), ist keine Zuordnung und wird übergangen.
    public static let known: [String] = ["1.8.0", "1.8.1", "1.8.2", "2.8.0", "2.8.1", "2.8.2"]

    /// Die Kennzahl aus dem, was das Kennzahl-Netz gelesen hat.
    ///
    /// Erlaubt sind `1.8.0`, ohne Punkte `180` (manche Displays zeigen sie nicht) und mit nur einem
    /// Punkt `18.0` oder `1.80` (ein Punkt ist zu klein und geht beim Lesen verloren). Gilt nur,
    /// wenn das Ergebnis eine bekannte Kennzahl ist.
    public static func read(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let digits = t.filter(\.isNumber)
        let dots = t.filter { $0 == "." }.count
        guard digits.count == 3, digits.count + dots == t.count else { return nil }
        let chars = Array(t)
        switch dots {
        case 0: break
        case 1: break
        case 2: guard chars.count == 5, chars[1] == ".", chars[3] == "." else { return nil }
        default: return nil
        }
        let d = Array(digits)
        let code = "\(d[0]).\(d[1]).\(d[2])"
        return known.contains(code) ? code : nil
    }

    /// Die Kennzahl je Zählwerk, ergänzt, wo keine eingetragen ist.
    ///
    /// **Warum ergänzen.** Wer einen Stromzähler mit einem Zählwerk anlegt und später die Einspeisung
    /// oder den Nachttarif dazunimmt, hat beim ersten Zählwerk keine Kennzahl: Die Vorlagen setzen sie
    /// nur bei den Zählwerken, die sie selbst anlegen. Ohne Ergänzung hielte die Kamera am Zweitarifzähler
    /// die Summe 1.8.0 für den Hochtarif.
    ///
    /// Nur beim Strom. Gas, Wasser und Wärme haben keine Kennzahl im Display, dort gilt `nil`.
    public static func effectiveCodes(of registers: [Register], kind: ResourceKind) -> [String?] {
        guard kind == .electricity else { return registers.map { _ in nil } }
        let set = Set(registers.compactMap(\.obisCode))
        return registers.map { r in
            if let code = r.obisCode { return code }
            switch r.direction {
            case .consumption: return set.contains("1.8.2") ? "1.8.1" : "1.8.0"
            case .feedIn: return set.contains("2.8.2") ? "2.8.1" : "2.8.0"
            default: return nil
            }
        }
    }
}

/// Zu welchem Zählwerk gehört die Zahl, auf die sich die Kamera geeinigt hat?
///
/// Mit Kennzahl entscheidet die Kennzahl. Ohne Kennzahl entscheiden die Bereiche: Liegt die Zahl
/// im eigenen Bereich und in keinem anderen, wird sie vorgeschlagen (``RegisterChoice``). Liegt sie
/// **nicht** im eigenen, aber in genau einem anderen, gehört sie zu diesem und wird gemerkt. So
/// liest ein Kamerabesuch beide Zahlen eines wechselnden Displays, sobald es Bereiche gibt, also
/// ab der zweiten Ablesung, auch ohne Kennzahl.
public enum RegisterAssignment: Hashable, Sendable {
    /// Vorschlagen.
    case propose
    /// Die Zahl gehört zu diesem anderen Zählwerk (Index in `codes`): merken, nicht vorschlagen.
    case remember(Int)
    /// Im Display steht eine Zahl, die zu keinem Zählwerk gehört, etwa die Summe 1.8.0 am
    /// Zweitarifzähler. Nicht vorschlagen.
    case foreign(String)
    /// Nicht eindeutig: Die Zahl passt auch zu diesem anderen Zählwerk.
    case ambiguous(Int)
    /// Die Zahl passt zu keinem Zählwerk, oder die Kennzahl widerspricht dem Bereich.
    /// Etwas stimmt nicht; nichts vorschlagen, nichts merken.
    case mismatch

    /// - Parameters:
    ///   - value: die Zahl, auf die sich die Kamera geeinigt hat.
    ///   - code: die Kennzahl, auf die sich die Kamera geeinigt hat (``ObisVote``), oder `nil`.
    ///   - asked: Index des gefragten Zählwerks.
    ///   - codes: Kennzahlen aller Zählwerke des Zählers (``ObisCode/effectiveCodes(of:kind:)``).
    ///   - ranges: Bereiche aller Zählwerke, `nil` ohne letzten Stand.
    public static func decide(value: Decimal, code: String?, asked: Int,
                              codes: [String?], ranges: [ClosedRange<Decimal>?]) -> RegisterAssignment {
        // Der eigene Bereich zählt immer, auch mit Kennzahl: Eine falsch gelesene Kennzahl darf den
        // Bereich nicht aushebeln.
        let inOwn = ranges[asked]?.contains(value) ?? true
        if let code, let own = codes[asked] {
            if code == own { return inOwn ? .propose : .mismatch }
            if let other = codes.indices.first(where: { $0 != asked && codes[$0] == code }) {
                if let range = ranges[other], !range.contains(value) { return .mismatch }
                return .remember(other)
            }
            // Ein Zählwerk allein: Bezug gegen Einspeisung ist eindeutig, die Tarife nicht. Wer nur den
            // Bezug führt, hat vielleicht einen Zähler, der nur „1.8.1“ zeigt.
            if codes.count == 1, code.prefix(2) == own.prefix(2) { return inOwn ? .propose : .mismatch }
            return .foreign(code)
        }
        let others = ranges.indices.filter { $0 != asked }
        if !inOwn {
            // Nicht die gefragte Zahl. Gehört sie zu genau einem anderen Zählwerk, mit Bereich?
            // Ein anderes ohne Bereich kommt dafür nicht in Frage: Wer nichts weiß, merkt nichts.
            let passt = others.filter { ranges[$0]?.contains(value) == true }
            return passt.count == 1 ? .remember(passt[0]) : .mismatch
        }
        switch RegisterChoice.check(value, others: others.map { ranges[$0] }) {
        case .own: return .propose
        case .couldBeOther(let k): return .ambiguous(others[k])
        }
    }
}

/// Die Kennzahl über mehrere Bilder: Gilt nur, wenn sie in genug Bildern gelesen wurde und kein
/// Bild etwas anderes las.
///
/// **Warum strenger als die Zahl.** Eine falsch gelesene Kennzahl, die zum gefragten Zählwerk
/// passt, setzt die Prüfung über den Bereich außer Kraft. Deshalb drei Bilder, nicht zwei,
/// und kein Widerspruch.
public enum ObisVote {
    public static let required = 3

    public static func agreed(_ codes: [String?], required: Int = ObisVote.required) -> String? {
        let read = codes.compactMap { $0 }
        guard let first = read.first, read.allSatisfy({ $0 == first }), read.count >= required else { return nil }
        return first
    }
}

/// Die Einigung über Zahl **und** Kennzahl: ``ReadingConsensus`` für die Zahl, dazu je Bild die
/// gelesene Kennzahl. Abgestimmt wird über die Kennzahlen der Bilder, die die geeinigte Zahl lasen.
public struct LabeledConsensus: Sendable {
    public struct Agreement: Hashable, Sendable {
        public var reading: ReadingConsensus.Agreement
        public var code: String?
    }

    private var numbers = ReadingConsensus()
    private var recent: [(value: Decimal?, code: String?)] = []

    public init() {}

    public mutating func add(_ outcome: MeterTextReader.Outcome, code: String?) -> Agreement? {
        let value: Decimal?
        if case .proposal(let p) = outcome { value = p.value } else { value = nil }
        recent.append((value, code))
        if recent.count > numbers.window { recent.removeFirst(recent.count - numbers.window) }
        guard let reading = numbers.add(outcome) else { return nil }
        let codes = recent.filter { $0.value == reading.proposal.value }.map(\.code)
        // Ein Bild ohne Zahl, aber mit einer anderen Kennzahl, ist ein Zeichen, dass das Display wechselt.
        let fremde = recent.filter { $0.value == nil }.compactMap(\.code)
        let code = ObisVote.agreed(codes)
        if let code, fremde.contains(where: { $0 != code }) { return Agreement(reading: reading, code: nil) }
        return Agreement(reading: reading, code: code)
    }

    public mutating func reset() {
        numbers.reset()
        recent.removeAll()
    }
}
