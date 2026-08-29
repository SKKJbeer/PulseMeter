import Foundation

/// Wie sich ein Jahresverbrauch über die Monate verteilt.
///
/// **Wozu das gut ist.** Eine Hochrechnung braucht eine Vorstellung davon, wie
/// viel des Jahres ein gemessener Ausschnitt darstellt. „Bis zum 1. April sind
/// 40 % angefallen" ist eine völlig andere Aussage bei Gas als bei Wasser —
/// und wer beides gleich behandelt, sagt einem Gaskunden im Februar das
/// Doppelte voraus. Gemessen: Ohne Profil lag die Hochrechnung für Gas am
/// 1. Februar **100 % zu hoch**.
///
/// **Woher die Zahlen kommen.** Nicht aus dem Gefühl und nicht aus den
/// Beispieldaten dieses Projekts, sondern aus veröffentlichten Quellen — die
/// Herkunft steht bei jedem Profil. Ein selbst ausgedachtes Profil würde in
/// einer Prüfung wunderbar aussehen, die es gegen sich selbst hält, und im
/// Zähler eines echten Nutzers versagen.
///
/// **Was es nicht ist.** Kein Ersatz für die eigene Historie. Sobald ein Jahr
/// eigener Ablesungen vorliegt, gewinnt die immer — ein Referenzprofil ist der
/// Durchschnitt vieler Haushalte, und niemand wohnt im Durchschnitt.
public struct SeasonalProfile: Hashable, Sendable {

    /// Woher die Verteilung stammt. Gehört zum Ergebnis, weil eine Zahl, die
    /// auf fremden Daten beruht, als solche gekennzeichnet werden muss
    /// (Produktprinzip 7).
    public let source: String

    /// Anteil je Monat, Januar bis Dezember. Summiert sich auf 1.
    public let monthlyShares: [Decimal]

    public init?(source: String, monthlyShares: [Decimal]) {
        guard monthlyShares.count == 12 else { return nil }
        let total = monthlyShares.reduce(0, +)
        guard total > 0 else { return nil }
        self.source = source
        // Normiert statt geprüft: Die veröffentlichten Tabellen sind gerundet
        // und summieren sich auf 99,8 oder 100,2 Prozent. Auf einer Rundung zu
        // bestehen hieße, eine Quelle wegen der zweiten Nachkommastelle nicht
        // benutzen zu können.
        self.monthlyShares = monthlyShares.map { $0 / total }
    }

    /// Welcher Anteil eines Jahres in diesen Zeitraum fällt.
    ///
    /// Innerhalb eines Monats wird **linear nach Tagen** geteilt. Das ist
    /// gröber als die Wirklichkeit — der 1. Januar ist kälter als der 31. —,
    /// aber der Fehler daraus ist klein gegen den, den es zu vermeiden gilt.
    ///
    /// Der Zeitraum wird halboffen gelesen: `start` zählt mit, `end` nicht.
    /// Genauso versteht `ConsumptionEngine` einen Zeitraum, und zwei
    /// Auffassungen davon wären die wiederkehrende Fehlerklasse aus CLAUDE.md
    /// in Reinform.
    public func share(of range: DayRange) -> Decimal {
        guard range.spanInDays > 0 else { return 0 }
        var total = Decimal(0)
        var cursor = range.start

        while cursor < range.end {
            let monthEnd = cursor.endOfMonth.adding(days: 1)   // erster Tag des Folgemonats
            let sliceEnd = Swift.min(monthEnd, range.end)
            let daysInSlice = sliceEnd.days(since: cursor)
            let daysInMonth = monthEnd.days(since: cursor.startOfMonth)
            if daysInMonth > 0, daysInSlice > 0 {
                let monthShare = monthlyShares[cursor.month - 1]
                total += monthShare * Decimal(daysInSlice) / Decimal(daysInMonth)
            }
            cursor = sliceEnd
        }
        return total
    }

    /// Welcher Anteil des Zeitraums `period` in `part` fällt.
    ///
    /// Nicht `share(of: part) / share(of: period)` an der Aufrufstelle, sondern
    /// hier: Ein Abrechnungszeitraum muss kein Kalenderjahr sein — er kann am
    /// 1. Juli beginnen —, und dann ist der Nenner eben nicht 1.
    public func share(of part: DayRange, within period: DayRange) -> Decimal? {
        let whole = share(of: period)
        guard whole > 0 else { return nil }
        let piece = share(of: part)
        guard piece > 0 else { return nil }
        return Swift.min(piece / whole, 1)
    }
}

// MARK: - Die veröffentlichten Profile

extension SeasonalProfile {

    /// Das typische Profil einer Zählerart in Deutschland.
    ///
    /// `nil`, wo es keine belastbare Quelle gibt. Dann rechnet
    /// ``ForecastEngine`` linear weiter und sagt das auch — ein erfundenes
    /// Profil wäre schlimmer als gar keines.
    public static func reference(for kind: ResourceKind,
                                 direction: FlowDirection = .consumption) -> SeasonalProfile? {
        // Was ins Netz zurückgeht, folgt der Sonne und nicht dem Zähler
        // dahinter. Ein Bezugsprofil auf die Einspeisung anzuwenden wäre
        // gegenläufig — und damit schlimmer als kein Profil.
        if direction == .feedIn { return solar }

        switch kind {
        case .gas, .districtHeating, .heatingOil:
            return heating
        case .electricity, .wallbox, .batteryStorage:
            return household
        case .solarProduction:
            return solar
        case .water, .hotWater, .rainwater, .operatingHours, .custom:
            // Wasser schwankt über das Jahr kaum, und der Gartenzuschlag im
            // Sommer ist von Haushalt zu Haushalt so verschieden, dass ein
            // Mittelwert nichts gewinnt. Gleichverteilt ist hier keine
            // Notlösung, sondern die ehrlichste Annahme.
            return nil
        }
    }

    /// Heizen: Gradtagszahlen nach VDI 2067, plus Warmwasser gleichmäßig.
    ///
    /// **Warum ausgerechnet diese Tabelle.** Die Gradtagszahlen nach VDI 2067
    /// sind in Deutschland der anerkannte Maßstab, um genau dieses Problem zu
    /// lösen: einen Jahresbetrag auf Monate aufzuteilen. Sie werden bei jeder
    /// Heizkostenabrechnung mit Mieterwechsel angewandt und stammen aus zwanzig
    /// Jahren Temperaturmessungen. Näher an „amtlich" kommt man hier nicht.
    ///
    /// Anteile je Tausend: Jan 170, Feb 150, Mär 130, Apr 80, Mai 40,
    /// Jun–Aug zusammen 40, Sep 30, Okt 80, Nov 120, Dez 160.
    ///
    /// **Warum sie allein nicht reicht.** Die Tabelle beschreibt die *Heizung*.
    /// Wer mit Gas auch das Warmwasser bereitet, verbraucht im Juli nicht
    /// nichts. Warmwasser macht in einem deutschen Haushalt grob ein Sechstel
    /// des Gasverbrauchs aus und fällt gleichmäßig an; es wird deshalb mit
    /// 18 % nach Tagen verteilt daruntergelegt.
    ///
    /// Das Verhältnis Januar zu Juli beträgt damit rund 6 zu 1 — dieselbe
    /// Größenordnung, die auch die veröffentlichten Tagesmengen für ganz
    /// Deutschland zeigen (Januar 2025 rund 3.988 GWh/Tag, August 1.181).
    public static let heating: SeasonalProfile = {
        let heizung: [Decimal] = [170, 150, 130, 80, 40,
                                  dec("13.333"), dec("13.333"), dec("13.333"),
                                  30, 80, 120, 160]
        let tage: [Decimal] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let warmwasserAnteil = dec("0.18")
        let shares = (0..<12).map { i in
            (1 - warmwasserAnteil) * heizung[i] / 1000
                + warmwasserAnteil * tage[i] / 365
        }
        return SeasonalProfile(source: "Gradtagszahlen nach VDI 2067, mit 18 % Warmwasser",
                               monthlyShares: shares)!
    }()

    /// Haushaltsstrom: aus dem Standardlastprofil H0 (VDEW/BDEW).
    ///
    /// Das Profil teilt das Jahr in drei Abschnitte und nennt für jeden den
    /// Anteil am Jahresverbrauch: Winter (1.11.–20.3.) 43,75 %, Sommer
    /// (15.5.–14.9.) 28,77 %, Übergangszeit 27,48 %. Daraus ergibt sich je
    /// Abschnitt ein Tagesmaß, und daraus die Monate.
    ///
    /// Ergebnis: Januar rund 9,7 %, Juli rund 7,3 %. Ein Verhältnis von 1,4 zu
    /// 1 — deutlich flacher als beim Heizen, aber eben nicht flach. Wer
    /// Haushaltsstrom gleichmäßig hochrechnet, liegt im Februar rund 20 % zu
    /// hoch.
    public static let household: SeasonalProfile = {
        // Tagesanteile der drei Abschnitte, in Prozent des Jahres je Tag.
        let winter = dec("43.75") / 140      // 1.11.–20.3.
        let sommer = dec("28.77") / 123      // 15.5.–14.9.
        let uebergang = dec("27.48") / 102   // der Rest
        // Je Monat: wie viele Tage in welchem Abschnitt liegen.
        let tage: [(w: Int, s: Int, u: Int)] = [
            (31, 0, 0),   // Januar
            (28, 0, 0),   // Februar
            (20, 0, 11),  // März
            (0, 0, 30),   // April
            (0, 17, 14),  // Mai
            (0, 30, 0),   // Juni
            (0, 31, 0),   // Juli
            (0, 31, 0),   // August
            (0, 14, 16),  // September
            (0, 0, 31),   // Oktober
            (30, 0, 0),   // November
            (31, 0, 0)    // Dezember
        ]
        let shares = tage.map { Decimal($0.w) * winter + Decimal($0.s) * sommer + Decimal($0.u) * uebergang }
        return SeasonalProfile(source: "Standardlastprofil H0 (VDEW/BDEW)", monthlyShares: shares)!
    }()

    /// Photovoltaik: der Jahresverlauf des spezifischen Ertrags in Deutschland.
    ///
    /// Veröffentlichte Monatswerte in kWh je kWp: 22, 43, 83, 100, 128, 134,
    /// 128, 120, 93, 57, 27, 15 — zusammen rund 950 im Jahr. Dezember zu Juni
    /// steht wie 1 zu 9.
    ///
    /// Das Profil gilt für **jede** Einspeisung, unabhängig von der Zählerart:
    /// Was ins Netz zurückgeht, folgt der Sonne.
    public static let solar = SeasonalProfile(
        source: "Monatlicher PV-Ertrag in Deutschland (kWh je kWp)",
        monthlyShares: [22, 43, 83, 100, 128, 134, 128, 120, 93, 57, 27, 15]
    )!
}

/// Kurzform für ein `Decimal` aus einer Zeichenkette.
///
/// Nur hier, damit die Profile über dem Literal lesbar bleiben. `Decimal(0.18)`
/// aus einem Fließkommaliteral wäre nicht 0,18, sondern etwas daneben — und
/// genau solche Abweichungen sammeln sich in einer Jahresrechnung.
private func dec(_ literal: String) -> Decimal { Decimal(string: literal)! }
