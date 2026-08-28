import Foundation
import Observation
import PulseCore

/// Woher der Kauf kommt.
///
/// **Warum ein Protokoll und keine StoreKit-Aufrufe.** Der Kauf selbst braucht
/// das Apple Developer Program — ohne Programm gibt es keine Produkt-Kennung,
/// keinen Sandkasten und nichts zu testen. Alles *um* den Kauf herum braucht es
/// nicht: die Grenze, die Sperren, die Kaufseite, die Bilder davon und die
/// Oberflächenprüfungen. Getrennt gebaut ist beides jetzt fertig bis auf die
/// eine Datei, die später `StoreKitGateway` heißen wird.
///
/// Der Zuschnitt ist mit Absicht klein: kaufen, wiederherstellen, und die
/// Auskunft, ob überhaupt gekauft werden kann.
///
/// **Warum `@MainActor`.** Zwei der vier Mitglieder sind synchron —
/// ``isAvailable`` und ``displayPrice(for:)`` beantworten Fragen, die eine
/// Ansicht beim Zeichnen stellt, und ein `await` beim Zeichnen gibt es nicht.
/// Ein Vermittler, der nebenher mit dem Store spricht, muss seinen Zustand
/// deshalb auf dem Hauptakteur halten. `Purchase` liegt ohnehin dort.
@MainActor
protocol PurchaseGateway: Sendable {

    /// Ob der Kauf zur Verfügung steht.
    ///
    /// `false`, solange die App nicht im App Store ist. Die Kaufseite zeigt
    /// dann ihre Leistungen und **keinen** Knopf, der nichts tut — ein Knopf,
    /// der ins Leere greift, ist schlimmer als kein Knopf.
    var isAvailable: Bool { get }

    /// Was der Store beim letzten Laden geantwortet hat, in einem Satz.
    ///
    /// **Warum eine Ansicht das überhaupt erfährt.** Drei Tage lang stand auf
    /// der Kaufseite „Kaufen geht, sobald PulseMeter im App Store ist" — ein
    /// Satz, der eine Ursache behauptet, ohne eine zu kennen. In Wahrheit
    /// wusste niemand, ob der Store nichts liefert, einen Fehler wirft oder
    /// gar nicht gefragt wurde. Gesucht wurde derweil in App Store Connect,
    /// bei den Käufen, bei den Verträgen — an jeder Stelle außer der einen,
    /// die die Antwort hat.
    ///
    /// `nil`, solange nichts geladen wurde. Sonst steht hier, was gezählt oder
    /// was geworfen wurde — ungeschönt, damit die nächste Suche eine Richtung
    /// hat statt einer Vermutung.
    var storeDiagnosis: String? { get }

    /// Kauft ein einzelnes Produkt.
    func purchase(_ product: ProductID) async throws -> Entitlement
    /// Holt zurück, was schon gekauft wurde — auf einem neuen Gerät der einzige
    /// Weg an die Käufe.
    func restore() async throws -> Entitlement
    /// Der Preis, wie ihn der Store dieses Nutzers nennt.
    ///
    /// `nil`, solange keiner vorliegt; dann zeigt die App den hinterlegten
    /// Vorschlagspreis mit einem „ca." davor. Eine fest verdrahtete Zahl ohne
    /// Kennzeichnung wäre in der Schweiz falsch.
    func displayPrice(for product: ProductID) -> String?
}

/// Der Stand ohne Programm: nichts zu kaufen.
///
/// Kein Platzhalter, der so tut, als ginge es — sondern einer, der ehrlich
/// sagt, dass es noch nicht geht.
struct UnavailablePurchaseGateway: PurchaseGateway {

    var isAvailable: Bool { false }
    var storeDiagnosis: String? { "Ohne StoreKit — dieser Stand fragt den Store gar nicht." }

    enum Unavailable: Error { case notYetInTheStore }

    func purchase(_ product: ProductID) async throws -> Entitlement {
        throw Unavailable.notYetInTheStore
    }
    func restore() async throws -> Entitlement { throw Unavailable.notYetInTheStore }
    func displayPrice(for product: ProductID) -> String? { nil }
}

/// Was der Nutzer freigeschaltet hat, und wo das steht.
///
/// **Warum `UserDefaults` und nicht der Schlüsselbund.** Die Wahrheit über
/// einen Kauf ist die Transaktion bei Apple, nicht ein Häkchen auf dem Gerät;
/// StoreKit prüft sie bei jedem Start nach. Was hier liegt, ist ein
/// Zwischenspeicher, damit die Oberfläche beim Start nicht erst kostenlos
/// aussieht und eine Sekunde später umspringt. Als Schutz taugt es nicht, und
/// das ist in Ordnung: Wer ein Häkchen auf seinem eigenen Gerät umlegt, um
/// 14,99 € zu sparen, wäre auch sonst kein Käufer geworden — und ein
/// Kopierschutz, der ehrliche Nutzer aussperrt, kostet mehr, als er einbringt.
///
/// Seit 0.40.0 ist es eine **Menge** und kein Schalter: Es wird einzeln
/// freigeschaltet, und „gekauft oder nicht" ließe sich nicht mehr beantworten,
/// ohne zu fragen *was*.
@MainActor
@Observable
final class Purchase {

    private static let storageKey = "pulse.entitlement"

    private let defaults: UserDefaults
    let gateway: PurchaseGateway

    /// Was gerade gilt.
    private(set) var entitlement: Entitlement

    /// Läuft gerade ein Kauf? Für den Knopf auf der Kaufseite.
    private(set) var isWorking = false

    /// Der letzte Fehlschlag, in einem Satz für den Nutzer.
    private(set) var problem: String?

    var policy: AccessPolicy { AccessPolicy(entitlement) }

    init(defaults: UserDefaults = .standard, gateway: PurchaseGateway = UnavailablePurchaseGateway()) {
        self.defaults = defaults
        self.gateway = gateway

        // Startschalter vor dem gespeicherten Wert. Nur so lässt sich beides
        // fotografieren und prüfen: der Zustand vor dem Kauf und der danach.
        // Im Alltag ist keiner der beiden Schalter gesetzt.
        //
        // `-pulse-frei` wird **zuerst** geprüft und gewinnt deshalb, wenn beide
        // gesetzt sind. `scripts/run.sh` hängt `-pulse-pro` an jeden Start an,
        // damit die Beispieldaten vollständig zu sehen sind; die zwei Bilder
        // vom Zustand vor dem Kauf müssen das überstimmen können, ohne dass
        // die Reihenfolge der Schalter auf der Kommandozeile eine Rolle spielt.
        if Startschalter.gesetzt("-pulse-frei") {
            entitlement = .none
        } else if Startschalter.gesetzt("-pulse-pro") {
            entitlement = .everything
        } else {
            entitlement = Entitlement(storageValue: defaults.string(forKey: Self.storageKey) ?? "")
        }
    }

    /// Ob eine Leistung offensteht — die Frage, die jede Ansicht stellt.
    func allows(_ product: ProductID) -> Bool { policy.allows(product) }

    func canAddMeter(existingCount: Int) -> Bool { policy.canAddMeter(existingCount: existingCount) }

    /// Ob der Bericht ein Wasserzeichen trägt.
    var reportIsWatermarked: Bool { policy.reportIsWatermarked }

    /// Der Preis, den die Kaufseite nennt.
    ///
    /// Zuerst der des Stores, sonst der hinterlegte Vorschlag mit „ca." davor.
    /// Ohne diese Kennzeichnung stünde dort eine Zahl, die im Ausland nicht
    /// stimmt — und ein Preis, der beim Antippen ein anderer ist, ist der
    /// schnellste Weg zu einer schlechten Bewertung.
    func price(for product: ProductID) -> String {
        if let fromStore = gateway.displayPrice(for: product) { return fromStore }
        let value = product.suggestedPrice.formatted(
            .currency(code: "EUR").locale(Locale(identifier: "de_DE")))
        return gateway.isAvailable ? value : "ca. " + value
    }

    func buy(_ product: ProductID) async {
        await run { try await gateway.purchase(product) }
    }

    func restore() async {
        await run { try await gateway.restore() }
    }

    private func run(_ work: () async throws -> Entitlement) async {
        isWorking = true
        problem = nil
        defer { isWorking = false }
        do {
            apply(try await work())
        } catch UnavailablePurchaseGateway.Unavailable.notYetInTheStore {
            problem = "Der Kauf steht bereit, sobald PulseMeter im App Store ist."
        } catch {
            // Ein Abbruch durch den Nutzer ist kein Fehler und bekommt keinen
            // roten Kasten; alles andere schon, und zwar mit dem Grund.
            problem = "Der Kauf ließ sich nicht abschließen. \(error.localizedDescription)"
        }
    }

    /// **Käufe werden zusammengelegt, nie ersetzt.**
    ///
    /// Der Vermittler meldet, was er gerade bestätigt hat. Käme dabei nur das
    /// eben gekaufte Stück zurück, verlöre der Nutzer bei jedem weiteren Kauf
    /// alle vorherigen — und zwar still.
    private func apply(_ confirmed: Entitlement) {
        var merged = entitlement
        for product in confirmed.owned { merged.add(product) }
        entitlement = merged
        defaults.set(merged.storageValue, forKey: Self.storageKey)
    }

    /// Übernimmt, was der Store sagt — **auch nach unten**.
    ///
    /// **Der Unterschied zu ``apply(_:)`` ist der ganze Punkt.** Nach einem
    /// einzelnen Kauf meldet der Vermittler nur das eben Bestätigte; würde das
    /// den Bestand ersetzen, verlöre der Nutzer bei jedem weiteren Kauf alle
    /// vorherigen. Beim Abgleich mit `Transaction.currentEntitlements` ist es
    /// umgekehrt: Dort steht der **vollständige** Bestand, und was fehlt,
    /// fehlt mit Grund — eine Rückerstattung, ein abgelaufener Familienzugang.
    /// Wer hier zusammenlegt statt zu ersetzen, verschenkt dauerhaft, was
    /// einmal erstattet wurde (`docs/11-sicherheit.md`, Abschnitt 5).
    ///
    /// Die Startschalter gewinnen weiterhin: Bildschirmfotos und
    /// Oberflächenprüfungen sollen einen festen Zustand zeigen und nicht den
    /// des Sandkastens, in dem sie gerade laufen.
    func synchronise(with truth: Entitlement) {
        guard !Startschalter.einerVon("-pulse-pro", "-pulse-frei") else { return }
        entitlement = truth
        defaults.set(truth.storageValue, forKey: Self.storageKey)
    }
}
