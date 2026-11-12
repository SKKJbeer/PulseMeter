# Konzept: Alle Zähler in einer Tabelle

Stand 12. November 2026. Herkunft: Rezension im App Store („Eine fast perfekte
App ohne Abo“, 4 Sterne, Lionthooth), vom Gründer am 12. November
weitergegeben mit dem Auftrag, es zu prüfen und einzuplanen. Wann es kommt,
steht in `05-roadmap.md`.

## Was der Käufer schreibt

Er hat sieben Zähler und wünscht sich drei Dinge:

1. Die Ablesungen nicht für jeden Zähler einzeln per Mail verschicken müssen.
2. „Warum ist der CSV-Export nur tabellarisch in einer E-Mail abgehängt? Ich
   wünsche mir eine echte CSV, die auch in Excel eingelesen werden kann.“
3. Eine CSV über alle Zähler.

Gelobt werden der Verbrauchsbericht mit Vorjahresvergleich, der Einmalkauf und
der Datenschutz.

## Was die App heute kann (geprüft am Stand von `main`, a389b0c)

| Wunsch | Heute | Stelle |
|---|---|---|
| Ablesungen als CSV | Ja, **je Zähler**: Verlauf → „Tabellen“ → „Ablesungen als CSV“ oder „Auswertung als CSV“ | `App/HistoryView.swift`, `exportRow` |
| Datei für Excel | Inhalt passt schon: Semikolon, Dezimalkomma, UTF-8 mit BOM, ISO-Datum, Formeln entschärft | `PulseCore/Engine/TableExport.swift`, `CSVAusgabe` |
| Als Datei in der Mail | **Wahrscheinlich nicht.** Siehe unten | `CSVAusgabe.transferRepresentation` |
| Alle Zähler auf einmal | Nur als **PDF-Verbrauchsbericht** („Alle Zähler“ ist dort schon wählbar, ohne Kauf mit Wasserzeichen). Als Tabelle: **nein** | `App/ReportComposer.swift` (`scope: nil`) |
| Kosten | Frei, Produktprinzip 5: der Export bleibt dauerhaft kostenlos | `TableExport.swift`, Kopfkommentar |

### Warum die Tabelle im Text der Mail landet

`CSVAusgabe` gibt die Tabelle als **Daten** weiter
(`DataRepresentation(exportedContentType: .commaSeparatedText)`), nicht als
Datei. Der Typ `public.comma-separated-values-text` gilt für iOS als Text. Mail
nimmt Text, den es aus dem Teilen-Blatt bekommt, in den Mailtext auf, statt ihn
anzuhängen. Genau das beschreibt der Käufer: die Tabelle steht in der Mail, und
Excel hat nichts zum Öffnen.

**Nicht gemessen**, nur aus dem Code und der Beschreibung geschlossen. Wird mit
dem ersten TestFlight-Bau am Gerät bestätigt (Mail, Dateien, Numbers, Excel),
bevor die Fassung eingereicht wird.

### Wie der Export am iPhone heute abläuft

Verlauf → Knopf „Tabellen“ (Symbol: Pfeil nach unten in eine Ablage, für
VoiceOver „Tabellen herunterladen“) → Auswahl „Ablesungen als CSV“ oder
„Auswertung als CSV“ → **Teilen-Blatt von iOS**. Es öffnet sich also weder
direkt eine Mail noch wird etwas gesichert. Im Teilen-Blatt stehen oben die
Apps, Mail meist ganz vorn; „In Dateien sichern“ steht weiter unten in der
Liste der Aktionen.

Der Verdacht des Gründers (12. November: „dass es auf dem Handy als Mail öffnet
und nicht direkt in Dateien sichert“) passt dazu: Das Symbol verspricht einen
Download, es kommt ein Teilen-Blatt, der naheliegende Griff ist Mail, und dort
landet die Tabelle im Text. Zwei Dinge sind also falsch, und beide werden
behoben: der Knopf sagt nicht, was passiert, und der Weg über Mail liefert
keine Datei.

Die Datei selbst ist für Excel bereits richtig gebaut. Es fehlt nicht das
Format, sondern der Anhang.

## Ziel

Wer mehrere Zähler hat, bekommt mit **einem** Tipp **eine** Datei mit allen
Ablesungen, die als Anhang ankommt und sich in Excel und Numbers mit einem
Doppelklick richtig öffnet.

## Umfang

### A. Die Tabelle wird eine Datei (betrifft auch den Export je Zähler)

- `CSVAusgabe` schreibt beim Teilen eine Datei in einen temporären Ordner und
  gibt sie als `FileRepresentation` weiter. Dateiname wie heute
  (`Zählora-Strom-Ablesungen.csv`).
- Der Inhalt bleibt Byte für Byte, wie er ist. Die Datei entsteht weiterhin
  erst beim Teilen, nie beim Zeichnen des Schirms (der Grund, warum
  `CSVAusgabe` existiert, 0.61.0).
- Alte Dateien im temporären Ordner werden beim nächsten Export weggeräumt.
- Der Knopf sagt, was passiert: Symbol `square.and.arrow.up` (Teilen) statt
  des Download-Pfeils, Beschriftung „Tabelle teilen oder sichern“, für
  VoiceOver „Tabellen teilen oder in Dateien sichern“. Ob das Wort „Teilen“
  allein reicht, entscheidet der Klick-Dummy.

### B. „Alle Zähler als Tabelle“

**Wo:** im Tab „Zähler“, als Karte direkt unter „Aus einer Tabelle einlesen“.
Dort, wo Zähler hineinkommen, kommen sie auch wieder heraus. Kein Umweg über
einen einzelnen Zähler und keine Einstellungsseite. Die Karte erscheint ab zwei
Zählern; mit einem Zähler reicht der Weg über den Verlauf.

**Was:** ein Tipp öffnet direkt das Teilen-Blatt mit einer Datei
`Zählora-Alle-Zähler-Ablesungen-2026-11-12.csv`. Keine Auswahl davor:
Zeitraum und Zählerwahl wären Fragen, die der Käufer nicht gestellt hat, und
Excel filtert besser als ein Formular.

**Aufbau der Datei:** dieselben Spalten wie der Export je Zähler, damit eine
Datei aus der App und eine Datei aus dem Verlauf nebeneinander passen:

```
Zähler;Bezeichnung;Datum;Uhrzeit;Stand;Einheit;Art
Strom;Bezug;2026-01-01;;8000,250;kWh;abgelesen
Strom;Einspeisung;2026-01-01;;1200,000;kWh;abgelesen
Wasser;Bezug;2026-01-01;;345,123;m³;Kamera
```

- Eine Zeile je Ablesung und Zählwerk. „Bezeichnung“ und „Uhrzeit“ stehen da,
  sobald **ein** Zähler sie braucht, sonst fehlen sie wie heute.
- Reihenfolge: Zähler wie im Tab „Zähler“, darin nach Datum. So steht jeder
  Zähler als Block untereinander, und ein Filter in Excel auf „Zähler“ gibt die
  Datei je Zähler zurück.
- Archivierte Zähler sind dabei, denn auch sie sind Daten des Nutzers
  (Produktprinzip 5). Eine Spalte dafür gibt es nicht; wer sie nicht will,
  filtert sie weg.
- Zwei Zähler mit gleichem Namen bleiben unterscheidbar: der zweite heißt in der
  Datei „Wasser (2)“.
- Diese Datei lässt sich mit „Aus einer Tabelle einlesen“ wieder einlesen. Das
  wird getestet, denn eine Sicherung, die man nicht zurückbekommt, ist keine.

**Nicht dabei:** die Auswertung (Verbrauch je Monat) über alle Zähler. Sie hat
je Zähler eine andere Einheit und einen anderen Zeitraum und wäre als eine
Tabelle schwer zu lesen. Für den Überblick über alle Zähler gibt es den
Verbrauchsbericht. Fragt jemand danach, kommt sie später.

**Kosten:** frei, ohne Kauf und ohne Grenze. Das ist schon entschieden
(Produktprinzip 5), auch wenn mehr als zwei Zähler einen Kauf brauchen.

### C. Wunsch 1 ist damit erfüllt

„Alle Ablesungen per Mail“ ist B plus Mail im Teilen-Blatt. Ein eigener
Mail-Knopf mit Empfänger und Betreff kommt nicht dazu: Das Teilen-Blatt kann
Mail, Nachrichten, Dateien und AirDrop, und jeder dieser Wege ist für jemanden
der richtige.

## Architektur

- **PulseCore:** `TableExport.readings(allMeters:)` nimmt eine Liste aus
  (Zähler, Ablesungen) und baut die eine Datei. Rein, ohne Speicher, mit den
  vorhandenen Bausteinen `escape`, `decimal`, `isoDate`, `name(of:)`. Der Export
  je Zähler ruft künftig dieselbe Funktion mit einem Element, damit es nur eine
  Umsetzung gibt.
- **App:** `CSVAusgabe` (aus `HistoryView.swift` in eine eigene Datei
  `App/CSVAusgabe.swift`, weil zwei Schirme sie brauchen) mit
  `FileRepresentation`. `MetersView` liest Zähler und Ablesungen über
  `PulseRepository` erst beim Teilen.
- **Klick-Dummy:** Karte im Zähler-Tab, Tipp zeigt die Datei als Tabelle.

## Bedienung

- Text der Karte: „Alle Zähler als Tabelle“, darunter „Alle Ablesungen in einer
  CSV-Datei, für Excel oder Numbers“. Symbol `square.and.arrow.up`.
- VoiceOver: „Alle Zähler als Tabelle teilen“.
- Im Verlauf bleibt „Tabellen“ wie es ist; dort ändert sich nur, dass die Datei
  als Anhang ankommt.

## Testplan

- PulseCore: Datei mit drei Zählern (einer mit zwei Zählwerken, einer mit
  Uhrzeit, einer archiviert): Kopfzeile, Reihenfolge, Spalten bei allen Zeilen
  gleich viele, gleiche Namen unterscheidbar, Formel im Namen entschärft.
- PulseCore: Rundweg. Datei bauen, mit `TableImport` einlesen, dieselben
  Ablesungen.
- PulseCore: ein Zähler über die neue Funktion gibt dieselbe Datei wie heute
  (der Export je Zähler ändert sich nicht unbemerkt).
- App-Test: Karte erscheint ab zwei Zählern, nicht bei einem.
- Am Gerät, vor dem Einreichen: Mail (Anhang statt Text), in Dateien sichern,
  in Excel und Numbers öffnen, Umlaute und Kommazahlen richtig.

## Aufwand

Klein bis mittel: eine Funktion im Rechenkern, eine Karte, ein geänderter
Teilen-Weg. Etwa ein Tag einschließlich Tests und Klick-Dummy.
