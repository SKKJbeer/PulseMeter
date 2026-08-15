import Foundation

/// Die Schalter, mit denen Prüfungen und Bildschirmfotos die App in einen
/// bestimmten Zustand bringen — und die es im ausgelieferten Programm **nicht
/// mehr gibt**.
///
/// **Warum das eine eigene Stelle ist.** Die Schalter standen an neun Stellen
/// verstreut als `ProcessInfo.processInfo.arguments.contains(…)`. Einer davon
/// heißt `-pulse-reset` und löscht alle Ablesungen; ein anderer, `-pulse-pro`,
/// schaltet jeden Kauf frei. Beides ist für einen Lauf im Simulator genau
/// richtig und hat in einer App, die im Store steht, nichts verloren.
///
/// **Wie groß die Gefahr wirklich war.** Startargumente lassen sich auf einem
/// gewöhnlichen iPhone nicht von außen setzen — dafür braucht es Xcode am
/// Kabel oder ein aufgebrochenes Gerät. Es war also keine offene Tür, sondern
/// eine Tür ohne Grund. Und ein Löschbefehl, der ohne Not mitgeliefert wird,
/// ist die Art Kleinigkeit, die zwei Jahre später jemand findet, wenn niemand
/// mehr weiß, wofür sie einmal da war.
///
/// Im Auslieferungsbau (`Release`) gibt `gesetzt(_:)` immer `false` zurück,
/// und der Übersetzer wirft die Zweige dahinter weg. Geprüft und fotografiert
/// wird ausschließlich mit `Debug` — `scripts/run.sh`, `scripts/test.sh` und
/// die CI setzen keine andere Konfiguration.
enum Startschalter {

    static func gesetzt(_ name: String) -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(name)
        #else
        return false
        #endif
    }

    /// Für Stellen, die mehrere Schalter auf einmal prüfen.
    static func einerVon(_ namen: String...) -> Bool {
        namen.contains(where: gesetzt)
    }
}
