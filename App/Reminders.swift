import Foundation
import UserNotifications
import PulseCore

/// Lokale Erinnerungen an fällige Ablesungen.
///
/// Ohne Konto, ohne Server, ohne Netz: `UNUserNotificationCenter` plant sie auf
/// dem Gerät. Das passt zu ADR-002 — was die App kann, soll sie ohne fremde
/// Hilfe können.
///
/// Am Hauptakteur, weil die Planung aus der Oberfläche angestoßen wird und die
/// Ergebnisse dorthin zurückfließen.
@MainActor
enum Reminders {

    /// Um wie viel Uhr erinnert wird.
    ///
    /// Achtzehn Uhr, nicht morgens: Ein Zählerstand wird abgelesen, wenn
    /// jemand zu Hause ist und in den Keller gehen kann. Eine Mitteilung um
    /// sieben Uhr früh wird weggewischt und nie nachgeholt.
    static let hour = 18

    static var center: UNUserNotificationCenter { .current() }

    /// Fragt nach Erlaubnis — und zwar erst, wenn der Nutzer weiß, wofür.
    ///
    /// Nicht beim ersten Start: Eine Systemfrage, bevor irgendetwas erklärt
    /// wurde, wird verneint, und ein zweites Mal fragt iOS nicht. Deshalb
    /// hängt sie hier am Schalter, den jemand bewusst umlegt.
    static func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
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
        center.removeAllPendingNotificationRequests()
    }

    /// Wie viele Mitteilungen tatsächlich in der Warteschlange stehen.
    /// Für die Anzeige — und damit ein Oberflächentest es prüfen kann.
    static func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }
}
