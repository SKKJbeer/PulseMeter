import AppIntents
import PulseCore

/// „Hey Siri, Strom in Zählora ablesen" — und der Ziffernblock für Strom ist da.
///
/// **Derselbe Weg wie Erinnerung und Widget, kein vierter.** Siri setzt nur einen
/// Wunsch in den ``Wegweiser``, genau wie der Tipp auf eine Erinnerung. Was
/// danach passiert (welcher Zähler bei fehlender Angabe, was bei einer
/// unbekannten Kennung geschieht, wie ein kalter Start behandelt wird), ist an
/// einer Stelle gelöst und geprüft. Ein Kurzbefehl mit eigener Logik wäre die
/// dritte Fassung derselben Entscheidung, und die liefe auseinander.
///
/// **Warum der Ziffernblock und nicht „Siri, trag 12.480 bei Strom ein".** Aus
/// demselben Grund, aus dem die Erinnerung keine Eingabe hat (siehe
/// ``AppAddress``): Die App fragt vor dem Sichern nach, wenn ein Wert unter dem
/// letzten Stand oder weit über dem Üblichen liegt. Eine gesprochene Zahl kann
/// das nicht, und ein verhörtes Komma landete ungeprüft im Verlauf.
struct ZaehlerstandEintragen: AppIntent {

    // `static let`, nicht `var`: Unter Swift 6 ist eine veränderliche
    // statische Eigenschaft geteilter Zustand und wird abgelehnt. Und der
    // Schritt, der beim Bauen die Metadaten für Siri ausliest, erwartet hier
    // feste Werte, keine Berechnung.
    static let title: LocalizedStringResource = "Zählerstand eintragen"
    static let description = IntentDescription(
        "Öffnet den Ziffernblock. Ohne Zähler den, der am längsten auf eine Ablesung wartet.")

    /// Die App muss dafür offen sein: Der Ziffernblock ist eine Ansicht in ihr.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Zähler")
    var zaehler: ZaehlerEintrag?

    @MainActor
    func perform() async throws -> some IntentResult {
        Wegweiser.aktuell?.springe(zu: .capture(zaehler?.id))
        return .result()
    }
}

/// Ein Zähler, wie Siri und die Kurzbefehle-App ihn kennen: Name und Kennung.
struct ZaehlerEintrag: AppEntity {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Zähler"
    static let defaultQuery = ZaehlerAbfrage()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Welche Zähler es gibt.
///
/// **Aus der Datei des Widgets, nicht aus dem Speicher.** Sie steht nach jedem
/// Laden der Übersicht neu da, hat Namen und Kennung und kostet einen
/// Lesevorgang. Den Speicher samt iCloud-Abgleich für eine Namensliste
/// aufzuziehen, während Siri auf eine Antwort wartet, wäre der langsamste Weg
/// zu derselben Liste. Fehlt die Datei, etwa vor dem ersten Start, ist die Liste
/// leer, und der Kurzbefehl ohne Zähler funktioniert trotzdem.
struct ZaehlerAbfrage: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [ZaehlerEintrag] {
        alle().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ZaehlerEintrag] {
        alle()
    }

    private func alle() -> [ZaehlerEintrag] {
        (WidgetBridge.read()?.meters ?? []).map { ZaehlerEintrag(id: $0.id, name: $0.name) }
    }
}

/// Die Sätze, auf die Siri hört, ohne dass jemand einen Kurzbefehl anlegt.
///
/// Jeder Satz muss den App-Namen enthalten; so will es Apple, damit „Strom
/// ablesen" nicht jede App gleichzeitig meint. Die Sätze mit Zähler kennt Siri,
/// sobald die App die Namen gemeldet hat (``aktualisieren()``).
struct ZaehloraKurzbefehle: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ZaehlerstandEintragen(),
            phrases: [
                "Zählerstand in \(.applicationName) eintragen",
                "\(.applicationName) ablesen",
                "\(\.$zaehler) in \(.applicationName) ablesen",
                "Zählerstand für \(\.$zaehler) in \(.applicationName) eintragen",
            ],
            shortTitle: "Zählerstand eintragen",
            systemImageName: "gauge.with.needle"
        )
    }

    /// Nach jeder Änderung an den Zählern: Siri lernt die neuen Namen erst,
    /// wenn die App sie meldet. Ein umbenannter Zähler hieße sonst für Siri
    /// weiter wie vorher.
    static func aktualisieren() {
        updateAppShortcutParameters()
    }
}
