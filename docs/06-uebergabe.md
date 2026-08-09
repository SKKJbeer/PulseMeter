# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-08-09, Version 0.32.10

---

## Wozu dieses Dokument

Eine neue Sitzung startet kalt. Sie kennt keinen Chatverlauf — weder den auf
dem Mac noch den in der Cloud. Was sie kennt, ist das Repository.

Der **dauerhafte** Teil steht deshalb längst dort und ist ausführlich:

| Was | Wo |
|---|---|
| Warum es dieses Produkt gibt, für wen, wogegen es sich entscheidet | `docs/00-produktstrategie.md` |
| Jede technische Entscheidung mit Begründung | `docs/01-architektur.md` |
| Domänenmodell, Rechenkern, Randfälle | `docs/02-datenmodell.md` |
| **Jede Änderung mit Begründung, neueste oben** | `CHANGELOG.md` |
| Arbeitsweise, Sprachregeln, Prüfschritte | `CLAUDE.md` |
| Was offen ist und in welcher Reihenfolge | `docs/05-roadmap.md` |

Dazu die Kommentare im Code: Sie begründen durchgehend das **Warum**, nicht das
Was. Wer `ConsumptionEngine.consumption(meteringPoint:)` liest, erfährt dort
auch, welcher Fehler zu dieser Form geführt hat.

Was **nicht** im Repository steht, ist der laufende Zustand: was gerade läuft,
was noch nicht geprüft ist, worauf zu achten ist. Genau dafür ist diese Datei.
Sie wird bei jeder Übergabe überschrieben, nicht fortgeschrieben.

---

## Wo die Arbeit gerade steht

**Zweig:** `main`. Der Arbeitszweig `claude/pulsemeter-kickoff-dns3am` ist mit
0.32.3 dorthin zusammengeführt worden — vorher stand `main` auf 0.30.1, und
eine Arbeitskopie darauf sah vollständig aus und war zwei Versionen alt. Genau
das ist einer Sitzung passiert.

| Version | Was | Zustand |
|---|---|---|
| 0.31.0 | Doppeltarif in der App | gebaut, CI grün außer den unten genannten Prüfungen |
| 0.32.0 | PDF-Bericht, dritter Barrierefreiheits-Durchgang | gebaut |
| 0.32.1 | `scripts/pruefen.sh`, Push-Haken, Zweig `pruefungen`, lokale Einrichtung | gebaut |
| 0.32.2 | zwei Oberflächenprüfungen berichtigt | **noch nicht auf einem Mac geprüft** |
| 0.32.3 | `scripts/mac-start.sh` und `Am-Mac-starten.command` — ein Aufruf für alles | **noch nicht auf einem Mac geprüft** |
| 0.32.4 | Der lokale Lauf liefert jetzt dasselbe wie die CI, inklusive Bilder | **noch nicht auf einem Mac geprüft** |
| 0.32.5 | Die letzte rote Oberflächenprüfung berichtigt; macOS-Auftrag der CI nur noch auf `main`, bei Pull-Requests und auf Zuruf | **noch nicht auf einem Mac geprüft** |

### Was als Nächstes zu tun ist

1. **`scripts/mac-start.sh` einmal laufen lassen** (oder
   `Am-Mac-starten.command` doppelklicken). Das ist der eigentliche offene
   Punkt: Die letzten vier Versionen sind nie auf einem Mac gelaufen, nur in
   der CI — und eine CI-Runde hatte zwei rote Prüfungen, die mit 0.32.2
   berichtigt sein sollten. Ob sie es sind, weiß niemand.
2. **Die Screenshots ansehen**, besonders `screenshot-bericht-*` und
   `screenshot-zurueck-*`. Beide zeigen etwas, das noch nie jemand gesehen
   hat: den PDF-Bericht und den zweiten Schritt der Erfassung.
3. Danach die Roadmap: **Foto-Belege**, dann **Siri-Kurzbefehl**.

### Was zuletzt rot war und warum

Der Lauf auf `6df2969` (0.32.2) meldete **21 Prüfungen, ein Fehlschlag**. Die
Korrektur an `testTheReportCarriesBothTariffsOfADualTariffMeter` hat gehalten;
die andere nicht:

```
LaunchTests.swift:629: XCTAssertTrue failed - Das Feld für den Nachtpreis fehlt
```

Das Produkt ist in Ordnung — `priceSection` zeigt „Arbeitspreis nachts", sobald
der Schalter steht, und der Schalter wurde im selben Test gefunden und
umgelegt. Rot war die **Prüfung**, aus zwei Gründen, die in 0.32.5 beide
geschlossen sind:

- `app.textFields.containing(…)` sucht die Beschriftung unter den **Nachfahren**
  des Feldes. Ein Eingabefeld hat keine; die Beschriftung hängt seit 0.32.0 am
  Feld selbst. Richtig ist `matching`. Bei den `staticTexts` weiter oben fällt
  der Unterschied nicht auf — deshalb ist er so lange durchgegangen.
- Der Scroll-Helfer wischte auf `collectionViews.firstMatch`. Bei einem
  vorgeblendeten Formular ist das die Liste **dahinter**; das Formular bewegt
  sich nicht, das Feld bleibt außerhalb des Bildes, und der Test meldet „fehlt".
  Er nimmt jetzt die oberste Sammlung.

**Beides ist Schlussfolgerung, nicht Messung.** Ein Simulator stand hier nicht
zur Verfügung. Der erste Lauf auf einem Mac entscheidet.

### Was ich nicht prüfen konnte

Diese Änderungen entstanden in einem Linux-Container. Dort laufen `PulseCore`
(154 Prüfungen) und der Klick-Dummy (44 Prüfungen) vollständig; **alles mit
SwiftUI, SwiftData oder dem Simulator nicht.** Der PDF-Bericht ist deshalb
zwar durchgerechnet und in `ReportBuilderTests` auf den Cent belegt — aber
**noch nie als PDF gesehen worden**. Das ist die größte offene Unsicherheit
im aktuellen Stand.

---

## Worauf besonders zu achten ist

**Die wiederkehrende Fehlerklasse.** Jeder bisher gefundene Rechenfehler in
diesem Projekt entstand daraus, dass ein Zeitraum, den die Daten abdecken,
gegen einen verglichen wurde, den sie nicht abdecken. Elf Fälle, zuletzt in
meiner eigenen Handrechnung zum Doppeltarif. Steht in `CLAUDE.md` und ist
keine Floskel.

**Der Klick-Dummy ist der produktivste Fehlerfinder.** Er rechnet echt, nicht
mit Platzhaltern. Weicht er von `PulseCore` ab, ist das ein Fehler, kein
Zustand — und in den meisten Fällen hatte bisher der Entwurf recht.

**Screenshots finden, was Tests nicht finden.** Sieben Darstellungsfehler kamen
so ans Licht, darunter der doppelt berechnete Grundpreis. Ein grüner Lauf sagt
nichts über Layout, Kontrast oder abgeschnittene Beschriftungen.

**Beim Nutzer liegen:** Apple Developer Program (Paywall, App-Gruppe fürs
Widget, TestFlight) und die 800-ms-Messung auf einem echten Gerät.

---

## Wie die beiden Orte zusammenarbeiten

Eine Sitzung am Mac und eine in der Cloud sehen einander **nicht**. Verbunden
sind sie über das Repository und über zwei Zweige:

- **`pruefungen`** — eine Zeile je lokalem Lauf: Zeitpunkt, Stand, Ergebnis,
  Umfang, Dauer, Rechner, und ob das Arbeitsverzeichnis sauber war. Geschrieben
  vom Haken vor dem Push. Eine Cloud-Sitzung liest daraus, ob ein Stand schon
  geprüft wurde, statt auf die CI zu warten.
- **`screenshots`** — die Bilder des letzten Laufs, hell und dunkel. Seit 0.32.4
  füllt ihn auch ein **lokaler** Lauf (`scripts/pruefen.sh --melden`, und damit
  jedes `scripts/mac-start.sh`), nicht mehr nur die CI. Die Kopfzeile im Zweig
  sagt, woher die Bilder stammen — CI oder Mac — und ob das Arbeitsverzeichnis
  sauber war. Wird überschrieben, ist also keine Historie.

Damit ist die CI für nichts mehr das Nadelöhr. Sie bleibt die Gegenprobe auf
einem frischen Rechner; der erste Durchgang gehört auf den Mac, weil er dort
zwei statt fünfzehn Minuten dauert.

Sinnvolle Aufteilung: Die Cloud-Sitzung nimmt `PulseCore` und den Entwurf, die
Sitzung am Mac baut, prüft und fotografiert die App. Beide halten sich an
`CLAUDE.md`.
