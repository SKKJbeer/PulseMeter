import Foundation

/// Liest Zählerstände aus einer Tabelle: einer CSV-Datei, einem Export aus
/// Excel oder Numbers, oder dem, was man dort markiert und kopiert hat.
///
/// **Ohne Einstellungen.** Vom Gründer am 13. Oktober verlangt: „mache es
/// dynamisch und so benutzerfreundlich wie möglich." Niemand soll wissen
/// müssen, was ein Trennzeichen ist. Erkannt wird deshalb alles aus dem Inhalt:
/// Trennzeichen, Kopfzeile, Datums- und Zahlenformat, welche Spalte was ist,
/// und ob die Tabelle **lang** ist (eine Zeile je Ablesung, eine Spalte nennt
/// den Zähler) oder **breit** (eine Zeile je Tag, eine Spalte je Zähler). Was
/// sich nicht eindeutig erkennen lässt, entscheidet die Oberfläche mit dem
/// Nutzer, nie still dieser Code (Produktprinzip 7).
///
/// **Verbräuche werden nicht eingelesen.** Zählora rechnet den Verbrauch aus
/// den Ständen. Eine Spalte „Verbrauch" daneben wäre eine zweite Wahrheit, die
/// beim nächsten Tippfehler von der ersten abweicht.
public enum TableImport {

    // MARK: - Text

    /// Macht aus den Bytes einer Datei Text.
    ///
    /// Excel unter Windows speichert CSV in Windows-1252, nicht in UTF-8. Ohne
    /// diesen Rückfall stünde aus „Zählerstand" ein „Z�hlerstand" in der
    /// Vorschau, und die Kopfzeile würde nicht erkannt.
    public static func text(from data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) { return String(data: data, encoding: .utf16LittleEndian) }
        if data.starts(with: [0xFE, 0xFF]) { return String(data: data, encoding: .utf16BigEndian) }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        return windows1252(data)
    }

    /// Selbst übersetzt statt über `String.Encoding.windowsCP1252`: Das kennt
    /// Foundation auf dem iPhone, unter Linux aber nicht, und dann prüfte die
    /// Testreihe etwas anderes, als das Telefon tut. Bis auf 0x80–0x9F ist
    /// Windows-1252 dasselbe wie Latin-1.
    static func windows1252(_ data: Data) -> String {
        let mitte: [UInt32] = [0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
                               0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
                               0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                               0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178]
        var out = String.UnicodeScalarView()
        for byte in data {
            let wert = (0x80...0x9F).contains(byte) ? mitte[Int(byte) - 0x80] : UInt32(byte)
            if let scalar = Unicode.Scalar(wert) { out.append(scalar) }
        }
        return String(out)
    }

    // MARK: - Ergebnis der Analyse

    /// Was eine Spalte ist.
    public enum Role: String, Hashable, Codable, Sendable, CaseIterable {
        case date, time, reading, meter, register, unit, note, ignored
    }

    public struct Column: Identifiable, Hashable, Sendable {
        public var id: Int { index }
        public let index: Int
        /// Die Überschrift, wie sie in der Datei steht. `nil` ohne Kopfzeile.
        public let header: String?
        public var role: Role
        /// Die ersten Werte, für die Vorschau.
        public let samples: [String]
        /// Warum die Spalte übergangen wird, wenn sie es wird.
        public let reason: String?
    }

    /// Reihenfolge von Tag und Monat in Daten wie `03/04/2025`.
    public enum DateOrder: String, Hashable, Sendable { case dayFirst, monthFirst }

    /// Eine Datenzeile mit ihrer Nummer in der Datei, damit jeder Hinweis
    /// sagen kann, wo er hingehört.
    public struct Row: Hashable, Sendable {
        public let line: Int
        public let cells: [String]
    }

    /// Die erkannte Tabelle, bevor daraus Zählerstände werden.
    public struct Draft: Hashable, Sendable {
        public var columns: [Column]
        /// Nur die Datenzeilen, ohne Kopfzeile.
        public let rows: [Row]
        public let hasHeader: Bool
        public let separator: Character
        public var decimalComma: Bool
        public var dateOrder: DateOrder

        /// Ob sich daraus etwas einlesen lässt: ein Datum und wenigstens ein Stand.
        public var isUsable: Bool {
            columns.contains { $0.role == .date } && columns.contains { $0.role == .reading }
        }
    }

    public struct Entry: Hashable, Sendable {
        public let line: Int
        public let day: CalendarDay
        public let time: TimeOfDay?
        public let value: Decimal
        public let note: String?
    }

    /// Ein Hinweis zu einer Zeile oder einer ganzen Reihe.
    public struct Issue: Hashable, Sendable {
        public enum Kind: String, Hashable, Sendable {
            case unreadableDate, unreadableNumber, negative, duplicate, sameDayDifferent,
                 decreasing, looksLikeConsumption, ignoredColumn, alreadyThere, conflict, doesNotFit
        }
        public let kind: Kind
        public let line: Int?
        public let text: String
    }

    /// Eine Folge von Ständen, die zu **einem** Zählwerk gehört.
    public struct Series: Identifiable, Hashable, Sendable {
        public var id: String { meterName + "\u{1F}" + (registerLabel ?? "") }
        public let meterName: String
        /// „HT", „NT", „Einspeisung" — `nil` beim gewöhnlichen Zähler.
        public let registerLabel: String?
        public let kind: ResourceKind
        public let direction: FlowDirection
        public let unit: MeasurementUnit
        /// Älteste zuerst, ohne Doppelte und ohne Stände, die zurückgehen.
        public let entries: [Entry]
        public let issues: [Issue]
        /// So viele Nachkommastellen, wie die Datei zeigt, mindestens die der Zählerart.
        public let fractionDigits: Int
        public let integerDigits: Int

        public var first: CalendarDay? { entries.first?.day }
        public var last: CalendarDay? { entries.last?.day }
    }

    public struct Result: Hashable, Sendable {
        public let series: [Series]
        /// Hinweise, die keiner Reihe gehören: unlesbare Zeilen, übergangene Spalten.
        public let issues: [Issue]
        public var entryCount: Int { series.reduce(0) { $0 + $1.entries.count } }
    }

    // MARK: - Analyse

    /// Erkennt, was in der Tabelle steht. `nil`, wenn nichts Tabellarisches darin ist.
    public static func analyse(_ text: String) -> Draft? {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard let (separator, grid) = bestGrid(normalized) else { return nil }

        // Leere Zeilen und Zeilen, in denen nur Trennzeichen stehen, fallen weg
        // — mit ihrer Zeilennummer, damit Hinweise auf die Datei passen.
        let numbered = grid.enumerated()
            .map { Row(line: $0.offset + 1, cells: $0.element.map(clean)) }
            .filter { $0.cells.contains { !$0.isEmpty } }
        guard numbered.count >= 1 else { return nil }

        let width = numbered.map(\.cells.count).max() ?? 0
        let padded = numbered.map { row in
            Row(line: row.line, cells: row.cells + Array(repeating: "", count: width - row.cells.count))
        }

        let hasHeader = looksLikeHeader(padded[0].cells, next: padded.dropFirst().first?.cells)
        let headers = hasHeader ? padded[0].cells : nil
        let data = Array(hasHeader ? padded.dropFirst() : padded[...])
        guard !data.isEmpty else { return nil }

        let decimalComma = decideDecimalComma(data.flatMap(\.cells))
        let dateOrder = decideDateOrder(data.flatMap(\.cells))

        var columns: [Column] = []
        for index in 0..<width {
            let values = data.map { $0.cells[index] }.filter { !$0.isEmpty }
            let header = headers?[index]
            let (role, reason) = classify(header: header, values: values,
                                          decimalComma: decimalComma, dateOrder: dateOrder)
            columns.append(Column(index: index, header: header?.isEmpty == true ? nil : header,
                                  role: role, samples: Array(values.prefix(3)), reason: reason))
        }

        // Nur eine Datumsspalte. Ein zweites Datum ist meistens „gebucht am"
        // oder „nächste Ablesung" und keine zweite Ablesung.
        if let firstDate = columns.firstIndex(where: { $0.role == .date }) {
            for i in columns.indices where i != firstDate && columns[i].role == .date {
                columns[i].role = .ignored
            }
        }
        return Draft(columns: columns, rows: data, hasHeader: hasHeader, separator: separator,
                     decimalComma: decimalComma, dateOrder: dateOrder)
    }

    // MARK: - Aus der Tabelle werden Reihen

    /// Bildet aus der erkannten (und vom Nutzer vielleicht korrigierten)
    /// Tabelle die Reihen, eine je Zählwerk.
    public static func series(from draft: Draft) -> Result {
        var general: [Issue] = []
        for column in draft.columns where column.role == .ignored {
            if let reason = column.reason {
                let name = column.header ?? String(column.index + 1)
                general.append(Issue(kind: .ignoredColumn, line: nil, text: "Spalte „\(name)“: \(reason)"))
            }
        }
        guard let dateColumn = draft.columns.first(where: { $0.role == .date }) else {
            return Result(series: [], issues: general)
        }
        let timeColumn = draft.columns.first { $0.role == .time }
        let meterColumn = draft.columns.first { $0.role == .meter }
        let registerColumn = draft.columns.first { $0.role == .register }
        let unitColumn = draft.columns.first { $0.role == .unit }
        let noteColumn = draft.columns.first { $0.role == .note }
        let readingColumns = draft.columns.filter { $0.role == .reading }

        // Schlüssel einer Reihe → (Name, Bezeichnung, Einheit aus der Datei, Einträge, Stellen)
        struct Sammlung {
            var name: String
            var label: String?
            var unitHint: String?
            var entries: [Entry] = []
            var decimals = 0
            var magnitude = Decimal(0)
        }
        var order: [String] = []
        var collected: [String: Sammlung] = [:]

        for row in draft.rows {
            let rawDate = row.cells[dateColumn.index]
            guard let (day, timeInDate) = parseDate(rawDate, order: draft.dateOrder) else {
                if !rawDate.isEmpty || readingColumns.contains(where: { !row.cells[$0.index].isEmpty }) {
                    general.append(Issue(kind: .unreadableDate, line: row.line,
                                         text: rawDate.isEmpty ? "Zeile \(row.line): kein Datum"
                                                               : "Zeile \(row.line): „\(rawDate)“ ist kein Datum"))
                }
                continue
            }
            let time = timeColumn.flatMap { parseTime(row.cells[$0.index]) } ?? timeInDate
            let note = noteColumn.map { row.cells[$0.index] }.flatMap { $0.isEmpty ? nil : $0 }

            for column in readingColumns {
                let raw = row.cells[column.index]
                guard !raw.isEmpty else { continue }
                guard let (value, decimals, unitInCell) = parseNumber(raw, decimalComma: draft.decimalComma) else {
                    general.append(Issue(kind: .unreadableNumber, line: row.line,
                                         text: "Zeile \(row.line): „\(raw)“ ist keine Zahl"))
                    continue
                }
                if value < 0 {
                    general.append(Issue(kind: .negative, line: row.line,
                                         text: "Zeile \(row.line): Ein Zählerstand ist nie negativ (\(raw))"))
                    continue
                }
                let (name, label) = seriesName(meterCell: meterColumn.map { row.cells[$0.index] },
                                               registerCell: registerColumn.map { row.cells[$0.index] },
                                               header: column.header,
                                               severalReadingColumns: readingColumns.count > 1)
                let key = name + "\u{1F}" + (label ?? "")
                if collected[key] == nil {
                    order.append(key)
                    collected[key] = Sammlung(name: name, label: label)
                }
                collected[key]!.entries.append(Entry(line: row.line, day: day, time: time,
                                                     value: value, note: note))
                collected[key]!.decimals = Swift.max(collected[key]!.decimals, decimals)
                collected[key]!.magnitude = Swift.max(collected[key]!.magnitude, value)
                if collected[key]!.unitHint == nil {
                    collected[key]!.unitHint = unitColumn.map { row.cells[$0.index] }.flatMap { $0.isEmpty ? nil : $0 }
                        ?? unitInCell ?? column.header
                }
            }
        }

        let series = order.compactMap { key -> Series? in
            guard let s = collected[key], !s.entries.isEmpty else { return nil }
            let hint = [s.name, s.label ?? "", s.unitHint ?? ""].joined(separator: " ")
            let unit = unitFrom(s.unitHint) ?? unitFrom(s.name)
            let kind = kindFrom(hint, unit: unit)
            let direction = directionFrom(hint)
            let (entries, issues) = tidy(s.entries)
            let digits = String(describing: NSDecimalNumber(decimal: s.magnitude).intValue).count
            return Series(meterName: s.name, registerLabel: s.label, kind: kind, direction: direction,
                          unit: unit ?? kind.defaultUnit, entries: entries, issues: issues,
                          fractionDigits: Swift.max(kind.defaultFractionDigits, s.decimals),
                          integerDigits: Swift.max(6, digits))
        }
        return Result(series: series, issues: general)
    }

    // MARK: - Abgleich mit dem, was schon da ist

    public struct Merge: Hashable, Sendable {
        public let readings: [Reading]
        /// Schon vorhanden: gleicher Tag, gleicher Stand.
        public let alreadyThere: Int
        /// Gleicher Tag, anderer Stand, oder ein Stand, der nicht zwischen die
        /// vorhandenen passt. Der vorhandene bleibt.
        public let conflicts: [Issue]
        /// Wie viele Stände nicht zwischen die vorhandenen passten. Sind es
        /// viele, gehört die Reihe zu einem anderen Zähler.
        public let misfits: Int
    }

    /// Macht aus einer Reihe Ablesungen für ein Zählwerk und lässt weg, was es
    /// dort schon gibt. Ein vorhandener Stand gewinnt immer: Ihn hat jemand am
    /// Zähler abgelesen, den eingelesenen nur abgeschrieben.
    public static func readings(
        from series: Series,
        register: Register.ID,
        existing: [Reading],
        createdAt: Date = Date()
    ) -> Merge {
        let vorhanden = existing.filter { $0.registerID == register }
        // **Nachschlagen statt durchsuchen.** Je Zeile alle vorhandenen Stände
        // zu filtern kostete bei tausend gegen tausend eine Million Vergleiche,
        // und die Vorschau rechnet das bei jeder Änderung neu.
        let nachTag = Dictionary(grouping: vorhanden, by: \.day)
        let tage = nachTag.keys.sorted()
        // Höchster Stand bis einschließlich Tag i, niedrigster ab Tag i.
        var bisHier: [Decimal] = [], abHier: [Decimal] = Array(repeating: 0, count: tage.count)
        for tag in tage {
            let hoch = nachTag[tag]!.map(\.value).max()!
            bisHier.append(Swift.max(bisHier.last ?? hoch, hoch))
        }
        for i in stride(from: tage.count - 1, through: 0, by: -1) {
            let tief = nachTag[tage[i]]!.map(\.value).min()!
            abHier[i] = i == tage.count - 1 ? tief : Swift.min(abHier[i + 1], tief)
        }
        /// Erster Index mit `tage[i] >= day`.
        func untereGrenze(_ day: CalendarDay) -> Int {
            var lo = 0, hi = tage.count
            while lo < hi { let mid = (lo + hi) / 2; if tage[mid] < day { lo = mid + 1 } else { hi = mid } }
            return lo
        }
        var neu: [Reading] = []
        var gleich = 0
        var konflikte: [Issue] = []
        var unpassend = 0
        for (offset, entry) in series.entries.enumerated() {
            let amTag = (nachTag[entry.day] ?? []).filter { entry.time == nil || $0.time == nil || $0.time == entry.time }
            if amTag.contains(where: { $0.value == entry.value }) { gleich += 1; continue }
            if let anderer = amTag.first {
                konflikte.append(Issue(kind: .conflict, line: entry.line,
                                       text: "Zeile \(entry.line): Am \(deutsch(entry.day)) steht schon \(format(anderer.value)), eingelesen wäre \(format(entry.value)). Der vorhandene bleibt."))
                continue
            }
            // **Er muss zwischen die vorhandenen Stände passen.** Ein Zähler
            // läuft nur vorwärts. Ein eingelesener Stand unter einem früheren
            // oder über einem späteren vorhandenen machte die Reihe kaputt,
            // und jeder Verbrauch daneben wäre falsch. Gefunden am Entwurf:
            // Das Beispiel landete wegen des gleichen Namens im Zähler
            // „Strom", dessen Stände viermal so hoch waren.
            let i = untereGrenze(entry.day)
            let davor = i > 0 ? bisHier[i - 1] : nil
            let j = i < tage.count && tage[i] == entry.day ? i + 1 : i
            let danach = j < tage.count ? abHier[j] : nil
            if let davor, entry.value < davor {
                unpassend += 1
                konflikte.append(Issue(kind: .doesNotFit, line: entry.line,
                                       text: "Zeile \(entry.line): \(format(entry.value)) liegt unter dem vorhandenen Stand \(format(davor)) von vorher. Nicht übernommen."))
                continue
            }
            if let danach, entry.value > danach {
                unpassend += 1
                konflikte.append(Issue(kind: .doesNotFit, line: entry.line,
                                       text: "Zeile \(entry.line): \(format(entry.value)) liegt über dem vorhandenen Stand \(format(danach)) von danach. Nicht übernommen."))
                continue
            }
            // Eine Mikrosekunde Abstand je Zeile hält die Reihenfolge am selben
            // Tag fest; sortiert wird bei gleichem Tag nach dem Erfassungszeitpunkt.
            neu.append(Reading(registerID: register, day: entry.day, time: entry.time,
                               value: entry.value, origin: .imported, note: entry.note,
                               createdAt: createdAt.addingTimeInterval(Double(offset) / 1_000_000)))
        }
        return Merge(readings: neu, alreadyThere: gleich, conflicts: konflikte, misfits: unpassend)
    }

    // MARK: - Raster

    /// Probiert die üblichen Trennzeichen und nimmt das, bei dem die meisten
    /// Zeilen gleich viele Felder haben.
    static func bestGrid(_ text: String) -> (Character, [[String]])? {
        // Entschieden wird an den ersten 50 Zeilen, zerlegt wird danach einmal.
        // Viermal den ganzen Text zu zerlegen kostete bei zehn Jahren täglicher
        // Stände die Hälfte der Zeit.
        let probe = text.split(separator: "\n", maxSplits: 50, omittingEmptySubsequences: false)
            .prefix(50).joined(separator: "\n")
        var best: (Character, Int)?
        for candidate: Character in ["\t", ";", ",", "|"] {
            let grid = split(probe, separator: candidate)
            let counts = grid.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
                .map(\.count)
            guard let mode = mostCommon(counts), mode > 1 else { continue }
            let score = counts.filter { $0 == mode }.count * 10 + mode
            if best == nil || score > best!.1 { best = (candidate, score) }
        }
        if let best { return (best.0, split(text, separator: best.0)) }
        // Eine einzige Spalte ist keine Tabelle — außer es stehen Datum und
        // Stand mit Leerzeichen getrennt darin, wie bei einer Notiz im Telefon.
        let spaced = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.split(whereSeparator: { $0 == " " }).map(String.init)
        }
        let counts = spaced.filter { !$0.isEmpty }.map(\.count)
        if let mode = mostCommon(counts), mode == 2 { return (" ", spaced) }
        return nil
    }

    /// CSV nach RFC 4180: Felder in Anführungszeichen dürfen Trennzeichen und
    /// Zeilenumbrüche enthalten, `""` ist ein Anführungszeichen.
    static func split(_ text: String, separator: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(text)
        if chars.last != "\n" { chars.append("\n") }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"" && field.trimmingCharacters(in: .whitespaces).isEmpty {
                field = ""; quoted = true
            } else if c == separator {
                row.append(field); field = ""
            } else if c == "\n" {
                row.append(field); rows.append(row); row = []; field = ""
            } else {
                field.append(c)
            }
            i += 1
        }
        return rows
    }

    static func mostCommon(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { a, b in a.value == b.value ? a.key < b.key : a.value < b.value }?.key
    }

    /// Leerzeichen am Rand, das geschützte Leerzeichen aus Excel und der
    /// Apostroph, mit dem unser eigener Export Text kennzeichnet.
    static func clean(_ cell: String) -> String {
        var s = cell.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("'") { s.removeFirst() }
        return s
    }

    // MARK: - Kopfzeile und Spalten

    static func looksLikeHeader(_ cells: [String], next: [String]?) -> Bool {
        let filled = cells.filter { !$0.isEmpty }
        guard !filled.isEmpty else { return false }
        let datumOderZahl = filled.filter {
            parseDate($0, order: .dayFirst) != nil || parseNumber($0, decimalComma: true) != nil
        }
        // Eine Kopfzeile hat kein Datum und nicht nur Zahlen. Und wenn die
        // nächste Zeile ein Datum hat, diese aber nicht, ist es erst recht eine.
        if datumOderZahl.isEmpty { return true }
        if let next, next.contains(where: { parseDate($0, order: .dayFirst) != nil }),
           !cells.contains(where: { parseDate($0, order: .dayFirst) != nil }) { return true }
        return false
    }

    static func classify(header: String?, values: [String], decimalComma: Bool,
                         dateOrder: DateOrder) -> (Role, String?) {
        // Für die Entscheidung reichen die ersten 200 Werte; gelesen wird danach jede Zeile.
        let values = Array(values.prefix(200))
        let h = (header ?? "").lowercased()
        // Kurze Wörter nur als ganzes Wort: „Zählerart" ist keine „Art",
        // und in „Haid" steckt keine „ID".
        let woerter = Set(h.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        func wort(_ liste: [String]) -> Bool { liste.contains { woerter.contains($0) } }
        guard !values.isEmpty else { return (.ignored, header == nil ? nil : "leer") }
        func share(_ test: (String) -> Bool) -> Double {
            Double(values.filter(test).count) / Double(values.count)
        }
        let dates = share { parseDate($0, order: dateOrder) != nil }
        let times = share { parseTime($0) != nil }
        let numbers = share { parseNumber($0, decimalComma: decimalComma) != nil }

        // **Sechzig Prozent, nicht achtzig.** Eine Zeile „im Urlaub" in einer
        // Liste von fünf reichte sonst, damit die Spalte nicht mehr als Datum
        // galt und gar nichts eingelesen wurde. Was in einer erkannten Spalte
        // nicht passt, wird je Zeile gemeldet.
        if dates >= 0.6 { return (.date, nil) }
        if times >= 0.8 && h.containsAny(["zeit", "uhr", "time"]) || times >= 0.95 { return (.time, nil) }

        if numbers >= 0.6 {
            if h.containsAny(["verbrauch", "differenz", "diff", "consumption", "usage", "delta"]) {
                return (.ignored, "Verbrauch, kein Zählerstand. Zählora rechnet ihn selbst.")
            }
            if h.containsAny(["kosten", "preis", "betrag", "€", "abschlag", "cost", "price"]) || wort(["eur", "euro"]) {
                return (.ignored, "Geldbetrag, kein Zählerstand")
            }
            if h.containsAny(["nummer", "zählernr", "kunden"]) || wort(["nr", "id", "jahr", "monat", "woche", "kw"]) {
                return (.ignored, "Nummer, kein Zählerstand")
            }
            return (.reading, nil)
        }

        if h.containsAny(["einheit"]) || wort(["unit"]) { return (.unit, nil) }
        if h.containsAny(["bezeichnung", "zählwerk", "tarif", "register", "obis"]) { return (.register, nil) }
        if h.containsAny(["notiz", "bemerkung", "kommentar", "comment", "hinweis"]) || wort(["note"]) { return (.note, nil) }
        if wort(["art", "quelle", "typ", "type", "status", "herkunft"]) { return (.ignored, nil) }
        if h.containsAny(["zähler", "zaehler", "meter", "name", "medium", "sparte", "energie"]) {
            return (.meter, nil)
        }
        // Ohne Überschrift: Wiederholen sich wenige Wörter, ist es der Zähler.
        let distinct = Set(values)
        if distinct.count <= 12 && distinct.count < values.count {
            if distinct.allSatisfy({ unitFrom($0) != nil }) { return (.unit, nil) }
            return (.meter, nil)
        }
        return (.note, nil)
    }

    /// Wie die Reihe heißt. Mit einer Spalte „Zähler" nennt die Zeile den
    /// Zähler, sonst die Überschrift der Spalte („Strom", „Gas HT").
    static func seriesName(meterCell: String?, registerCell: String?, header: String?,
                           severalReadingColumns: Bool) -> (String, String?) {
        if let meterCell, !meterCell.isEmpty {
            var label = registerCell.flatMap { $0.isEmpty ? nil : $0 }
            if label == nil, severalReadingColumns, let header, !isGenericReadingHeader(header) {
                label = header
            }
            if label == nil, let (base, suffix) = splitTariff(meterCell) { return (base, suffix) }
            return (meterCell, label)
        }
        if let header, !header.isEmpty, !isGenericReadingHeader(header) {
            let ohneEinheit = stripUnit(header)
            if let (base, suffix) = splitTariff(ohneEinheit) { return (base, registerCell.flatMap { $0.isEmpty ? nil : $0 } ?? suffix) }
            return (ohneEinheit, registerCell.flatMap { $0.isEmpty ? nil : $0 })
        }
        return ("Zähler", registerCell.flatMap { $0.isEmpty ? nil : $0 })
    }

    static func isGenericReadingHeader(_ header: String) -> Bool {
        let h = stripUnit(header).lowercased()
        return ["stand", "zählerstand", "zaehlerstand", "wert", "value", "reading", "ablesung",
                "messwert", "kwh", "m³", "m3", ""].contains(h)
    }

    /// „Strom HT" → („Strom", „HT"). Tarifwörter am Ende gehören zum Zählwerk.
    static func splitTariff(_ name: String) -> (String, String)? {
        let words = name.split(separator: " ").map(String.init)
        guard words.count >= 2, let last = words.last else { return nil }
        let tariffs = ["ht", "nt", "hochtarif", "niedertarif", "tag", "nacht", "bezug",
                       "einspeisung", "rückspeisung", "1.8.0", "2.8.0", "1.8.1", "1.8.2"]
        guard tariffs.contains(last.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "()"))) else { return nil }
        return (words.dropLast().joined(separator: " "), last.trimmingCharacters(in: CharacterSet(charactersIn: "()")))
    }

    static func stripUnit(_ text: String) -> String {
        var s = text
        for pattern in ["(kWh)", "[kWh]", "(m³)", "[m³]", "(m3)", "in kWh", "in m³", "in m3",
                        " kWh", " m³", " m3", "(l)", "(Liter)"] {
            if let range = s.range(of: pattern, options: [.caseInsensitive, .backwards]) {
                s.removeSubrange(range)
            }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    static func unitFrom(_ text: String?) -> MeasurementUnit? {
        guard let t = text?.lowercased() else { return nil }
        if t.contains("mwh") { return .megawattHour }
        if t.contains("kwh") { return .kilowattHour }
        if t.contains("m³") || t.contains("m3") || t.contains("kubik") || t.contains("cbm") { return .cubicMetre }
        if t.contains("gj") { return .gigajoule }
        if t == "l" || t.contains("liter") || t.contains("(l)") { return .litre }
        return nil
    }

    static func kindFrom(_ text: String, unit: MeasurementUnit?) -> ResourceKind {
        let t = text.lowercased()
        if t.containsAny(["warmwasser", "hot water"]) { return .hotWater }
        if t.containsAny(["wasser", "water"]) { return .water }
        if t.containsAny(["gas"]) { return .gas }
        if t.containsAny(["heizöl", "öl ", "oil"]) { return .heatingOil }
        if t.containsAny(["fernwärme", "wärmemenge", "heizung"]) { return .districtHeating }
        if t.containsAny(["wallbox", "e-auto", "auto", "laden"]) { return .wallbox }
        if t.containsAny(["pv", "photovoltaik", "solar", "erzeugung"]) { return .solarProduction }
        if t.containsAny(["strom", "wärmepumpe", "wp", "power", "electric", "haushalt", "einspeisung"]) { return .electricity }
        switch unit {
        case .cubicMetre?: return .water
        case .litre?: return .heatingOil
        default: return .electricity
        }
    }

    static func directionFrom(_ text: String) -> FlowDirection {
        let t = text.lowercased()
        if t.containsAny(["einspeisung", "rückspeisung", "2.8.0", "lieferung"]) { return .feedIn }
        if t.containsAny(["erzeugung", "ertrag"]) { return .production }
        return .consumption
    }

    // MARK: - Ordnen und prüfen

    /// Sortiert, fasst Doppelte zusammen und lässt Stände weg, die zurückgehen.
    static func tidy(_ raw: [Entry]) -> ([Entry], [Issue]) {
        let sorted = raw.enumerated().sorted { a, b in
            if a.element.day != b.element.day { return a.element.day < b.element.day }
            if let x = a.element.time, let y = b.element.time, x != y { return x < y }
            return a.offset < b.offset
        }.map(\.element)
        var out: [Entry] = []
        var issues: [Issue] = []
        var sinks = 0
        for entry in sorted {
            if let previous = out.last, previous.day == entry.day, previous.time == entry.time {
                if previous.value == entry.value {
                    issues.append(Issue(kind: .duplicate, line: entry.line,
                                        text: "Zeile \(entry.line): steht doppelt drin, einmal übernommen"))
                } else {
                    issues.append(Issue(kind: .sameDayDifferent, line: entry.line,
                                        text: "Zeile \(entry.line): Am \(deutsch(entry.day)) stehen zwei Stände. Übernommen ist \(format(previous.value)) aus Zeile \(previous.line)."))
                }
                continue
            }
            if let previous = out.last, entry.value < previous.value {
                sinks += 1
                issues.append(Issue(kind: .decreasing, line: entry.line,
                                    text: "Zeile \(entry.line): \(format(entry.value)) am \(deutsch(entry.day)) ist kleiner als der Stand davor (\(format(previous.value))). Nicht übernommen. War es ein Zählerwechsel, trag ihn in der App ein."))
                continue
            }
            out.append(entry)
        }
        // Fallen viele Werte, sind es Verbräuche je Zeitraum, keine Stände.
        // Ein einzelner Tippfehler ist noch kein Muster.
        if sorted.count >= 4, sinks >= 2, Double(sinks) / Double(sorted.count - 1) >= 0.25 {
            issues.insert(Issue(kind: .looksLikeConsumption, line: nil,
                                text: "Die Zahlen gehen oft zurück. Das sieht nach Verbrauch je Zeitraum aus und nicht nach Zählerständen."), at: 0)
        }
        return (out, issues)
    }

    // MARK: - Datum, Uhrzeit, Zahl

    static let monate: [String: Int] = [
        "jan": 1, "januar": 1, "jänner": 1, "feb": 2, "februar": 2, "mär": 3, "märz": 3, "mrz": 3, "maerz": 3,
        "mar": 3, "march": 3, "apr": 4, "april": 4, "mai": 5, "may": 5, "jun": 6, "juni": 6, "june": 6,
        "jul": 7, "juli": 7, "july": 7, "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9,
        "okt": 10, "oktober": 10, "oct": 10, "october": 10, "nov": 11, "november": 11,
        "dez": 12, "dezember": 12, "dec": 12, "december": 12
    ]

    /// Liest ein Datum, mit oder ohne Uhrzeit dahinter.
    ///
    /// `03.04.2025`, `3.4.25`, `2025-04-03`, `2025-04-03T08:15`, `03/04/2025`,
    /// `3. April 2025`. Ein Monat ohne Tag („April 2025") ist **kein** Datum:
    /// Wann abgelesen wurde, ließe sich nur raten.
    public static func parseDate(_ raw: String, order: DateOrder) -> (CalendarDay, TimeOfDay?)? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard s.count >= 6, s.count <= 30 else { return nil }
        var time: TimeOfDay?
        // Uhrzeit abtrennen: nach Leerzeichen, Komma oder „T".
        if s.contains(":") {
            if s.hasSuffix("Uhr") { s = String(s.dropLast(3)).trimmingCharacters(in: .whitespaces) }
            guard let trenner = s.lastIndex(where: { $0 == " " || $0 == "T" || $0 == "," }),
                  let zeit = parseTime(String(s[s.index(after: trenner)...])) else { return nil }
            time = zeit
            s = String(s[..<trenner]).trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        }
        func jahr(_ y: Int, _ text: Substring) -> Int { text.count <= 2 ? (y < 70 ? 2000 + y : 1900 + y) : y }
        func tag(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay? {
            guard (1990...2100).contains(y) else { return nil }
            return CalendarDay(year: y, month: m, day: d)
        }

        let teile = s.split(whereSeparator: { ".-/".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }
        if teile.count == 3, teile.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            let a = Int(teile[0])!, b = Int(teile[1])!, c = Int(teile[2])!
            if teile[0].count == 4 { return tag(a, b, c).map { ($0, time) } }                 // 2025-04-03
            let y = jahr(c, Substring(teile[2]))
            guard teile[2].count == 2 || teile[2].count == 4 else { return nil }
            let punkt = s.contains(".")
            // Mit Punkt ist es in Deutschland immer Tag.Monat. Nur beim
            // Schrägstrich kann es auch Monat/Tag sein.
            if punkt || order == .dayFirst { return tag(y, b, a).map { ($0, time) } }
            return tag(y, a, b).map { ($0, time) }
        }
        // „3. April 2025", „03. Apr. 2025"
        let worte = s.replacingOccurrences(of: ".", with: " ").split(separator: " ").map(String.init)
        if worte.count == 3, let d = Int(worte[0]), let m = monate[worte[1].lowercased()], let y = Int(worte[2]) {
            return tag(jahr(y, Substring(worte[2])), m, d).map { ($0, time) }
        }
        return nil
    }

    public static func parseTime(_ raw: String) -> TimeOfDay? {
        let s = raw.replacingOccurrences(of: "Uhr", with: "").trimmingCharacters(in: .whitespaces)
        let teile = s.split(separator: ":")
        guard teile.count == 2 || teile.count == 3, let h = Int(teile[0]), let m = Int(teile[1]),
              teile[0].count <= 2, teile[1].count == 2 else { return nil }
        return TimeOfDay(hour: h, minute: m)
    }

    /// Liest eine Zahl, deutsch oder englisch geschrieben, mit oder ohne
    /// Einheit dahinter. Liefert auch, wie viele Nachkommastellen dastanden.
    public static func parseNumber(_ raw: String, decimalComma: Bool) -> (Decimal, Int, String?)? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        var unit: String?
        // Einheit am Ende abtrennen („1.234,5 kWh"). Ohne regulären Ausdruck:
        // Der kostete bei 14.600 Zellen über eine Sekunde.
        // Nur ASCII-Ziffern: Swift hält auch das „³" in „m³" für eine Ziffer.
        if let letzteZiffer = s.lastIndex(where: { $0.isASCII && $0.isNumber }), letzteZiffer < s.index(before: s.endIndex) {
            let rest = s[s.index(after: letzteZiffer)...].trimmingCharacters(in: .whitespaces)
            guard unitFrom(rest) != nil else { return nil }
            unit = rest
            s = String(s[...letzteZiffer])
        }
        s = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "'", with: "")
        guard !s.isEmpty, s.contains(where: \.isNumber),
              s.enumerated().allSatisfy({ $0.element.isASCII && ($0.element.isNumber || $0.element == "." || $0.element == ","
                                                                 || ($0.element == "-" && $0.offset == 0)) })
        else { return nil }
        let negativ = s.hasPrefix("-")
        if negativ { s.removeFirst() }

        let komma = s.lastIndex(of: ","), punkt = s.lastIndex(of: ".")
        var dezimal: Character?
        if let komma, let punkt { dezimal = komma > punkt ? "," : "." }
        else if komma != nil { dezimal = decimalComma || !isThousandsGrouping(s, ",") ? "," : nil }
        else if punkt != nil { dezimal = !decimalComma || !isThousandsGrouping(s, ".") ? "." : nil }

        var ganz = s, nachkomma = ""
        if let dezimal, let i = s.lastIndex(of: dezimal) {
            ganz = String(s[..<i]); nachkomma = String(s[s.index(after: i)...])
        }
        ganz = ganz.filter(\.isNumber)
        guard !(ganz.isEmpty && nachkomma.isEmpty), nachkomma.allSatisfy(\.isNumber) else { return nil }
        guard let wert = Decimal(string: (ganz.isEmpty ? "0" : ganz) + (nachkomma.isEmpty ? "" : "." + nachkomma),
                                 locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return (negativ ? -wert : wert, nachkomma.count, unit)
    }

    /// `12.345.678` oder `12.345` mit genau drei Ziffern je Gruppe.
    static func isThousandsGrouping(_ s: String, _ sep: Character) -> Bool {
        let gruppen = s.split(separator: sep, omittingEmptySubsequences: false)
        guard gruppen.count >= 2, let erste = gruppen.first, (1...3).contains(erste.count) else { return false }
        return gruppen.dropFirst().allSatisfy { $0.count == 3 }
    }

    /// Komma oder Punkt als Dezimalzeichen, entschieden an der ganzen Tabelle.
    ///
    /// Eindeutig ist eine Zahl, in der beide stehen (das hintere ist das
    /// Dezimalzeichen), oder eine, bei der hinter dem Zeichen keine drei
    /// Ziffern folgen. Ohne Hinweis gilt das deutsche Komma.
    static func decideDecimalComma(_ cells: [String]) -> Bool {
        var komma = 0, punkt = 0
        for raw in cells.prefix(4_000) where raw.count <= 20 && raw.contains(where: \.isNumber) {
            let zahl = raw.filter { $0.isNumber || $0 == "," || $0 == "." }
            guard zahl.contains(",") || zahl.contains("."),
                  raw.allSatisfy({ $0.isNumber || ",.- ".contains($0) || $0.isLetter || $0 == "³" }) else { continue }
            // Ein Datum wie 03.04.2025 sagt nichts über Zahlen.
            if zahl.filter({ $0 == "." }).count >= 2, parseDate(raw, order: .dayFirst) != nil { continue }
            let k = zahl.lastIndex(of: ","), p = zahl.lastIndex(of: ".")
            if let k, let p { if k > p { komma += 1 } else { punkt += 1 }; continue }
            if k != nil, !isThousandsGrouping(zahl, ",") { komma += 1 }
            if p != nil, !isThousandsGrouping(zahl, ".") { punkt += 1 }
        }
        return komma >= punkt
    }

    static func decideDateOrder(_ cells: [String]) -> DateOrder {
        for raw in cells where raw.contains("/") {
            let teile = raw.split(separator: " ").first?.split(separator: "/") ?? []
            guard teile.count == 3, let a = Int(teile[0]), let b = Int(teile[1]) else { continue }
            if a > 12 { return .dayFirst }
            if b > 12 { return .monthFirst }
        }
        return .dayFirst
    }

    // MARK: - Text für Hinweise

    static func deutsch(_ day: CalendarDay) -> String {
        String(format: "%02d.%02d.%04d", day.day, day.month, day.year)
    }

    /// Über `FormatStyle` statt einen gemeinsamen `NumberFormatter`: Der gilt
    /// auf Linux als threadsicher, auf dem iPhone nicht, und eine Prüfung
    /// unter Linux sähe den Unterschied nie.
    static func format(_ value: Decimal) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(0...6)))
    }
}

private extension String {
    func containsAny(_ words: [String]) -> Bool { words.contains { contains($0) } }
}
