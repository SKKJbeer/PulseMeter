import SwiftUI
import SwiftData
import PulseData

@main
struct PulseMeterApp: App {

    private let container: ModelContainer

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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
