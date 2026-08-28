import Foundation

/// Was einzeln freigeschaltet werden kann.
///
/// **Warum kleine Stücke statt eines großen Kaufs.** Ein einzelner Kauf über
/// 14,99 € ist eine Entscheidung, die jemand vertagt — und vertagte
/// Entscheidungen werden nie getroffen. Drei Euro für die eine Sache, die
/// gerade fehlt, sind keine Entscheidung, sondern ein Tipp. Wer später mehr
/// braucht, kauft mehr; wer alles will, nimmt das Bündel und spart ein Drittel.
///
/// **Warum vier und nicht sechs.** Abschlagsvergleich und Jahresvorschau
/// lassen sich ohne Preise gar nicht rechnen — sie einzeln zu verkaufen hieße,
/// etwas anzubieten, das ohne einen zweiten Kauf nichts tut. Sie gehören
/// deshalb zu ``costsAndTariffs``.
///
/// **Was hier bewusst fehlt: der Export.** Er bleibt dauerhaft kostenlos, und
/// das ist keine Preisfrage, sondern Produktprinzip 5. Der freie Export ist
/// das stärkste Argument gegen die Sorge „was, wenn die App eingestellt wird" —
/// genau die Sorge, die Menschen bei Excel hält. Wer ihn verkauft, löst ein
/// paar Euro und verliert das Argument, das alles andere trägt.
public enum ProductID: String, Hashable, Codable, Sendable, CaseIterable, Identifiable {

    /// Die Kennung ist der Kauf selbst — es gibt jeden nur einmal.
    ///
    /// Damit lässt sich ein Kaufblatt an dem Produkt aufhängen, das jemand
    /// angetippt hat, statt an einem Schalter daneben. Zwei Zustände für eine
    /// Sache geraten aus dem Takt; einer kann das nicht.
    public var id: String { rawValue }

    /// Der dritte und jeder weitere Zähler.
    case additionalMeters

    /// Mehr als ein Zählwerk an einem Gerät: Tag- und Nachtstrom, Einspeisung.
    case multipleRegisters

    /// Preise eintragen, Kosten sehen — und damit auch Abschlagsvergleich und
    /// Vorschau aufs Jahresende, die ohne Preise nicht rechnen können.
    case costsAndTariffs

    /// Der gestaltete Bericht ohne Wasserzeichen.
    ///
    /// **Nicht der Bericht selbst.** Er lässt sich auch ungekauft ansehen,
    /// blättern und drucken — quer darüber steht dann ein Wasserzeichen. Wer
    /// das Dokument weitergeben will, kauft es frei. Das ist ehrlicher als
    /// eine Sperre: Man sieht vorher, was man bekommt.
    case pdfReport

    /// Alles auf einmal, günstiger als die Summe.
    case everything

    /// Die Produkt-Kennung im App Store.
    ///
    /// Fest verdrahtet und nie abgeleitet: Diese Zeichenketten stehen in App
    /// Store Connect und dürfen sich nie ändern — ein umbenanntes Produkt ist
    /// für jeden, der es gekauft hat, ein verlorener Kauf.
    public var storeIdentifier: String {
        "de.karjoth.pulsemeter." + rawValue.lowercased()
    }

    /// Was der Kauf freischaltet, in der Sprache des Nutzers.
    public var title: String {
        switch self {
        case .additionalMeters:  return "Unbegrenzt viele Zähler"
        case .multipleRegisters: return "Tag- und Nachtstrom, Einspeisung"
        case .costsAndTariffs:   return "Kosten und Preise"
        case .pdfReport:         return "Bericht ohne Wasserzeichen"
        case .everything:        return "Alles freischalten"
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
            return "Zwei Zahlen von der Rechnung, und aus dem Verbrauch wird ein Betrag — mit Abschlagsvergleich und Vorschau aufs Jahresende."
        case .pdfReport:
            return "Der Bericht zum Weitergeben, ohne den Schriftzug quer darüber. Ansehen und drucken kannst du ihn auch so."
        case .everything:
            return "Alle vier Freischaltungen zusammen, dauerhaft. Günstiger als einzeln."
        }
    }

    /// Was darin enthalten ist — als Stichpunkte, nicht als Absatz.
    ///
    /// **Warum zusätzlich zu ``explanation``.** Der Satz sagt, *wozu* etwas gut
    /// ist, und das trägt, solange man vor genau dieser einen Sperre steht. Wer
    /// dagegen vor der Liste aller Käufe steht, will nicht vier Absätze lesen,
    /// sondern in fünf Sekunden sehen, was er bekommt. Vom Gründer verlangt:
    /// „nicht so viel Fließtext, sondern einfach nur die klaren Stichpunkte,
    /// was alles enthalten ist."
    ///
    /// Drei Zeilen sind die Grenze, und jede beginnt mit dem Gegenstand, nicht
    /// mit einem Verb: In einer Liste liest man die erste Spalte.
    public var includes: [String] {
        switch self {
        case .additionalMeters:
            return ["Beliebig viele Zähler statt zwei",
                    "Strom, Gas, Wasser und Wärme nebeneinander"]
        case .multipleRegisters:
            return ["Zwei Zählwerke an einem Gerät",
                    "Tag- und Nachtstrom getrennt",
                    "Einspeisung neben dem Bezug"]
        case .costsAndTariffs:
            return ["Grundpreis und Arbeitspreis eintragen",
                    "Kosten statt nur Verbrauch",
                    "Abschlagsvergleich und Vorschau aufs Jahresende"]
        case .pdfReport:
            return ["Bericht ohne Wasserzeichen",
                    "Zum Weitergeben an Vermieter oder Versorger"]
        case .everything:
            return ProductID.individually.map(\.title)
        }
    }

    /// Was dauerhaft nichts kostet — und deshalb genannt gehört.
    ///
    /// **Die Liste steht neben den Preisen, nicht im Kleingedruckten.** Die
    /// häufigste Sorge bei einer Zähler-App ist nicht der Preis, sondern die
    /// Angst, später nicht mehr an die eigenen Zahlen zu kommen. Der freie
    /// Export ist die Antwort darauf (Produktprinzip 5), und der Abgleich
    /// zwischen Geräten gehört genannt, weil ihn sonst niemand bemerkt: Er
    /// läuft von selbst und kostet nichts.
    public static let alwaysFree: [String] = [
        "Zwei Zähler mit unbegrenzt vielen Ablesungen",
        "Die ganze Historie und der Vorjahresvergleich",
        "Abgleich zwischen deinen Geräten über iCloud",
        "Erinnerungen an fällige Ablesungen",
        "Export aller Daten als Tabelle — dauerhaft kostenlos",
    ]

    /// Der Preis, den die App nennt, solange StoreKit keinen liefert.
    ///
    /// **Nur ein Platzhalter.** Sobald die App im Store ist, kommt der Preis
    /// von dort — in der Währung des Ladens, in dem der Nutzer steht, und mit
    /// der Steuer seines Landes. Eine fest verdrahtete Zahl wäre in der
    /// Schweiz falsch und in Österreich womöglich auch.
    public var suggestedPrice: Decimal {
        switch self {
        case .costsAndTariffs: return Decimal(string: "3.99")!
        case .everything:      return Decimal(string: "9.99")!
        default:               return Decimal(string: "2.99")!
        }
    }

    /// Die vier einzeln käuflichen Stücke, in der Reihenfolge, in der sie auf
    /// der Kaufseite stehen. Das Bündel gehört nicht dazu — es steht darunter.
    public static var individually: [ProductID] {
        [.additionalMeters, .multipleRegisters, .costsAndTariffs, .pdfReport]
    }
}

/// Was ein Nutzer gekauft hat.
///
/// Eine Menge und kein Schalter: Seit 0.40.0 wird einzeln freigeschaltet, und
/// „gekauft oder nicht" ließe sich nicht mehr beantworten, ohne zu fragen
/// *was*.
public struct Entitlement: Hashable, Codable, Sendable {

    public private(set) var owned: Set<ProductID>

    public init(_ owned: Set<ProductID> = []) {
        self.owned = owned
    }

    /// Nichts gekauft — der Zustand, in dem jeder anfängt und in dem viele
    /// dauerhaft bleiben. Er ist kein Mangel: Zwei Zähler, alle Ablesungen,
    /// die ganze Historie und der Export gehören dazu.
    public static let none = Entitlement()

    /// Alles gekauft. Nur für Prüfungen und Bildschirmfotos gedacht.
    public static let everything = Entitlement([.everything])

    /// Ob ein Produkt offensteht — direkt gekauft oder über das Bündel.
    public func owns(_ product: ProductID) -> Bool {
        owned.contains(product) || owned.contains(.everything)
    }

    public var ownsAnything: Bool { !owned.isEmpty }

    public mutating func add(_ product: ProductID) {
        owned.insert(product)
    }

    // MARK: - Speicherform

    /// Als Zeichenkette für `UserDefaults`.
    ///
    /// Sortiert, damit derselbe Bestand immer dieselbe Zeichenkette ergibt —
    /// sonst ist nicht zu erkennen, ob sich etwas geändert hat.
    public var storageValue: String {
        owned.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Unbekannte Einträge werden übergangen statt den ganzen Bestand zu
    /// verwerfen: Wer mit einer neueren Fassung etwas gekauft hat und die
    /// ältere startet, soll den Rest behalten.
    public init(storageValue: String) {
        let ids = storageValue
            .split(separator: ",")
            .compactMap { ProductID(rawValue: String($0)) }
        self.init(Set(ids))
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

    /// Ob eine Leistung offensteht.
    public func allows(_ product: ProductID) -> Bool { entitlement.owns(product) }

    /// Ob ein **weiterer** Zähler angelegt werden darf.
    ///
    /// - Parameter existingCount: Wie viele Zähler es schon gibt, archivierte
    ///   eingeschlossen. Ein archivierter Zähler belegt seinen Platz weiter:
    ///   Er ist nicht gelöscht, seine Ablesungen liegen vollständig vor, und
    ///   er lässt sich jederzeit zurückholen. Zählte er nicht mit, wäre
    ///   Archivieren ein Weg, die Grenze zu umgehen.
    public func canAddMeter(existingCount: Int) -> Bool {
        allows(.additionalMeters) || existingCount < Self.freeMeterLimit
    }

    /// Was schon da ist, bleibt.
    ///
    /// **Die wichtigste Regel dieses Typs.** Die Grenze greift beim *Anlegen*,
    /// nie beim Ansehen, Ablesen, Ändern oder Ausführen. Ein Zähler, der
    /// bereits existiert, ist unabhängig vom Kauf vollständig benutzbar —
    /// einschließlich seiner Ablesungen und seines Exports.
    ///
    /// Auftreten kann ein Bestand über der Grenze über die Beispieldaten und
    /// über iCloud — und in beiden Fällen wäre es unverzeihlich, dem Nutzer
    /// seine eigenen Zahlen wegzunehmen (Produktprinzip 5).
    public func canUse(existingMeterCount: Int) -> Bool { true }

    /// Wie viele Zähler noch frei sind, oder `nil` bei freigeschalteten Zählern.
    ///
    /// Negative Werte werden auf null gezogen: Ein Bestand über der Grenze ist
    /// möglich, und „noch −2 frei" wäre keine Auskunft, sondern ein Fehler.
    public func remainingMeters(existingCount: Int) -> Int? {
        allows(.additionalMeters) ? nil : max(0, Self.freeMeterLimit - existingCount)
    }

    /// Ob der Bericht ein Wasserzeichen trägt.
    ///
    /// Ansehen und drucken darf ihn jeder — das Wasserzeichen ist keine Sperre,
    /// sondern der Unterschied zwischen „für mich" und „zum Weitergeben".
    public var reportIsWatermarked: Bool { !allows(.pdfReport) }
}
