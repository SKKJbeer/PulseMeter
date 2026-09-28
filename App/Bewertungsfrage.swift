import Foundation
import PulseCore

/// Merkt sich, wie oft jemand selbst abgelesen hat und ob schon um eine
/// Bewertung gebeten wurde. Die Regel selbst steht in ``ReviewPrompt``.
///
/// **In `UserDefaults`, nicht im Datenbestand.** Es ist eine Angabe über dieses
/// Gerät und diese Person, nicht über einen Zähler. Im Bestand würde sie über
/// iCloud auf das iPad gespiegelt, und dort fragte die App dann nie, obwohl
/// dort noch niemand gefragt wurde. Umgekehrt ist das richtig so: iOS zählt
/// die Fragen je Gerät.
enum Bewertungsfrage {

    private static let gesichertSchluessel = "bewertung.gesicherteAblesungen"
    private static let gefragtSchluessel = "bewertung.gefragt"

    /// Nach jeder Ablesung, die jemand im Ziffernblock gesichert hat.
    static func ablesungGesichert(_ speicher: UserDefaults = .standard) {
        speicher.set(speicher.integer(forKey: gesichertSchluessel) + 1, forKey: gesichertSchluessel)
    }

    /// Ob jetzt gefragt wird. Wenn ja, gilt die Frage ab hier als gestellt,
    /// auch wenn iOS sie am Ende nicht zeigt: Das entscheidet iOS, und ein
    /// zweiter Versuch bei der nächsten Ablesung wäre Drängeln.
    ///
    /// **Nie in Prüfungen und Bildschirmfotos.** Das Blatt von Apple läge über
    /// dem Schirm, den eine Oberflächenprüfung gerade sucht, und im Simulator
    /// erscheint es jedes Mal.
    static func jetztFragen(_ speicher: UserDefaults = .standard) -> Bool {
        guard !Startschalter.einerVon("-pulse-reset", "-pulse-empty") else { return false }
        let fragen = ReviewPrompt.shouldAsk(
            savedReadings: speicher.integer(forKey: gesichertSchluessel),
            alreadyAsked: speicher.bool(forKey: gefragtSchluessel))
        if fragen { speicher.set(true, forKey: gefragtSchluessel) }
        return fragen
    }
}
