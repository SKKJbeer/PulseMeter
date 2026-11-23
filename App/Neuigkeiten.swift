import Foundation
import SwiftUI
import PulseCore
import PulseUI

/// „Neu in Zählora 1.9“: nach einem Update einmal ein kurzes Blatt, was die
/// Fassung mitbringt. Die Regel steht in ``ReleaseNotes``, der Text in
/// `docs/fassungen/<fassung>.json` (Block `app`), derselben Datei, aus der die
/// Website ihren Eintrag bekommt.
///
/// Vom Gründer am 23. November: „wenn neue versionen kommen will ich dass es
/// auch in der app die update notes in kurzform kommen dass man direkt sieht
/// dass sich hier etwas weiter entwickelt. es soll einfach wegklickbar dann
/// sein und nur einmalig kommen.“
///
/// **In `UserDefaults`, nicht im Datenbestand**, aus demselben Grund wie bei
/// ``Bewertungsfrage``: Gesehen hat es diese Person auf diesem Gerät. Über
/// iCloud gespiegelt, bekäme das iPad das Blatt nie, obwohl dort niemand es
/// gesehen hat.
enum Neuigkeiten {

    static let gesehenSchluessel = "neuigkeiten.gesehen"

    /// Alle Fassungen mit Text, aus dem Ordner `fassungen` im Bündel.
    ///
    /// **Der ganze Ordner, nicht eine Datei.** Welche Fassung die neueste ist,
    /// entscheidet ``ReleaseNotes/latest(_:)`` an den Nummern. Eine fest
    /// eingetragene Datei hätte bei jeder Fassung einen Handgriff mehr
    /// gebraucht, und der vergessene Handgriff hätte die alte Neuigkeit ein
    /// zweites Mal gezeigt.
    static func imBuendel(_ bundle: Bundle = .main) -> [ReleaseNote] {
        let dateien = bundle.urls(forResourcesWithExtension: "json", subdirectory: "fassungen") ?? []
        return dateien.compactMap { url in
            (try? Data(contentsOf: url)).flatMap(ReleaseNote.decode)
        }
    }

    /// Was beim Start zu tun ist. Merkt die Fassung gleich, wenn nichts
    /// gezeigt wird; wenn etwas gezeigt wird, erst beim Schließen
    /// (``gesehen(_:speicher:)``). Wer die App beendet, bevor er das Blatt
    /// weggetippt hat, bekommt es beim nächsten Start noch einmal.
    @MainActor
    static func beimStart(bestandVorhanden: Bool,
                          speicher: UserDefaults = .standard) -> ReleaseNote? {
        guard zeigenErlaubt else { return nil }
        if Startschalter.gesetzt("-pulse-neuigkeiten-vergessen") {
            speicher.removeObject(forKey: gesehenSchluessel)
        }
        let entscheidung = ReleaseNotes.decide(
            latest: ReleaseNotes.latest(imBuendel()),
            lastSeen: speicher.string(forKey: gesehenSchluessel),
            usedBefore: bestandVorhanden)
        switch entscheidung {
        case .show(let note): return note
        case .remember(let fassung): speicher.set(fassung, forKey: gesehenSchluessel)
        case .nothing: break
        }
        return nil
    }

    static func gesehen(_ note: ReleaseNote, speicher: UserDefaults = .standard) {
        speicher.set(note.version, forKey: gesehenSchluessel)
    }

    /// **Im Debug-Bau nur mit `-pulse-neuigkeiten`**, im Auslieferungsbau
    /// (TestFlight, Laden) immer.
    ///
    /// Zuerst hieß es hier „ohne irgendeinen Schalter auch“. Der erste Lauf
    /// der CI hat das widerlegt: `testAppLaunchesAndOffersItsThreeDestinations`
    /// startet ganz ohne Schalter, fand Zähler vom Lauf davor und bekam das
    /// Blatt über die Übersicht. Jede Prüfung und jedes Bildschirmfoto läuft
    /// im Debug-Bau, also ist der Debug-Bau der Ort, an dem es schweigt.
    private static var zeigenErlaubt: Bool {
        #if DEBUG
        return Startschalter.gesetzt("-pulse-neuigkeiten")
        #else
        return true
        #endif
    }
}

/// Das Blatt selbst. Halbe Höhe, eine Überschrift, höchstens drei Punkte und
/// ein Knopf. Wegwischen zählt wie der Knopf.
struct NeuigkeitenView: View {
    let note: ReleaseNote

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Neu in Zählora \(note.version)")
                    .font(PulseText.caption)
                    .foregroundStyle(PulseColor.inkSecondary)
                    .accessibilityIdentifier("neuigkeiten-fassung")
                Text(note.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PulseColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("neuigkeiten-titel")
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(note.points.enumerated()), id: \.offset) { _, punkt in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseColor.tintInk)
                            .accessibilityHidden(true)
                        Text(punkt)
                            .font(.body)
                            .foregroundStyle(PulseColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer(minLength: 0)
            // **Dunkler Bernstein mit `onAccent`, nicht `.borderedProminent`.**
            // Der setzt Weiß auf die Akzentfarbe, und Weiß auf dem hellen
            // Bernstein des Dunkelmodus liegt bei 2,3:1 (gemessen im
            // Klick-Dummy, `check-nichtfunktional.mjs`).
            Button {
                dismiss()
            } label: {
                Text("Weiter")
                    .font(.headline)
                    .foregroundStyle(PulseColor.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(PulseColor.tintInk, in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("neuigkeiten-weiter")
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(PulseColor.ground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // **Keine Kennung am Ganzen.** SwiftUI reicht sie an jedes Kind
        // weiter und überschreibt damit „neuigkeiten-weiter“ — der erste
        // CI-Lauf fand den Knopf deshalb nicht.
    }
}
