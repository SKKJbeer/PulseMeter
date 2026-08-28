import Foundation
import StoreKit
import PulseCore

/// Der Kauf über StoreKit 2.
///
/// **Die eine Regel dieses Typs: der Store hat recht, nicht das Gerät.**
/// `Purchase` hält den Kaufzustand in `UserDefaults`, damit die Oberfläche beim
/// Start nicht erst kostenlos aussieht. Das ist ein Zwischenspeicher und kein
/// Beweis. Was gilt, steht in `Transaction.currentEntitlements`, und das wird
/// bei jedem Start gelesen — auch nach unten (`docs/11-sicherheit.md`,
/// Abschnitt 5). Eine Rückerstattung nimmt den Kauf zurück; eine App, die das
/// nicht mitbekommt, verschenkt, was sie verkauft hat.
///
/// **Warum keine Belegprüfung auf einem Server.** Es gibt keinen Server, und es
/// soll keinen geben (ADR-002). StoreKit 2 liefert bereits verifizierte
/// Transaktionen — `VerificationResult` ist die Signaturprüfung, und sie
/// findet auf dem Gerät statt. Ein eigener Prüfdienst wäre eine zweite
/// Datenquelle über Nutzer, die wir nicht haben wollen.
///
/// Vorbereitet ist das seit 0.35.0: Die Sperren, die Kaufseite und deren
/// Prüfungen liegen hinter dem Protokoll `PurchaseGateway` und kennen StoreKit
/// nicht. Diese Datei ist das, was hinten drangehängt wird.
@MainActor
final class StoreKitGateway: PurchaseGateway {

    /// Was der Store zu unseren fünf Kennungen sagt.
    ///
    /// Leer, solange nichts geladen ist — und dann meldet ``isAvailable``
    /// `false`, die Kaufseite zeigt ihre Leistungen ohne Knopf. Ein Knopf, der
    /// ins Leere greift, ist schlimmer als kein Knopf.
    private var produkte: [ProductID: Product] = [:]

    /// Wird gerufen, wenn sich der Bestand ändert, ohne dass jemand gekauft
    /// hat.
    ///
    /// **Ohne das wäre der Beobachter unten wirkungslos.** Ein Kauf auf dem
    /// iPad, eine Freigabe durch die Kindersicherung, eine Rückerstattung —
    /// das alles meldet StoreKit hier, und die Oberfläche erführe nichts
    /// davon, weil das Protokoll nur Fragen kennt und keine Antworten von
    /// selbst. `Purchase` hängt sich hier ein.
    var onChange: (@MainActor (Entitlement) -> Void)?

    /// Läuft, solange die App läuft: StoreKit meldet hierüber Käufe, die
    /// woanders passiert sind.
    ///
    /// Kein `deinit` dazu: Dieser Vermittler lebt so lange wie die App, und
    /// aus einem `deinit` heraus ließe sich eine Eigenschaft des Hauptakteurs
    /// unter Swift 6 ohnehin nicht mehr anfassen.
    private var beobachter: Task<Void, Never>?

    init() {
        beobachter = Task { [weak self] in
            for await ergebnis in Transaction.updates {
                guard let transaktion = try? Self.gepruef(ergebnis) else { continue }
                await transaktion.finish()
                guard let self else { return }
                let neu = await self.bestand()
                self.onChange?(neu)
            }
        }
    }

    // MARK: - PurchaseGateway

    var isAvailable: Bool { !produkte.isEmpty }

    /// Was beim letzten `laden()` herauskam. Siehe ``PurchaseGateway/storeDiagnosis``.
    private(set) var storeDiagnosis: String?

    /// Holt die Produkte und den aktuellen Bestand. Beim Start aufzurufen.
    ///
    /// Getrennt vom `init`, weil beides über das Netz geht und ein
    /// Konstruktor nicht warten kann. Schlägt es fehl — Flugmodus, Store
    /// gestört —, bleibt ``isAvailable`` `false`, und die App ist deshalb
    /// nicht kaputt: Alles Gekaufte gilt weiter aus dem Zwischenspeicher.
    func laden() async -> Entitlement {
        let kennungen = ProductID.allCases.map(\.storeIdentifier)

        // **`try?` war hier die teuerste Zeile der App.** Sie hat drei Tage
        // lang dieselben zwei Sachverhalte unter einen Wert gelegt: „der Store
        // hat einen Fehler geworfen" und „der Store kennt keines unserer fünf
        // Produkte". Beides endete in einer leeren Liste, und die Kaufseite
        // sagte dazu nur, sie sei noch nicht im Store — was gar nicht die Frage
        // war. Gesucht wurde derweil überall sonst.
        do {
            let geladen = try await Product.products(for: kennungen)
            produkte = Dictionary(uniqueKeysWithValues: geladen.compactMap { produkt in
                ProductID.allCases
                    .first { $0.storeIdentifier == produkt.id }
                    .map { ($0, produkt) }
            })
            if geladen.isEmpty {
                storeDiagnosis = "Der Store kennt keine der \(kennungen.count) Kennungen."
            } else if geladen.count < kennungen.count {
                storeDiagnosis = "Der Store liefert \(geladen.count) von \(kennungen.count) Käufen."
            } else {
                storeDiagnosis = "Alle \(geladen.count) Käufe geladen."
            }
        } catch {
            produkte = [:]
            storeDiagnosis = "Der Store antwortete mit einem Fehler: \(error.localizedDescription)"
        }
        return await bestand()
    }

    func purchase(_ product: ProductID) async throws -> Entitlement {
        guard let produkt = produkte[product] else { throw Fehler.nichtImStore }

        switch try await produkt.purchase() {
        case .success(let ergebnis):
            let transaktion = try Self.gepruef(ergebnis)
            // **Erst abschließen, dann melden.** Eine nicht abgeschlossene
            // Transaktion kommt bei jedem Start wieder, und der Nutzer sähe
            // dauerhaft eine Kaufbestätigung für etwas, das er längst hat.
            await transaktion.finish()
            return await bestand()

        case .userCancelled:
            // Kein Fehler und kein roter Kasten. Wer abbricht, hat sich
            // entschieden; ihn dafür anzublinken wäre eine Belehrung.
            throw Fehler.abgebrochen

        case .pending:
            // „Kauf bestätigen lassen" bei Kindersicherung. Der Kauf kommt
            // später über `Transaction.updates` an.
            throw Fehler.wartetAufFreigabe

        @unknown default:
            throw Fehler.unbekannt
        }
    }

    /// Auf einem neuen Gerät der einzige Weg an die Käufe.
    ///
    /// `AppStore.sync()` verlangt eine Anmeldung und gehört deshalb hinter
    /// einen Knopf, nie in den Start. Danach wird der Bestand neu gelesen.
    func restore() async throws -> Entitlement {
        try await AppStore.sync()
        return await bestand()
    }

    func displayPrice(for product: ProductID) -> String? {
        produkte[product]?.displayPrice
    }

    // MARK: - Bestand

    /// Was gerade wirklich gekauft ist — die Wahrheit, gegen die alles andere
    /// abgeglichen wird.
    ///
    /// Widerrufene und abgelaufene Käufe stehen nicht in
    /// `currentEntitlements`; sie fallen damit von selbst heraus.
    private func bestand() async -> Entitlement {
        var gekauft: Set<ProductID> = []
        for await ergebnis in Transaction.currentEntitlements {
            guard let transaktion = try? Self.gepruef(ergebnis) else { continue }
            if let id = ProductID.allCases.first(where: { $0.storeIdentifier == transaktion.productID }) {
                gekauft.insert(id)
            }
        }
        return Entitlement(gekauft)
    }

    /// Die Signaturprüfung von StoreKit 2, ausgepackt.
    ///
    /// `.unverified` wird **verworfen** und nicht als Kauf gewertet. Das ist
    /// die Stelle, an der ein manipuliertes Gerät sonst durchkäme.
    private static func gepruef<T>(_ ergebnis: VerificationResult<T>) throws -> T {
        switch ergebnis {
        case .verified(let sicher): return sicher
        case .unverified: throw Fehler.nichtBeglaubigt
        }
    }

    enum Fehler: LocalizedError {
        case nichtImStore
        case abgebrochen
        case wartetAufFreigabe
        case nichtBeglaubigt
        case unbekannt

        var errorDescription: String? {
            switch self {
            case .nichtImStore:      return "Dieser Kauf steht im Store gerade nicht zur Verfügung."
            case .abgebrochen:       return nil
            case .wartetAufFreigabe: return "Der Kauf wartet auf eine Freigabe. Sobald sie da ist, wird freigeschaltet."
            case .nichtBeglaubigt:   return "Der Kauf ließ sich nicht beglaubigen."
            case .unbekannt:         return "Der Kauf ließ sich nicht abschließen."
            }
        }
    }
}
