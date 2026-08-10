# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-08-09, Version 0.33.4

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
der Schalter steht. **Rot ist die Prüfung**, und inzwischen ist auch gemessen,
woran:

```
LaunchTests.swift:640: XCTAssertEqual failed: („Optional(„0“)“) ≠ („Optional(„1“)“)
                       — Der Schalter für Tag- und Nachtstrom ließ sich nicht umlegen
```

**Der Schalter wird nie umgelegt.** Die Prüfung tippt ihn an und läuft weiter,
und alles Weitere sucht danach ein Feld, das die App zu Recht nicht zeigt.

Drei Diagnosen sind dabei **widerlegt** worden, alle drei durch Messung:

| Vermutung | Version | Widerlegt durch |
|---|---|---|
| Sichtbarer Text statt Feldbeschriftung | 0.32.2 | blieb rot |
| `containing` statt `matching`; falsche Sammlung beim Schieben | 0.32.5 | Baum enthält genau **eine** Sammlung, und die Beschriftung hängt am Feld |
| Ein zweiter Tipper genügt | 0.32.9 | Wert blieb „0" |

**Mit 0.33.1 gelöst.** Ein `tap()` landet in der **Mitte** des Schalters, und
die liegt bei einer Formularzeile auf der Beschriftung statt auf dem Knopf. Der
zusätzliche Tipper bei 90 % der Breite legt ihn um — belegt dadurch, dass der
Fehlschlag von Zeile 640 auf **727** gewandert ist und die Prüfung jetzt
39 statt 21 Sekunden läuft: Sie legt den Schalter um, trägt beide Preise ein,
sichert den Zähler, findet ihn auf der Übersicht und scheitert erst in der
Erfassung.

Der neue Fehlschlag lautet „Die Erfassung nennt das erste Zählwerk nicht" — sie
sucht einen Text, der mit `Hochtarif` beginnt. Vermutlich benennt ein selbst
angelegter Doppeltarifzähler sein erstes Zählwerk anders als der aus den
Beispieldaten. **Nicht geraten:** 0.33.2 gibt bei einem Fehlschlag alle Texte
des Schirms aus, dann ist es eine Ablesung.

**Die Lehre, teuer bezahlt:** Nach dem zweiten Fehlversuch nicht weiterraten,
sondern die Prüfung dazu bringen, den Zustand zu berichten. Der eine Lauf mit
Aufstellung hat mehr geklärt als drei Vermutungen davor.

### Der leere PDF-Bericht — Ursache gefunden, Behebung ungeprüft

Mit 0.32.8 entstehen Bilder auch bei einem gefallenen Lauf. Das erste Bild des
Berichts, das je jemand gesehen hat, zeigte **sechs leere Seitenrahmen**,
schmal in der Mitte des Schirms, in Hell wie in Dunkel.

**Die Wartezeit war es nicht.** 0.33.1 gab dem Bericht 15 statt 4 Sekunden —
das Bild ist unverändert.

**Der Inhalt fehlt auch nicht.** `testTheReportCarriesBothTariffsOfADualTariffMeter`
läuft grün durch und findet „Arbeitspreis Hochtarif" und „Arbeitspreis
Niedertarif" als Text im Bericht. Er ist da, er wird nur unlesbar klein
gezeichnet.

**Die Ursache ist ein Kreisschluss in der Vorschau.** `ReportView` maß die
Breite mit einem `GeometryReader` am Hintergrund genau des Stapels, dessen
Breite von den Seiten kommt — und deren Breite kommt aus dieser Messung. Der
Maßstab blieb bei einem winzigen Wert stehen. 0.33.2 misst stattdessen die
**Bildlaufansicht**: Ihre Breite kommt von außen und hängt an nichts, was von
der Messung abhängt. Dazu `onChange` statt nur `onAppear`, damit Drehung und
geteilter Bildschirm nachziehen.

**Und mit 0.33.3 die zweite, schwerer wiegende Ursache.** Der Gründer sah sich
das Bild an und stellte die Frage, die den Ausschlag gab: Warum sind die Rahmen
*vollständig* leer und nicht bloß winzig bekritzelt?

`scaleEffect` ändert die **Layoutgröße nicht**. Die Seite bleibt 595 × 842 groß
und wird nur kleiner gezeichnet. Der Rahmen darunter — `.frame(width:height:)`
ohne Ausrichtung — zentriert diese unveränderte Box im kleinen Rahmen, während
ab **oben links** gezeichnet wird. Der gemalte Inhalt sitzt dadurch oberhalb
und links des Zuschnitts und wird vollständig weggeschnitten. Übrig bleibt der
leere Rahmen mit Haarlinie, genau wie auf dem Bild. Je kleiner der Maßstab,
desto vollständiger der Verlust — beide Fehler verstärkten einander.

Behoben durch `alignment: .topLeading` am äußeren Rahmen.

**Dazu ein Regressionsnetz:** `testTheReportCarriesBothTariffsOfADualTariffMeter`
fragt jetzt `isHittable` statt nur `exists`. Genau diese Prüfung lief grün,
während der Schirm leer war — der Text stand im Baum und wurde weggeschnitten.
Ein Bericht, den man nicht sehen kann, ist keiner.

**Und das Bild aus dem Lauf zu `79a71b2` (0.33.2) widerlegt auch das.** Die
Seiten sind nicht größer geworden, sondern **kleiner** — von rund 95 auf rund
60 Punkte Breite. Die Messung an der Bildlaufansicht liefert also ebenfalls
einen falschen Wert, und zwar einen kleineren als vorher. Warum, ist unbekannt:
Der Fühler hängt am Hintergrund der `ScrollView`, deren Breite von außen kommt.

Vier Erklärungen, vier Fehlschläge:

| Vermutung | Version | Widerlegt durch |
|---|---|---|
| Vorschau noch nicht fertig | 0.33.1 | 15 statt 4 Sekunden — Bild unverändert |
| Inhalt fehlt | — | `isHittable`-Prüfung findet den Text im Baum |
| Kreisschluss bei der Breitenmessung | 0.33.2 | Seiten wurden **kleiner**, nicht größer |
| Ausrichtung unter `scaleEffect` | 0.33.3 | noch ungeprüft, aber allein zu wenig |

**0.33.4 rät deshalb nicht weiter, sondern schreibt die Zahlen aufs Bild.**
Beim Start mit `-pulse-bericht` steht über den Seiten eine rote Zeile:
`breite=… maßstab=… rahmen=…×… seiten=…`. Sie erscheint nur beim
Bildschirmfoto-Start, nie für einen Nutzer. Das nächste Bild sagt damit selbst,
welche Zahl falsch ist.

Wer das auf einem Mac in zwei Minuten sehen will: `scripts/run.sh` und dann
`build/screenshot-bericht-light.png`.

Und unabhängig vom Ausgang: Das **PDF** in der Datei entsteht über einen
eigenen Weg (`ReportPDF.write` mit `renderer.proposedSize` auf A4) und ist von
diesem Fehler nicht betroffen. Betroffen war die Vorschau auf dem Schirm.

Dieser Fund ist die Bestätigung des Satzes weiter unten: Screenshots finden,
was Tests nicht finden. Der Bericht war seit 0.32.0 „auf den Cent belegt", alle
Prüfungen dazu grün — und trotzdem sah ihn niemand.

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
