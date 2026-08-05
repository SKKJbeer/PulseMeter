# Änderungen

Alle nennenswerten Änderungen an PulseMeter, neueste Version oben.
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/);
bis zur Einreichung im App Store bleibt die Hauptversion `0`.

Der Ablauf, nach dem diese Datei gepflegt wird, steht in
`.claude/skills/release-discipline/SKILL.md`.

---

## 0.12.0 — 2026-08-05

### Hinzugefügt
- Der Erfassungsscreen. Zählwerk in Geräteoptik — weiße Vorkomma-, rote
  Nachkommastellen auf dunklem Grund —, eigener großer Ziffernblock statt
  Systemtastatur, Datum auf heute vorbelegt.
- Live-Plausibilisierung während der Eingabe: „Entspricht 312 kWh in 31 Tagen
  — normal für dich" oder bei einer Stelle zu viel „rund 11× dein üblicher
  Verbrauch. Stimmt die Zahl?". Ein Hinweis, keine Blockade — ein auffälliger
  Wert kann richtig sein, und die App weiß es nicht besser als der Mensch vor
  dem Zähler.
- „Vom letzten Stand übernehmen", damit sich die unveränderten führenden
  Ziffern nicht abtippen lassen müssen.

### Geändert
- Die Beispieldaten umfassen drei Zähler statt einem, davon einer bewusst
  überfällig. Nur so lassen sich Fällig-Zustand, Hinweiszeile und der
  Erfassungsfluss überhaupt prüfen.
- Zwei zusätzliche Oberflächentests: Wird ein überfälliger Zähler gemeldet, und
  führt der Erfassungsfluss zurück in die Übersicht?

Warum dieser Screen vor allen anderen kommt: Der Nutzer steht im Keller, bei
schlechtem Licht, vielleicht mit einer Lampe in der Hand. Entsteht hier
Reibung, hört er nach drei Monaten auf — und alle anderen Funktionen werden
wertlos.

---

## 0.11.1 — 2026-08-05

### Behoben
- Die Simulator-Auswahl verglich Gerätenamen als Text. Dabei steht
  „iPhone SE" hinter „iPhone 16 Pro", weil S hinter 1 kommt — acht Läufe lang
  wurde die App auf dem kleinsten verfügbaren Bildschirm gebaut, getestet und
  fotografiert. Jetzt wird die Zahl im Namen ausgewertet.

Gefunden hat das kein Test, sondern der Blick auf den Screenshot: 750 × 1334
Pixel sind kein aktuelles Gerät. Genau dafür steht der Schritt in der
Prüfliste.

_Keine Änderung am Produkt. Tests unverändert._

---

## 0.11.0 — 2026-08-04

### Hinzugefügt
- `PulseUI`, das Design-System: Farben, Textstile und die Kernkomponenten aus
  `03-ux-konzept.md`. Die Palette steht als Code statt in einem Asset-Katalog —
  sie bleibt damit lesbar, versionierbar und in einer Zeile vergleichbar mit
  dem Klick-Dummy.
- Die Übersicht zeigt jetzt Zähler-Karten mit Verlaufslinie, Vorjahresvergleich
  und Statuszeile in ganzen Sätzen, statt einer Liste aus Textzeilen.

### Geändert
- Die Neutralen sind warm gebrochen statt kalt-grau. Die Zählerfarben sind die
  eigentliche Palette und machen die App ohne Text lesbar; ein kaltes Grau
  konkurriert mit ihnen.
- Sämtliche Textstile leiten sich von Systemstilen ab und wachsen deshalb mit
  Dynamic Type. Feste Punktgrößen wären bequemer und zerbrächen bei der
  größten Stufe — also genau dort, wo Barrierefreiheit anfängt.
- Die Beispieldaten umfassen gut zwei Jahre statt zweier Ablesungen. Mit zwei
  Werten sähe die Karte fertig aus und wäre doch leer: keine Verlaufslinie,
  kein Vorjahresvergleich.
- Der Oberflächentest prüft jetzt den Vorjahresvergleich statt nur den
  Jahresverbrauch. Er entsteht nur, wenn Speicher und Rechenkern über zwei
  Jahre Historie zusammenspielen.

_82 Tests in PulseCore, 10 in PulseData, beide Oberflächentests. Screenshots in
Hell und Dunkel liegen dem Lauf bei._

---

## 0.10.2 — 2026-08-04

Die erste Fassung, die auf einer Apple-Plattform tatsächlich gebaut, getestet
und gestartet wurde. Die CI auf einem macOS-Läufer fand innerhalb einer Stunde
fünf Fehler, die unter Linux allesamt unsichtbar waren.

### Behoben
- `Schema` lag als statische Konstante vor. `Schema` ist nicht `Sendable`,
  also unter Swift 6 global geteilter Zustand — `PulseData` ließ sich nicht
  übersetzen. Jetzt berechnet.
- Der Wiederherstellungstest legte einen zweiten Speicher im selben Prozess an
  und brachte ihn zu Fall. SwiftData verträgt das nicht, auch nicht mit
  unterschiedlichen Namen. Der leere Zustand entsteht jetzt durch Löschen —
  und belegt nebenbei, dass die Löschregel die Ablesungen mitnimmt.
- Die Oberflächentests waren nicht an den Hauptakteur gebunden. Die
  XCUITest-Schnittstellen sind es unter Swift 6, das Testziel ließ sich nicht
  bauen.
- Das Datum stand als `2026-08-04` auf dem Schirm — die Rohform des
  Kalendertags und damit technisches Vokabular. Jetzt „4. August 2026".

### Geändert
- Der Screenshot-Schritt übersetzte die App ein zweites Mal vollständig, für
  dasselbe Programm. Test- und Screenshot-Schritt teilen sich jetzt das
  Ableseverzeichnis; Hell und Dunkel entstehen durch Neustarten statt
  Neubauen. Spart auf einem gemieteten macOS-Läufer mehrere Minuten je Lauf.

_82 Tests in PulseCore, 10 in PulseData, beide Oberflächentests — alle grün auf
macOS. Die App startet im Simulator und zeigt einen vom Rechenkern ermittelten
Verbrauch._

---

## 0.10.1 — 2026-08-04

### Hinzugefügt
- CI auf einem macOS-Läufer. Sie übersetzt und testet, was auf einem
  Linux-Rechner nicht übersetzt werden kann: `PulseData`, das App-Target und
  die Skripte. Screenshots beider Erscheinungsbilder werden abgelegt.

### Behoben
- `PulseCore` gab keine Mindestversion der Plattform an. SwiftPM nahm auf
  Apple-Plattformen daraufhin eine sehr alte an, unter der `Identifiable` als
  nicht verfügbar gilt — das Paket ließ sich auf einem Mac gar nicht
  übersetzen. Unter Linux gibt es keine Verfügbarkeitsprüfung, deshalb fiel es
  dort nie auf. Der erste Fund der neuen CI, und ein gutes Argument für sie.

_82 Tests grün._

---

## 0.10.0 — 2026-08-04

### Hinzugefügt
- App-Gerüst: iOS-Target mit Tab-Navigation, das die Übersicht aus dem
  gespeicherten Bestand lädt und den Verbrauch über den Rechenkern ermittelt.
  Es belegt, dass App, Persistenz und Domäne zusammenspielen — gestaltet wird
  später mit `PulseUI`.
- Das Xcode-Projekt wird aus `project.yml` erzeugt statt eingecheckt. Eine
  `.xcodeproj` sortiert bei jeder Änderung Zeilen um und macht das
  Zusammenführen unnötig schwer; die Beschreibung ist lesbar und wiederholbar.
- Automatisierung in `scripts/`: `setup-mac.sh` richtet die Umgebung ein,
  `test.sh` prüft Pakete und App im Simulator, `run.sh` startet die App und
  legt einen Screenshot ab. Damit lässt sich ein Ergebnis auch ohne Blick auf
  den Bildschirm beurteilen.
- Zwei Oberflächentests: Startet die App, und erzeugt das Anlegen von
  Beispieldaten einen berechneten Wert? Ein Übersetzungsfehler fällt beim Bauen
  auf, ein Absturz beim Start nicht.
- Skill `xcode-workflow` mit dem Ablauf, den erwartbaren Fehlerbildern und dem
  Weg, CloudKit später einzuschalten.

### Geändert
- Die Prüfliste beginnt jetzt mit `git status`. Ein auf einen älteren Stand
  zurückgefallenes Arbeitsverzeichnis sah schon einmal wie verlorene Arbeit
  aus, obwohl auf dem Remote alles vollständig war.

_82 Tests in PulseCore, alle grün. App-Gerüst, `PulseData` und die Skripte sind
unter Linux nicht ausführbar und warten auf den ersten Lauf am Mac._

---

## 0.9.1 — 2026-08-04

### Geändert
- Die Roadmap nennt den erreichten Stand je Schritt, die nächsten drei
  Schritte und wo welche Arbeit geprüft werden kann. Damit findet sich eine
  Sitzung auf einem anderen Rechner ohne Gesprächsverlauf zurecht.

_Nur Dokumentation, keine Codeänderung. 82 Tests unverändert grün._

---

## 0.9.0 — 2026-08-04

### Hinzugefügt
- Release Notes und Versionierung als verbindlicher Teil jeder Änderung, samt
  Skill, die den Ablauf festhält. Ohne Änderungshistorie weiß in sechs Monaten
  niemand mehr, warum eine Zahl anders berechnet wird als vorher.
- Die Version steht jetzt in der Kopfzeile des Klick-Dummys. Damit lässt sich
  ein weitergegebener Entwurf einem Eintrag in dieser Datei zuordnen.

_82 Tests in PulseCore, alle grün._

---

## 0.8.0 — 2026-08-04

### Hinzugefügt
- `PulseData`: Persistenzschicht auf SwiftData mit CloudKit als Synchronisation.
  Datensätze spiegeln die Domänentypen, Beziehungen und Vorgabewerte halten
  sich an die Einschränkungen, die CloudKit dem Schema auferlegt.
- `ScaledDecimal`: Zählerstände und Preise werden als Ganzzahl mit
  mitgeführtem Dezimalfaktor gespeichert. CloudKit überträgt `Int64`
  verlustfrei, macht aus `Decimal` aber `Double` — aus 49.157,4 kWh wäre
  49157.399999999994 geworden, sichtbar in jedem Kostenbericht.
- `PulseSnapshot`: Sicherungs-, Export- und Wiederherstellungsformat mit einer
  Zusammenführung, die über die Kennungen idempotent ist. Dieselbe Sicherung
  zweimal einzuspielen erzeugt keine Dubletten — ohne diese Eigenschaft traut
  sich niemand, eine Sicherung einzuspielen.
- `ResourceKind` erhält eine stabile Speicher-Kennung. Eine unbekannte
  Zählerart aus einer neueren App-Version wird zu einem frei definierten
  Zähler statt zu einem Fehler: Der Nutzer verliert eine Vorbelegung, nie
  seine Ablesungen.

### Geändert
- Das Speichern eines geänderten Zählers gleicht die Zählwerke über ihre
  Kennung ab, statt sie zu ersetzen. Ein Ersetzen hätte über die Löschregel
  `.cascade` die gesamte Ablesehistorie mitgenommen — ein Umbenennen hätte
  die Historie gelöscht.
- Zähler werden archiviert statt gelöscht; endgültiges Löschen ist ein
  getrennter Weg.

_82 Tests in PulseCore, alle grün. `PulseData` ist unter Linux nicht baubar und
wartet auf eine Prüfung in Xcode._

---

## 0.7.0 — 2026-08-04

### Hinzugefügt
- `BillingCycle`: Abrechnungsrhythmus des Versorgers als eigener Typ. Er
  beginnt fast nie am 1. Januar — bei Strom oft im April, bei Gas im Oktober.
  Ein Bericht über das Kalenderjahr taugt deshalb nicht zum Prüfen der
  Jahresabrechnung.

### Behoben
- Ein Stichtag am 31. hätte im Februar kein Datum ergeben und damit Jahre ohne
  Zeitraumbeginn erzeugt. Er wird jetzt auf die Monatslänge begrenzt.
- Aufeinanderfolgende Abrechnungszeiträume teilen sich ihren Grenztag. Ohne das
  wäre der Verbrauch eines Tages zwischen die Zeiträume gefallen — derselbe
  Fehler, der zuvor schon an den Tarifgrenzen behoben wurde.

_62 Tests, alle grün._

---

## 0.6.0 — 2026-08-04

### Hinzugefügt
- Verbrauchsbericht als gestaltetes Dokument: Zusammenfassung, je Zähler
  Zählernummer, Anfangs- und Endstand, Monatstabelle gegen das Vorjahr und
  Kostenaufschlüsselung. Mit Druckformatierung.
- Auswahl von Umfang und Zeitraum vor dem Bericht — einzelner Zähler oder
  alle, laufendes oder abgeschlossenes Abrechnungsjahr, Kalenderjahr oder
  letzte zwölf Monate.

### Behoben
- Die Zusammenfassung stellte die Kosten aller vier Zähler den Abschlägen von
  zweien gegenüber und meldete 636,43 € Nachzahlung, wo 257,75 € Guthaben
  stehen. Nicht nur die Höhe war falsch, sondern das Vorzeichen. In den Saldo
  fließen jetzt nur Zähler mit hinterlegtem Abschlag, und der Bericht nennt sie.
- Bögen legten sich übereinander, statt einander zu ersetzen — der Export
  schob sich vor den Bericht, den er gerade geöffnet hatte.

_53 Tests, alle grün. Prototyp in Hell und Dunkel geprüft._

---

## 0.5.0 — 2026-08-04

### Hinzugefügt
- Monatsvergleich über drei Jahre: Ein Monat im Diagramm ist antippbar und
  öffnet darunter denselben Monat aller Jahre auf gemeinsamem Maßstab, mit
  Veränderung, Tagesmittel und Kosten.
- Umschalter „Summe / Ø je Tag" in der Datenansicht. Januar 290 kWh gegen
  Februar 266 kWh liest sich wie ein Rückgang; pro Tag sind es 9,35 gegen
  9,50 — also ein Anstieg. Die Rohzahlen sagten das Gegenteil der Wahrheit.

### Geändert
- Die Ablesungsliste im Verlauf liegt hinter einer Zeile statt im Hauptfluss.
  Sie zeigt dafür alle Einträge statt der letzten acht, und Diagramm samt
  Jahresvergleich passen ohne Scrollen auf einen Schirm.

_53 Tests, alle grün. Prototyp in Hell und Dunkel geprüft._

---

## 0.4.0 — 2026-08-04

### Hinzugefügt
- Datenansicht im Verlauf: Monat, Quartal oder Jahr gegen 2026, 2025 und 2024,
  wahlweise als Menge oder als Kosten.
- CSV-Export von Ablesungen und Auswertung, tatsächlich erzeugt und
  herunterladbar, dauerhaft kostenlos.
- Drittes Jahr Historie (2024), damit Vergleiche Tiefe haben.

### Geändert
- Bei „Alle Zähler" ist nur die Kostenansicht wählbar, die Mengenansicht ist
  gesperrt: kWh und m³ lassen sich nicht addieren, Euro schon. Die
  Einschränkung wird gezeigt statt still eine Variante zu wählen.
- Zwei Summenzeilen statt einer. Die rohen Spaltensummen tragen keine
  Veränderung mehr, weil 1.607 (Jan–Jul 2026) neben 3.020 (volles Jahr 2025)
  zum Fehlschluss einlädt. Nebeneinander lesbar ist nur die Zeile, die in
  allen Jahren denselben Ausschnitt beschreibt.

_53 Tests, alle grün. Prototyp in Hell und Dunkel geprüft._

---

## 0.3.0 — 2026-08-04

### Hinzugefügt
- Klick-Dummy: Übersicht, Erfassung mit Zählwerk-Optik und
  Live-Plausibilisierung, Verlauf und Zählerverwaltung. Rechnet mit echten
  Zeitreihen statt mit Platzhalterzahlen.

### Behoben
Drei Fehler, die der Prototyp aufdeckte — alle derselben Klasse: ein Zeitraum,
den die Daten abdecken, verglichen mit einem, den sie nicht abdecken.

- **Hochrechnung.** Die Tage zwischen letzter Ablesung und heute galten als
  gemessen und verbrauchsfrei. Wer länger nicht ablas, bekam eine zu niedrige
  Prognose — die App hätte Nachlässigkeit mit falscher Beruhigung belohnt.
- **Vorjahresvergleich.** Ein Gaszähler mit letzter Ablesung im Mai meldete
  +33 %, tatsächlich sind es −3 %. Verglichen wurde eine halbe Heizperiode
  gegen ein Vorjahr einschließlich Sommer.
- **Plausibilitätsprüfung.** Referenz war der Jahresdurchschnitt. Bei einem
  Gaszähler heißt das: jede korrekte Julimessung wird beanstandet, ein
  zehnfach zu hoher Wert geht durch. Genau verkehrt herum — das Feature, das
  Vertrauen schaffen soll, hätte es zerstört. Referenz ist jetzt derselbe
  Zeitraum des Vorjahres.

_53 Tests, alle grün._

---

## 0.2.0 — 2026-08-04

### Hinzugefügt
- `PulseCore`: Domänenmodell und Rechenkern, ausschließlich auf Foundation und
  damit ohne Xcode prüfbar.
- Trennung von Messstelle, Zählwerk und Gerät. Nur so lassen sich
  Zweirichtungszähler, Doppeltarifzähler und der Zählerwechsel abbilden, ohne
  die Historie zu zerreißen.
- Wertetypen `CalendarDay`, `Quantity` und `Money`: zeitzonenfreie
  Kalendertage, Einheit als Teil des Wertes, Geld als `Decimal`.
- Rechenkern mit Verlässlichkeitsangabe an jedem Ergebnis. Die Oberfläche kann
  eine interpolierte Zahl dadurch nicht wie eine gemessene darstellen.
- Kostenrechnung mit abschnittsweiser Tarifzerlegung, Gas-Umrechnung über
  Zustandszahl und Brennwert, Einspeisung als Gutschrift.

_50 Tests, alle grün._

---

## 0.1.0 — 2026-08-04

### Hinzugefügt
- Produktstrategie, Architektur als ADR, Datenmodell, UX-Konzept,
  Monetarisierung und Roadmap.
- Drei dokumentierte Einwände gegen das ursprüngliche Briefing: tägliche
  Nutzung als Erfolgskriterium, die Sogwirkung Richtung Smart Home, und die
  rechtliche Formulierung der Vermieter-Funktionen.
