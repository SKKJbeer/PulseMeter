import CoreData
import Foundation
import Observation

/// Ob der iCloud-Abgleich klappt — als eine Zeile im Zähler-Tab (1.8).
///
/// **Warum es das gibt.** Im Oktober schrieb ein Käufer, seine Ablesungen
/// kämen auf dem iPad nicht an. Die Ursache lag bei CloudKit (Schema nicht in
/// der Produktion, behoben am 10. November), aber die App konnte es ihm nicht
/// sagen: Ob abgeglichen wird, war nirgends zu sehen. Er konnte nur warten.
///
/// **Was gelesen wird, und was nicht.** Ob auf dem Gerät jemand bei iCloud
/// angemeldet ist (`FileManager.ubiquityIdentityToken`) und die Ereignisse,
/// die SwiftData über
/// `NSPersistentCloudKitContainer.eventChangedNotification` meldet. Beides
/// fragt nur das Gerät; es geht keine eigene Anfrage ins Netz und nichts wird
/// gesendet.
@MainActor
@Observable
final class ICloudAbgleich {

    enum Zustand: Equatable {
        /// Der Speicher läuft ohne Abgleich: im Simulator, in der CI, oder
        /// wenn der Aufbau mit iCloud scheiterte.
        case aus
        /// Auf dem Gerät ist niemand bei iCloud angemeldet, oder iCloud ist
        /// für die App abgeschaltet.
        case keinKonto
        /// Angemeldet, aber noch kein Abgleich beendet, seit die App läuft.
        case wartet
        case abgeglichen(Date)
        case fehler
    }

    private(set) var zustand: Zustand
    @ObservationIgnored private var beobachter: NSObjectProtocol?

    /// - Parameter aktiv: ob der Speicher mit iCloud aufgebaut wurde.
    ///
    /// **Kein `CKContainer`.** Der erste Anlauf fragte
    /// `CKContainer(identifier:).accountStatus()`, und mit ihm stürzte die App
    /// im Simulator der CI beim Start ab (Lauf 43122513685, alle 57
    /// Oberflächenprüfungen rot, der Startbildschirm auf dem Foto). Die
    /// naheliegende Ursache: Ohne passendes Profil wirft das Anlegen eine
    /// Ausnahme, die Swift nicht fangen kann. `ubiquityIdentityToken` sagt
    /// dasselbe, was hier gebraucht wird (angemeldet oder nicht), und wirft nie.
    init(aktiv: Bool) {
        guard aktiv else { zustand = .aus; return }
        zustand = FileManager.default.ubiquityIdentityToken == nil ? .keinKonto : .wartet
        beobachter = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] meldung in
            guard let ereignis = meldung.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let ende = ereignis.endDate else { return }
            let geklappt = ereignis.succeeded
            MainActor.assumeIsolated {
                self?.melde(geklappt: geklappt, ende: ende)
            }
        }
    }

    /// Ein beendetes Ereignis. Ein Fehlschlag überschreibt einen früheren
    /// Erfolg, ein Erfolg einen früheren Fehlschlag — es zählt das Letzte.
    func melde(geklappt: Bool, ende: Date) {
        if zustand == .keinKonto || zustand == .aus { return }
        zustand = geklappt ? .abgeglichen(ende) : .fehler
    }

    /// Die Zeile, wie sie im Zähler-Tab steht.
    static func text(_ zustand: Zustand, jetzt: Date = .now,
                     kalender: Calendar = .current) -> String {
        switch zustand {
        case .aus, .keinKonto:
            return "iCloud ist aus. Ohne iCloud bleiben deine Zählerstände nur auf diesem Gerät."
        case .wartet:
            return "iCloud ist an. Der Abgleich läuft."
        case .fehler:
            return "Der iCloud-Abgleich klappt gerade nicht. Die Zählerstände auf diesem Gerät sind sicher."
        case .abgeglichen(let wann):
            return "Mit iCloud abgeglichen: \(Self.wann(wann, jetzt: jetzt, kalender: kalender))"
        }
    }

    private static func wann(_ datum: Date, jetzt: Date, kalender: Calendar) -> String {
        let uhr = datum.formatted(.dateTime.hour().minute().locale(Locale(identifier: "de_DE")))
        if kalender.isDate(datum, inSameDayAs: jetzt) { return "heute, \(uhr)" }
        if let gestern = kalender.date(byAdding: .day, value: -1, to: jetzt),
           kalender.isDate(datum, inSameDayAs: gestern) { return "gestern, \(uhr)" }
        let tag = datum.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "de_DE")))
        return "\(tag), \(uhr)"
    }
}
