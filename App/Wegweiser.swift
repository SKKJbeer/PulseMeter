import Foundation
import UserNotifications
import PulseCore

/// Wohin die App als Nächstes springen soll — ein Wunsch, kein Zustand.
///
/// **Warum ein eigenes Objekt und kein Wert in `RootView`.** Drei Eingänge
/// setzen ihn, und nur einer davon lebt in einer Ansicht: Eine Adresse kommt
/// über `onOpenURL` an, eine Mitteilung aber über den Empfänger unten, der vor
/// der ersten Ansicht entsteht — sonst verpasst er den Tipp, der die App kalt
/// startet. Beide brauchen dieselbe Stelle, an die sie schreiben.
///
/// **Warum er verfällt.** Dasselbe Muster wie `verlaufFuer` in `RootView`: Die
/// Übersicht nimmt den Wunsch entgegen und setzt ihn zurück. Bliebe er stehen,
/// öffnete jeder spätere Wechsel auf die Übersicht wieder den Ziffernblock.
@MainActor
@Observable
final class Wegweiser {

    private(set) var ziel: AppAddress?

    func springe(zu adresse: AppAddress) {
        ziel = adresse
    }

    func erledigt() {
        ziel = nil
    }
}

/// Nimmt den Tipp auf eine Erinnerung entgegen.
///
/// **Warum `NSObject` und `@unchecked Sendable`.** Die Schnittstelle von Apple
/// verlangt ein Objekt aus Objective-C und ruft es von einem Hintergrundfaden
/// aus. Gehalten wird nur der Wegweiser, und der wird ausschließlich auf dem
/// Hauptfaden angefasst.
final class MitteilungsEmpfang: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    private let wegweiser: Wegweiser

    init(wegweiser: Wegweiser) {
        self.wegweiser = wegweiser
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Vor dem Sprung auf den Hauptfaden auslesen: Die Antwort selbst darf
        // dort nicht hin, die Adresse schon.
        let adresse = AppAddress(notificationInfo: response.notification.request.content.userInfo)
        completionHandler()
        let wegweiser = self.wegweiser
        Task { @MainActor in
            wegweiser.springe(zu: adresse)
        }
    }

    /// Auch bei offener App soll die Erinnerung erscheinen.
    ///
    /// Ohne diese Antwort verschluckt iOS eine Mitteilung, solange die App im
    /// Vordergrund steht — wer sie gerade offen hat, erführe nicht, dass ein
    /// Zähler fällig ist.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
