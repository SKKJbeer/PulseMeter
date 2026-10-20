import Foundation

/// Ein Stück Text, wie es die Texterkennung des Telefons aus einem Foto liefert.
public struct RecognizedText: Hashable, Sendable {
    public var text: String
    /// 0 bis 1, so wie Vision es meldet.
    public var confidence: Double

    public init(_ text: String, confidence: Double = 1) {
        self.text = text
        self.confidence = confidence
    }
}

/// Die Stellen eines Zählwerks — genug, um in einem Foto die richtige Zahl zu
/// finden.
public struct MeterFormat: Hashable, Sendable {
    public var integerDigits: Int
    public var fractionDigits: Int

    public init(integerDigits: Int, fractionDigits: Int) {
        self.integerDigits = integerDigits
        self.fractionDigits = fractionDigits
    }

    public init(_ register: Register) {
        self.init(integerDigits: register.integerDigits, fractionDigits: register.fractionDigits)
    }
}

/// Sucht in dem, was die Texterkennung auf einem Zählerfoto gelesen hat, den
/// Zählerstand — und schlägt **nichts** vor, wenn es nicht eindeutig ist.
///
/// **Warum so streng.** Auf einem ganzen Zählerfoto liest eine Texterkennung
/// vor allem das Typenschild: `2566`, `5000 imp/kWh`, `230V`, `2024`,
/// Seriennummern mit acht Stellen, die Eigentumsnummer `6.047.178` des
/// Netzbetreibers. Die Ziffern im Display, auf die es ankommt, fehlen oder
/// stehen daneben. Gemessen an 48 Fotos von Wikimedia Commons (`docs/kamera/`).
/// Eine falsch gelesene Ziffer ist schlimmer als keine (Produktprinzip 7); der
/// Nutzer bestätigt zwar jeden Vorschlag, aber wer einen Vorschlag bekommt,
/// prüft ihn weniger genau, als wer tippt.
///
/// **Was als Zählerstand gilt.** Ein Stück Text, das *nur* aus Ziffern, höchstens
/// einem Komma oder Punkt und höchstens einer Einheit dahinter besteht, und das
/// zum Zählwerk passt: nicht mehr Vorkommastellen, nicht mehr Nachkommastellen.
/// Alles mit Buchstaben mittendrin (`04972G072`, `7AA50 61`), mit Schrägstrich
/// oder Bindestrich (`50470-3`, `10(60)A`) oder mit zwei Trennzeichen
/// (`1.8.0`, `6.047.178`) ist ein Typenschild oder eine Kennzahl.
///
/// **Stark oder schwach.** Eine Zahl ist *stark*, wenn sie so breit ist wie das
/// Zählwerk (mit führenden Nullen, wie Displays und Rollen sie zeigen) oder ihre
/// Einheit trägt. Sie ist *schwach*, wenn sie nur zufällig passt (`1936`). Eine
/// schwache Zahl wird nur vorgeschlagen, wenn der Aufrufer sagt, in welchem
/// Bereich der Stand liegen kann, und sie darin die einzige ist.
///
/// **Bei der ersten Ablesung** gibt es keinen Bereich, an dem sich eine
/// Seriennummer verraten könnte: `424501` auf dem Typenschild ist für ein
/// sechsstelliges Zählwerk eine Zahl wie jede andere. Dann zählt nur, was ein
/// Merkmal trägt, das eine Seriennummer nicht hat: eine Einheit dahinter, ein
/// Komma oder eine führende Null. Ein Stand ohne all das (`655219` auf einem
/// alten Rollenzähler) wird bei der ersten Ablesung nicht vorgeschlagen und ab
/// der zweiten schon.
public enum MeterTextReader {

    public enum Outcome: Hashable, Sendable {
        case proposal(Proposal)
        case none(Reason)
    }

    public struct Proposal: Hashable, Sendable {
        public var value: Decimal
        /// Wie sie im Foto stand, für die Anzeige „aus dem Foto".
        public var text: String
        public var confidence: Double
        /// Ob nur die Vorkommastellen gelesen wurden, obwohl das Zählwerk
        /// Nachkommastellen hat (rote Ziffern, die auf Displays oft fehlen).
        public var fractionMissing: Bool
    }

    public enum Reason: Hashable, Sendable {
        /// Nichts im Foto sieht nach einem Zählerstand aus.
        case noCandidate
        /// Mehrere verschiedene Zahlen kommen in Frage.
        case ambiguous
        /// Eine passende Zahl steht im Foto, liegt aber außerhalb dessen, was der
        /// Zähler seit der letzten Ablesung geschafft haben kann.
        case outsideRange
        /// Die Texterkennung war sich zu unsicher.
        case lowConfidence
    }

    /// - Parameters:
    ///   - texts: Alles, was die Texterkennung im Foto gefunden hat.
    ///   - format: Stellen des Zählwerks, das abgelesen wird.
    ///   - plausible: Bereich, in dem der Stand liegen kann (letzter Stand bis
    ///     letzter Stand plus großzügiger Verbrauch). `nil` bei der ersten
    ///     Ablesung.
    public static func propose(
        from texts: [RecognizedText],
        format: MeterFormat,
        plausible: ClosedRange<Decimal>? = nil
    ) -> Outcome {
        let candidates = texts.flatMap { readCandidates(in: $0, format: format) }
        guard !candidates.isEmpty else { return .none(.noCandidate) }

        // Ohne Bereich nur Zahlen mit Merkmal (siehe oben).
        let strong = candidates.filter { $0.strong && (plausible != nil || $0.marked) }
        var pool: [Candidate]
        let needed: Double

        if !strong.isEmpty {
            pool = plausible.map { range in strong.filter { range.contains($0.value) } } ?? strong
            // Passt eine starke Zahl, aber nicht in den Bereich, darf auch keine
            // schwache einspringen: Die Kennzahl „180" würde sonst für einen
            // Stand gehalten, der nur weiter gelaufen ist als erwartet.
            if pool.isEmpty { return .none(.outsideRange) }
            needed = 0.5
        } else {
            guard let range = plausible else { return .none(.noCandidate) }
            pool = candidates.filter { range.contains($0.value) }
            if pool.isEmpty { return .none(.outsideRange) }
            needed = 0.8
        }

        let values = Set(pool.map(\.value))
        guard values.count == 1 else { return .none(.ambiguous) }

        let best = pool.max { $0.confidence < $1.confidence }!
        guard best.confidence >= needed else { return .none(.lowConfidence) }
        return .proposal(Proposal(
            value: best.value, text: best.raw, confidence: best.confidence,
            fractionMissing: best.fractionMissing))
    }

    // MARK: - Kandidaten

    struct Candidate: Hashable {
        var value: Decimal
        var raw: String
        var confidence: Double
        var strong: Bool
        /// Einheit, Komma oder führende Null: das, was eine Seriennummer nicht hat.
        var marked: Bool
        var fractionMissing: Bool
    }

    static func readCandidates(in item: RecognizedText, format: MeterFormat) -> [Candidate] {
        var text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // Die Einheit hinter der Zahl: „00047,36 m³", „002423 kWh", „1936kWh".
        var hasUnit = false
        if let range = text.range(of: #"\s*(kwh|k\s?w\s?h|m3|m³|m\^3|m\s?3)\s*$"#,
                                  options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
            hasUnit = true
        }
        text = text.trimmingCharacters(in: .whitespaces)
        text = fixLookalikes(text)

        // Rollenzählwerke und Siebensegment-Anzeigen kommen oft einzeln:
        // „0 0 2 4 2 3". Und die roten Ziffern getrennt: „00047 36".
        let groups = text.split(whereSeparator: { $0 == " " }).map(String.init)
        guard !groups.isEmpty, groups.allSatisfy({ $0.allSatisfy { $0.isASCIIDigit || $0 == "," || $0 == "." } }) else {
            return []
        }
        let joined: String
        if groups.count == 1 {
            joined = groups[0]
        } else if groups.allSatisfy({ $0.count == 1 && $0.first!.isASCIIDigit }) {
            joined = groups.joined()
        } else if groups.count == 2, format.fractionDigits > 0,
                  groups.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
                  groups[1].count == format.fractionDigits, groups[0].count <= format.integerDigits + 2 {
            joined = groups[0] + "," + groups[1]
        } else {
            return []
        }

        guard let parsed = parse(joined, format: format) else { return [] }
        // Stark: so breit wie das Zählwerk oder mit Einheit.
        let strong = hasUnit || parsed.rawIntegerDigits >= format.integerDigits
        return [Candidate(value: parsed.value, raw: item.text.trimmingCharacters(in: .whitespacesAndNewlines),
                          confidence: item.confidence, strong: strong,
                          marked: hasUnit || joined.contains(",") || joined.contains(".") || joined.hasPrefix("0"),
                          fractionMissing: parsed.fractionMissing && format.fractionDigits > 0)]
    }

    private struct Parsed { var value: Decimal; var rawIntegerDigits: Int; var fractionMissing: Bool }

    private static func parse(_ s: String, format: MeterFormat) -> Parsed? {
        let separators = s.filter { $0 == "," || $0 == "." }.count
        guard separators <= 1, s.first != ",", s.first != ".", s.last != ",", s.last != "." else { return nil }

        if separators == 1 {
            let parts = s.split(whereSeparator: { $0 == "," || $0 == "." }).map(String.init)
            guard parts.count == 2 else { return nil }
            let (int, frac) = (parts[0], parts[1])
            // Mehr Nachkommastellen, als das Zählwerk hat: ein Tausenderpunkt
            // oder eine Kennzahl, kein Stand.
            guard frac.count <= format.fractionDigits, significant(int) <= format.integerDigits,
                  let value = Decimal(string: int + "." + frac, locale: Locale(identifier: "en_US_POSIX"))
            else { return nil }
            return Parsed(value: value, rawIntegerDigits: int.count, fractionMissing: frac.count < format.fractionDigits)
        }

        guard s.allSatisfy(\.isASCIIDigit) else { return nil }
        let total = format.integerDigits + format.fractionDigits
        if format.fractionDigits > 0, s.count == total {
            // Rollenzählwerk ohne Komma: die letzten Stellen sind die roten.
            let split = s.index(s.endIndex, offsetBy: -format.fractionDigits)
            guard let value = Decimal(string: String(s[..<split]) + "." + String(s[split...]),
                                      locale: Locale(identifier: "en_US_POSIX")) else { return nil }
            return Parsed(value: value, rawIntegerDigits: s.count - format.fractionDigits, fractionMissing: false)
        }
        guard significant(s) <= format.integerDigits, let value = Decimal(string: s) else { return nil }
        return Parsed(value: value, rawIntegerDigits: s.count, fractionMissing: format.fractionDigits > 0)
    }

    /// Stellen ohne führende Nullen: „0014426" hat fünf.
    private static func significant(_ digits: String) -> Int {
        let rest = digits.drop(while: { $0 == "0" })
        return rest.isEmpty ? 0 : rest.count
    }

    /// Siebensegment-Ziffern und Rollen verwechselt die Erkennung gern mit
    /// Buchstaben. Nur dort ersetzt, wo der Rest des Textes klar nach Zahl
    /// aussieht — sonst würde aus dem Typenschild „SB2" ein Stand.
    static func fixLookalikes(_ s: String) -> String {
        let map: [Character: Character] = ["O": "0", "o": "0", "D": "0", "Q": "0",
                                           "I": "1", "l": "1", "|": "1", "S": "5", "B": "8", "Z": "2"]
        let digits = s.filter(\.isASCIIDigit).count
        let others = s.filter { !$0.isASCIIDigit && $0 != " " && $0 != "," && $0 != "." }
        guard digits >= 3, digits >= others.count, others.allSatisfy({ map[$0] != nil }) else { return s }
        return String(s.map { map[$0] ?? $0 })
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
