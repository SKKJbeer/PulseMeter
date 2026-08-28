import Foundation
import UserNotifications
import PulseCore

/// Lokale Erinnerungen an fällige Ablesungen.
///
/// Ohne Konto, ohne Server, ohne Netz: `UNUserNotificationCenter` plant sie auf
/// dem Gerät. Das passt zu ADR-002 — was die App kann, soll sie ohne fremde
/// Hilfe können.
///
/// **Bewusst nicht am Hauptakteur.** Zwei Läufe sind daran gescheitert:
/// `UNUserNotificationCenter` ist selbst threadsicher, und seine Methoden sind
/// nicht isoliert. Steht `@MainActor` am Typ, wird `center` dem Hauptakteur
/// zugeordnet, und **jeder** Aufruf einer Systemmethode ist dann ein
/// Grenzübertritt, den Swift 6 zu Recht verweigert — beim Rückgabewert wie
/// beim Empfänger selbst.
///
/// Die Regel, die daraus folgt: Ein Typ, der nur eine threadsichere
/// Systemschnittstelle umhüllt, bekommt keine Isolation. Er reicht nur
/// `Sendable`-Werte heraus, und die Oberfläche wartet vom Hauptakteur aus
/// darauf.
enum Reminders {

    /// Um wie viel Uhr erinnert wird.
    ///
    /// Achtzehn Uhr, nicht morgens: Ein Zählerstand wird abgelesen, wenn
    /// jemand zu Hause ist und zum Zähler gehen kann. Eine Mitteilung um
    /// sieben Uhr früh wird weggewischt und nie nachgeholt.
    static let hour = 18

    /// Fragt nach Erlaubnis — und zwar erst, wenn der Nutzer weiß, wofür.
    ///
    /// Nicht beim ersten Start: Eine Systemfrage, bevor irgendetwas erklärt
    /// wurde, wird verneint, und ein zweites Mal fragt iOS nicht. Deshalb
    /// hängt sie am Schalter, den jemand bewusst umlegt.
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Über den Rückruf statt über `await notificationSettings()`.
    ///
    /// `UNNotificationSettings` ist nicht `Sendable`. Im Rückruf wird nur der
    /// Status herausgezogen — eine Aufzählung und damit unbedenklich.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// Plant die Erinnerungen neu.
    ///
    /// Erst alles löschen, dann neu setzen: Eine Ablesung verschiebt den
    /// nächsten Termin, und eine stehengebliebene alte Mitteilung würde zu
    /// einem Zeitpunkt kommen, an dem längst nichts mehr fällig ist. Genau so
    /// verlieren Apps das Vertrauen in ihre eigenen Hinweise.
    static func reschedule(meteringPoints: [MeteringPoint],
                           readings: [MeteringPoint.ID: [Reading]],
                           today: CalendarDay) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard await authorizationStatus() == .authorized else { return }

        let plan = ReminderEngine.schedule(meteringPoints: meteringPoints,
                                           readings: readings, today: today)
        for entry in plan {
            let content = UNMutableNotificationContent()
            content.title = entry.meteringPoint.name
            content.body = "Zeit für eine Ablesung."
            content.sound = .default

            var components = DateComponents()
            components.year = entry.day.year
            components.month = entry.day.month
            components.day = entry.day.day
            components.hour = hour

            let request = UNNotificationRequest(
                identifier: "pulse-\(entry.meteringPoint.id.uuidString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Wie viele Mitteilungen tatsächlich in der Warteschlange stehen.
    /// Für die Anzeige — und damit sich überhaupt prüfen lässt, dass geplant
    /// wurde.
    static func pendingCount() async -> Int {
        // Dieselbe Regel wie beim Status: `[UNNotificationRequest]` bleibt
        // drüben, herüber kommt nur die Anzahl.
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.count)
            }
        }
    }
}
