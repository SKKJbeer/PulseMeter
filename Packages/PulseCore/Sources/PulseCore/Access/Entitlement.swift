import Foundation

/// Was ein Nutzer freigeschaltet hat.
///
/// Bewusst zwei Fälle und kein Datum: PulseMeter Pro ist ein **Einmalkauf**
/// (docs/04-monetarisierung.md, Abschnitt 3). Er läuft nicht ab, also gibt es
/// keinen Zustand „war einmal Pro". Das erspart der ganzen App die Frage, was
/// mit Daten geschieht, die unter Pro entstanden sind — sie kann nicht
/// auftreten.
///
/// Das Vermieter-Abo ist hier absichtlich **nicht** vertreten. Es kommt nach
/// 1.0 und bringt eine zweite Achse mit (mehrere Objekte, Mieterzuordnung);
/// sie jetzt schon anzudeuten hieße, eine Struktur zu pflegen, die noch
/// niemand kennt.
public enum Entitlement: String, Hashable, Codable, Sendable, CaseIterable {

    /// Der Dauerzustand für alle, die nicht kaufen — kein Zeitlimit, keine
    /// Testphase, kein Ablauf.
    case free

    /// Nach dem Einmalkauf.
    case pro
}

/// Die Leistungen, die dem Kauf vorbehalten sind.
///
/// Die Aufzählung ist die **einzige** Stelle, an der steht, was Pro ausmacht.
/// Vorher stand es nur in `docs/04-monetarisierung.md`, und die Oberfläche
/// hatte gar keine Grenze — kostenlos war alles.
///
/// Was hier bewusst **fehlt**, ist genauso wichtig wie das, was dasteht:
/// Ablesungen, Historie, Vorjahresvergleich, Erinnerungen und der CSV-Export
/// sind dauerhaft kostenlos. Der Export ist Produktprinzip 5 („Datenfreiheit")
/// und darf nie hierher wandern — ein Zahlungsmodell, das die eigenen Daten
/// als Pfand nimmt, zerstört genau das Vertrauen, das dieses Produkt trägt.
public enum ProFeature: String, Hashable, Codable, Sendable, CaseIterable {

    /// Der dritte und jeder weitere Zähler.
    case additionalMeters

    /// Mehr als ein Zählwerk an einem Gerät: Tag- und Nachtstrom,
    /// Einspeisung ins Netz.
    case multipleRegisters

    /// Preise eintragen und Kosten sehen.
    case costsAndTariffs

    /// Abschlagsvergleich — Vorschau auf Nachzahlung oder Guthaben.
    case prepaymentComparison

    /// Hochrechnung auf das Jahresende.
    case yearlyForecast

    /// Der gestaltete PDF-Bericht.
    ///
    /// Nicht zu verwechseln mit dem CSV-Export: Der eine ist ein Dokument, der
    /// andere sind die eigenen Daten.
    case pdfReport

    /// Wie die Leistung in der Oberfläche heißt.
    ///
    /// Im Rechenkern und nicht in der Ansicht, weil dieselben Wörter an drei
    /// Stellen auftauchen — auf der Kaufseite, an der Sperre selbst und im
    /// Klick-Dummy. Drei Fassungen wären drei Gelegenheiten, etwas zu
    /// versprechen, das die Sperre anders abgrenzt.
    public var title: String {
        switch self {
        case .additionalMeters:      return "Unbegrenzt viele Zähler"
        case .multipleRegisters:     return "Tag- und Nachtstrom, Einspeisung"
        case .costsAndTariffs:       return "Kosten und Preise"
        case .prepaymentComparison:  return "Abschlagsvergleich"
        case .yearlyForecast:        return "Vorschau aufs Jahresende"
        case .pdfReport:             return "Bericht als PDF"
        }
    }

    /// Ein Satz, der sagt, wozu es gut ist — nicht, wie es gebaut ist.
    public var explanation: String {
        switch self {
        case .additionalMeters:
            return "Kostenlos sind zwei. Wer Strom, Gas und Wasser führt, braucht den dritten."
        case .multipleRegisters:
            return "Ein Gerät mit zwei Zahlen darauf: Nachtstrom, Wärmepumpe, Wallbox oder eine Anlage auf dem Dach."
        case .costsAndTariffs:
            return "Zwei Zahlen von der Rechnung, und aus dem Verbrauch wird ein Betrag."
        case .prepaymentComparison:
            return "Zeigt vor der Abrechnung, ob eine Nachzahlung kommt oder Geld zurück."
        case .yearlyForecast:
            return "Rechnet den angefangenen Zeitraum aufs Jahr hoch."
        case .pdfReport:
            return "Ein gestaltetes Dokument zum Weitergeben — an den Vermieter, den Steuerberater, das Amt."
        }
    }
}

/// Die Regel, wer was darf.
///
/// Ein eigener Typ statt eines Häkchens an jeder Ansicht: Die Grenze soll an
/// **einer** Stelle stehen und ohne Simulator prüfbar sein. Jede Ansicht fragt
/// sie, keine kennt sie.
public struct AccessPolicy: Hashable, Sendable {

    /// Wie viele Zähler kostenlos sind.
    ///
    /// Zwei, und die Zahl ist begründet (docs/04-monetarisierung.md): Der
    /// typische Mieter hat Strom und Wasser, wird nie zahlen und ist trotzdem
    /// ein zufriedener Nutzer. Der Eigenheimbesitzer hat vier bis sechs Zähler
    /// und stößt in der ersten Woche an die Grenze — im Moment des erkannten
    /// Nutzens, nicht davor.
    public static let freeMeterLimit = 2

    public let entitlement: Entitlement

    public init(_ entitlement: Entitlement) {
        self.entitlement = entitlement
    }

    public var isPro: Bool { entitlement == .pro }

    /// Ob eine Leistung offensteht.
    public func allows(_ feature: ProFeature) -> Bool { isPro }

    /// Ob ein **weiterer** Zähler angelegt werden darf.
    ///
    /// - Parameter existingCount: Wie viele Zähler es schon gibt, archivierte
    ///   eingeschlossen. Ein archivierter Zähler belegt seinen Platz weiter:
    ///   Er ist nicht gelöscht, seine Ablesungen liegen vollständig vor, und
    ///   er lässt sich jederzeit zurückholen. Zählte er nicht mit, wäre
    ///   Archivieren ein Weg, die Grenze zu umgehen — und der erste Nutzer,
    ///   der seine zwei archivierten Zähler zurückholt, stünde ohne Vorwarnung
    ///   über dem Limit.
    public func canAddMeter(existingCount: Int) -> Bool {
        isPro || existingCount < Self.freeMeterLimit
    }

    /// Was schon da ist, bleibt.
    ///
    /// **Die wichtigste Regel dieses Typs.** Die Grenze greift beim *Anlegen*,
    /// nie beim Ansehen, Ablesen, Ändern oder Ausführen. Ein Zähler, der
    /// bereits existiert, ist unabhängig vom Kauf vollständig benutzbar —
    /// einschließlich seiner Ablesungen und seines Exports.
    ///
    /// Warum das kein Loch ist: Pro ist ein Einmalkauf und läuft nicht ab, es
    /// kann also niemand aus Pro herausfallen und dann mehr Zähler haben, als
    /// ihm zustehen. Auftreten kann der Fall nur über die Beispieldaten und
    /// über einen Bestand, der aus iCloud zurückkommt — und in beiden Fällen
    /// wäre es unverzeihlich, dem Nutzer seine eigenen Zahlen wegzunehmen
    /// (Produktprinzip 5).
    public func canUse(existingMeterCount: Int) -> Bool { true }

    /// Wie viele Zähler noch frei sind, oder `nil` bei Pro.
    ///
    /// Für den Satz auf dem Schirm. Negative Werte werden auf null gezogen:
    /// Ein Bestand über der Grenze ist möglich (siehe ``canUse(existingMeterCount:)``),
    /// und „noch −2 frei" wäre keine Auskunft, sondern ein Fehler.
    public func remainingMeters(existingCount: Int) -> Int? {
        isPro ? nil : max(0, Self.freeMeterLimit - existingCount)
    }
}
