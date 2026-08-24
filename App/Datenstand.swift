import Foundation

/// Wie oft sich der Bestand an Zählern und Ablesungen geändert hat.
///
/// **Warum es das gibt.** Jede der drei Ansichten hat bisher in ihrem eigenen
/// `onAppear` geladen und danach nur noch dann, wenn ein Blatt, das *sie*
/// aufgemacht hatte, sich wieder schloss. Das genügt, solange eine Änderung nur
/// die Ansicht angeht, in der sie passiert ist — und genau das stimmt bei
/// keiner einzigen. Wer im Verlauf eine Ablesung löscht, ändert damit die Zahl
/// auf der Übersichtskarte, die Sparkline daneben und den Zählerstand in der
/// Zählerliste mit. Ohne ein gemeinsames Signal erfahren die beiden davon erst,
/// wenn iOS sie aus eigenem Antrieb neu aufbaut — was es tut, wenn ihm danach
/// ist, und nicht, wenn es nötig wäre.
///
/// **Warum ein Zähler und kein Inhalt.** Der Wert bedeutet nichts, nur seine
/// Änderung. Würde hier stehen, *was* sich geändert hat, müsste jede Ansicht
/// entscheiden, ob sie das betrifft — und jede falsche Entscheidung wäre wieder
/// eine Zahl, die stehen bleibt. Neu rechnen ist billig, seit die Übersicht mit
/// `readingCount` und `lastReading` auskommt statt mit der ganzen Reihe.
///
/// **Warum nicht an den Änderungsstellen selbst.** Die Stellen, an denen etwas
/// gesichert oder gelöscht wird, liegen in Blättern, die den Bestand gar nicht
/// anzeigen. Sie melden sich seit jeher über einen Rückruf — `onSaved`,
/// `onDone`, `onChanged` — bei dem, der sie aufgemacht hat. Genau diese
/// Rückrufe zählen jetzt hoch, und nur sie. `scripts/check-aktualisierung.py`
/// besteht darauf.
@MainActor
@Observable
final class Datenstand {

    /// Zählt hoch, sonst nichts.
    private(set) var version = 0

    func geaendert() {
        version += 1
    }
}
