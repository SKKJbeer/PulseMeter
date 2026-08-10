import SwiftUI
import SwiftData
import PulseData

@main
struct PulseMeterApp: App {

    private let container: ModelContainer

    /// Der Kaufzustand, einmal für die ganze App.
    ///
    /// Hier und nicht in einer Ansicht: Vier Stellen fragen ihn, und vier
    /// eigene Kopien wären vier Gelegenheiten, dass eine davon nach einem Kauf
    /// noch die alte Antwort gibt.
    @State private var purchase = Purchase()

    init() {
        // CloudKit bleibt vorerst aus. Die Synchronisation verlangt die
        // iCloud-Berechtigung am Target; fehlt sie, schlägt schon der Aufbau
        // des Speichers beim ersten Start fehl. Einschalten, sobald die
        // Capability eingetragen ist — siehe Packages/PulseData/README.md.
        if let store = try? PulseStore.container(cloudKit: false) {
            container = store
        } else if let memory = try? PulseStore.container(inMemory: true, cloudKit: false) {
            // Lieber flüchtig arbeiten als gar nicht starten. Der Nutzer sieht
            // in der Übersicht, dass nichts gesichert wird.
            container = memory
        } else {
            fatalError("Der Datenspeicher ließ sich nicht anlegen.")
        }

        // Vor der ersten Ansicht, nicht in einer davon: Welcher Tab beim Start
        // sichtbar ist, darf nicht darüber entscheiden, welche Daten da sind.
        // Ohne Startschalter tut das gar nichts.
        LaunchFixture.apply(to: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchase)
        }
        .modelContainer(container)
    }
}
