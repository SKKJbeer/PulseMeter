# 02 – Datenmodell

Status: Entwurf zur Entscheidung
Letzte Änderung: 2026-08-04

> Dies ist das wichtigste Dokument des Projekts. Ein UI-Fehler kostet einen Nachmittag.
> Ein Datenmodell-Fehler kostet eine Migration mit Datenverlust bei bezahlenden Nutzern.

---

## 1. Die zentrale Entscheidung: Zähler ≠ eine Zahl

**Problem.** Die naheliegende Modellierung ist: ein Zähler hat einen Namen und eine Liste von Ständen. Das funktioniert für den Stromzähler einer Mietwohnung — und bricht bei praktisch jedem interessanten Fall:

| Fall | Warum „eine Zahl pro Zähler" scheitert |
|---|---|
| **Zweirichtungszähler (PV)** | Ein physisches Gerät, zwei Zählwerke: Bezug (OBIS 1.8.0) und Einspeisung (2.8.0). Zwei getrennte Zähler anzulegen zerreißt Gerät, Nummer und Wechsel-Historie. |
| **Doppeltarifzähler (HT/NT)** | Zwei Zählwerke, zwei Preise, ein Gerät. |
| **Wärmepumpen-Zähler** | Oft Untermessung des Hauptzählers — Verhältnis nur korrekt, wenn beide zum selben Objekt gehören. |
| **Zählerwechsel** | Neues Gerät, neue Nummer, Stand springt auf 0. Wenn die Gerätenummer am „Zähler" hängt, geht entweder die Historie verloren oder der Verbrauch wird negativ. |
| **Batteriespeicher** | Ladung und Entladung als zwei Zählwerke eines Systems. |

**Empfehlung: Drei getrennte Konzepte statt einem.**

```
Messstelle (was gemessen wird, dauerhaft)
   └── Zählwerk / Register (welche Zahl, 1..n)          ← Ablesungen hängen hier
   └── Gerät (welches Kästchen hängt gerade dort, 0..n) ← Seriennummer, Ein-/Ausbau
```

**Begründung.** Die Messstelle ist die stabile Identität über Jahrzehnte („Strom Haupthaus"). Geräte werden gewechselt, Zählwerke gehören zum Gerätetyp. Nur diese Trennung erlaubt eine lückenlose Verbrauchshistorie über einen Zählerwechsel hinweg — und genau das ist der Fall, an dem jede uns bekannte Konkurrenz-App scheitert.

**Auswirkung auf UX (entscheidend).** Der Nutzer sieht diese Struktur **nie**. Beim Anlegen von „Strom" entsteht automatisch eine Messstelle mit genau einem Zählwerk und optional einem Gerät. Die Wörter „Messstelle", „Zählwerk", „Register", „OBIS" tauchen in der Oberfläche nicht auf. Erst wenn der Nutzer „Zweirichtungszähler" oder „Doppeltarif" auswählt, erscheint ein zweites, benanntes Zählwerk — als „Einspeisung" bzw. „Nachttarif", in seiner Sprache.

**Kosten der Entscheidung.** Etwa ein Tag Mehraufwand am Anfang. Die Alternative kostet später eine riskante Migration bei zahlenden Nutzern. Das ist keine knappe Abwägung.

---

## 2. Entitäten

Notation: plattformfreie Domänen-Wertetypen aus `PulseCore`. Die SwiftData-Klassen in `PulseData` spiegeln diese 1:1 wider.

### Property – Objekt / Standort

```swift
struct Property: Identifiable, Hashable {
    let id: UUID
    var name: String              // "Zuhause", "Mühlenweg 4"
    var address: PostalAddress?   // optional, nur für Vermieter relevant
    var note: String?
    var sortIndex: Int
}
```

Für Einzelnutzer wird beim ersten Start implizit ein Standard-Objekt angelegt, das in der UI nicht erscheint. Sichtbar wird die Ebene erst ab dem zweiten Objekt. → Kein Konzept, das man erst lernen muss, aber auch keine Migration, wenn es gebraucht wird.

### Unit – Einheit innerhalb eines Objekts (v1.1, Vermieter)

```swift
struct RentalUnit: Identifiable, Hashable {
    let id: UUID
    var propertyID: Property.ID
    var name: String              // "Wohnung EG links"
    var tenantName: String?
    var occupancy: [OccupancyPeriod]  // Mieterwechsel als Zeiträume
}
```

Bewusst ab Tag 1 im Modell, in v1 ohne UI. Additiv, blockiert nichts.

### MeteringPoint – Messstelle (in der UI: „Zähler")

```swift
struct MeteringPoint: Identifiable, Hashable {
    let id: UUID
    var propertyID: Property.ID
    var unitID: RentalUnit.ID?          // nil = Allgemein / Gesamtobjekt
    var name: String                    // "Strom", "Wärmepumpe"
    var kind: ResourceKind
    var appearance: Appearance          // Symbol + Farbe
    var registers: [Register]           // 1..n
    var devices: [MeterDevice]          // Wechselhistorie, kann leer sein
    var readingInterval: ReadingInterval  // für Erinnerungen
    var isArchived: Bool
    var sortIndex: Int
}
```

### ResourceKind – Zählerart

```swift
enum ResourceKind: Codable, Hashable {
    case electricity, water, hotWater, gas, districtHeating, heatingOil
    case solarProduction, wallbox, batteryStorage
    case operatingHours, rainwater
    case custom(name: String, unit: MeasurementUnit)
}
```

**Wichtig:** `ResourceKind` ist ein *Preset*, kein Constraint. Es bestimmt nur die Vorbelegung von Einheit, Symbol, Farbe, Nachkommastellen und typischem Ableseintervall. Jede dieser Vorbelegungen ist überschreibbar. Damit ist die Erweiterbarkeit („frei definierbare Zähler") kein Sonderfall, sondern der Normalfall mit anderem Startwert.

**Bewusst kein Vererbungsbaum.** Ein „Wärmepumpen-Zähler" ist kein Subtyp mit eigener Logik, sondern ein Stromzähler mit anderem Namen und anderer Rolle. Sondertypen im Code wären der Anfang der Unwartbarkeit.

### Register – Zählwerk

```swift
struct Register: Identifiable, Hashable {
    let id: UUID
    var label: String?              // nil bei Einzel-Register (UI zeigt nichts)
                                    // "Hochtarif", "Einspeisung", "Ladung"
    var unit: MeasurementUnit       // kWh, m³, l, h, MWh
    var direction: FlowDirection    // .consumption | .production | .feedIn | .charge | .discharge
    var integerDigits: Int          // z.B. 6  → Überlauf bei 1.000.000
    var fractionDigits: Int         // z.B. 1  → 12345,6
    var obisCode: String?           // optional, nur Expertenansicht
}
```

`integerDigits`/`fractionDigits` erfüllen zwei Zwecke: die Eingabemaske sieht aus wie das echte Zählwerk (mechanische Ziffernrollen, weiße Vor- und rote Nachkommastellen), **und** sie definieren den Überlaufpunkt für die Verbrauchsberechnung. Ein Detail, das Vertrauen und Korrektheit gleichzeitig erzeugt.

### MeterDevice – physisches Gerät

```swift
struct MeterDevice: Identifiable, Hashable {
    let id: UUID
    var serialNumber: String?
    var installedOn: CalendarDay
    var removedOn: CalendarDay?
    var photoID: UUID?
}
```

Beim Zählerwechsel erfasst der Nutzer **einen** Vorgang („Zähler wurde gewechselt"), die App erzeugt daraus: Endstand altes Gerät + Ausbaudatum + Anfangsstand neues Gerät (Vorbelegung 0) + Einbaudatum. Der Rechenkern verbindet die Zeitreihe über die Lücke. → Der Verbrauch bleibt stetig, obwohl der Zählerstand springt.

### Reading – Ablesung

```swift
struct Reading: Identifiable, Hashable {
    let id: UUID
    var registerID: Register.ID
    var deviceID: MeterDevice.ID?
    var day: CalendarDay
    var value: Decimal
    var origin: ReadingOrigin       // .manual | .camera | .imported | .estimated
    var note: String?
    var photoID: UUID?
    var createdAt: Date             // Beweis-Zeitstempel, nie für Berechnungen
}
```

**Regel:** `value` ist immer der **abgelesene Zählerstand**, nie ein Verbrauch. Verbräuche werden ausschließlich berechnet, nie gespeichert. Damit gibt es genau eine Wahrheit; nachträgliche Korrekturen wirken automatisch auf alle abgeleiteten Werte.

Für Zählertypen ohne kumulatives Zählwerk (z. B. Regenwassertonne, manuelle Mengen) gibt es `Register.accumulationMode = .cumulative | .interval`. Im Intervall-Modus ist `value` die Menge des Zeitraums. Der Rechenkern behandelt beide Fälle hinter derselben Schnittstelle.

### Tariff – Tarif

```swift
struct Tariff: Identifiable, Hashable {
    let id: UUID
    var meteringPointID: MeteringPoint.ID
    var registerID: Register.ID?     // nil = gilt für alle Zählwerke
    var validFrom: CalendarDay
    var validTo: CalendarDay?
    var pricePerUnit: Decimal        // brutto
    var monthlyBasePrice: Decimal
    var currency: CurrencyCode
    var feedInTariff: Decimal?       // Einspeisevergütung
    var gasConversion: GasConversion? // Zustandszahl + Brennwert
}
```

Tarife sind **zeitlich versioniert**. Ein Preiswechsel legt einen neuen Tarif an, korrigiert nie den alten. Der Rechenkern teilt Zeiträume an Tarifgrenzen und rechnet abschnittsweise. Genau hier liegen die Rechenfehler der Wettbewerber.

### BillingCycle – Abrechnungsrhythmus

```swift
struct BillingCycle: Hashable {
    var anchorMonth: Int      // 1...12
    var anchorDay: Int        // 1...31, auf die Monatslänge begrenzt

    func anchor(in year: Int) -> CalendarDay
    func periodStart(onOrBefore: CalendarDay) -> CalendarDay
    func period(containing: CalendarDay) -> DayRange
    func runningPeriod(on: CalendarDay) -> DayRange?
    func completedPeriod(before: CalendarDay) -> DayRange
}
```

Der Abrechnungszeitraum eines Versorgers beginnt fast nie am 1. Januar: Strom
häufig im April, Gas im Oktober, nach einem Umzug irgendwann mitten im Monat.
Ein Bericht über das Kalenderjahr taugt deshalb nicht zum Prüfen der
Jahresabrechnung — er beschreibt einen anderen Zeitraum als die Rechnung.

Zwei Feinheiten, die beide getestet sind:

- **Der Stichtag wird auf die Monatslänge begrenzt.** Ein Rhythmus zum 31.
  wird im Februar zum 28. bzw. 29. Ohne diese Begrenzung gäbe es Jahre ohne
  Stichtag und damit Zeiträume ohne Anfang.
- **Aufeinanderfolgende Zeiträume teilen sich ihren Grenztag.** Der Stand am
  Stichtag ist Endstand des alten und Anfangsstand des neuen Zeitraums.
  Andernfalls fiele der Verbrauch eines Tages zwischen die Zeiträume — derselbe
  Fehler wie bei den Tarifgrenzen in `CostEngine`.

`MeteringPoint.billingCycle` ist optional. Ohne hinterlegten Rhythmus bleiben
nur Kalenderzeiträume, und die Oberfläche bietet die Abrechnungsjahre gar nicht
erst an, statt einen zu erfinden.

### BillingPeriod – Abrechnungszeitraum & Abschlag

```swift
struct BillingPeriod: Identifiable, Hashable {
    let id: UUID
    var meteringPointID: MeteringPoint.ID
    var provider: String?
    var customerReference: String?
    var start: CalendarDay
    var end: CalendarDay
    var monthlyPrepayment: Decimal?   // Abschlag
}
```

Das ist die Entität, die aus einer Zahlensammlung ein Produkt macht: Sie ermöglicht die Aussage **„Bei diesem Verbrauch liegst du am Jahresende 84 € im Plus."** Ohne sie sind wir eine Tabelle.

---

## 3. Der Rechenkern

Reine Funktionen über Wertetypen, keine Persistenz, keine Nebenwirkungen, vollständig testbar.

```swift
enum ConsumptionEngine {
    // Verbrauch zwischen zwei Tagen, mit Interpolation an den Rändern
    static func consumption(register: Register,
                            readings: [Reading],
                            from: CalendarDay, to: CalendarDay) -> ConsumptionResult

    static func dailyAverage(...) -> Quantity
    static func forecast(toEndOf period: BillingPeriod, ...) -> Forecast
    static func cost(consumption: ..., tariffs: [Tariff], over: DateRange) -> Money
    static func prepaymentDelta(period: BillingPeriod, ...) -> Money   // + = Guthaben
    static func yearOverYear(...) -> Comparison
}
```

`ConsumptionResult` enthält nie nur eine Zahl, sondern immer auch die **Qualität** des Ergebnisses:

```swift
struct ConsumptionResult {
    let quantity: Quantity
    let confidence: Confidence   // .measured | .interpolated | .estimated
    let coveredDays: Int
    let warnings: [ConsumptionWarning]
}
```

Damit erfüllen wir Produktprinzip 7 („nie stillschweigend rechnen") technisch erzwungen statt nur als Vorsatz: Die UI *kann* eine interpolierte Zahl nicht wie eine gemessene darstellen, weil die Information mitgeliefert wird.

### Die Randfälle, die den Unterschied machen

| Fall | Verhalten |
|---|---|
| **Zählerüberlauf** | Neuer Stand < alter Stand, Differenz plausibel bei Überlauf um `10^integerDigits` → korrigiert rechnen, Hinweis anzeigen |
| **Zählerwechsel** | Ablesungen zweier Geräte verbinden: (Endstand alt − letzter Stand alt) + (neuer Stand − Anfangsstand neu) |
| **Rückwärtssprung ohne Erklärung** | Nicht raten. Warnung + gezielte Rückfrage: „Zählerwechsel, Rückspeisung oder Tippfehler?" |
| **Fehlende Ablesungen** | Linear interpolieren, aber als `.interpolated` markieren |
| **Tarifwechsel mitten im Zeitraum** | Zeitraum an Tarifgrenzen splitten, tagesgenau anteilig rechnen |
| **Schaltjahr / Monatslängen** | Tagesbasierte Normalisierung statt „÷ 12" |
| **Gas m³ → kWh** | `kWh = m³ × Zustandszahl × Brennwert`; dem Nutzer m³ zeigen, Kosten in kWh rechnen, Umrechnung antippbar erklären |
| **Doppelte Ablesung am selben Tag** | Erlaubt (z. B. Zählerwechsel-Tag); Sortierung sekundär über `createdAt` |
| **Ablesung in der Zukunft** | Blockieren, freundlich erklären |

Diese Tabelle ist gleichzeitig die Testspezifikation für `PulseCore`.

---

## 4. Was wir bewusst NICHT modellieren (v1)

| Nicht enthalten | Begründung |
|---|---|
| Gespeicherte Verbrauchswerte | Redundanz erzeugt Inkonsistenz. Immer berechnen. |
| CO₂-Bilanzierung | Emissionsfaktoren sind politisch, regional und volatil. Wirkt schnell wie Greenwashing. Kandidat für v2, nur mit sauberer Quelle. |
| Live-Datenquellen / Smart Meter | Explizites Nicht-Ziel (siehe `00`, 4.2) |
| Mehrbenutzer / geteilte Haushalte | Erfordert Sync-Konfliktmodell. Realer Bedarf zuerst belegen. |
| Rechtssichere Nebenkostenabrechnung | Rechtliches Risiko (siehe `00`, 4.3) |
| Prognose per ML | Lineare Hochrechnung mit Vorjahresvergleich ist bei 12 Datenpunkten pro Jahr genauso gut und erklärbar. Erklärbarkeit schlägt hier Raffinesse. |

---

## 5. Migrations- und Sicherungsstrategie

- Schema-Version explizit im Store; jede Änderung erhält eine benannte Migrationsstufe.
- **Vor jeder Migration** automatischer vollständiger JSON-Snapshot im App-Container, die letzten drei werden vorgehalten.
- Export enthält *alle* Entitäten, nicht nur Ablesungen — ein Export muss ein vollständiger Wiederherstellungspunkt sein.
- Import ist idempotent über die `UUID`s. Ein zweimal importierter Export erzeugt keine Dubletten.

---

## Hochrechnung: die Rangfolge und ihre Quellen

Seit 0.38.0 wählt `ForecastEngine` in dieser Reihenfolge, und `Forecast.method`
sagt hinterher, welche Stufe gegriffen hat:

| Stufe | Grundlage | Wann |
|---|---|---|
| `ownHistory` | Form gemittelt über bis zu **drei** eigene Vorjahre | Mehrere vollständige Jahre liegen vor |
| `previousYear` | Form des eigenen Vorjahres | Genau ein vollständiges Jahr |
| `reference` | Veröffentlichtes Profil für die Zählerart | Kein eigenes Jahr, aber eine Quelle |
| `linear` | Tagesschnitt gleichmäßig fortgeschrieben | Kein Jahr und keine Quelle |

Gerechnet wird immer gleich: Deckt der gemessene Ausschnitt **x %** eines
Jahres ab, entspricht das Gemessene x % des Jahres. Nur die Herkunft von x
unterscheidet die Stufen. Gemittelt werden Anteile, nie Mengen — die Vorjahre
steuern die Form bei, das Niveau kommt aus dem laufenden Jahr.

### Woher die Referenzprofile stammen

Sie stehen in `SeasonalProfile` und sind **keine Schätzungen**:

- **Heizen** (Gas, Fernwärme, Heizöl) — Gradtagszahlen nach **VDI 2067**, in
  Deutschland der anerkannte Maßstab, um einen Jahresbetrag auf Monate zu
  verteilen; angewandt bei jeder Heizkostenabrechnung mit Mieterwechsel.
  Darunter 18 % Warmwasser gleichmäßig nach Tagen.
- **Haushaltsstrom** — **Standardlastprofil H0** (VDEW/BDEW): Winter 43,75 %,
  Sommer 28,77 %, Übergangszeit 27,48 %, auf Monate umgerechnet.
- **Photovoltaik und jede Einspeisung** — der veröffentlichte Jahresverlauf des
  spezifischen Ertrags in Deutschland.
- **Wasser, Warmwasser, Regenwasser, Betriebsstunden** — bewusst **kein**
  Profil. Ohne belastbare Quelle wäre es erfunden, und der Verbrauch schwankt
  über das Jahr ohnehin kaum.

**Ein Profil ist immer die zweitbeste Antwort.** Es ist der Durchschnitt vieler
Haushalte, und niemand wohnt im Durchschnitt. Sobald ein eigenes Jahr vorliegt,
gewinnt es — ausnahmslos.
