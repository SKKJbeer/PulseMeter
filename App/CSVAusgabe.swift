import SwiftUI
import UniformTypeIdentifiers

/// Eine Tabelle, die **erst beim Teilen** entsteht, und zwar als **Datei**.
///
/// **Warum sie erst beim Teilen entsteht.** Bis 0.61.0 waren die zwei
/// Exportdateien berechnete Eigenschaften, die im Bildaufbau standen. Jede
/// Neuauswertung des Verlaufsschirms hat damit zwei CSV-Dateien gebaut **und
/// auf die Platte geschrieben** — beim Blättern, beim Umschalten von Monat auf
/// Quartal, und beim Antippen von „Alle Ablesungen", weil auch das den Zustand
/// ändert. Der Gründer beim ersten Gebrauch: „lädt ziemlich lange".
/// `Transferable` löst das: Die Beschreibung ist billig, `inhalt` läuft erst,
/// wenn das Teilen-Blatt die Daten anfordert.
///
/// **Warum eine Datei und keine Daten** (0.164.0). Bis 0.163.0 ging die
/// Tabelle als `DataRepresentation` mit dem Typ `.commaSeparatedText` hinaus.
/// Der Typ gilt für iOS als Text, und Mail setzt Text, den es aus dem
/// Teilen-Blatt bekommt, in die Nachricht statt ihn anzuhängen. Ein Käufer im
/// Laden: „Warum ist der CSV-Export nur tabellarisch in einer E-Mail
/// abgehängt? Ich wünsche mir eine echte CSV, die auch in Excel eingelesen
/// werden kann.“ Eine Datei mit Namen kommt überall als Datei an: in Mail als
/// Anhang, in „In Dateien sichern“ als `.csv`, in Excel und Numbers zum
/// Öffnen. Am Inhalt ändert sich nichts.
struct CSVAusgabe: Transferable {

    let dateiname: String
    /// Wird genau einmal aufgerufen, und nur beim Teilen.
    ///
    /// **Auf dem Hauptfaden.** Das Teilen-Blatt fordert die Datei auf einem
    /// beliebigen Faden an; „Alle Zähler als Tabelle“ liest dabei den
    /// Speicher, und der gehört dem Hauptfaden. Ohne die Kennzeichnung prüft
    /// das niemand, und es geht nur meistens gut.
    let inhalt: @MainActor @Sendable () -> String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { ausgabe in
            SentTransferredFile(try await ausgabe.schreiben())
        }
        .suggestedFileName { $0.dateiname }
    }

    /// Schreibt die Datei in einen eigenen Ordner im temporären Verzeichnis.
    ///
    /// Ein eigener Ordner je Export, damit der Dateiname genau der ist, den
    /// der Empfänger sieht („Zählora-Strom-Ablesungen.csv“), ohne Nummer oder
    /// Kennung davor. Was ein früherer Export dort liegen ließ, wird vorher
    /// weggeräumt — das Teilen-Blatt kopiert die Datei, sobald es sie bekommt.
    func schreiben() async throws -> URL {
        let text = await inhalt()
        let fm = FileManager.default
        let wurzel = fm.temporaryDirectory.appendingPathComponent("Tabellen", isDirectory: true)
        try? fm.removeItem(at: wurzel)
        let ordner = wurzel.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: ordner, withIntermediateDirectories: true)
        let url = ordner.appendingPathComponent(dateiname)
        // Byte-Reihenfolge-Marke für Excel: Ohne sie öffnet es eine
        // UTF-8-Datei mit Umlauten als Buchstabensalat.
        try Data("\u{FEFF}\(text)".utf8).write(to: url, options: .atomic)
        return url
    }
}
