import Foundation
import PulseCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Die Brücke zwischen App und Widget: eine kleine Datei in einem geteilten
/// Ordner.
///
/// **Warum eine Datei und nicht der Speicher.** Ein Widget ist ein eigener
/// Prozess mit knappem Speicher und wenigen Millisekunden Zeit. Zöge es
/// SwiftData samt CloudKit auf, um drei Zahlen zu zeigen, wäre es das
/// langsamste und fehleranfälligste Stück der App. Die Datei kostet das
/// Widget einen Lesevorgang und keine Rechnung.
///
/// **Warum das Schreiben nicht scheitern darf.** Ohne App-Gruppe — etwa in
/// der CI, wo ohne Signatur gebaut wird — gibt es den geteilten Ordner nicht.
/// Dann landet die Datei im eigenen Ordner der App: Das Widget sieht sie
/// nicht, aber die App läuft. Ein Absturz an dieser Stelle wäre absurd, denn
/// niemand verliert etwas, wenn ein Widget leer bleibt.
enum WidgetBridge {

    /// Muss mit der App-Gruppe im Zielprofil übereinstimmen.
    static let appGroup = "group.com.pulsemeter.app"
    static let fileName = "widget-summary.json"

    /// Wohin geschrieben und woher gelesen wird.
    static var fileURL: URL? {
        let shared = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        let base = shared ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent(fileName)
    }

    static func write(_ summary: WidgetSummary) {
        guard let url = fileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Atomar: Läse das Widget genau während des Schreibens, bekäme es
            // sonst eine halbe Datei — und zeigte nichts, ohne dass jemals
            // etwas kaputt gewesen wäre.
            try data.write(to: url, options: .atomic)
        } catch {
            // Bewusst still. Siehe oben: Ein leeres Widget ist ein
            // Schönheitsfehler, ein Absturz der Übersicht wäre keiner.
            return
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func read() -> WidgetSummary? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let summary = try? decoder.decode(WidgetSummary.self, from: data) else { return nil }
        // Eine neuere Fassung wird nicht geraten. Das Widget läuft weiter,
        // während die App schon aktualisiert ist — dann lieber der leere
        // Zustand als eine Zahl, deren Bedeutung sich verschoben hat.
        guard summary.version <= WidgetSummary.currentVersion else { return nil }
        return summary
    }
}
