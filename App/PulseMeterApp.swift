import SwiftUI
import SwiftData
import PulseData

@main
struct PulseMeterApp: App {

    private let container: ModelContainer

    /// Der Vermittler zum Store. Einmal, weil er einen Beobachter auf
    /// `Transaction.updates` hält — zwei davon meldeten jeden Kauf doppelt.
    private let store = StoreKitGateway()

    /// Der Kaufzustand, einmal für die ganze App.
    ///
    /// Hier und nicht in einer Ansicht: Vier Stellen fragen ihn, und vier
    /// eigene Kopien wären vier Gelegenheiten, dass eine davon nach einem Kauf
    /// noch die alte Antwort gibt.
    @State private var purchase: Purchase

    /// Das Signal, dass sich am Bestand etwas geändert hat — einmal für die
    /// ganze App, aus demselben Grund wie der Kaufzustand darüber: Drei
    /// Ansichten hören darauf, und drei eigene Kopien wären drei Zähler, die
    /// einander nicht erreichen.
    @State private var datenstand = Datenstand()

    init() {
        // **Drei Stufen, nicht ein Schalter.**
        //
        // Bis 0.55.0 stand hier fest `cloudKit: false`, weil ohne die
        // iCloud-Berechtigung schon der Aufbau des Speichers scheitert. Sie
        // einfach auf `true` zu setzen wäre falsch gewesen: Im Simulator und
        // in der CI gibt es keine Berechtigung, der Aufbau schlüge fehl, und
        // die alte zweite Stufe fiel auf einen **flüchtigen** Speicher zurück.
        // Die App liefe dann — und würde nichts sichern. Jede
        // Oberflächenprüfung, die eine Ablesung einträgt, wäre rot, und der
        // Grund stünde nirgends.
        //
        // Deshalb ist die zweite Stufe jetzt derselbe Speicher ohne Abgleich.
        // Auf dem Gerät greift die erste, im Simulator die zweite, und
        // flüchtig wird es erst, wenn beides nicht geht.
        if let store = try? PulseStore.container(cloudKit: true) {
            container = store
        } else if let lokal = try? PulseStore.container(cloudKit: false) {
            // Kein Abgleich, aber alles bleibt erhalten. Das ist der Zustand
            // im Simulator, in der CI und auf einem Gerät ohne angemeldete
            // iCloud.
            container = lokal
        } else if let memory = try? PulseStore.container(inMemory: true, cloudKit: false) {
            // Lieber flüchtig arbeiten als gar nicht starten.
            //
            // **Hier stand „Der Nutzer sieht in der Übersicht, dass nichts
            // gesichert wird". Das war nie gebaut.** Es gibt keine solche
            // Zeile, in keiner Ansicht — der Satz beschrieb eine Absicht und
            // las sich wie ein Zustand. Wer diese Stufe erreicht, verliert
            // seine Eingaben beim Beenden und erfährt es nicht.
            //
            // Stehen bleibt sie trotzdem: Eine App, die gar nicht startet,
            // ist schlechter. Der Hinweis gehört nachgebaut, bevor jemand
            // diesen Fall erreicht — bisher hat ihn niemand erreicht, weil
            // Stufe zwei auf jedem Gerät und in jedem Simulator greift.
            container = memory
        } else {
            fatalError("Der Datenspeicher ließ sich nicht anlegen.")
        }

        // Vor der ersten Ansicht, nicht in einer davon: Welcher Tab beim Start
        // sichtbar ist, darf nicht darüber entscheiden, welche Daten da sind.
        // Ohne Startschalter tut das gar nichts.
        LaunchFixture.apply(to: container)

        // **`-pulse-ohne-store` prüft den Fall, den es im Simulator nicht
        // gibt.** Die Annahme war, dort gebe es keinen Store — der Lauf zu
        // 0.90.0 hat das Gegenteil ausgeschrieben: Auf der Kaufseite standen
        // `$2.99` und `$8.99`, also echte Preise aus der Sandbox. Ein Test für
        // „der Store liefert nichts" braucht deshalb einen Vermittler, der
        // nichts liefert, statt einer Umgebung, von der man es annimmt.
        let gateway: PurchaseGateway = Startschalter.gesetzt("-pulse-ohne-store")
            ? UnavailablePurchaseGateway()
            : store
        let purchase = Purchase(gateway: gateway)
        _purchase = State(initialValue: purchase)

        // Käufe, die woanders passiert sind: auf dem iPad, durch eine Freigabe
        // der Kindersicherung, oder eine Rückerstattung. Ohne diese Zeile
        // erführe die Oberfläche davon erst beim nächsten Start.
        store.onChange = { [weak purchase] neu in purchase?.synchronise(with: neu) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchase)
                .environment(datenstand)
                .task {
                    // **Nicht im Konstruktor.** Beides geht übers Netz, und
                    // ein Konstruktor kann nicht warten. Solange nichts
                    // geladen ist, zeigt die Kaufseite ihre Leistungen mit
                    // „ca."-Preisen und ohne Knopf — was ohne Netz auch der
                    // richtige Zustand ist.
                    purchase.synchronise(with: await store.laden())
                }
        }
        .modelContainer(container)
    }
}
