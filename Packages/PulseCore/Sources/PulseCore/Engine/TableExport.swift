import Foundation

/// Ausgabe als Tabelle für Tabellenkalkulationen.
///
/// Produktprinzip 5 — Datenfreiheit: Der Export bleibt dauerhaft kostenlos.
/// Wer seine Daten nicht wieder herausbekommt, hat sie nicht.
///
/// Semikolon statt Komma als Trennzeichen und Dezimalkomma statt Punkt: Die
/// Zielgruppe sitzt im deutschsprachigen Raum, und dort öffnet Excel eine
/// Datei mit Komma-Trennung in einer einzigen Spalte. Wer die Datei anders
/// braucht, kann sie umstellen — wer sie nur öffnen will, soll das können,
/// ohne einen Importdialog zu verstehen.
public enum TableExport {

    static let separator = ";"

    /// Alle Ablesungen eines Zählwerks, älteste zuerst.
    public static func readings(
        _ readings: [Reading],
        register: Register,
        meterName: String
    ) -> String {
        // Die Spalte „Uhrzeit" steht nur da, wenn wenigstens eine Ablesung eine
        // trägt — wie „Bezeichnung" weiter unten. Eine leere Spalte ist eine
        // Frage ohne Anlass: Der Leser weiß nicht, ob dort nichts steht oder
        // etwas fehlt.
        let mitUhrzeit = readings.contains { $0.time != nil }
        var lines = ["Zähler\(separator)Datum"
            + (mitUhrzeit ? "\(separator)Uhrzeit" : "")
            + "\(separator)Stand\(separator)Einheit\(separator)Art"]
        for reading in readings.chronological() {
            var felder = [escape(meterName), isoDate(reading.day)]
            if mitUhrzeit { felder.append(reading.time?.description ?? "") }
            felder.append(contentsOf: [
                decimal(reading.value, digits: register.fractionDigits),
                escape(register.unit.symbol),
                origin(reading.origin)
            ])
            lines.append(felder.joined(separator: separator))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Alle Ablesungen eines Zählers, älteste zuerst.
    ///
    /// **Warum es diese zweite Fassung gibt.** Ein Doppeltarifzähler führt zwei
    /// Zahlen. Wer nur die des ersten Zählwerks exportiert, verliert beim
    /// Export die Hälfte seiner Daten — und merkt es an der Datei nicht, weil
    /// sie vollständig aussieht. Produktprinzip 5 ist damit gebrochen, bevor
    /// jemand die Datei öffnet.
    ///
    /// Die Spalte „Bezeichnung" steht nur da, wenn es mehr als eine Zahl gibt.
    /// Bei einem gewöhnlichen Zähler bliebe sie leer und wäre eine Frage ohne
    /// Anlass.
    public static func readings(
        _ readings: [Reading],
        meteringPoint: MeteringPoint,
        meterName: String
    ) -> String {
        // Dieselbe Umsetzung wie „Alle Zähler als Tabelle“, mit einem Zähler.
        // Zwei Umsetzungen würden auseinanderlaufen, und dann passten eine
        // Datei aus dem Verlauf und eine aus dem Zähler-Tab nicht mehr
        // nebeneinander.
        table([Block(name: meterName, meteringPoint: meteringPoint, readings: readings)])
    }

    /// Ein Zähler mit seinen Ablesungen, für ``allMeters(_:)``.
    public struct MeterReadings: Sendable {
        public let meteringPoint: MeteringPoint
        public let readings: [Reading]

        public init(meteringPoint: MeteringPoint, readings: [Reading]) {
            self.meteringPoint = meteringPoint
            self.readings = readings
        }
    }

    /// Alle Ablesungen aller Zähler in **einer** Tabelle.
    ///
    /// Aus einer Rezension im Laden (12. November 2026): sieben Zähler, und
    /// jeder musste einzeln verschickt werden. Die Spalten sind dieselben wie
    /// beim Export je Zähler, damit beide Dateien nebeneinander passen und ein
    /// Filter auf „Zähler“ die Datei je Zähler zurückgibt.
    ///
    /// Reihenfolge: Zähler wie übergeben (die App gibt sie wie im Tab
    /// „Zähler“), darin nach Datum. „Bezeichnung“ und „Uhrzeit“ stehen da,
    /// sobald **ein** Zähler sie braucht — eine Tabelle hat für alle Zeilen
    /// dieselben Spalten, sonst verrutscht sie in Excel.
    ///
    /// Zwei Zähler mit demselben Namen bekämen sonst dieselben Zeilen-Köpfe,
    /// und beim Wiedereinlesen würden sie zu einem verschmolzen. Der zweite
    /// heißt deshalb „Wasser (2)“.
    public static func allMeters(_ meters: [MeterReadings]) -> String {
        var vergeben: [String: Int] = [:]
        var blocks: [Block] = []
        for meter in meters {
            let name = meter.meteringPoint.name
            let anzahl = (vergeben[name] ?? 0) + 1
            vergeben[name] = anzahl
            blocks.append(Block(name: anzahl == 1 ? name : "\(name) (\(anzahl))",
                                meteringPoint: meter.meteringPoint,
                                readings: meter.readings))
        }
        return table(blocks)
    }

    struct Block {
        let name: String
        let meteringPoint: MeteringPoint
        let readings: [Reading]
    }

    /// Die eine Umsetzung hinter beiden Exporten.
    ///
    /// **Warum es die Spalte „Bezeichnung“ gibt.** Ein Doppeltarifzähler führt
    /// zwei Zahlen. Wer nur die des ersten Zählwerks exportiert, verliert beim
    /// Export die Hälfte seiner Daten — und merkt es an der Datei nicht, weil
    /// sie vollständig aussieht. Produktprinzip 5 ist damit gebrochen, bevor
    /// jemand die Datei öffnet.
    ///
    /// Die Spalte steht nur da, wenn es irgendwo mehr als eine Zahl gibt. Bei
    /// gewöhnlichen Zählern bliebe sie leer und wäre eine Frage ohne Anlass.
    /// Dasselbe gilt für „Uhrzeit“.
    static func table(_ blocks: [Block]) -> String {
        let mitBezeichnung = blocks.contains { $0.meteringPoint.registers.count > 1 }
        let mitUhrzeit = blocks.contains { $0.readings.contains { $0.time != nil } }

        var kopf = ["Zähler"]
        if mitBezeichnung { kopf.append("Bezeichnung") }
        kopf.append("Datum")
        if mitUhrzeit { kopf.append("Uhrzeit") }
        kopf.append(contentsOf: ["Stand", "Einheit", "Art"])
        var lines = [kopf.joined(separator: separator)]

        for block in blocks {
            let punkt = block.meteringPoint
            let registers = punkt.registers
            let fallback = punkt.primaryRegister ?? registers.first
                ?? Register(unit: punkt.kind.defaultUnit)
            let byID = Dictionary(registers.map { ($0.id, $0) }, uniquingKeysWith: { erstes, _ in erstes })
            // Reihenfolge wie am Gerät, damit die Zeilen eines Tages so
            // untereinanderstehen wie sie abgelesen wurden.
            let order = Dictionary(registers.enumerated().map { ($0.element.id, $0.offset) },
                                   uniquingKeysWith: { erstes, _ in erstes })

            let sorted: [Reading]
            if registers.count > 1 {
                // Tag, dann Uhrzeit, dann Reihenfolge am Gerät. Die Zählwerke
                // einer Ablesung bleiben damit beieinander.
                sorted = block.readings.sorted {
                    if $0.day != $1.day { return $0.day < $1.day }
                    if let links = $0.time, let rechts = $1.time, links != rechts { return links < rechts }
                    return (order[$0.registerID] ?? 0) < (order[$1.registerID] ?? 0)
                }
            } else {
                sorted = block.readings.chronological()
            }

            for reading in sorted {
                // Ein gewöhnlicher Zähler hat ein Zählwerk; jede seiner
                // Ablesungen gehört dazu, auch wenn die Kennung abweicht.
                let register = registers.count > 1 ? (byID[reading.registerID] ?? fallback) : fallback
                var felder = [escape(block.name)]
                if mitBezeichnung {
                    felder.append(registers.count > 1 ? escape(name(of: register)) : "")
                }
                felder.append(isoDate(reading.day))
                if mitUhrzeit { felder.append(reading.time?.description ?? "") }
                felder.append(contentsOf: [
                    decimal(reading.value, digits: register.fractionDigits),
                    escape(register.unit.symbol),
                    origin(reading.origin)
                ])
                lines.append(felder.joined(separator: separator))
            }
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Wie ein Zählwerk in der Tabelle heißt.
    ///
    /// Ein leeres Feld neben „Einspeisung" wäre eine Frage: Der Leser weiß
    /// nicht, ob dort nichts steht oder etwas fehlt. Ohne eigenen Namen ergibt
    /// er sich aus der Richtung.
    static func name(of register: Register) -> String {
        if let label = register.label, !label.isEmpty { return label }
        switch register.direction {
        case .consumption: return "Bezug"
        case .feedIn:      return "Einspeisung"
        case .production:  return "Erzeugung"
        case .charge:      return "Ladung"
        case .discharge:   return "Entladung"
        }
    }

    /// Auswertung nach Monaten, Quartalen oder Jahren.
    ///
    /// Die Spalte „Vollständig" ist kein Beiwerk. Ohne sie steht in der
    /// Tabellenkalkulation eine Zahl für einen laufenden Monat neben elf
    /// abgeschlossenen, und die Summe darunter wirkt wie ein Jahr. Genau diese
    /// Verwechslung ist die wiederkehrende Fehlerklasse dieses Projekts —
    /// exportiert man sie mit, wandert sie in jede Tabelle weiter.
    public static func breakdown(
        _ buckets: [PeriodEngine.Bucket],
        unit: MeasurementUnit,
        meterName: String,
        fractionDigits: Int = 0
    ) -> String {
        var lines = [[
            "Zähler", "Zeitraum", "Von", "Bis", "Verbrauch", "Einheit",
            "Tage", "Vollständig"
        ].joined(separator: separator)]

        for bucket in buckets {
            let covered = bucket.result.coveredRange
            lines.append([
                escape(meterName),
                escape(label(for: bucket)),
                covered.map { isoDate($0.start) } ?? "",
                covered.map { isoDate($0.end) } ?? "",
                bucket.hasData ? decimal(bucket.value, digits: fractionDigits) : "",
                escape(unit.symbol),
                String(bucket.result.coveredDays),
                bucket.hasData ? (bucket.isComplete ? "ja" : "nein") : "keine Daten"
            ].joined(separator: separator))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Bausteine

    static func label(for bucket: PeriodEngine.Bucket) -> String {
        switch bucket.granularity {
        case .month: return "\(monthNames[bucket.slot - 1]) \(bucket.year)"
        case .quarter: return "Q\(bucket.slot) \(bucket.year)"
        case .year: return "\(bucket.year)"
        }
    }

    static let monthNames = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                             "Juli", "August", "September", "Oktober", "November", "Dezember"]

    /// ISO-Datum in der Datei, deutsches Datum auf dem Schirm: Eine Tabelle
    /// wird sortiert und weiterverarbeitet, und `2026-05-01` sortiert richtig.
    static func isoDate(_ day: CalendarDay) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    /// Feste Nachkommastellen, nachgestellte Nullen eingeschlossen.
    ///
    /// `8000,250` statt `8000,25`: Der Export eines Zählerstands ist ein
    /// Beleg — er soll zeigen, mit welcher Genauigkeit das Gerät anzeigt. Über
    /// ``ScaledDecimal`` und nicht über `Double`, weil genau dieser Umweg die
    /// krummen Werte erzeugt, gegen die es diesen Typ gibt.
    static func decimal(_ value: Decimal, digits: Int) -> String {
        let scaled = ScaledDecimal(value, scale: Swift.max(0, digits))
        let sign = scaled.scaled < 0 ? "-" : ""
        let magnitude = String(abs(scaled.scaled))
        guard digits > 0 else { return sign + magnitude }
        let padded = String(repeating: "0", count: Swift.max(0, digits + 1 - magnitude.count)) + magnitude
        let cut = padded.index(padded.endIndex, offsetBy: -digits)
        return sign + padded[..<cut] + "," + padded[cut...]
    }

    static func origin(_ origin: ReadingOrigin) -> String {
        switch origin {
        case .manual: return "abgelesen"
        case .camera: return "Kamera"
        case .imported: return "eingelesen"
        case .estimated: return "geschätzt"
        }
    }

    /// Zeichen, mit denen eine Tabellenkalkulation eine **Formel** beginnt.
    ///
    /// Auch `-` gehört dazu, obwohl es harmlos aussieht: `-2+3` rechnet Excel
    /// ebenso wie `=2+3`.
    private static let formelStart: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

    /// Felder mit Trennzeichen, Anführungszeichen oder Zeilenumbruch werden
    /// eingefasst — ein Zählername darf alles enthalten, was der Nutzer tippt.
    ///
    /// **Und Formeln werden entschärft.** Ein Zähler namens
    /// `=HYPERLINK("http://…")` ist in der Datei nur Text; beim Öffnen in
    /// Excel, Numbers oder LibreOffice wird daraus eine Formel, die beim
    /// bloßen Ansehen der Tabelle läuft. Einfassen allein hilft nicht — auch
    /// `"=1+1"` wird ausgewertet. Davor steht deshalb ein Apostroph, das
    /// Zeichen, mit dem Tabellenkalkulationen seit jeher „das ist Text"
    /// meinen.
    ///
    /// **Warum das hier zählt, obwohl der Nutzer seine Namen selbst tippt:**
    /// Der Export ist zum **Weitergeben** gedacht — an den Vermieter, an den
    /// Mieter, an die Steuerberatung. Sobald jemand anderes die Datei öffnet,
    /// ist der Name kein selbst gewählter mehr, sondern fremde Eingabe. Für
    /// die Vermieter-Fassung (`04-monetarisierung.md`) gilt das doppelt.
    static func escape(_ text: String) -> String {
        var wert = text
        if let erstes = wert.first, formelStart.contains(erstes) {
            wert = "'" + wert
        }
        guard wert.contains(separator) || wert.contains("\"") || wert.contains("\n") || wert.contains("\r")
        else { return wert }
        return "\"" + wert.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
