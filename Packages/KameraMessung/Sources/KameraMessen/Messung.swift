import Foundation
import PulseCore

/// Ein Foto der Sammlung, wie `docs/kamera/fotos.json` es beschreibt.
struct Foto: Decodable {
    let datei: String
    let art: String
    /// Von Hand abgelesen; `nil`, wenn eine Erkennung **nichts** vorschlagen soll.
    let stand: String?
    let vorkommastellen: Int
    let nachkommastellen: Int

    var soll: Decimal? { stand.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) } }
    var format: MeterFormat { MeterFormat(integerDigits: vorkommastellen, fractionDigits: nachkommastellen) }
    var name: String { (datei as NSString).lastPathComponent.replacingOccurrences(of: ".jpg", with: "") }
}

struct Sammlung: Decodable { let fotos: [Foto] }

enum Urteil: String {
    case richtig, nichts, falsch
}

/// **Falsch ist, was schlimmer ist als nichts.** Ein Vorschlag, der nicht dem
/// Soll-Stand entspricht, ist falsch, und ebenso einer bei einem Foto, auf dem
/// keiner stehen soll (leeres Display, Datum, Zeiger).
func urteil(_ ergebnis: MeterTextReader.Outcome, soll: Decimal?) -> Urteil {
    switch ergebnis {
    case .none: return .nichts
    case .proposal(let vorschlag): return soll != nil && vorschlag.value == soll ? .richtig : .falsch
    }
}

/// Der Bereich, den die App bei einer **zweiten** Ablesung mitgäbe: um den
/// Soll-Stand herum, großzügig. Bei Fotos ohne Soll-Stand ein **enger** Bereich
/// um einen gedachten letzten Stand: Ein weiter Bereich ließe jede Zahl vom
/// Typenschild durch und prüfte nicht, was die App tut, denn die hat nach einer
/// Ablesung immer einen engen (letzter Stand bis das Vierfache des Üblichen).
func bereich(soll: Decimal?, format: MeterFormat) -> ClosedRange<Decimal> {
    guard let soll else { return 12_345...13_845 }
    return max(0, soll - 100)...(soll + 100)
}

struct Zeile {
    let foto: Foto
    let texte: [RecognizedText]
    let erste: MeterTextReader.Outcome
    let zweite: MeterTextReader.Outcome

    var ersteUrteil: Urteil { urteil(erste, soll: foto.soll) }
    var zweiteUrteil: Urteil { urteil(zweite, soll: foto.soll) }
}

func auswerten(_ foto: Foto, texte: [RecognizedText]) -> Zeile {
    Zeile(
        foto: foto, texte: texte,
        erste: MeterTextReader.propose(from: texte, format: foto.format),
        zweite: MeterTextReader.propose(from: texte, format: foto.format, plausible: bereich(soll: foto.soll, format: foto.format)))
}

func beschreibe(_ ergebnis: MeterTextReader.Outcome) -> String {
    switch ergebnis {
    case .proposal(let v): return "\(v.value)"
    case .none(let grund): return "– (\(grund))"
    }
}

/// Der Bericht: eine Zeile je Foto, darunter die Summen. Soll und Vorschlag
/// stehen nebeneinander, damit ein falscher Vorschlag sofort auffällt.
func bericht(_ zeilen: [Zeile], mitTexten: Bool) -> String {
    func fest(_ s: String, _ n: Int) -> String { s.count >= n ? String(s.prefix(n)) : s + String(repeating: " ", count: n - s.count) }
    var out = [fest("Foto", 26) + fest("Soll", 10) + fest("Erste Ablesung", 30) + "Zweite Ablesung"]
    for z in zeilen {
        let soll = z.foto.stand ?? "nichts"
        out.append(fest(z.foto.name, 26) + fest(soll, 10)
                   + fest("\(z.ersteUrteil.rawValue.uppercased()): \(beschreibe(z.erste))", 30)
                   + "\(z.zweiteUrteil.rawValue.uppercased()): \(beschreibe(z.zweite))")
        if mitTexten { out.append("    gelesen: " + z.texte.map { "\($0.text)(\(Int($0.confidence * 100)))" }.joined(separator: " | ")) }
    }
    func summe(_ nimm: (Zeile) -> Urteil) -> String {
        let u = zeilen.map(nimm)
        return "\(u.filter { $0 == .richtig }.count) richtig, \(u.filter { $0 == .nichts }.count) nichts, \(u.filter { $0 == .falsch }.count) FALSCH"
    }
    let ablesbar = zeilen.filter { $0.foto.stand != nil }.count
    out.append("")
    out.append("\(zeilen.count) Fotos, davon \(ablesbar) mit ablesbarem Stand.")
    out.append("Erste Ablesung (ohne Bereich): " + summe(\.ersteUrteil))
    out.append("Zweite Ablesung (mit Bereich): " + summe(\.zweiteUrteil))
    return out.joined(separator: "\n")
}

/// Ob irgendwo ein falscher Vorschlag steht: Das Ziel für Stufe 1 ist keiner.
func hatFalsche(_ zeilen: [Zeile]) -> Bool {
    zeilen.contains { $0.ersteUrteil == .falsch || $0.zweiteUrteil == .falsch }
}
