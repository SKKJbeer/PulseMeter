import SwiftUI
import SwiftData
import PulseCore
import PulseData

/// Das Blatt zum Ablesen, mit Rundgang: Nach dem Sichern geht es mit dem
/// nächsten fälligen Zähler weiter, bis keiner mehr wartet.
///
/// **Ein Blatt für den ganzen Rundgang, kein neues je Zähler.** Ein Blatt, das
/// zugeht und gleich wieder aufgeht, zieht einmal über den ganzen Schirm, und
/// wer am Zähler steht, sieht für einen Moment die Übersicht und fragt sich, ob
/// es geklappt hat. Hier wechselt nur der Inhalt, und oben steht, was eben
/// gesichert wurde.
///
/// **Welcher Zähler als Nächstes kommt, steht in ``ReadingRound``**, im
/// Rechenkern und geprüft. Hier wird nur geblättert. Gibt es keinen weiteren
/// fälligen Zähler, ist dieses Blatt genau der Ziffernblock von vorher.
struct Rundgang: View {

    let start: MeteringPoint
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context

    @State private var aktuell: MeteringPoint?
    @State private var runde: ReadingRound?
    @State private var zaehler: [UUID: MeteringPoint] = [:]
    /// Die Namen der Zähler, die in diesem Rundgang gesichert wurden.
    @State private var gesichert: [String] = []

    /// Ob gerade ein Rundgang offen ist. Die Bewertungsfrage wartet so lange.
    ///
    /// Apples Blatt über dem Ziffernblock für Wasser hielte genau den auf, der
    /// gerade am Zähler steht. Gefragt wird, wenn das Blatt zu ist.
    @MainActor static var laeuft = false

    private var punkt: MeteringPoint { aktuell ?? start }
    private var naechster: MeteringPoint? { runde?.next.flatMap { zaehler[$0] } }

    var body: some View {
        // **Erscheinen und Verschwinden hängen an der Hülle, nicht am
        // Ziffernblock.** Der bekommt je Zähler eine neue Identität, und mit
        // ihr meldete er bei jedem Wechsel ein Verschwinden, mitten im
        // Rundgang.
        ZStack {
            CaptureView(meteringPoint: punkt,
                        schritt: RundgangSchritt(naechster: naechster?.name,
                                                 zuletztGesichert: gesichert.last),
                        onSaved: {
                            gesichert.append(punkt.name)
                            onSaved()
                        },
                        onWeiter: naechster == nil ? nil : { weiter() })
                // Ein neuer Zähler ist ein neuer Ziffernblock: leere Anzeige,
                // erstes Zählwerk, Zeitpunkt jetzt. Ohne die Kennung behielte
                // SwiftUI die eingetippten Ziffern des vorigen.
                .id(punkt.id)
        }
        .onAppear(perform: beginne)
        .onDisappear {
            Self.laeuft = false
            // Einmal melden, wenn das Blatt zu ist. Erst jetzt darf die
            // Bewertungsfrage kommen, und sie hängt an genau dieser Meldung.
            if !gesichert.isEmpty { onSaved() }
        }
    }

    /// Legt den Rundgang einmal fest, beim ersten Erscheinen.
    ///
    /// Aus dem Speicher und nicht aus den Karten der Übersicht: Das Blatt geht
    /// auch von außen auf, über Erinnerung, Widget und Siri, und dort gibt es
    /// keine Karten.
    private func beginne() {
        guard runde == nil else { return }
        Self.laeuft = true
        let repository = PulseRepository(context: context)
        guard let points = try? repository.meteringPoints() else { return }
        zaehler = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        var staende: [UUID: [Reading]] = [:]
        for point in points {
            guard let register = point.primaryRegister else { continue }
            staende[point.id] = (try? repository.readings(for: register.id)) ?? []
        }
        runde = ReadingRound(start: start.id, meteringPoints: points,
                             primaryReadings: staende,
                             today: CalendarDay.containing(Date(), in: .current))
    }

    /// Zum nächsten Zähler, ob gesichert oder übersprungen.
    private func weiter() {
        guard let id = runde?.advance(), let naechster = zaehler[id] else { return }
        aktuell = naechster
    }
}

/// Was der Ziffernblock über den Rundgang wissen muss, und nicht mehr.
struct RundgangSchritt: Equatable {
    /// Der Name des Zählers, der nach diesem kommt. `nil`: Hier endet es.
    var naechster: String?
    /// Der Name des Zählers, der eben gesichert wurde.
    var zuletztGesichert: String?

    static let ohne = RundgangSchritt()
}
