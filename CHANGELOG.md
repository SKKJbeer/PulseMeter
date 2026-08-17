# Änderungen

Alle nennenswerten Änderungen an PulseMeter, neueste Version oben.
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/);
bis zur Einreichung im App Store bleibt die Hauptversion `0`.

Der Ablauf, nach dem diese Datei gepflegt wird, steht in
`.claude/skills/release-discipline/SKILL.md`.

---

## 0.64.1 — 2026-08-17

**Die Messung hat geantwortet, und der Wähler spricht jetzt Deutsch.**

`breite=404 maßstab=0.679 rahmen=404×572` — das steht im Bildschirmfoto des
Laufs zu `e864906`, auf demselben 440 Punkte breiten Gerät, auf dem vorher 237
gemessen wurden. Der `GeometryReader` um die Bildlaufansicht misst, was das Blatt
hergibt, und nichts, was er selbst bestimmt. Die Vorschau des Berichts ist damit
so breit wie der Schirm und lesbar.

Die Messzeile ist wieder heraus. Sie hat in zwei Läufen mehr geklärt als vier
Vermutungen davor — dieselbe Erfahrung wie in 0.33.4, und deshalb steht sie in
`docs/08-baukasten.md`.

**Und ein Fehler, den erst das Bild gezeigt hat:** Unter dem Ziffernblock stand
„8/17/26" und „5:46 PM". Der Datumswähler nimmt die Einstellung des Geräts, und
im Prüflauf ist die amerikanisch. Jede andere Datumsangabe dieser App wird
ausdrücklich mit `de_DE` gesetzt; dieser eine Ort war die Ausnahme. Jetzt nicht
mehr — „17.08.26" und „17:46".

---

## 0.64.0 — 2026-08-17

**Datum und Uhrzeit beim Eintippen — und damit mehr als eine Ablesung am Tag.**

Bis 0.63.0 stand unter dem Sichern-Knopf ein Satz: „Datum: heute, 17. August
2026". Unveränderlich. Eine Ablesung von gestern ging nicht, und zwei am selben
Tag unterschieden sich nur im Erfassungszeitpunkt — einer Zahl, die niemand
sieht.

Jetzt steht dort eine Zeile mit Datum und Uhrzeit, vorbelegt auf jetzt. Wer
nichts anfasst, merkt von ihr nichts; die 60 Sekunden und die drei Berührungen
bleiben. Wer morgens und abends abliest, bekommt zwei Einträge, die sich
unterscheiden — und wer eine Ablesung nachträgt, wählt den Tag, an dem sie
entstanden ist.

### Der Tag rechnet, die Uhrzeit ordnet

`TimeOfDay` ist neu in PulseCore: Stunde und Minute, ohne Sekunden, ohne
Zeitzone, gespeichert als Minuten seit Mitternacht. Getrennt von `CalendarDay`,
weil beide verschiedene Fragen beantworten — der Tag ist die Grundlage jeder
Berechnung (ADR-004), die Uhrzeit sagt nur, welche von zwei Ablesungen desselben
Tages die spätere ist.

`chronological()` benutzt sie: Bei gleichem Tag entscheidet die Uhrzeit, wenn
**beide** eine tragen. Sonst weiter der Erfassungszeitpunkt. Die Uhrzeit der
einen gegen die Erfassung der anderen zu stellen wäre wieder ein Vergleich
zweier verschiedener Dinge — eine nachgetragene Ablesung von gestern Abend wurde
heute erfasst.

An der Rechnung ändert sich nichts: Zwei Ablesungen an einem Tag tragen **beide**
bei, so wie am Tag eines Zählerwechsels. Eine Prüfung hält das ausdrücklich fest
— 10 kWh morgens und 15 kWh abends sind 25 kWh.

### Was noch mitmusste

- **Die Plausibilitätsprüfung urteilt über den gewählten Tag**, nicht über heute.
  Eine Zahl von vor drei Tagen gegen den heutigen Zeitraum zu bewerten wäre die
  wiederkehrende Fehlerklasse dieses Projekts, hier in der Eingabe.
- **Die Gerätekennung kommt vom gewählten Tag.** Bei einer nachgetragenen
  Ablesung von vor einem Zählerwechsel wäre die heutige die falsche, und der
  Rechenkern hielte den erklärten Rücksprung für einen Fehler.
- **Die Liste der Ablesungen zeigt die Uhrzeit**, wo eine angegeben wurde. Zwei
  Zeilen mit demselben Datum und verschiedenen Zahlen sähen sonst nach einem
  doppelten Eintrag aus.
- **Der CSV-Export bekommt eine Spalte „Uhrzeit"** — aber nur, wenn wenigstens
  eine Ablesung eine trägt. Eine leere Spalte ist eine Frage ohne Anlass.
- **Der Klick-Dummy hat die Zeile ebenfalls**, mit echten Feldern statt des alten
  Satzes „antippen zum Ändern", der nichts tat. Und er sortiert die Reihe nach
  dem Einfügen: Eine nachgetragene Ablesung hing sonst hinten und hätte jeden
  Abschnitt danach falsch gerechnet.
- **Ein Feld in der Speicherung**, optional und ohne Vorgabe, damit SwiftData und
  CloudKit es leichtgewichtig übernehmen. Alles, was vorher gespeichert wurde,
  bleibt gültig und trägt keine Uhrzeit — „an diesem Tag".

### Die Vorschau des Berichts: der Kreisschluss ist gefunden

Die Messzeile aus 0.63.0 hat geantwortet: `breite=237 maßstab=0.399` auf einem
440 Punkte breiten Gerät. Zusammen mit dem Lauf davor — dort standen rund 50
Punkte, die Seiten waren unlesbar — ergibt das das Bild: **dieselbe Fassung, zwei
Ergebnisse.** Ein Kreisschluss mit zwei Ruhelagen, keine zwei Fehler.

Der Messfühler saß am Hintergrund der Bildlaufansicht, und deren Breite hängt am
Inhalt — der Inhalt sind die Seiten, deren Breite aus der Messung kommt. Jetzt
liegt der `GeometryReader` **um** die Bildlaufansicht: Seine Breite kommt vom
Blatt und hängt an nichts, was darin entschieden wird.

Die Messzeile bleibt diesen einen Lauf noch stehen — sie soll bestätigen, dass
dort nun rund 404 Punkte ankommen. Danach geht sie heraus.

---

## 0.63.0 — 2026-08-17

**Der Bericht ist jetzt eine Datei.**

Der Gründer über das neue Herunterladen-Menü: „gar kein Weg zur Datei". Er hatte
recht. Zwei Einträge lieferten eine CSV-Datei ins Teilen-Blatt, der dritte machte
einen Schirm mit Auswahl und Vorschau auf — in einem Menü, das „Herunterladen"
heißt, ist das ein Bruch im Versprechen.

„Verbrauchsbericht als PDF" gibt jetzt die PDF-Datei heraus, genau wie die zwei
Tabellen daneben: `PulseMeter-Bericht-Gas-2026-08-16.pdf`, sechs Seiten,
ungekauft mit Wasserzeichen und mit „(mit Wasserzeichen)" im Eintrag, bevor
jemand sie verschickt. Genommen wird der Zeitraum, den der Berichtsschirm auch
voreinstellt — der erste zum Abrechnungsrhythmus dieses Zählers.

Die Zeile „Verbrauchsbericht" unter dem Menü bleibt: Dort steht die Wahl von
Zeitraum und Umfang, und dort ist die Vorschau. Wer nur die Datei will, braucht
sie nicht mehr.

### Eine Zusammenstellung, zwei Ausgänge

`ReportComposer` ist neu und enthält, was vorher in `ReportView.build()` stand:
Ablesungen, Tarife und Abschläge einsammeln und `ReportBuilder` füttern. Der
Kommentar an der alten Stelle warnte davor, das zu verdoppeln — „zwei Fassungen,
die früher oder später verschiedene PDFs liefern" —, und diese Warnung war der
Grund, warum der Eintrag überhaupt einen Schirm aufmachte. Eine gemeinsame
Stelle löst beides.

Dazu `ReportPDF.data(_:watermarked:)`: dasselbe Dokument ohne Umweg über eine
Datei im Zwischenordner. `write(to:)` und `data(_:)` zeichnen durch dieselbe
private Funktion, es gibt also weiterhin genau einen Zeichenweg.

### Gerechnet beim Laden, gezeichnet beim Teilen

Der Bericht wird zusammengestellt, wenn der Verlauf lädt — das ist Lesen aus dem
Speicher und dauert Millisekunden. Gezeichnet werden die sechs A4-Seiten erst,
wenn ein Ziel für die Datei gewählt ist. Wäre es umgekehrt, hätte das Menü beim
Aufklappen gestockt, und das war genau der Fehler aus 0.62.0.

Liegt für den Zeitraum keine Ablesung vor, bleibt der Eintrag ein Knopf zum
Berichtsschirm — dort steht der Satz, warum es nichts zu berichten gibt. Ein
Eintrag, der je nach Datenlage da ist oder fehlt, erklärt sich nicht mehr selbst
(Produktprinzip 4).

### Eine Messzeile für die Vorschau

Auf dem Bildschirmfoto aus dem Lauf zu `9445365` stehen die sechs Seiten der
Vorschau wieder als schmale Rahmen mitten auf dem Schirm — dieselbe Erscheinung
wie in 0.33.4, obwohl der damalige Grund behoben ist. Statt zu raten schreibt
die Ansicht jetzt Breite, Maßstab und Rahmengröße ins Bild, so wie damals; nur
im Bildschirmfoto-Lauf, hinter `-pulse-bericht`. Der nächste CI-Lauf sagt, was
wirklich gemessen wird. Diese Zeile geht wieder heraus, sobald die Zahl bekannt
ist.

### Was hier nicht geprüft ist

Dass aus dem Menü wirklich eine lesbare PDF-Datei herauskommt, kann keine
Prüfung dieses Projekts zeigen: Der Rechenkern kennt kein Papier, und die
Oberflächenprüfung klappt das Menü absichtlich nicht auf — was darin steht,
zeichnet iOS in einem eigenen Fenster. Die Gegenprobe ist der nächste
TestFlight-Bau auf dem Gerät des Gründers.

---

## 0.62.2 — 2026-08-17

**Der Entwurf hat den Knopf jetzt auch.**

0.62.0 hat die zwei Marken „Ablesungen" und „Auswertung" in der App durch einen
Knopf „Herunterladen" mit Auswahl ersetzt — im Klick-Dummy standen sie noch da.
Zwei Oberflächen, die dasselbe anders zeigen, sind nach Regel 2 ein Fehler und
kein Zustand.

Im Entwurf ist es jetzt derselbe Weg: ein Knopf mit Pfeil-nach-unten unter dem
Diagramm **und** unter der Tabelle, dahinter ein Bogen mit drei Einträgen —
Ablesungen als CSV, Auswertung als CSV, Verbrauchsbericht als PDF. Ungekauft
steht „(mit Wasserzeichen)" dahinter und der Preis daneben; der Bericht bleibt
offen, er ist nur gezeichnet.

Der Bericht stand vorher **im** Exportbogen, also hinter einer der beiden
Marken. Wer den Bericht wollte, musste eine Tabelle antippen. Diese Zeile ist
weg, der Bericht steht jetzt gleichberechtigt in der Auswahl.

### Geprüft

`scripts/check-prototype.mjs` prüft die drei Einträge namentlich und geht auf
dem neuen Weg zum Bericht — 96 statt 94 Prüfungen, hell und dunkel. Die alte
Wegbeschreibung wäre stumm grün geblieben: Sie klickte `[data-export]`, und das
gibt es auf dem Blatt nicht mehr. Erst der Zeitablauf hat es gezeigt.

---

## 0.62.1 — 2026-08-17

**Die Einheit ist keine Zeichenkette.**

Der Bau von 0.62.0 ist nach 52 Sekunden gescheitert, an einer Zeile:

```
App/HistoryView.swift:719:38: error: binary operator '??' cannot be applied
to operands of type 'MeasurementUnit?' and 'String'
```

Beim Umbau auf die verzögerte Ausgabe war aus `register?.unit.symbol ?? ""`
ein `register?.unit ?? ""` geworden. `TableExport.breakdown` nimmt keine
Zeichenkette, sondern eine `MeasurementUnit`. Jetzt behält die Auswertung
Zählwerk und Zähler als Ganzes und prüft sie erst in der Ausgabe — dasselbe
Muster, das die Ablesungen schon verwenden.

### Was daran zu lernen war

`swiftc -parse` über die geänderten Dateien ist **keine Übersetzung**. Es liest
die Datei, es prüft keine Typen — und die CI-Stufe „Syntax der iOS-Quellen"
tut genau dasselbe. Ein Fehler dieser Art kann in einem Linux-Container nicht
auffallen; SwiftUI und SwiftData gibt es hier nicht. Der erste echte Übersetzer
läuft auf dem macOS-Läufer, und das bleibt so.

Was die Oberflächentests zum neuen Menü sagen, ist damit weiterhin offen: Der
Bau ist gescheitert, bevor ein Test gelaufen ist.

---

## 0.62.0 — 2026-08-17

**Der Export ist ein Knopf mit Auswahl — und schreibt keine Dateien mehr beim
Zeichnen.**

Zwei Rückmeldungen aus dem ersten echten Gebrauch, beide am selben Bildschirm.
Das ist der Punkt, den `07-v1-plan.md` als produktivsten benennt, und er hat
beim ersten Anlauf geliefert.

### Behoben — „lädt ziemlich lange"

`readingsFile` und `breakdownFile` waren **berechnete Eigenschaften im
Bildaufbau**. Jede Neuauswertung des Verlaufsschirms hat damit zwei CSV-Dateien
gebaut **und atomar auf die Platte geschrieben** — beim Blättern, beim
Umschalten von Monat auf Quartal, und beim Antippen von „Alle Ablesungen", weil
auch das nur einen Zustand umsetzt. Zwei Dateisystemschreibvorgänge, bevor das
Blatt aufging.

Dateien als Nebenwirkung des Zeichnens zu schreiben ist unabhängig von der
Geschwindigkeit falsch gebaut. Der neue Typ `CSVAusgabe` ist `Transferable`:
Die Beschreibung ist billig, der Inhalt entsteht erst, wenn das Teilen-Blatt
ihn anfordert.

⚠️ **Nicht gemessen.** Das ist eine Diagnose aus dem Quelltext; ein Linux-Container
hat keinen Simulator. Ob die Verzögerung ganz daran hing, sagt erst das Gerät.

### Geändert — „verstehe nicht, was dahinter ist"

Zwei gleich aussehende Kacheln „Ablesungen" und „Auswertung", ohne einen Satz
dazu, und beim Antippen kam unerwartet ein Teilen-Blatt. Produktprinzip 4
verlangt, dass sich jede Fläche erklärt — diese zwei taten es nicht. Dazu hieß
„Ablesungen" auf demselben Schirm zweierlei: eine Liste zum Ansehen und eine
Datei zum Verschicken.

An ihrer Stelle steht **ein** Knopf, **Herunterladen**, mit Pfeilsymbol und
einer Auswahl:

- **Ablesungen als CSV** — eine Zeile je eingetippter Zahl
- **Auswertung als CSV** — eine Zeile je Zeitraum, der gerechnete Verbrauch
- **Verbrauchsbericht als PDF** — mit dem Zusatz „(mit Wasserzeichen)", solange
  er nicht freigeschaltet ist

Die Dateiart steht jetzt **im Eintrag**, nicht nur in der Endung. Und
`exportedContentType: .commaSeparatedText` sagt es auch dem System — vorher hing
das allein am Dateinamen, und je nach Ziel kam die Tabelle als Textdatei an.

### Zwei Dinge, die schon stimmten

Bei der Durchsicht geprüft, statt sie neu zu bauen:

- **Die Endung war schon `.csv`** — `PulseMeter-<Zähler>-Ablesungen.csv`. Neu
  ist der ausdrückliche Dateityp, nicht die Endung.
- **Der Bericht war schon herunterladbar, mit Wasserzeichen, und der Kauf nimmt
  es weg** — samt Neuschreiben der Datei nach dem Kauf. Gefehlt hat nur, dass
  er im Ausgang auftauchte.

### Warum der Bericht den Schirm öffnet statt hier ein PDF zu bauen

Er braucht eine Wahl: Zeitraum und Zähler. Die Logik dafür steht vollständig in
`ReportView` — Wasserzeichen, Neuschreiben nach dem Kauf, Teilen. Sie im Menü
zu wiederholen hieße, zwei Fassungen zu pflegen, die früher oder später
verschiedene PDFs liefern.

### Nachgezogen

`testTheReportIsWatermarkedAndTheExportNeverCosts` prüft jetzt den Zugang
(`Herunterladen`) statt der zwei Einträge. Was im Menü steht, zeigt iOS in einem
eigenen Fenster; eine Prüfung, die es aufklappt, prüft die Menüdarstellung von
iOS und nicht diese App.

---

## 0.61.0 — 2026-08-17

**PulseMeter läuft in TestFlight — und der Weg dorthin ist aufgeschrieben.**

Am 17. August um 10:28 UTC: „UPLOAD SUCCEEDED with no errors". Kein Kabel, kein
Xcode auf dem Rechner des Gründers, kein Klick im Entwicklerportal. Gebaut,
signiert und hochgeladen hat ein macOS-Läufer bei GitHub, gestartet mit einem
Knopf im Browser.

Gebraucht hat das **fünf Läufe**. Vier sind an je einem echten Befund
gescheitert, und keiner davon stand in einer Anleitung, die vorher gelesen
worden wäre.

### Hinzugefügt

- **`docs/12-auslieferung.md`** — das Gegenstück zum Baukasten. Der Baukasten
  beschreibt, wie geprüft wird; dieses Dokument, wie ausgeliefert wird. Inhalt:
  die Reihenfolge, die funktioniert (mit gemessenen Zeiten), die sechs Befunde
  in der Reihenfolge, in der sie zuschlagen, sechs Kleinigkeiten, die je einen
  Lauf kosten, und die fünf Dateien, die das Ganze tragen.

  Die Befunde, kurz:
  1. **Die Bundle-ID gehört nicht auf eine fremde Domain.**
     `com.pulsemeter.app` war belegt. Und die Entscheidung fällt **vor** allem
     anderen — danach kostet sie jeden Käufer seinen Kauf.
  2. **`xcodebuild archive` mit automatischer Signierung holt ein
     *Development*-Profil**, und das braucht ein registriertes Gerät. Ohne
     Kabel kann dieser Weg nie durchgehen. Ausweg: manuelle Signierung mit
     App-Store-Profilen aus der Schnittstelle.
  3. **Bauvorgaben auf der Kommandozeile gelten für alle Ziele** — also je
     Ziel in der Projektdatei, über Variablen.
  4. **Berechtigungen brauchen Häkchen an der App-ID.** Die erste Auslieferung
     darf ohne sie fahren, wenn der Code den Ausfall aushält.
  5. **Nie das voreingestellte Xcode nehmen.** 16.4 war gesetzt, 26.3 lag
     daneben, und Apple verlangt 26.
  6. **Hochgeladen ist nicht testbar.** Exportbestimmungen, Gruppe, Tester,
     Zuweisung — vier Dinge, jedes hält den Bau unsichtbar. Sich selbst als
     Tester einzutragen war der letzte Stolperstein.

- Verweise aufeinander in `08-baukasten.md` und in der README.

### Was das Vorgehen gelehrt hat, und es steht dort auch so

**Zweimal war meine Vermutung falsch und das Protokoll richtig** — einmal bei
`-configuration Release`, einmal bei der Ursache des roten Oberflächentests. Aus
einer Meldung eine Erklärung zu bauen und danach zu handeln hat mehr gekostet
als das Lesen.

**Ein schneller Fehlschlag ist billig.** 80 bis 130 Sekunden je Lauf — da lohnt
Probieren statt Grübeln. Deshalb steht die Zugangsprüfung als erster Schritt.

**Zwei rote Läufe mit derselben Meldung sind kein Fortschritt.** Dann ist die
Ursache nicht im Code.

---

## 0.60.3 — 2026-08-17

**Drei übersetzte Zwischendateien waren mitgewandert.**

`scripts/__pycache__/*.pyc` landete in 0.60.1 im Commit — Nebenprodukt der
Übersetzungsprüfung, die ich zum Aufspüren der Anführungszeichen-Fehler von
Hand aufgerufen hatte. Erzeugte Dateien gehören nicht ins Repository; dieselbe
Regel, aus der `PulseMeter.xcodeproj` draußen bleibt.

### Behoben

- Die drei Dateien sind aus der Verwaltung genommen, `__pycache__/` und `*.pyc`
  stehen in `.gitignore`.
- `check-strings.py` übersetzt jetzt in einen Ordner, der sich danach selbst
  auflöst, statt in einen Pfad aus `tempfile.mktemp()`. Der ließ bei jedem Lauf
  eine Datei liegen.

### Und der rote Lauf zu 0.60.0 ist geklärt

Es war ein **Wackler**, kein Rückschritt: `testAddingAMeterFromTheMetersTab`
fiel am Tabwechsel, und der Lauf zu 0.60.1 — derselbe Code, dieselben
Berechtigungen — ist grün. Damit sind 0.60.0 und 0.60.1 in `main`.

**Dieser Test ist jetzt zum fünften Mal gefallen** (0.34.0, 0.36.0, 0.53.0,
0.54.1, 0.60.0). Der Helfer `wechsel(zu:in:)` tippt zweimal; unter drei
parallelen Simulatoren reicht das offenbar nicht immer. Das ist die nächste
Kleinigkeit, die Geld kostet, und sie gehört behoben — nicht wieder mit einer
längeren Uhr, sondern mit einem dritten Versuch.

---

## 0.60.2 — 2026-08-17

**Apple nimmt kein iOS-18-SDK mehr an.**

Lauf 4 kam weiter als alle davor: Der App-Eintrag stand, Apple hat die IPA
**angenommen** und dann bei der Prüfung abgelehnt.

    Validation failed (409) SDK version issue. This app was built with the
    iOS 18.5 SDK. All iOS and iPadOS apps must be built with the iOS 26 SDK
    or later, included in Xcode 26 or later.

Der Läufer stand auf Xcode 16.4. Das ist kein Fehler im Projekt, sondern eine
Frist, die verstrichen ist.

### Geändert

- **Neuer erster Schritt „Xcode wählen"** in `testflight.yml`: listet auf, was
  auf dem Läufer liegt, wählt die höchste Fassung und setzt sie über
  `xcode-select`. Reicht keine, hält der Lauf **dort** an und nennt die
  vorhandenen Versionen — sonst rät man beim nächsten Versuch am Läuferbild
  vorbei und verbrennt weitere zwanzig Minuten.

### Und die Fehlerklasse, die heute viermal zugeschlagen hat

Ein deutsches Anführungszeichen unten, ein **gerades** oben. Zweimal in einem
Python-Skript, zweimal in einem Workflow — und im YAML fällt es erst auf dem
Läufer auf.

**Der erste Versuch, das zu prüfen, war falsch.** Eine Suche nach dem Muster
fand 24 Stellen, von denen keine einzige schadete: In einem Kommentar ist das
Zeichen harmlos. Eine Prüfung, die so oft grundlos anschlägt, liest nach drei
Tagen niemand mehr — dieselbe Lehre wie bei den wackligen Oberflächentests.

`check-strings.py` prüft deshalb nicht das Zeichen, sondern die **Folge**:

- übersetzt jedes Skript unter `scripts/*.py`,
- lädt jede Workflow-Datei als YAML,
- und schickt **jeden `run:`-Block durch `bash -n`**.

Gegengeprüft mit je einem echten Bruch in beiden Sprachen; beide wurden
gefangen. Der zweite Fall ist der teure: Er hätte sonst wieder einen Lauf
gekostet.

---

## 0.60.1 — 2026-08-17

**Ohne Gerät gibt es kein Entwicklungsprofil — und `archive` will genau das.**

Lauf 2 scheiterte an derselben Meldung wie Lauf 1: „Your team has no devices
from which to generate a provisioning profile." Die Kennung war diesmal in
Ordnung, `-configuration Release` war übergeben — und es half nichts. Meine
Erklärung in 0.60.0 war falsch.

**Der wirkliche Grund.** `xcodebuild archive` mit `CODE_SIGN_STYLE=Automatic`
besorgt sich ein **Development**-Profil und signiert erst beim Ausführen auf
Verteilung um. Die Profilart hängt nicht an der Konfiguration. Und ein
Entwicklungsprofil verlangt mindestens ein registriertes Gerät — das Konto hat
keins, weil es kein Kabel gibt. Dieser Weg konnte nie durchgehen.

### Hinzugefügt

- **`scripts/asc-profil.py`** — legt App-Store-Profile für App und Widget über
  dieselbe Schnittstelle an, über die auch das Zertifikat kam, und legt sie in
  den Ordner, den `xcodebuild` liest. Kein Gerät, kein Anmeldefenster, kein
  Klick im Portal.

  Eine Falle steckt schon drin: **Apple filtert `filter[identifier]` als
  Präfix.** Die Abfrage nach `de.karjoth.pulsemeter` liefert auch
  `de.karjoth.pulsemeter.widget` mit — wer das erste Ergebnis nimmt, signiert
  die App mit dem Profil des Widgets. Es wird deshalb genau verglichen.

### Geändert

- **Manuelle Signierung**, `PROVISIONING_PROFILE_SPECIFIER` je Ziel über
  `$(PULSE_PROFILE_APP)` und `$(PULSE_PROFILE_WIDGET)`. Leer als Vorgabe, damit
  Simulator und CI wie bisher automatisch signieren.
- **Die Berechtigungen bleiben bei diesem Bau leer**, gesteuert über
  `$(PULSE_ENTITLEMENTS_APP)` und `$(PULSE_ENTITLEMENTS_WIDGET)`. App-Gruppe,
  iCloud und Push müssten an der App-ID im Portal freigeschaltet sein, sonst
  lehnt Apple das Profil ab. **Das ist eine bewusste Verkürzung, keine
  Nachlässigkeit:** Ohne sie läuft die App vollständig, nur das Widget bleibt
  leer und der Abgleich aus — und für beides gibt es im Code einen Rückfall,
  der genau dafür gebaut wurde. Die zwei Wochen Eigennutzung, an denen alles
  hängt, können sofort anfangen (`07-v1-plan.md`, Abschnitt 5).
- Die Ausfuhrvorgaben nennen die Profile namentlich und stehen auf `manual`.

### Nebenbei, dieselbe Fehlerklasse wie schon zweimal

Ein deutsches Anführungszeichen mit **geradem** Schlusszeichen —
`„Zertifikat anlegen"` — hat die Python-Zeichenkette beendet. Genau davor warnt
`CLAUDE.md`, und es ist das dritte Mal. `check-strings.py` sieht nur
Swift-Quellen; hier hat der Übersetzer es gefangen.

---

## 0.60.0 — 2026-08-17

**`com.pulsemeter.app` war bei Apple schon vergeben.**

Der erste TestFlight-Lauf ist gescheitert, und die Meldung ließ keinen Zweifel:
„The app identifier `com.pulsemeter.app` cannot be registered to your
development team because it is not available." Ein anderes Team hält die
Kennung. Kein Schalter hilft da — sie muss eine andere werden.

**Der Zeitpunkt ist der glücklichste, den es dafür gibt.** In App Store Connect
existiert noch keine App und kein Kauf; ab dem Moment, in dem der erste Kauf
angelegt ist, wäre dieselbe Änderung nicht mehr möglich, ohne jeden Käufer zu
verlieren (`10-sichtbarkeit.md`, Abschnitt 4).

### Geändert

- **Die Kennung heißt jetzt `de.karjoth.pulsemeter`** — an 27 Stellen in einem
  Zug: `project.yml` (App, Widget, Oberflächentests, Präfix), beide
  Berechtigungsdateien, `WidgetBridge.appGroup`,
  `ProductID.storeIdentifier`, `AccessPolicyTests`, `scripts/run.sh` und fünf
  Dokumente. Daraus folgen App-Gruppe `group.de.karjoth.pulsemeter`,
  iCloud-Container `iCloud.de.karjoth.pulsemeter` und fünf neue
  Kauf-Kennungen.

  Umgekehrte Namensschreibweise auf den Gründer statt auf eine Domäne: Wer
  `pulsemeter.de` nicht besitzt, sollte die Kennung nicht darauf bauen — genau
  daran ist die alte gescheitert.

- **`-configuration Release` beim Archivieren.** Ohne die Angabe nahm der Lauf
  `Debug`, und Xcode suchte daraufhin ein **Development**-Profil. Die zweite
  Meldung des Fehlschlags sagte das auch, nur nicht offensichtlich: „Your team
  has no devices from which to generate a provisioning profile." Für einen
  Store-Bau braucht es kein Gerät, sondern ein Verteilprofil — und das gibt es
  nur zur Release-Konfiguration.

- **`aps-environment` kommt aus `$(APS_ENVIRONMENT)`**, gesetzt je
  Konfiguration in `project.yml`: `development` normal, `production` in
  Release. Fest eingetragen wäre einer der beiden Wege immer falsch — der
  Gerätebau braucht das eine, der Store-Bau das andere.

### Was der Fehlschlag wert war

Er hat zwei Dinge gezeigt, die kein Nachdenken gezeigt hätte: dass die Kennung
belegt ist, und dass die Archivkonfiguration fehlte. **Und er hat bewiesen,
was funktioniert** — „Zertifikat einlesen" lief durch. Das PKCS#12-Bündel aus
`zertifikat.yml`, `security import`, `set-key-partition-list`: alles drei hielt
beim ersten Versuch auf echter Hardware.

---

## 0.59.1 — 2026-08-16

**Die Anleitung verlinkt jetzt, wohin sie schickt.**

„App Store Connect › Users and Access › Integrations" ist eine Wegbeschreibung.
Wer mitten in der Arbeit steckt, will keinen Weg, sondern das Ziel.

### Geändert

- **Elf direkte Verweise** in `docs/go-live-anleitung.html`: der Schlüssel bei
  App Store Connect, die Team-ID unter Membership, die Geheimnisse und das
  Token bei GitHub, die zwei Abläufe, die Zertifikatsliste, die Apps-Übersicht,
  TestFlight im App Store, Cloudflare. Alle öffnen in einem neuen Tab — sonst
  ist die Anleitung weg, gerade wenn man sie braucht.
- **Eine Sammlung am Ende**, dieselben Ziele beieinander, jedes mit dem
  Schritt daneben, zu dem es gehört.
- Verweise nach außen sind **unterstrichen und tragen einen Pfeil**. Farbe
  allein unterscheidet bei einer Rot-Grün-Schwäche nichts, und auf einem
  Telefon will man sehen, was ein Ziel ist, bevor man danach greift.

### Was dabei nicht weggefallen ist

**Die Namen der Bereiche stehen weiter im Text.** Apple und GitHub bauen ihre
Oberflächen um; ein Verweis, der ins Leere führt, lässt jemanden ratlos zurück,
wenn daneben nicht steht, wonach er suchen soll. Ein Hinweis am Ende nennt
zusätzlich die Ebene darüber.

Eine neue Prüfung im Bauskript hält fest, dass **jeder** äußere Verweis
`target="_blank"` und `rel="noopener"` trägt — 24 sind es, keiner schlampig.

---

## 0.59.0 — 2026-08-16

**Das Zertifikat wird einmal angelegt und bleibt dann liegen.**

In 0.58.0 stand die Zertifikatsgrenze noch als Unschönheit in der Anleitung:
Jeder TestFlight-Lauf startet auf einem frischen Rechner, Xcode legt dort ein
neues Signaturzertifikat an, und nach dem dritten ist Schluss. Der Gründer
wollte nicht ständig wechseln müssen — zu Recht. Eine Automatisierung, die alle
drei Läufe Handarbeit im Portal verlangt, ist keine.

### Hinzugefügt

- **`.github/workflows/zertifikat.yml`** — einmal starten, danach ein Jahr
  Ruhe. Erzeugt Schlüsselpaar und Antrag, holt das Verteilzertifikat über die
  Schnittstelle von App Store Connect, schnürt ein PKCS#12-Bündel und legt es
  als Repository-Geheimnis ab. Läuft auf Linux, weil dabei nichts gebaut wird.

- **`scripts/asc-zertifikat.py`** — der Teil, der mit Apple spricht. Zählt
  vorher den Bestand und warnt, statt zu raten: Ob die Grenze bei drei liegt,
  hängt an der Art der Mitgliedschaft, und Apple lehnt den vierten mit einer
  eindeutigeren Meldung ab, als eine geratene Regel es könnte. Für die zwei
  häufigsten Ablehnungen — Grenze erreicht, Schlüssel ohne Rechte — steht ein
  ganzer Satz da, was zu tun ist.

- **`scripts/gh-geheimnis.py`** — schreibt das Ergebnis direkt ins Repository.
  Viertausend Zeichen Base64 aus einem Protokoll abzutippen, auf einem Telefon,
  wäre keine Automatisierung; und ein privater Schlüssel, der durch die
  Zwischenablage geht, liegt danach in der Zwischenablage. GitHub nimmt
  Geheimnisse ohnehin nur **versiegelt** entgegen — der Klartext verlässt den
  Lauf nie.

- **`testflight.yml` liest das Zertifikat ein**, wenn eines hinterlegt ist, und
  legt sonst weiter selbst eines an. Eigener Schlüsselbund, nicht der
  Anmeldebund. Dazu die zwei Zeilen, ohne die es klemmt:
  `set-key-partition-list`, sonst fragt `codesign` nach einem Kennwort und
  wartet bis zur Zeitgrenze, und `-legacy` beim Schnüren, weil OpenSSL 3 sonst
  ein Format erzeugt, das der Schlüsselbund von macOS je nach Version nicht
  öffnet — mit der Meldung „MAC verification failed", die nach falschem
  Kennwort aussieht und keins ist.

### Geprüft, nicht behauptet

Die ganze Kette lief hier durch, mit einem selbstsignierten Zertifikat
anstelle von Apples: Antrag erzeugen, DER einlesen, PKCS#12 schnüren, mit dem
Kennwort wieder öffnen — und mit einem falschen Kennwort scheitern. Die
Versiegelung für GitHub wurde gegen ein selbst erzeugtes Schlüsselpaar geprüft:
3.356 Zeichen hinein, 4.540 versiegelt, entsiegelt identisch.

Was hier **nicht** prüfbar war: der Aufruf bei Apple und `security import` auf
einem macOS-Läufer.

### Ein Zugeständnis

Damit der Lauf die Geheimnisse selbst schreiben darf, braucht er ein
Personal Access Token als `GH_PAT` — fein granuliert, nur dieses Repository,
nur „Secrets: Read and write". Wer das nicht vergeben will, bekommt die Werte
als Artefakt und trägt sie von Hand ein; der Ablauf sagt das dann auch. Ein
Token mit Schreibrecht auf Geheimnisse ist nicht nichts, und diese Wahl gehört
dem Gründer, nicht mir.

---

## 0.58.0 — 2026-08-16

**Es geht doch ohne eigenen Mac. Ich hatte das zu schnell verneint.**

Auf die Frage, ob das nicht auch vom Telefon aus ginge, war meine erste
Antwort im Kern „nein, iOS-Apps brauchen Xcode". Das stimmt — und ist trotzdem
die falsche Auskunft, denn **dieses Projekt hat längst einen Mac**: `ci.yml`
baut die App bei jedem Push auf `macos-15`. Gefehlt haben nur zwei Dinge, und
beide gehen headless: signieren und hochladen.

### Hinzugefügt

- **`.github/workflows/testflight.yml`** — baut, signiert und lädt nach
  TestFlight. Gestartet über Actions › Run workflow, also mit einem Knopf im
  Browser; das geht auch vom Telefon. Zurück kommt die App über die
  TestFlight-App aufs Gerät. **Kein Kabel, kein Xcode, kein Mac.**

  Der Kern ist `-allowProvisioningUpdates` zusammen mit einem
  App-Store-Connect-Schlüssel statt eines Anmeldefensters: Xcode legt App-ID,
  App-Gruppe, iCloud-Container, Zertifikat und Profil selbst an.

- **Vier Schritte A bis D** in `docs/go-live-anleitung.html`, plus ein Abzweig
  direkt unter dem Vorspann — die Frage „habe ich überhaupt einen Mac" gehört
  vor den ersten Schritt und nicht auf halbe Strecke.

### Drei Fallen, die schon eingebaut sind

- **Die Zugangsprüfung steht als erster Schritt**, nicht als letzter. Fehlt
  eines der vier Geheimnisse, sagt der Lauf das nach zehn Sekunden mit Namen.
  Sonst liefe er zwanzig Minuten und scheiterte an einer `altool`-Meldung, die
  nicht verrät, welches fehlt.
- **Die Buildnummer kommt aus `github.run_number`.** App Store Connect nimmt
  jede Nummer nur einmal an; zweimal `1` hochzuladen scheitert im allerletzten
  Schritt.
- **Nach drei, vier Läufen ist die Zertifikatsgrenze erreicht.** Jeder Lauf
  startet auf einem frischen Rechner und legt dafür ein neues Verteilzertifikat
  an; erlaubt sind drei. Das ist eine echte Unschönheit dieses Weges und steht
  deshalb in der Anleitung, samt der Stelle im Portal, an der man die alten
  widerruft.

### Was der Weg kostet

Zwanzig Minuten je Bau statt zwei, und danach prüft Apple noch einmal fünf bis
dreißig Minuten. `scripts/aufs-handy.sh` bleibt der schnellere Weg, wenn ein
Mac und ein Kabel dastehen. Er ist nur eben keine Voraussetzung mehr.

---

## 0.57.0 — 2026-08-16

**Eine Anleitung zum Abarbeiten, nicht zum Nachschlagen.**

`07-v1-plan.md` begründet, warum die Reihenfolge so ist. Wer am Mac sitzt und
das Telefon in der Hand hat, braucht das nicht — er braucht den nächsten
Befehl.

### Hinzugefügt

- **`docs/go-live-anleitung.html`** — elf Schritte, in vier Abschnitten nach
  dem, was gerade dran ist: heute am Mac, diese Woche nebenher, eine ruhige
  Stunde, zum Schluss. Je Schritt ein Befehl zum Kopieren, eine Zeitangabe und
  — wo es erfahrungsgemäß hakt — was dann zu tun ist.

  **Die Ortsmarke ist die eigentliche Auskunft:** Terminal, iPhone oder
  Browser. Der Aufwand steckt nicht in den Befehlen, sondern im Wechsel
  dazwischen, und wer weiß, dass die nächsten drei Schritte alle im Browser
  passieren, macht sie am Stück.

  Nach Schritt 4 steht ausdrücklich „hier kannst du aufhören": Die zwei Wochen
  Eigennutzung laufen dann schon, alles Weitere kann warten. Das ist der
  Unterschied zwischen einer Liste, die man abarbeitet, und einer, vor der man
  zurückschreckt.

  Farben, Maße und Ton kommen aus `docs/website/stil.css` — es sollen nicht
  zwei Gestaltungen nebeneinanderstehen. In sich geschlossen, keine fremde
  Anfrage, hell und dunkel, ab 320 Pixel.

### Zwei Fehler beim Bauen, beide gemessen statt geraten

- **172 Pixel Überlauf bei 320 Pixel Breite.** Ein Grid-Element steht auf
  `min-width: auto` und schrumpft nicht unter seinen Inhalt; die langen
  Produktkennungen im Befehlsblock zogen die Spalte auf 492 Pixel. Das
  `overflow-x: auto` am Block griff nie, weil dort gar nichts überlief.
- **Danach noch 10 Pixel.** `docs/website/datenschutz.html` im Fließtext — ein
  Pfad ohne Leerzeichen bricht nirgends um. `overflow-wrap: anywhere`.

Beide Male hat erst das Ausmessen der Elementkanten gesagt, was los war. Ein
zweiter Blick auf den Quelltext hätte weder das eine noch das andere gefunden.

---

## 0.56.0 — 2026-08-16

**Alles, was sich automatisieren lässt, läuft jetzt aus einem Befehl.**

Auf „ich will dass das alles automatisiert von dir passiert": Drei Dinge kann
kein Skript — das Programm kaufen, die Käufe in App Store Connect anlegen und
die App zwei Wochen benutzen. Der Rest ist jetzt Code, und der Weg durchs
Entwicklerportal fällt ganz weg.

### Hinzugefügt

- **`scripts/go-live.sh`** — die Kette aus `07-v1-plan.md` Abschnitt 5, in
  einem Befehl, jeder Schritt einzeln geprüft. Hält beim ersten echten Problem
  an und sagt, was zu tun ist, statt weiterzulaufen. `--pruefen` sieht nur
  nach. Läuft unter Linux so weit, wie es ohne Xcode geht, und benennt den
  Rest.

  Die nützlichste Prüfung darin ist die kleinste: **Die App-Gruppe steht an
  drei Stellen** — `WidgetBridge.swift` und die zwei Berechtigungsdateien —
  und muss überall gleich lauten. Läuft eine weg, bleibt das Widget dauerhaft
  leer, ohne Fehlermeldung und ohne Absturz. Gegengeprüft.

- **`App/PulseMeter.entitlements`** und **`Widget/PulseWidget.entitlements`**.
  App: App-Gruppe, iCloud-Container, CloudKit — und `aps-environment`, weil
  SwiftData Änderungen aus iCloud über eine stille Mitteilung meldet. Ohne die
  gleicht die App nur beim Start ab, und das zweite Gerät zeigt tagelang alte
  Zahlen. Das ist die eine Berechtigung über die zwei aus `11-sicherheit.md`
  hinaus; sie ist dort jetzt begründet. Widget: nur die App-Gruppe.

  **Der Gang ins Entwicklerportal entfällt damit.**
  `-allowProvisioningUpdates` in `aufs-handy.sh` registriert App-ID,
  App-Gruppe und iCloud-Container beim ersten Bau selbst.

- **`App/StoreKitGateway.swift`** — der Kauf, hinter dem Protokoll, das seit
  0.35.0 dasteht. Fünf Produkte laden, kaufen, wiederherstellen, Preise aus
  dem Store, und ein Beobachter auf `Transaction.updates` für Käufe, die
  woanders passiert sind.

- **`Purchase.synchronise(with:)`** — und das ist der Punkt, an dem es hätte
  falsch werden können. `apply(_:)` **legt zusammen**, weil nach einem
  einzelnen Kauf nur das eben Bestätigte zurückkommt und der Nutzer sonst bei
  jedem weiteren Kauf alle vorherigen verlöre. Der Abgleich mit
  `Transaction.currentEntitlements` muss das Gegenteil tun und **ersetzen**:
  Dort steht der vollständige Bestand, und was fehlt, fehlt mit Grund. Wer
  hier zusammenlegt, verschenkt dauerhaft, was einmal erstattet wurde
  (`11-sicherheit.md`, Abschnitt 5). Startschalter gewinnen weiterhin, damit
  Bildschirmfotos einen festen Zustand zeigen.

### Geändert

- **iCloud ist an — in drei Stufen, nicht als Schalter.** `cloudKit: true`
  einfach zu setzen wäre falsch gewesen: Im Simulator und in der CI gibt es
  keine Berechtigung, der Aufbau schlüge fehl, und die alte zweite Stufe fiel
  auf einen **flüchtigen** Speicher zurück. Die App liefe und würde nichts
  sichern; jede Oberflächenprüfung, die eine Ablesung einträgt, wäre rot, und
  der Grund stünde nirgends. Die zweite Stufe ist jetzt derselbe Speicher ohne
  Abgleich.
- **`PurchaseGateway` ist `@MainActor`.** Zwei der vier Mitglieder sind
  synchron, weil eine Ansicht sie beim Zeichnen fragt, und beim Zeichnen gibt
  es kein `await`.
- **Die Berechtigungen stehen je Ziel in `project.yml`**, nicht auf der
  Kommandozeile: Eine Bauvorgabe dort gilt für alle Ziele auf einmal, und das
  Widget bekäme die iCloud-Berechtigung der App, die seine Kennung nicht hat.

### Was hier nicht geprüft werden konnte

**Unter Linux lief kein Compiler über diese Dateien** — nur `swiftc -parse`,
und das prüft die Form, nicht die Namen. `StoreKitGateway` ruft eine
Schnittstelle auf, die es hier nicht gibt. Der erste macOS-Lauf ist damit die
erste echte Übersetzung, und die wahrscheinlichsten Stellen stehen in der
Nachschau: die `@MainActor`-Umstellung des Protokolls, der Beobachter im
Konstruktor und die Berechtigungen je Ziel im Simulatorbau.

---

## 0.55.0 — 2026-08-16

**Das Privacy-Manifest ist da — der einzige Pflichtpunkt, der nie am
Developer Program hing.**

Er stand seit Mai in der Liste und wartete hinter dem Engpass, obwohl er nicht
dahinter gehört: Eine Plist im Bündel braucht kein Programm.

### Hinzugefügt

- **`App/PrivacyInfo.xcprivacy`** und **`Widget/PrivacyInfo.xcprivacy`**. Zwei
  Dateien, weil Apple je Bündel liest — eine Erweiterung ist nicht vom Manifest
  der App abgedeckt.

  Inhalt der App: kein Tracking, keine Tracking-Domänen, keine erfassten
  Daten. Als einzige begründungspflichtige Schnittstelle `UserDefaults` mit
  Grund **CA92.1** — Zugriff nur auf die Voreinstellungen dieser App, für den
  Kaufzustand in `Purchase.swift`. Nicht `1C8F.1`: Das gälte für eine
  App-Gruppe, und die wird dafür nicht benutzt. Der Kommentar in der Datei
  sagt, wann das zu wechseln ist.

  Das Widget deklariert **keine** solche Schnittstelle, und das ist
  nachgesehen: Es liest über `WidgetBridge` eine Datei, und
  `FileManager.containerURL` gehört nicht dazu.

- **Neunte Prüfung in `scripts/check-sicherheit.sh`.** Sie liest die beiden
  Manifeste als Plist und verlangt: gültiges Format, `NSPrivacyTracking`
  falsch, keine Tracking-Domänen, keine erfassten Daten, alle vier Schlüssel
  vorhanden.

  **Warum den Inhalt und nicht die Anwesenheit.** Der teure Fehler ist nicht
  das fehlende Manifest — das meldet Apple beim Hochladen. Teuer ist das
  widersprüchliche: Manifest und Fragebogen sagen Verschiedenes, das fällt
  erst in der Prüfung auf, und dann ist eine Runde weg.

  Gegengeprüft: einmal mit `NSPrivacyCollectedDataTypeDeviceID` im Manifest,
  einmal mit einer abgeschnittenen Plist. Beide Male hat sie angeschlagen.

### Was bewusst **nicht** dabei ist

**Die `.entitlements`.** Sie sind der nächste Punkt und werden trotzdem hier
nicht angelegt: Eine Berechtigungsdatei, die auf eine im Entwicklerportal noch
nicht angelegte Kennung zeigt, lässt die Signierung scheitern — und die
Fehlermeldung sagt nicht, welche der drei Kennungen fehlt. Sie gehören in
denselben Arbeitsgang wie das Anlegen von App-ID, App-Gruppe und
iCloud-Container, auf einem Rechner, der danach sofort bauen kann.

### Geändert

- **`docs/07-v1-plan.md`**: Die Reihenfolge nach der Freischaltung ist jetzt
  begründet und nicht nur nummeriert. Kennungen anlegen kommt vor allem
  anderen; **die App aufs Telefon kommt vor CloudKit und StoreKit**, weil die
  zwei Wochen Eigennutzung erst dann anfangen können und die beiden anderen
  zusammen eine Woche dauern.
- `docs/09-appstore.md` und `docs/11-sicherheit.md` führen den Punkt als
  erledigt, mit dem einen Rest: ob die Datei im gebauten Bündel landet, zeigt
  erst der Gerätebau.

---

## 0.54.1 — 2026-08-16

**Ein verlorener Tipp, zum vierten Mal — und diesmal an einer Stelle, die nie
angefasst wurde.**

Der Lauf zu 0.53.0 ist rot geworden: `testAddingAMeterFromTheMetersTab` mit
„Das Namensfeld fehlt". 0.53.0 hat **keine einzige Swift-Zeile** geändert — nur
Dokumente, die Website und ein Shell-Skript. Dieselbe App war eine Stunde
vorher grün. Es war also kein Rückschritt, sondern derselbe Wackler wie in
0.34.0 und 0.36.0: Der Tipp auf „Zähler hinzufügen" ging unter Last verloren,
das Blatt kam nie, und das Feld fehlte nicht — es war nicht da.

### Behoben

- **Neuer Helfer `oeffne(_:bis:in:_:)`** in `AppUITests/LaunchTests.swift`:
  tippen, nachsehen, ob der Anker da ist, sonst noch einmal tippen. Das ist
  genau die Lehre, die seit 0.36.1 für die Tab-Leiste im Code steht — sie galt
  nur dort, weil dort der erste Fehlschlag war. Jetzt gilt sie auch fürs
  Öffnen eines Blatts.
- **Zwei Aufrufstellen** benutzen ihn: `testAddingAMeterFromTheMetersTab` und
  `testFirstMeterThenFirstReadingThenConsumption`. Beide griffen vorher direkt
  aufs Namensfeld.

Der Anker ist bewusst die Navigationsleiste „Neuer Zähler" und **nicht** das
Namensfeld: Das Feld ist die Aussage dieser Tests. Wäre es zugleich die
Bedingung fürs Wiederholen, prüfte sich der Test selbst.

### Warum nicht einfach länger warten

Weil das in 0.34.1 schon versucht wurde — alle Wartezeiten von fünf auf zehn
Sekunden — und es danach wieder fiel. Ein Element, das nicht existiert, weil
der Schirm gar nicht offen ist, erscheint auch nach einer Minute nicht. Länger
warten kostet nur Zeit und findet nichts.

---

## 0.54.0 — 2026-08-16

**Der Go-Live-Plan stand noch auf dem Stand vom 10. August.**

Auf die Frage „was fehlt noch für go live" war die ehrliche erste Antwort: Der
Plan weiß es selbst nicht mehr. Dort stand „App-Store-Material: nicht
angefangen" — geschrieben, bevor `09-appstore.md`, die Website, die
Bildschirmfotos und die Sicherheitsprüfung existierten. Ein Plan, der die
eigene Arbeit nicht kennt, führt in die falsche Reihenfolge.

### Geändert

- **`docs/07-v1-plan.md`** neu am Code nachgesehen, nicht fortgeschrieben.
  Sechs Punkte fallen weg, keiner kommt dazu: Icon und Asset-Katalog,
  App-Store-Texte, Bildschirmfotos im Pflichtmaß, Datenschutzerklärung und
  Support-Seite als Text, die Sicherheitsprüfung.
- **Die Reihenfolge ist geteilt** in „vor dem Programm" und „danach". Zwei
  Punkte warten auf niemanden: die Veröffentlichung der Website (die
  Datenschutz-URL ist ein Pflichtfeld in App Store Connect) und
  `PrivacyInfo.xcprivacy` — eine Plist im Bündel, die kein Programm braucht.
  Beide standen bisher hinter dem Engpass, obwohl sie nicht dahinter gehören.
- **„Die App benutzen" steht jetzt vor StoreKit**, nicht daneben. Sie hat
  bisher am meisten gefunden, und sie braucht das Telefon, nicht den Kauf.
- **Der Zeitrahmen** geht von vier bis sechs auf **drei bis fünf Wochen ab
  Freischaltung** — das Material fällt als Engpass weg. Der Vorbehalt bleibt
  wörtlich derselbe: Die App lief noch nie auf einem echten Gerät.
- **„Was am meisten unterschätzt wird"** ist nicht mehr das Material, sondern
  der **iCloud-Abgleich**. Er ist nie gelaufen, trägt laut ADR-002 den
  Einmalkauf, und eine SwiftData-Schemamigration über CloudKit ist keine
  Einstellung, sondern eine eigene Testrunde.

---

## 0.53.0 — 2026-08-16

**Das Datenschutzversprechen steht jetzt vorn — und es ist geprüft.**

Der Gründer: „wichtig ist mir auch dass rüber kommt, dass keine daten erhoben
werden […] stelle das sicher dass wir das auch wirklich machen wenn wir das
versprechen." Der zweite Teil ist der wichtigere, und deshalb kam er zuerst.

### Geprüft, bevor etwas versprochen wurde

Die Zusagen halten. Nachgesehen, nicht angenommen:

- **Kein Netzverkehr, keine fremden Pakete, keine Protokollausgabe** — die
  bestehenden Prüfungen greifen und sind grün.
- **Der Export hängt an keinem Kauf.** `ProductID` kennt keinen Eintrag dafür,
  `AccessPolicy.canUse` gibt immer `true` zurück, die Ausgabezeile in
  `HistoryView` ist an keine Berechtigung gebunden, und `AccessPolicyTests`
  hält beides mit `testExportIsNeverForSale` fest.
- **iCloud nutzt `.automatic`**, also die private Datenbank des Nutzers.

### Hinzugefügt

- **Zwei neue Prüfungen in `scripts/check-sicherheit.sh`** (jetzt acht):
  - **Kein Analyse-, Werbe- oder Absturzberichtsbaustein** —
    `AppTrackingTransparency`, `AdSupport`, `SKAdNetwork`, Firebase, Sentry,
    Mixpanel, Amplitude, Bugsnag, Crashlytics, TelemetryDeck, PostHog.
  - **iCloud nur privat** — `cloudKitDatabase` darf nie `.public` oder
    `.shared` sein.

  Beide sind **gegengeprüft**: `import Sentry` und `cloudKitDatabase: .public`
  wurden absichtlich eingebaut, beide Prüfungen schlugen an, danach zurück.
  Eine Prüfung, die nie ausschlägt, beweist nichts.

### Geändert

- **Die Startseite** sagt es jetzt zweimal. Unter den Knöpfen drei Zusagen
  (kein Konto, keine Werbung und kein Tracking, deine Zahlen bleiben bei dir),
  und weiter unten ein eigener Abschnitt mit sechs Karten: kein Konto, keine
  Server, kein Tracking, deine eigene iCloud, Export dauerhaft kostenlos,
  Löschen heißt gelöscht. Die Überschrift heißt „Wir sehen deine Zählerstände
  nicht. Nie." — nicht „Datenschutz".
- **Der Absatz nennt, warum man das glauben kann:** dass ein Skript im
  Quelltext bei jeder Änderung mitprüft, und was es prüft.
- **`docs/09-appstore.md`**: „Keine Daten erfasst" — die Kennzeichnung des
  Stores — steht jetzt in der Beschreibung, dazu „Löschen heißt gelöscht".
  3.844 von 4.000 Zeichen.
- **`docs/11-sicherheit.md`** und die README-Tabelle führen die zwei neuen
  Prüfungen.

### Gelernt

Ein Versprechen auf einer Website ist eine Aussage über den Quelltext. Wer es
schreibt, ohne nachzusehen, hat geraten — und ein Absturzmelder wird nicht aus
Böswilligkeit eingebaut, sondern weil er nützlich ist. Genau deshalb gehört
jede solche Zusage an eine Prüfung, die den Tag überlebt, an dem sie
geschrieben wurde.

---

## 0.52.0 — 2026-08-16

**Die Startseite erzählt nicht mehr, wie die Eingabe aussieht.**

Rückmeldung des Gründers: „das interessiert user nicht." Zu Recht. Dass Ziffern
von rechts einlaufen und Nachkommastellen rot bleiben, ist eine
Gestaltungsentscheidung — für den, der die App noch nicht hat, ist es nichts.
Auf einer Produktseite steht, was jemand davon hat, nicht wie es innen gebaut
ist.

### Geändert

- **`docs/website/index.html` neu aufgebaut.** Reihenfolge jetzt Überblick →
  Kosten → Erfassen → besondere Fälle → Daten → Preise: erst der Nutzen, dann
  der Weg dorthin. Jeder der drei großen Abschnitte hat eine Liste mit drei
  belegbaren Punkten statt einer Beschreibung der Oberfläche.
  - **Überblick:** Vergleich auf gleicher Grundlage, gekennzeichnete
    Schätzungen, jede Zahl antippbar.
  - **Kosten:** Hochrechnung, die den Winter kennt; Abschlagsvergleich mit
    Betrag; Preiswechsel getrennt gerechnet.
  - **Erfassen:** Der Punkt ist die Prüfung beim Eintippen, nicht das Aussehen
    des Feldes — ein Wert unter dem letzten Stand oder weit über dem Üblichen
    wird hinterfragt, solange man noch am Zähler steht.
- **Zwei neue Karten** bei den besonderen Fällen: **Zählerüberlauf** (ein
  sechsstelliger Zähler fängt wieder bei null an) und **Heizperiode statt
  Kalenderjahr**. Beides rechnet der Kern seit Langem, und beides stand
  nirgends. Dafür sind „Erinnerungen" und „Bericht und Export" aus dem Raster
  heraus — sie stehen jetzt dort, wo sie hingehören.
- **Der Abschnitt „Datenschutz" heißt „Deine Daten"** und nennt konkret, was
  herauskommt: Tabelle, PDF-Bericht, Abgleich über die eigene iCloud.
- **Der Vorspann** sagt in einem Satz, was die App führt und was sie zeigt.
- **`docs/09-appstore.md`**: derselbe Absatz dort ebenso. Die Beschreibung
  liegt jetzt bei 3.612 von 4.000 Zeichen.

Nichts davon ist eine neue Behauptung: Jeder Punkt hat seine Entsprechung in
`PulseCore` — `ConsumptionEngine.plausibility`, `ForecastEngine`,
`PeriodEngine`, die Überlaufbehandlung in `ConsumptionResult`.

---

## 0.51.1 — 2026-08-16

**Der Umsatzsteuer-Abschnitt ist raus statt leer.**

Vom Gründer bestätigt: Er hat keine Umsatzsteuer-Identifikationsnummer. § 5 DDG
verlangt sie nur, *soweit vorhanden* — also gehört dort nichts hin, und schon
gar keine leere Zeile.

### Entfernt

- **Der Abschnitt „Umsatzsteuer"** in `docs/website/impressum.html`, samt des
  Platzhalters `[USt-IdNr. eintragen]`. An seiner Stelle steht ein Kommentar,
  der begründet, warum dort nichts steht — sonst trägt die nächste Sitzung
  wieder etwas Plausibles ein. Genau so ist bis 0.49.0 „Kleinunternehmer nach
  § 19 UStG" hineingeraten.

### Geändert

- **`docs/website/EINTRAGEN.md`**: Der Punkt wandert von „offen" nach
  „erledigt", mit dem Vermerk, dass eine spätere USt-IdNr. als eigener
  Abschnitt zurückkommt. Offen ist damit nur noch der Name des Hosters.
- Der verbliebene Platzhalter heißt jetzt `PLATZHALTER 1 von 1`.

Auf die Preise wirkt sich nichts aus: Bei App-Verkäufen in der EU ist Apple
der Verkäufer gegenüber dem Kunden und führt die Umsatzsteuer ab.

---

## 0.51.0 — 2026-08-16

**Auf der Website stand noch der alte Zähler.**

Die Ziffernwalzen sind seit 0.46.0 weg, die Bilder auf der Startseite zeigten
sie trotzdem — sie stammten aus einem Lauf davor. Und weil die Bilder alt
waren, war es der Text daneben auch: Er beschrieb ein Zählwerk an der Wand,
das es in der App nicht mehr gibt. Dieselbe Beschreibung stand außerdem noch
in der App-Store-Fassung. Vom Nutzer bemerkt, nicht von einer Prüfung.

### Geändert

- **Alle sechs Bilder** unter `docs/website/bilder/` neu aus dem Zweig
  `screenshots` geholt (Stand 03fc1eb). Die Erfassung zeigt jetzt das, was die
  App tatsächlich anzeigt: `00.000,000`, blasse Stellen für das, was noch
  fehlt, rote Nachkommastellen und die Schreibmarke.
- **Der Text auf der Startseite** und beide Bildbeschreibungen beschreiben die
  Eingabe von rechts nach links statt der Walzen.
- **`docs/09-appstore.md`**: derselbe Satz in der Beschreibung ersetzt. Die
  Beschreibung liegt damit bei 3.633 von 4.000 Zeichen.

### Gelernt

Ein Screenshot altert lautlos. Er wird nicht rot, er bricht nichts, und je
länger er liegt, desto selbstverständlicher sieht er aus. Der Text daneben
altert mit — wer die Bilder tauscht, muss die Sätze mitlesen, sonst beschreibt
die Seite weiter ein Gerät, das niemand mehr sieht.

---

## 0.50.0 — 2026-08-16

**Die Website beantwortet jetzt Fragen, die Leute wirklich eintippen.**

Auszeichnungen sind schnell gesetzt und bringen für sich genommen wenig.
Gefunden wird eine Seite, weil sie eine Frage beantwortet — und solche Seiten
gab es hier bisher nicht. Beides ist jetzt da.

### Hinzugefügt

- **Zwei Antwortseiten**, genau auf die Suchabsichten aus
  `10-sichtbarkeit.md`, Abschnitt 7:
  - `gas-in-kwh.html` — „Kubikmeter in Kilowattstunden umrechnen". Mit der
    Formel, einem Beispiel zum Nachrechnen (250 m³ → 2.702 kWh) und den drei
    Fehlern, die dabei am häufigsten passieren. Der erste davon ist die
    Faustformel „mal zehn", die je nach Gasqualität um mehrere Prozent
    danebenliegt.
  - `abschlag-zu-hoch.html` — „Abschlag zu hoch? So rechnest du es nach".
    (Jahresverbrauch × Arbeitspreis + Grundpreis) ÷ 12, mit einem Beispiel, bei
    dem 130 statt 91 € im Monat rund 470 € im Jahr vorstrecken.
  Beide sind von der Hilfeseite und aus dem Fuß der Startseite verlinkt — eine
  Seite, auf die nichts zeigt, findet weder Mensch noch Suchmaschine.
- `robots.txt` und `sitemap.xml` mit fünf Adressen. Das Impressum steht
  bewusst **nicht** drin: Es trägt `noindex` und soll erreichbar sein, nicht
  auffindbar. Eine Adresse anzumelden und gleichzeitig auszuschließen wäre ein
  widersprüchliches Signal.
- Open Graph und Twitter Cards auf allen Seiten — nicht fürs Ranking, sondern
  damit ein geteilter Link nicht als nackte Adresse ankommt.
- Ein JSON-LD-Block auf der Startseite (`SoftwareApplication`), der sagt, was
  das Ding ist, für welches System und in welcher Sprache.

### Behoben

- **Der Namensraum der Sitemap war falsch.** Dort stand `sitemap.org` statt
  `sitemaps.org` — mit s. Google hätte die Datei stillschweigend verworfen, und
  wir hätten sie für erledigt gehalten. Gefunden beim Nachprüfen mit einem
  XML-Parser, nicht mit dem Auge. Eine Prüfung hält den Namensraum jetzt fest.

### Geändert

- `scripts/domain-setzen.sh` stellt jetzt auch `og:url`, `og:image`, die
  JSON-LD-Adresse sowie `robots.txt` und `sitemap.xml` um. Ohne das wären nach
  einem Domainwechsel genau die Dateien stehen geblieben, die eine Suchmaschine
  als Erstes liest. Gegengeprüft: einmal auf `pulsemeter.de` und zurück, alle
  Stellen wandern mit.
- Die Prüfung deckt jetzt **sechs** Seiten ab statt vier und vergleicht die
  Adresse in `robots.txt` und `sitemap.xml` gegen die der Seiten.

_Die Wirkung ist **nicht gemessen** und kann es vor der Veröffentlichung auch
nicht sein. Was hier steht, ist die Umsetzung der Wette aus
`10-sichtbarkeit.md`; nachprüfbar wird sie vier Wochen nach dem Onlinegehen
über Impressionen und Seitenaufrufe._

---

## 0.49.0 — 2026-08-16

**Im Impressum stand eine Behauptung, die niemand aufgestellt hatte.**

„Kleinunternehmer im Sinne von § 19 Umsatzsteuergesetz" — ich hatte das
geschrieben, weil es bei einem Einzelentwickler plausibel klingt. Der Gründer
hat am 16. August bestätigt, dass es **nicht** zutrifft. Eine falsche Angabe
zur Umsatzsteuer im Impressum ist kein Schönheitsfehler.

### Behoben

- Der Satz ist ersatzlos raus. An seiner Stelle steht ein Platzhalter für die
  Umsatzsteuer-Identifikationsnummer, die § 5 DDG **soweit vorhanden** verlangt.
- Die Startseite sagte „Bald im App Store". Das ist eine Absicht, keine
  Tatsache. Jetzt: „Die App ist noch nicht im App Store."
- Auf der Preisliste steht jetzt dabei, dass sich noch nichts kaufen lässt und
  die Beträge die **geplanten** Preise sind. Preise für ein Produkt, das man
  nicht erwerben kann, sind sonst eine stillschweigende Zusage.
- Der Stand der Datenschutzerklärung ist auf den 16. August gesetzt — er stand
  auf dem 14., obwohl der Text seither dreimal geändert wurde.

### Hinzugefügt

- **Eine Regel in `CLAUDE.md`:** Was über den Gründer, sein Gewerbe, seine
  Anschrift oder seine Zahlen behauptet wird, muss von ihm bestätigt sein.
  Sonst wird es weggelassen — ein fehlender Absatz ist harmlos, ein falscher
  nicht — oder es steht als markierter Platzhalter da. In `docs/` darf eine
  Annahme stehen, wenn sie als solche gekennzeichnet ist. Rechtstexte sind
  keine Textsorte, in der sich etwas plausibel ergänzen lässt.
- Eine Prüfung dazu: **Jede eckige Klammer im sichtbaren Text braucht einen
  `PLATZHALTER`-Kommentar.** Ohne sie könnte `[USt-IdNr. eintragen]` online
  gehen, weil der Kommentar beim Bearbeiten verlorenging und die Zählung dann
  auf null steht.

### Nachgetragen

- Zur Umsatzsteuer und den Preisen, als überprüfbare Tatsache statt als
  Vermutung: Bei App-Verkäufen in der EU ist **Apple der Verkäufer** gegenüber
  dem Kunden und führt die Umsatzsteuer ab. Die Beträge in
  `04-monetarisierung.md` sind das, was der Kunde zahlt, und bleiben es —
  unabhängig davon, was im Impressum steht.

_Website-Prüfungen erweitert, 94 Prüfungen des Klick-Dummys, 198 Tests in
PulseCore, 6 Sicherheitsprüfungen — alle grün._

---

## 0.48.3 — 2026-08-16

**Im Impressum stand ein Kommentarrest als Text.**

### Behoben

- Beim Entfernen des Platzhalters in 0.48.2 blieb die zweite Zeile eines
  zweizeiligen HTML-Kommentars stehen — ein `-->` ohne Anfang. Der Browser
  zeigt so etwas als **Text** an: Über der Anschrift stand „Ohne ladungsfähige
  Anschrift darf diese Seite nicht online gehen. -->", mitten im Impressum.
  Genau auf der Seite, die Vertrauen herstellen soll.
- Keine der 231 Prüfungen sah es. Überschrift, Verweise, Überlauf, fremde
  Anfragen — alles war in Ordnung. Deshalb gibt es jetzt eine 232.: **Die
  Kommentarzeichen jeder Seite müssen paarweise auftreten.** Sie hätte den
  Fehler im selben Lauf gefangen, in dem er entstand.

_Gefunden beim Nachsehen des eigenen Handgriffs, nicht durch eine Prüfung — und
das ist der Grund, warum es die neue Prüfung jetzt gibt. 232 Website-Prüfungen,
94 Prüfungen des Klick-Dummys, 198 Tests in PulseCore, 6 Sicherheitsprüfungen._

---

## 0.48.2 — 2026-08-16

**Die Anschrift steht. Von den vier Platzhaltern ist noch einer übrig — und
der wartet auf Cloudflare, nicht auf eine Entscheidung.**

### Geändert

- Impressum und Datenschutzerklärung tragen Name und ladungsfähige Anschrift,
  an beiden Stellen wortgleich. Damit ist die Seite in dem Punkt vollständig,
  an dem eine deutsche Website sonst abmahnfähig wäre.
- `docs/website/EINTRAGEN.md` neu gefasst: Was erledigt ist, steht als
  erledigt da; offen ist nur noch der Name des Hosters in Abschnitt 7 der
  Datenschutzerklärung. Sobald Cloudflare Pages steht, sind dort die eckigen
  Klammern zu entfernen — und dann prüft
  `PULSE_WEBSITE_LIVE=1 node scripts/check-website.mjs` als **Fehlschlag**,
  ob wirklich keiner mehr offen ist.

### Offen und ausdrücklich vermerkt

- Im Impressum steht „Kleinunternehmer im Sinne von § 19 Umsatzsteuergesetz".
  Das ist eine **Annahme**, keine geprüfte Angabe. Trifft sie nicht zu, gehört
  dort die Umsatzsteuer-Identifikationsnummer hin — und es betrifft dann auch
  die Preise in `04-monetarisierung.md`, die als Bruttopreise gedacht sind.

_231 Website-Prüfungen, 94 Prüfungen des Klick-Dummys, 198 Tests in PulseCore,
6 Sicherheitsprüfungen — alle grün._

---

## 0.48.1 — 2026-08-15

**Die Kontaktadresse steht. Von drei offenen Stellen ist eine weg.**

### Geändert

- `geschult-atome.6r@icloud.com` ist auf der Hilfeseite, im Impressum und in
  der Datenschutzerklärung eingetragen — eine Adresse aus Apples
  „E-Mail-Adresse verbergen". Sie leitet weiter, hält die private Adresse aus
  dem öffentlichen Impressum und lässt sich abschalten, falls Werbung darüber
  kommt.
- Die Platzhalter sind neu gezählt: `n von 3` statt `n von 4`. Offen bleiben
  die Anschrift im Impressum, dieselbe Anschrift in der Datenschutzerklärung —
  sie **müssen** übereinstimmen, sonst fällt es genau dann auf, wenn es
  unangenehm ist — und der Name des Hosters, sobald Cloudflare Pages steht.

_231 Website-Prüfungen, 94 Prüfungen des Klick-Dummys, 198 Tests in PulseCore,
6 Sicherheitsprüfungen — alle grün. Ohne Anschrift darf die Seite weiterhin
nicht online: Ein Impressum ohne ladungsfähige Anschrift ist abmahnfähig._

---

## 0.48.0 — 2026-08-15

**Die Website bekommt erst einmal eine kostenlose Adresse — und der Wechsel
kostet später einen Befehl.**

Der Gründer will mit `pulsemeter.pages.dev` anfangen statt mit einer eigenen
Domain. Vernünftig, solange die Entscheidung umkehrbar bleibt: Die Adresse
steht in vier `canonical`-Zeilen, und eine **halb** umgestellte Website ist
schlimmer als eine mit der falschen Adresse. Suchmaschinen halten `canonical`
für die Wahrheit und werfen weg, was auf eine fremde Adresse zeigt.

### Hinzugefügt

- `scripts/domain-setzen.sh` — setzt alle vier Seiten in einem Zug um, zeigt
  ohne Argument nur an, was eingetragen ist, und **weigert sich**, wenn die
  Seiten schon auseinanderlaufen. Ersetzt wird ausschließlich innerhalb der
  `canonical`-Zeilen; ein stumpfes Suchen und Ersetzen über die ganze Datei
  träfe auch Fließtext.
- Eine Prüfung in `check-website.mjs`: Alle Seiten müssen auf **dieselbe**
  Adresse zeigen. Sie merkt, wenn es doch jemand von Hand versucht hat.

### Geändert

- Eingetragen ist jetzt `pulsemeter.pages.dev` statt `pulsemeter.de`.
- Die Kontaktadresse ist wieder ein Platzhalter. `hallo@pulsemeter.de` gibt es
  ohne Domain nicht, und eine Support-Seite mit toter Adresse ist schlimmer als
  keine. Vorgesehen ist stattdessen eine Adresse aus Apples „E-Mail-Adresse
  verbergen" — sie leitet weiter, hält die private Adresse aus dem Impressum
  und lässt sich abschalten, wenn Werbung kommt. Der Weg dorthin steht Schritt
  für Schritt in `docs/website/EINTRAGEN.md`.

_Ausdrücklich **nicht** empfohlen und nirgends eingetragen: Freenom-Adressen
(`.tk`, `.ml`, `.ga`). Sie sind bei Spam-Filtern verbrannt und werden ohne
Vorwarnung eingezogen. Eine ehrliche Subdomain trägt weiter als eine billige
Domain._

_231 Website-Prüfungen, 94 Prüfungen des Klick-Dummys, 198 Tests in PulseCore,
6 Sicherheitsprüfungen — alle grün._

---

## 0.47.0 — 2026-08-15

**Sicherheitsprüfung über die ganze App. Zwei Funde, beide behoben.**

Das Ergebnis vorweg: Die Fläche ist ungewöhnlich klein. Kein `URLSession`,
keine fremden Pakete, keine Zwischenablage, keine Protokollausgabe, keine
eigenen URL-Schemata, keine ATS-Ausnahmen, keine Berechtigungstexte für Dinge,
die es nicht gibt. Das ist kein Zufall, sondern ADR-002 — was es nicht gibt,
kann nicht falsch konfiguriert werden. Alles steht in `docs/11-sicherheit.md`.

### Behoben

- **Ein Zählername konnte in einer Tabellenkalkulation zur Formel werden.** Der
  CSV-Export fasste Felder korrekt ein, neutralisierte aber keine
  Formelzeichen. Ein Zähler namens `=HYPERLINK("http://…")` ist in der Datei
  nur Text; beim Öffnen in Excel, Numbers oder LibreOffice wird daraus eine
  Formel, die **beim bloßen Ansehen der Tabelle läuft**. Einfassen allein hilft
  nicht — auch `"=1+1"` wird ausgewertet. Beginnt ein Textfeld jetzt mit `=`,
  `+`, `-`, `@`, Tabulator oder Wagenrücklauf, steht ein Apostroph davor.
  Zahlen und Daten bleiben unberührt.
  Heute gering — der Nutzer tippt seine Namen selbst. Ab der Vermieter-Fassung
  mittel: Dort tippt der eine, und der andere öffnet.
- **Die Startschalter lagen im ausgelieferten Programm.** An neun Stellen stand
  `ProcessInfo.processInfo.arguments.contains("-pulse-…")`; zwei davon sind
  scharf — `-pulse-reset` löscht alle Ablesungen, `-pulse-pro` schaltet jeden
  Kauf frei. Sie waren in jeder Konfiguration übersetzt. Von außen setzen ließen
  sie sich auf einem gewöhnlichen iPhone nicht, also keine offene Tür — aber
  eine Tür ohne Grund. Alle Abfragen laufen jetzt über `App/Startschalter.swift`
  und geben im `Release`-Bau `false` zurück.

### Hinzugefügt

- `docs/11-sicherheit.md`: die vollständige Prüfung mit Datum — was behoben
  wurde, was angesehen und für richtig befunden, was mangels Gegenstand
  entfällt, und was erst mit dem Developer Program prüfbar wird (StoreKit-Belege,
  CloudKit-Rechte, `.entitlements`, Privacy-Manifest, Systemprotokolle am Gerät).
- `scripts/check-sicherheit.sh` — sechs Prüfungen, eine Sekunde, eingehängt in
  `scripts/pruefen.sh` und in die CI. Sie hält fest, was **nicht** da sein darf.
  Gegengeprüft: Mit einer eingeschmuggelten `URLSession`-Zeile schlägt sie an,
  ohne sie nicht. Eine Prüfung, die immer grün ist, prüft nichts.
- Zwei Tests in `TableExportTests`: ein Name wird nie zur Formel, und ein
  gewöhnliches „Strom" bleibt unangetastet — die Heilung darf nicht schlimmer
  sein als die Krankheit.

_198 Tests in PulseCore, 94 Prüfungen des Klick-Dummys, 230 Website-Prüfungen,
6 Sicherheitsprüfungen — alle grün._

---

## 0.46.0 — 2026-08-15

**Die Zahl läuft jetzt von rechts ein — und Stromzähler führen zwei
Nachkommastellen.**

Aus den drei Entwürfen von 0.45.0 hat der Gründer B gewählt. Die sechs Walzen
sind damit Geschichte: Es steht eine große Zahl da, die Ziffern rutschen von
rechts herein, die Tausenderpunkte setzen sich selbst, die Nachkommastellen
bleiben rot wie am Gerät. Der Grund war Tempo — sechs Rollen einzeln zu drehen
dauert im Keller länger, als eine Zahl einzutippen.

### Geändert

- Das Zählwerk in `PulseUI` und im Klick-Dummy gleichzeitig umgebaut. Noch
  nicht getippte Stellen stehen **blass da statt zu fehlen**: So sieht man auf
  einen Blick, wie viele Ziffern das Gerät hat. Ein Strich zeigt, wo die
  nächste Ziffer landet; bei eingeschalteter Bewegungsreduzierung blinkt er
  nicht.
- Tausenderpunkte werden **von rechts** gezählt. Sonst wandern sie, während
  die Zahl wächst, und das Auge verliert die Stelle, an der es gerade war.
- **Stromzähler stehen jetzt auf zwei Nachkommastellen** statt einer, ebenso
  Photovoltaik, Wallbox, Speicher und Fernwärme. Mechanische Ferraris-Zähler
  haben eine rote Ziffer, elektronische führen zwei — und die hängen inzwischen
  in den meisten Kellern. Wer nur eine Stelle eintragen kann, rundet bei jeder
  Ablesung. Wasser und Gas bleiben bei drei, Heizöl bei null. Die Zahl ist eine
  Vorbelegung und steht an jedem Zählwerk einzeln.

### Behoben

- `testTheCounterAnnouncesItsValue` verglich die vorgelesene Zeichenkette mit
  `123` und prüfte damit in Wahrheit die Nachkommastellen des zuerst gefundenen
  Zählers — vorgelesen wird je nach Gerät „12 Komma 3" oder „0 Komma 123". Die
  Prüfung hätte bei jeder Änderung an den Vorbelegungen fallen können, ohne
  dass etwas kaputt gewesen wäre. Sie vergleicht jetzt nur die Ziffern.

### Hinzugefügt

- Zehn neue Prüfungen am Klick-Dummy (jetzt **94**): Tausenderpunkte an der
  richtigen Stelle, zwei rote Nachkommastellen, blasse Stellen für das, was
  noch fehlt, und der Strich, der nach dem Löschen zurückkommt.
- `testTheCounterFillsFromTheRight` in den Oberflächenprüfungen: Die zuletzt
  getippte Ziffer landet hinten, und die Zahl wird mit keinem Anschlag kürzer.
  Eine Zahl, die um eine Stelle verrutscht, macht aus 41.312,74 eben 4.131,27 —
  und das fiele erst bei der Abrechnung auf.

_196 Tests in PulseCore, 94 Prüfungen des Klick-Dummys, 230 Website-Prüfungen —
alle grün. Die Oberflächenprüfungen brauchen einen Mac und laufen in der CI._

---

## 0.45.0 — 2026-08-15

**Drei Entwürfe für die Zählereingabe, alle drei zum Anfassen.**

Dem Gründer gefällt die heutige Eingabe nicht ganz. Statt einer Beschreibung
liegen jetzt drei Vorschläge da, die man durchtippen kann — eine Eingabe
beurteilt man nicht nach dem Aussehen, sondern danach, wie sie sich beim
sechsten Zeichen anfühlt.

### Hinzugefügt

- `docs/entwuerfe/zaehlereingabe.html` mit drei Varianten am selben Beispiel
  (Strom, letzter Stand 18.472,3 kWh, 34 Tage her) und derselben
  Plausibilitätsprüfung wie in `PulseCore`:
  - **A — Walzen wie am Gerät.** Jede Stelle eine Rolle zum Ziehen oder
    Antippen. Man überträgt nicht, man dreht nach. Dafür am langsamsten.
  - **B — Zahl läuft von rechts ein.** Eine große Zahl, Tausenderpunkte setzen
    sich selbst, die Nachkommastelle bleibt rot. Am schnellsten, aber ein
    Zahlendreher fällt erst am Ergebnis auf.
  - **C — Nur, was sich geändert hat.** Die vorderen Stellen stehen schon da;
    getippt wird der Rest, vier Zeichen statt sechs. Der Verbrauch steht
    daneben, während man tippt. Nach einem Zählerwechsel greift der Vorschlag
    nicht — dafür gibt es den Weg zurück zur ganzen Zahl.
- `scripts/check-entwuerfe.mjs`: klickt alle drei durch, in Hell und Dunkel bei
  360 und 1280 Pixeln. Getippte Zahl, Verbrauchszeile, gesperrtes Sichern bei
  einem Rückwärtsstand, kein Überlauf, keine JavaScript-Fehler. **Nicht** in
  `scripts/pruefen.sh` eingehängt: Entwürfe verschwinden wieder, sobald
  entschieden ist, und sollen die tägliche Prüfung nicht überdauern.

_Kein Eingriff in App oder Prototyp — nur ein Entscheidungshilfsmittel. 230
Website-Prüfungen, 84 Prüfungen des Klick-Dummys, 196 Tests in PulseCore
unverändert grün; die Entwürfe selbst grün in vier Kombinationen aus
Erscheinungsbild und Breite._

---

## 0.44.0 — 2026-08-15

**Die App-Store-Texte sprechen jetzt dieselbe Sprache wie die Website.**

Sie waren als Letztes noch im alten Register — und sie sind der Text, den jeder
liest, der die App findet.

### Geändert

- Beschreibung, Werbetext und Versionshinweise neu geschrieben. Die
  Abschnitte heißen nach dem, was der Leser davon hat: „ABLESEN, BEVOR DAS
  LICHT AUSGEHT", „DIE NACHZAHLUNG SIEHST DU IM OKTOBER", „WIR WISSEN NICHT,
  WIE VIEL STROM DU VERBRAUCHST". Die Beschreibung ist von rund 2900 auf 3581
  Zeichen gewachsen und liegt damit weiter unter der Grenze von 4000.
- **Nicht** umgeschrieben: Name, Untertitel und Schlagwortfeld — die werden
  durchsucht, nicht gelesen. Ein hübscherer Untertitel, der `Zähler` und
  `Kosten` verliert, kostet mehr, als er einbringt. Ebenso wenig die Hinweise
  an die Prüfung: Ein Prüfer will wissen, wo er tippen muss, und sonst nichts.
- Das Schlagwortfeld in `09-appstore.md` stand noch auf der alten Liste, die
  mit `zählerstand`, `stromzähler`, `ablesen` und `verbrauch` begann. Alle vier
  stehen bereits in Name und Untertitel; ein Viertel des Feldes ging dafür
  drauf. Jetzt steht dort dieselbe Liste wie in `10-sichtbarkeit.md`.

### Behoben

- **Diese Liste war 101 Zeichen lang.** In 0.42.0 steht „99 von 100" — schlicht
  falsch gezählt. App Store Connect hätte beim Einfügen stillschweigend am Ende
  abgeschnitten, und niemand hätte gemerkt, welches Wort fehlt. `nachtstrom`
  ist heraus (über den Anzeigenamen des Kaufs ohnehin abgedeckt), `wallbox` ist
  drin, das Feld liegt bei 98 Zeichen. Beide Dokumente sind angeglichen, und in
  `10-sichtbarkeit.md` steht jetzt die Regel, jede künftige Fassung
  nachzuzählen.

_Nur Dokumente. 230 Website-Prüfungen, 84 Prüfungen des Klick-Dummys, 196 Tests
in PulseCore unverändert grün. Alle fünf Textfelder nachgezählt: Name 25,
Untertitel 28, Werbetext 167, Schlagworte 98, Beschreibung 3581._

---

## 0.43.1 — 2026-08-15

**Die Website klang wie eine Maschine. Jetzt klingt sie wie jemand, der die
Sache kennt.**

Der Gründer hat die erste Fassung als „steril und wie von KI" bezeichnet, und
er hatte recht: Jeder Satz begründete sich selbst mit einem Gedankenstrich,
alle waren gleich lang und gleich gebaut, und keiner beschrieb eine Lage, in
der jemand tatsächlich steckt.

### Geändert

- Start- und Hilfeseite komplett neu getextet. Aus „Eine Zahl eintragen. Und
  wissen, ob alles im Rahmen ist." wurde „Einmal im Monat ablesen. Den Rest des
  Jahres Bescheid wissen." Aus „Ein großer Ziffernblock, bedienbar bei
  schlechtem Licht" wurde „Groß genug, dass man ihn im Keller einhändig
  trifft."
- Die Abschnitte heißen nicht mehr nach ihrer Funktion, sondern nach dem, was
  der Leser davon hat: „Die Nachzahlung siehst du im Oktober, nicht im März"
  statt „Aus Verbrauch wird ein Betrag". „Wir wissen nicht, wie viel Strom du
  verbrauchst" statt „Deine Zahlen bleiben deine".
- Konkretes statt Adjektive: Keller, Sicherungskasten, Februar, Wallbox in der
  Garage, Zustandszahl von der Rechnung.

### Hinzugefügt

- `CLAUDE.md` hat einen Abschnitt **Tonfall** bekommen, mit einer Tabelle
  „nicht so / sondern". Ohne ihn schreibt die nächste Sitzung wieder im alten
  Klang, und die Arbeit war umsonst. Er gilt für Website, App-Store-Texte,
  Oberfläche und Mitteilungen — nicht für `docs/` und nicht für die Kommentare
  im Code, die dürfen weiter erklären.
- Ausdrücklich festgehalten, was der lockerere Ton **nicht** erlaubt: Es wird
  nichts versprochen, was es nicht gibt, und geschätzte Zahlen bleiben
  gekennzeichnet.

### Behoben

- Die CI prüfte die Website gar nicht. Lokal hängt die Prüfung in
  `scripts/pruefen.sh`, aber `ci.yml` ruft die Skripte einzeln auf — und dort
  stand nur der Klick-Dummy. Der Lauf zu 0.43.0 war deshalb grün, ohne eine
  einzige Seite angesehen zu haben. Jetzt läuft `check-website.mjs` im selben
  Auftrag auf derselben Maschine, zwanzig Sekunden zusätzlich.

_230 Website-Prüfungen weiter grün, 84 Prüfungen des Klick-Dummys, 196 Tests in
PulseCore. Die Rechtstexte bleiben unangetastet — Datenschutz und Impressum
müssen genau sein, nicht schwungvoll._

---

## 0.43.0 — 2026-08-14

**Die Website steht: Startseite, Hilfe, Datenschutz, Impressum.**

Sie erledigt die zwei URLs, die Apple zur Einreichung verlangt und die bisher
offen waren — und sie ist zugleich die einzige Fläche, auf der klassische
Suchmaschinenoptimierung überhaupt greift (`10-sichtbarkeit.md`, Abschnitt 7).

### Hinzugefügt

- `docs/website/` — vier Seiten, ein Stilblatt, drei Bildschirmfotos. Kein
  Aufbauschritt, kein JavaScript, **keine einzige Anfrage an einen fremden
  Server**: keine Schriften von Google, kein Analysewerkzeug, kein
  eingebettetes Video. Das ist die Pointe und keine Sparsamkeit — ohne fremde
  Anfragen entstehen keine Cookies, und damit braucht die Seite **kein
  Zustimmungsfenster**. Eine App, die „Keine Daten erfasst" verspricht, darf
  ihre Website nicht mit einem Cookie-Banner eröffnen.
- Die Bildschirmfotos kommen aus dem Zweig `screenshots`, den die CI ohnehin
  füllt — in Hell und Dunkel, und die Seite zeigt automatisch die passende
  Fassung. Keine zweite Quelle, die auseinanderlaufen könnte.
- `scripts/check-website.mjs` mit **230 Prüfungen**: alle vier Seiten in Hell
  und Dunkel bei 320, 768 und 1280 Pixeln, kein horizontaler Überlauf, jeder
  interne Verweis führt irgendwohin, Datenschutz und Impressum von jeder Seite
  aus in einem Klick erreichbar, jedes Bild mit Beschreibung — und null
  Anfragen nach draußen. Das Letzte wird **gemessen**, nicht behauptet: Eine
  eingebundene Schriftart genügt, um das Versprechen zu brechen, und man sieht
  ihr das nicht an.
- Eingehängt in `scripts/pruefen.sh`, parallel zum Klick-Dummy am selben
  Chromium. Kostet keine zusätzliche Wartezeit und wird geprüft, ohne dass
  jemand daran denken muss.
- `docs/website/EINTRAGEN.md` — die vier Stellen, die vor dem Onlinegehen
  ausgefüllt werden müssen, alle im Quelltext als `PLATZHALTER n von 4`
  markiert. Solange eine offen ist, bleibt es ein **Hinweis** und kein
  Fehlschlag; mit `PULSE_WEBSITE_LIVE=1` wird daraus ein Fehler. Ein dauerhaft
  roter Lauf für etwas, das nur der Gründer eintragen kann, wird nach drei
  Tagen nicht mehr gelesen.
- Die Datenschutzerklärung hat einen Abschnitt „Diese Website" bekommen. Er
  fehlte: Auch ein Hoster, der nichts auswertet, verarbeitet beim Ausliefern
  IP-Adressen, und das ist anzugeben.

### Behoben

- Der Sprungverweis für die Tastatur stand auf `left: -9999px` — der übliche
  Trick, der das Dokument um 9999 Pixel verbreitert. Sichtbar war davon nichts;
  gefunden hat es die neue Überlaufmessung im ersten Lauf. Er liegt jetzt
  oberhalb des Bildes und kostet keine Breite.
- Die Kopfzeile lief bei 320 Pixeln aus dem Bild. Die Navigation rutscht dort
  jetzt in eine zweite Zeile, statt versteckt zu werden — auf den Rechtsseiten
  ist sie der einzige Weg zurück.
- Lange deutsche Wörter (`Datenschutz-Grundverordnung`) standen auf schmalen
  Telefonen über den Rand hinaus. `overflow-wrap` und `hyphens` stehen jetzt
  global.

_230 Website-Prüfungen, 84 Prüfungen des Klick-Dummys, 196 Tests in PulseCore
— alle grün. An App und Prototyp ist nichts geändert. Die drei ersten Fehler
oben hat die Prüfung selbst gefunden, keiner davon war mit bloßem Auge zu
sehen._

---

## 0.42.0 — 2026-08-13

**Wie jemand von dieser App erfährt, der uns nicht kennt.**

### Hinzugefügt

- `docs/10-sichtbarkeit.md`. Der Kern: **Der App Store durchsucht die
  Beschreibung nicht.** Gefunden wird über Name, Untertitel, das unsichtbare
  Schlagwortfeld und — fast immer übersehen — die **Anzeigenamen der
  In-App-Käufe**. Wir haben fünf davon, also fünf zusätzliche Suchfelder, für
  die das Dokument Namen vorschlägt. Die Kennungen bleiben dabei unangetastet;
  nur was im Store darübersteht, ändert sich.
- Ein neuer Vorschlag fürs Schlagwortfeld, 99 von 100 Zeichen, ohne ein
  einziges Wort aus Name und Untertitel — die stehen dort doppelt und kosten
  die meisten Apps ein Viertel ihres Feldes.
- Die Wette, auf der das Dokument steht, ausdrücklich als Wette gekennzeichnet:
  Wer „zählerstand" tippt, sucht einen Notizblock; wer „nebenkostenabrechnung
  prüfen" tippt, hat einen Brief in der Hand und sucht ein Mittel. Der zweite
  ist unsere Beschreibung Wort für Wort, und dort steht kaum jemand. Nachprüfbar
  ist das erst vier Wochen nach der Veröffentlichung.
- Der Zeitpunkt: Diese App hat eine Saison. Gesucht wird von Januar bis März,
  wenn die Jahresabrechnungen kommen. Wer im Februar erscheint, verpasst sie —
  der Store braucht Wochen, um eine neue App einzuordnen. Also im Herbst
  veröffentlichen.

### Behoben

- Die Hinweise für die Prüfung in `docs/09-appstore.md` beschrieben noch den
  Stand vor 0.40.0: einen einzelnen Kauf namens „PulseMeter Pro". Seit 0.40.0
  sind es fünf. Unbemerkt geblieben wäre das der erste Text gewesen, den ein
  Prüfer liest — und er hätte etwas anderes vorgefunden, als dort steht. Das
  ist der kürzeste Weg zu einer Rückfrage, die eine Woche kostet.

_Nur Dokumente; an Code und Prototyp ist nichts geändert. 196 Tests in
PulseCore und 84 Prüfungen des Klick-Dummys unverändert grün. Die Zahlen zur
Sichtbarkeit selbst sind **nicht** gemessen und im Dokument als Schätzung
gekennzeichnet — Suchvolumen lässt sich aus einem Container nicht ermitteln._

---

## 0.41.1 — 2026-08-11

**Die App kommt jetzt per Doppelklick aufs Telefon.**

### Hinzugefügt

- `Aufs-iPhone.command` — im Finder doppelklicken, fertig. Es holt vorher den
  aktuellen Stand, aber nur vorspulend: Liegt im Arbeitsverzeichnis eigene,
  noch nicht gesicherte Arbeit, bleibt sie unangetastet und es wird gebaut, was
  da ist. Ein Doppelklick darf nichts wegwerfen. Dasselbe Muster wie
  `Am-Mac-starten.command` und aus demselben Grund: `.command` ist die einzige
  Endung, die der Finder von sich aus im Terminal öffnet.

### Geändert

- Die README nennt für Claude Code jetzt zuerst den Installer ohne Node
  (`curl -fsSL https://claude.ai/install.sh | bash`). `npm install -g` stand
  dort als einziger Weg — auf einem Mac ohne Node eine Sackgasse, und dieses
  Projekt braucht Node nur für die Prüfung des Klick-Dummys, weder für den
  App-Build noch für die Installation aufs Telefon.

_Wie 0.41.0 auf einem Linux-Container nicht ausführbar; geprüft ist die Syntax
(`bash -n`). Sonst unverändert: 196 Tests in PulseCore, 84 Prüfungen des
Klick-Dummys._

---

## 0.41.0 — 2026-08-11

**Ein Aufruf, und die App liegt auf dem eigenen iPhone — ohne Apple Developer
Program.**

Bisher lief PulseMeter nur im Simulator. Auf ein echtes Telefon kam sie nicht,
und der Grund stand in `project.yml`: `CODE_SIGNING_ALLOWED: NO`. Für den
Simulator und die CI ist das genau richtig — dort wird nichts signiert, und die
Einstellung spart auf einem gemieteten Läufer jedes Mal den Umweg über den
Schlüsselbund. Auf einem Gerät ist es ein Riegel.

### Hinzugefügt

- `scripts/aufs-handy.sh` baut, signiert und installiert auf ein angestecktes
  iPhone. Es sucht das Team im Schlüsselbund und das Gerät über `xctrace`,
  erzeugt das Xcode-Projekt bei Bedarf neu und lässt Xcode mit
  `-allowProvisioningUpdates` das Profil selbst anlegen. Eine gewöhnliche
  Apple-ID genügt; das Programm für 99 € im Jahr ist dafür **nicht** nötig.
- Die Einschränkungen ohne Programm stehen in der Ausgabe des Skripts und in
  der README, statt später als Überraschung aufzutreten: sieben Tage Laufzeit,
  ein leeres Widget (es liest über eine App-Gruppe, und die hängt am Programm),
  kein iCloud-Abgleich, keine Käufe.

### Geändert

- Signiert wird über Bauvariablen auf der Kommandozeile, nicht durch eine
  Änderung an `project.yml`. In der Xcode-Oberfläche ließe sich der Riegel
  ebenfalls umlegen — aber `PulseMeter.xcodeproj` wird erzeugt, und beim
  nächsten `xcodegen generate` wäre die Einstellung spurlos weg. Die CI baut
  unverändert unsigniert.

_Auf einem Linux-Container **nicht** ausführbar: Das Skript braucht Xcode, ein
angestecktes iPhone und einen Signierschlüssel. Geprüft ist hier die Syntax
(`bash -n`) und die Wahl der Kennung — `xcodebuild -destination` und `devicectl`
verlangen verschiedene, was ohne die Zeile aus `xctrace` zu „Unable to find a
device matching the provided destination" führt. Der erste echte Lauf ist der
auf dem Mac. Sonst unverändert: 196 Tests in PulseCore, 84 Prüfungen des
Klick-Dummys._

---

## 0.40.1 — 2026-08-11

**Zwei Oberflächenprüfungen aus 0.40.0 suchten am falschen Ort und meldeten
„fehlt", wo nichts fehlte.**

Der Lauf zu 0.40.0 war rot: 26 von 28 Prüfungen grün, App-Build und alle 22
Bildschirmfotos in Ordnung, aber `testThePurchasePagePromisesOnlyWhatExists`
und `testTheReportIsWatermarkedAndTheExportNeverCosts` fielen. Beide Male lag
es an der Prüfung, nicht an der App — und beide Male ist die Ursache dieselbe:
Die Prüfung verlangte einen Text so, wie er im Quelltext steht, statt so, wie
er beim Nutzer ankommt.

### Behoben

- Die Kaufseite suchte den Absatz `Dauerhaft kostenlos` wortgetreu. Abschnitts-
  titel tragen `pulseSectionLabel()` und damit `textCase(.uppercase)`; auf dem
  Schirm heißt der Absatz `DAUERHAFT KOSTENLOS`. Die Prüfung vergleicht jetzt
  ohne Rücksicht auf Groß- und Kleinschreibung. Unbemerkt geblieben hätte der
  Fehler nichts kaputt gemacht, aber die Prüfung, die verhindert, dass die
  Kaufseite Foto-Belege oder Siri-Kurzbefehle verspricht, lief wegen des
  Abbruchs davor **nie** — sie hätte ein falsches Verkaufsversprechen bis in
  die Einreichung durchgelassen.
- Die Prüfung des Wasserzeichens hielt sich für den Beleg, dass sich der
  Bericht ohne Kauf öffnen lässt, an `Verbrauchsbericht` — das ist aber schon
  der Titel der Navigationsleiste und steht da, bevor irgendetwas aufgebaut
  ist. Die Zusicherung war damit erfüllt, ohne etwas zu prüfen; anschließend
  fehlte der Hinweis zu Recht, weil ohne Vorschau keiner existiert. Sie tippt
  jetzt „Bericht erstellen" an und prüft die Zusammenfassung des fertigen
  Dokuments.
- Denselben Hinweis suchte sie unter den Texten. Er fasst sich für VoiceOver zu
  einem Element zusammen (`accessibilityElement(children: .ignore)`) und führt
  angetippt zur Freischaltung, ist also ein **Knopf**. Über `staticTexts` war
  er nicht zu finden, obwohl er sichtbar dastand.

### Hinzugefügt

- `beschriftungen(in:)` in den Oberflächenprüfungen: Findet eine Prüfung ein
  Element nicht, steht in der Begründung, was stattdessen auf dem Schirm steht —
  Texte und Knöpfe getrennt gekennzeichnet. Beide Fehlschläge oben hätten damit
  einen Lauf statt zwei gekostet. Die Lehre steht seit 0.33.4 in
  `docs/08-baukasten.md` und galt bisher nur für Zahlen, nicht für
  Beschriftungen.

_196 Tests in PulseCore, alle grün. 84 Prüfungen des Klick-Dummys in Hell und
Dunkel. Die Oberflächenprüfungen brauchen einen Mac und laufen in der CI — am
Prototyp und am Rechenkern hat sich nichts geändert._

---

## 0.40.0 — 2026-08-11

**Aus einem Kauf über 14,99 € werden vier über zwei bis vier Euro. Und der
Bericht wird nicht mehr gesperrt, sondern gestempelt.**

Ein einzelner Kauf über fünfzehn Euro ist eine Entscheidung, die man vertagt —
und vertagte Entscheidungen werden nie getroffen. Drei Euro für die eine Sache,
die gerade fehlt, sind keine Entscheidung, sondern ein Tipp.

### Neu: fünf Produkte statt eines

| Was | Preis |
|---|---|
| Unbegrenzt viele Zähler | 2,99 € |
| Tag- und Nachtstrom, Einspeisung | 2,99 € |
| Kosten und Preise (mit Abschlagsvergleich und Jahresvorschau) | 3,99 € |
| Bericht ohne Wasserzeichen | 2,99 € |
| **Alles freischalten** | **9,99 €** — rund 23 % günstiger |

Abschlagsvergleich und Jahresvorschau sind **kein** eigenes Produkt: Ohne
Preise können sie nicht rechnen, und etwas zu verkaufen, das ohne einen zweiten
Kauf nichts tut, wäre eine Falle.

`Entitlement` ist deshalb eine **Menge** und kein Schalter — „gekauft oder
nicht" ließe sich nicht mehr beantworten, ohne zu fragen *was*. Käufe werden
zusammengelegt und nie ersetzt: Käme vom Vermittler nur das eben Gekaufte
zurück, verlöre der Nutzer bei jedem weiteren Kauf still alle vorherigen.

### Neu: ein Kaufblatt je Funktion, kein Laden

Gekauft wird dort, wo etwas fehlt. Wer am dritten Zähler steht, bekommt den
dritten Zähler angeboten — mit einem Preis und einem Knopf. Das Bündel steht
als eine Zeile darunter, mit der ausgerechneten Ersparnis; ein eigener Schirm
mit allen Produkten wäre ein Ort, den niemand aufsucht.

An den Sperren steht jetzt der **Preis** statt des Wortes „Pro". Ein Wort, das
nichts kostet, weckt die Erwartung eines großen Kaufs.

### Neu: Der Bericht ist nie gesperrt

Ansehen, blättern und drucken kann ihn jeder. Ungekauft liegt quer über jeder
Seite „PulseMeter · Vorschau" — blass genug, dass die Zahlen darunter lesbar
bleiben, deutlich genug, dass ein Empfänger es sieht. Eine Prüfung im
Klick-Dummy misst genau das: Wasserzeichen vorhanden **und** 3261 Zeichen
Inhalt weiter lesbar. Ein Wasserzeichen, das den Bericht unbrauchbar macht,
wäre eine Sperre mit Umweg — dann wäre eine Sperre ehrlicher.

Wer nur prüfen will, ob die Jahresabrechnung stimmt, zahlt nichts. Bezahlt wird
für das, was man weitergibt. Nach dem Kauf wird das PDF neu geschrieben — sonst
trüge die Datei auf der Platte weiter den Schriftzug, für den gerade bezahlt
wurde.

### Der CSV-Export bleibt kostenlos

Er stand ausdrücklich zur Entscheidung — drei Euro — und wurde verneint. Der
freie Export ist Produktprinzip 5 und das stärkste Argument gegen die Sorge
„was, wenn die App eingestellt wird": genau die Sorge, die Menschen bei Excel
hält. Zwei Prüfungen halten fest, dass in **keinem** Produkt das Wort Export,
CSV oder Tabelle vorkommt.

### Geändert

- `docs/04-monetarisierung.md` und `docs/09-appstore.md` tragen das neue
  Modell, samt der fünf Produktkennungen für App Store Connect. Sie dürfen sich
  nie ändern: Ein umbenanntes Produkt ist für jeden Käufer ein verlorener Kauf.
- Ein Abo bleibt für Vermieter reserviert und wird in keinem Text angedeutet.

_Geprüft: 196 Prüfungen in `PulseCore` (7 neu), 84 im Klick-Dummy (10 neu),
Syntax aller iOS-Quellen. Die Oberflächenprüfungen zum Kauf sind auf das neue
Modell umgeschrieben._

---

## 0.39.0 — 2026-08-11

**Am Preisfeld stand nicht, dass es Bruttopreise will. Der Fehler daraus wäre
niemandem aufgefallen — bis zur Jahresabrechnung.**

`Tariff.pricePerUnit` ist im Modell seit jeher als **brutto** dokumentiert. Auf
dem Schirm hieß das Feld nur „Arbeitspreis · €/kWh". Auf einer deutschen
Rechnung steht der **Netto**-Arbeitspreis oft größer und weiter oben als der
Bruttopreis; wer ihn abschreibt, bekommt dauerhaft rund ein Fünftel zu niedrige
Kosten.

Nachgerechnet: 3000 kWh zu 0,34 € brutto sind 1020 €. Dieselbe Zahl netto
(0,2857 €) ergibt 857 € — **163 € zu wenig**, ein Jahr lang. Und die App kann
es nicht bemerken: Aus einer Zahl allein lässt sich nicht erkennen, ob Steuer
darin steckt.

### Behoben

- **Arbeitspreis und Grundpreis heißen jetzt „(brutto)"** — in der sichtbaren
  Beschriftung und damit auch in der, die VoiceOver beim Betreten des Feldes
  vorliest. Am Feld und nicht nur in der Fußzeile: Wer den Preis eintippt, hat
  die Fußzeile schon hinter sich.
- Die Fußzeile sagt zusätzlich, woran man den falschen Wert erkennt — der
  Nettopreis steht auf der Rechnung meist daneben und ist rund ein Fünftel
  kleiner.
- Die **Einspeisevergütung** bekommt den Zusatz bewusst **nicht**: Sie ist für
  private Anlagen in aller Regel ein Nettobetrag ohne Umsatzsteuer, und
  „brutto" wäre dort die falsche Ansage.
- **Der Kostenbetrag trägt jetzt sein „≈".** Der Rechenkern reicht die
  Verlässlichkeit vom Verbrauch bis in den Betrag durch — die Übersicht ließ
  sie beim Anzeigen fallen. Die Menge war als geschätzt gekennzeichnet, der
  Euro-Betrag daneben nicht, obwohl er dieselbe Unsicherheit erbt
  (Produktprinzip 7).

### Was dabei sonst am Kostenkonzept auffiel

Nicht behoben, weil es erst eine echte Rechnung zu klären gilt:

- **Der Grundpreis wird nach Tagen verteilt, nicht nach Monaten.**
  `monthlyBasePrice × 12 ÷ Tage des Jahres × Tage des Abschnitts`. Übers Jahr
  exakt; im Februar 11,88 € statt 12,90 € (**−8 %**), im Januar 13,15 €
  (+1,9 %). Ob das falsch ist, hängt am Versorger — viele rechnen den
  Grundpreis bei Teilzeiträumen ebenfalls tagesanteilig ab. Steht auf der
  Rechnung des Gründers und gehört in die zwei Wochen Eigennutzung.
- `dailyBasePrice` nimmt die Jahreslänge aus `range.start.year`. Ein
  Abrechnungsjahr, das ins Schaltjahr läuft, rechnet durchgehend mit 365 Tagen
  — rund 0,3 %.
- Zwei Tarife mit demselben Starttag: Der ältere fällt still weg. Ein
  plausibler Eingabefehler ohne Warnung.

_Geprüft: 189 Prüfungen in `PulseCore`, 74 im Klick-Dummy, Syntax aller
iOS-Quellen. Eine neue Oberflächenprüfung hält fest, dass der Hinweis am Feld
steht — im Klick-Dummy steht er wortgleich._

---

## 0.38.0 — 2026-08-10

**Die Hochrechnung sagte einem Gaskunden im ersten Jahr am 1. Februar das
Doppelte voraus. Gemessen, nicht vermutet — und behoben.**

Die Vorschau aufs Jahresende ist die Zahl, für die dieses Produkt existiert.
Sie beruhte bisher auf zwei Verfahren: dem eigenen Vorjahr, wenn eines
vollständig vorlag, und sonst einer gleichmäßigen Fortschreibung des
Tagesschnitts. Der zweite Fall trifft **jeden neuen Nutzer** — und bei allem,
was mit der Jahreszeit schwankt, ist er grob falsch.

### Was die Messung ergab

Ein Gaszähler, erstes Jahr, gleichmäßig fortgeschrieben:

| Stand | Fehler gegenüber dem wahren Jahreswert |
|---|---|
| 1. Februar | **+100 %** |
| 1. April | +80 % |
| 1. Juni | +34 % |
| 1. Oktober | −15 % |

Bei Haushaltsstrom sind es +22 % im Februar. Aus „+100 % Verbrauch" wird im
Abschlagsvergleich eine erfundene Nachzahlung von mehreren hundert Euro — in
der Jahreszeit, in der jemand die App installiert.

### Neu: Referenzprofile aus veröffentlichten Quellen

`SeasonalProfile` in `PulseCore` weiß, wie sich ein Jahresverbrauch typisch auf
die Monate verteilt. Die Zahlen sind **nicht ausgedacht** — das ist der Punkt:

- **Heizen** (Gas, Fernwärme, Heizöl): Gradtagszahlen nach **VDI 2067**, der
  Maßstab, nach dem in Deutschland Heizkosten auf Monate verteilt werden, aus
  zwanzig Jahren Temperaturmessungen. Darunter 18 % Warmwasser gleichmäßig
  verteilt, denn wer mit Gas auch das Wasser wärmt, verbraucht im Juli nicht
  nichts. Januar zu Juli steht damit bei 5,9 zu 1.
- **Haushaltsstrom**: aus dem **Standardlastprofil H0** (VDEW/BDEW) —
  Winter 43,75 %, Sommer 28,77 %, Übergangszeit 27,48 %, umgerechnet auf
  Monate. Januar zu Juli: 1,34 zu 1.
- **Photovoltaik**: aus dem veröffentlichten Jahresverlauf des spezifischen
  Ertrags in Deutschland. Juni zu Dezember: 8,9 zu 1 — **gegenläufig** zum
  Verbrauch, weshalb eine Einspeisung nie mit einem Bezugsprofil gerechnet
  werden darf.
- **Wasser, Warmwasser, Regenwasser, Betriebsstunden**: **kein** Profil. Es
  gibt keine belastbare Quelle, der Verbrauch schwankt kaum, und ein
  erfundenes Profil wäre schlimmer als gar keines. Hier bleibt es bei der
  gleichmäßigen Fortschreibung — und die App sagt das.

### Neu: eine Rangfolge statt zweier Fälle

1. **Mehrere eigene Jahre** — die Form wird über bis zu drei Vorjahre
   gemittelt. Ein Ausreißer (Umbau, Sommer im Ausland) zieht die Form dann
   nicht mehr allein.
2. **Das eigene Vorjahr** — wie bisher.
3. **Das Referenzprofil** — neu, und der Fall, der die 100 % beseitigt.
4. **Gleichmäßig** — nur noch dort, wo es richtig ist.

Gemittelt werden die **Anteile**, nicht die Mengen: Die Vorjahre steuern die
Form bei, das Niveau kommt ausschließlich aus dem laufenden Jahr.

### Neu: Die App sagt endlich, worauf die Zahl beruht

Auf der Karte stand „≈ 71,63 € Guthaben" und sonst nichts. Ob dahinter das
eigene Vorjahr steckte oder eine Fortschreibung, die um 100 % danebenliegt,
war der Zahl nicht anzusehen — bei der folgenreichsten Zahl der App und
entgegen Produktprinzip 7.

`PrepaymentOutlook` führt die Methode jetzt mit, und darunter steht ein Satz:
„Hochgerechnet nach dem Verlauf deines Vorjahres" oder „…nach einem typischen
Jahresverlauf, weil noch kein eigenes Jahr vorliegt". Bei mehreren Zählwerken
wird die **schwächste** Grundlage genannt, nicht die schmeichelhafteste.

**Der Klick-Dummy konnte das längst** — er zeigte die Grundlage im
Erklärungsblatt, die App gar nicht. Das war ein Regel-2-Verstoß, und er ist
jetzt in beide Richtungen aufgelöst: Der Entwurf hat die Rangfolge und die
Profile ebenfalls bekommen.

### Was sich an bestehenden Zahlen ändert

Die Prüfungen zum Abschlagsvergleich tragen neue Erwartungswerte, alle von
Hand nachgerechnet. Zwei Beispiele:

- Strom, 900 kWh bis zum 1. April: vorher 1095 € erwartete Kosten, jetzt
  **976,46 €**. Januar bis März sind 27,65 % des Jahres, nicht 24,7 %.
- Ein Zweirichtungszähler: vorher 422,81 €, jetzt **342,09 €**. Der
  Unterschied kommt fast vollständig aus der Einspeisung — gleichmäßig
  fortgeschrieben hätte die Anlage im Sommer so weitergeliefert wie im Winter.

### Zur Ehrlichkeit dieser Messung

Die erste Fassung dieser Untersuchung hat gegen ein Verbrauchsprofil gemessen,
das ich mir selbst ausgedacht hatte — das beweist nur, dass der Rechenkern
seine eigene Kurve wiederfindet. Der Einwand kam vom Gründer und war richtig.
Die Profile stammen deshalb aus veröffentlichten Quellen, und die Prüfungen
messen die Vorhersagegüte gegen ein Jahr, das den Profilen ausdrücklich
**nicht** folgt.

Was damit **nicht** belegt ist: wie gut die Profile zu einem konkreten
Haushalt passen. Das zeigt erst ein Jahr eigener Ablesungen — und genau
deshalb schlägt die eigene Historie das Profil, sobald sie vorliegt.

_Geprüft: 189 Prüfungen in `PulseCore` (17 neu), 74 im Klick-Dummy (14 neu),
Syntax aller iOS-Quellen. Die Zahlen der Beispiele oben sind von Hand
nachgerechnet und stehen als Erwartungswerte in den Prüfungen._

---

## 0.37.1 — 2026-08-10

**Meine Erklärung aus 0.34.1 war falsch. Der Tipp ging verloren, nicht die
Zeit.**

`testAddingAMeterFromTheMetersTab` ist zum zweiten Mal gefallen — in 0.34.0
und jetzt in 0.36.0. Beide Male mit derselben Meldung („Die Schaltfläche zum
Anlegen fehlt"), beide Male als **erste** Prüfung des Laufs, beide Male nach
knapp einer Minute, und beide Male war derselbe Commit im nächsten Anlauf
grün.

In 0.34.1 hatte ich daraus geschlossen, es sei zu kurz gewartet, und alle 39
Wartezeiten von fünf auf zehn Sekunden gesetzt. Das hat den Fehler nicht
behoben, weil er nicht dort saß.

### Was das Protokoll wirklich sagt

Lauf 31418692022, Zeitstempel im Klartext: Der Start brauchte **14 Sekunden**
— `Setting up automation session` allein 7,85 s, `Wait for app to idle`
weitere 3 s. Der Tipp auf den Tab „Zähler" fiel in genau dieses Fenster und
**ging verloren**. Die App blieb auf der Übersicht stehen.

Danach hätte auch eine Wartezeit von einer Minute nichts gefunden: Der Knopf
war nicht langsam, er war auf einem anderen Schirm. Eine längere Wartezeit
kann einen verlorenen Tipp nicht nachholen.

### Behoben

Alle Tabwechsel laufen jetzt über einen Helfer, der **nachprüft, dass der
Wechsel stattgefunden hat**, und den Tipp einmal wiederholt, wenn nicht. Die
Gegenprobe fragt die **Navigationsleiste** ab, nicht einen Text: Der Tab trägt
denselben Namen wie der Schirm, und über `staticTexts` hätte die Prüfung sich
selbst bestätigen können, ohne dass etwas gewechselt wäre.

Kommt der Schirm auch beim zweiten Versuch nicht, ist es ein echter Fehler —
und die Meldung sagt es als solchen.

### Was daraus zu lernen ist

Das steht so schon in `docs/08-baukasten.md` und ist hier zum dritten Mal
bestätigt: **Nach dem zweiten Fehlversuch nicht weiterraten, sondern messen.**
Die Zeitstempel standen im Protokoll jedes gefallenen Laufs — ich hatte sie
beim ersten Mal nur nicht gelesen, sondern eine plausible Erklärung gebaut.
Plausibel und richtig sind nicht dasselbe.

_Geprüft: 172 Prüfungen in `PulseCore`, 60 im Klick-Dummy, Syntax aller
iOS-Quellen. Ob der Helfer trägt, zeigt erst die CI — und richtig belegt ist
er erst, wenn mehrere Läufe hintereinander grün bleiben._

---

## 0.37.0 — 2026-08-10

**Material für den App Store: Icon, Texte, Bilder, Datenschutzerklärung — und
eine Einstellung, die eine Ablehnung gekostet hätte.**

`docs/07-v1-plan.md` nennt das App-Store-Material seit jeher „das, was am
meisten unterschätzt wird" und führte es als **nicht angefangen**. Es ist
jetzt fertig, so weit es ohne Apple-Konto geht.

### Neu

- **Ein App-Icon.** Bis heute gab es im ganzen Repository keinen
  Asset-Katalog — ohne Icon nimmt Apple nichts entgegen. Die Zeichnung ist der
  Name: ein Bogen als Skala eines Messwerks, ein Puls als Linie darin.
  Bernstein auf warmem Dunkel, weil die Kategorie blau und grün ist.

  Erzeugt wird es aus `scripts/icon.mjs` in den drei Fassungen, die iOS 18
  verlangt — hell, dunkel, getönt. Ein Skript und keine Bilddateien von Hand:
  Drei Fassungen laufen auseinander, sobald sich eine Farbe ändert, und dann
  steht im Store ein anderes Zeichen als auf dem Gerät.

- **`docs/09-appstore.md`** — jedes Textfeld fertig zum Einfügen, mit
  Zeichenzahl und Begründung: Name, Untertitel, Werbetext, Schlagworte,
  Beschreibung, Versionshinweise, Kategorien, Altersfreigabe, die Antworten
  des Datenschutz-Fragebogens und die Notizen für die Prüfung.

- **`docs/datenschutz.md`** — die Datenschutzerklärung, die als erreichbare
  URL Pflicht ist. Sie kann kurz sein, weil die Architektur es hergibt: kein
  Konto, kein Tracking, keine Server. Nur Name und Anschrift des
  Verantwortlichen fehlen; die kann niemand außer dem Gründer eintragen.

- **`scripts/store-shots.mjs`** — setzt die Simulator-Bilder mit Überschrift
  und Gerätrahmen auf 1320 × 2868, das Maß für 6,9 Zoll. Ein Skript, weil sich
  die Bilder bei jeder Oberflächenänderung ändern: Von Hand gesetzte müsste
  man jedes Mal neu setzen, also setzt man sie irgendwann nicht mehr neu — und
  im Store steht dann eine App, die es so nicht mehr gibt.

- Der Klick-Dummy trägt das Zeichen jetzt im Kopf.

### Behoben

- **Die App war als Universal-App eingestellt.** `TARGETED_DEVICE_FAMILY`
  stand auf `"1,2"`, also iPhone **und** iPad. Damit hätte Apple zur
  Einreichung iPad-Bilder verlangt und die App auf einem iPad geprüft, für das
  sie nicht gebaut ist: Die Ansichten sind für eine Hand gemacht, ein iPad
  bekäme eine auf 13 Zoll gezogene Telefonoberfläche und eine schlechte
  Bewertung dafür. iPad steht in `docs/07-v1-plan.md` für 1.1 — dann richtig.
  Jetzt `"1"`, und der iPad-Block aus `Info.plist` ist mit weg.

### Zur Vorsicht vermerkt

Das sechste Store-Bild zeigt die Kaufseite, und dort steht heute „Der Kauf
steht bereit, sobald PulseMeter im App Store ist". Im Store selbst wäre dieser
Satz absurd — und er stünde ausgerechnet auf dem Bild, das verkaufen soll.
Nach dem Einbau von StoreKit sind die Bilder neu zu erzeugen; der Hinweis
steht in `09-appstore.md` an der Stelle, an der jemand danach sucht.

_Geprüft: 172 Prüfungen in `PulseCore`, 60 im Klick-Dummy, Syntax aller
iOS-Quellen. Icon und Store-Bilder erzeugt und angesehen. Der Xcode-Build
läuft in der CI — dort zeigt sich auch, ob der Asset-Katalog richtig
eingebunden ist._

---

## 0.36.0 — 2026-08-10

**Beim Nachsehen für die Barrierefreiheit fiel eine Taste auf, die nichts tat
— mitten auf dem wichtigsten Schirm der App.**

### Behoben

- **Der Ziffernblock hatte eine tote Taste.** Ein Kamerasymbol als Platzhalter
  für Belegfotos, für VoiceOver angekündigt als „Belegfoto"; angetippt
  passierte nichts (`case .photo: break`). Wer sie sieht, probiert es einmal
  und lässt es. Wer sie nur hört, hat einen Knopf gefunden, der eine Funktion
  verspricht, die es nicht gibt — eine Sackgasse im Erfassungsschirm, und
  Produktprinzip 4 schließt genau die aus.

  Belegfotos sind für 1.0 gestrichen (`docs/07-v1-plan.md`). Die Taste kommt
  mit ihnen zurück; bis dahin hält eine leere Fläche den Platz, damit später
  nichts wandert. Entfernt in App **und** Entwurf, mit je einer Prüfung
  dagegen.

- **Das Widget hatte keine einzige Zugriffsangabe.** Es ist der eine Teil der
  App, den ein Nutzer sieht, **ohne** die App zu öffnen — für jemanden mit
  VoiceOver war es damit der eine Teil, den es nicht gab. Name, Zeile, Zahl und
  Einheit standen als vier Fundstücke nebeneinander, und „kWh" ohne die Zahl
  davor sagt nichts.

  Jetzt ein Satz je Zähler: „Gas. Seit 96 Tagen fällig. ungefähr 1181
  Kubikmeter." Gebaut wird er in `PulseCore` und ist dort ohne Simulator
  geprüft — samt der Regel, dass Fälligkeit vor dem Zeitraum kommt. Die
  sichtbare Zeile stammt seither aus derselben Quelle; zwei Fassungen hätten
  früher oder später verschiedene Zeilen gewählt, und die gesprochene sieht
  niemand nach.

- **„≈" wird zu „ungefähr".** Das Zeichen liest je nach Stimme „Ungefähr
  gleich" oder gar nichts. Es ist aber keine Zierde, sondern Produktprinzip 7:
  Die Zahl beruht auf einer Schätzung, und das muss mitgesprochen werden.

- **Eine volle Anzeige meldet sich.** Wer sie sieht, merkt am Ausbleiben der
  Ziffer, dass nichts mehr geht. Wer sie nicht sieht, hörte beim Tippen nur den
  Namen der Taste — „7" — und hielt den Wert für angekommen. Eine stille Grenze
  ist für ihn eine falsche Zahl.

- **Der Ziffernblock wächst jetzt mit der Schrift.** Feste 52 und 26 Punkt
  ließen ihn auf der größten Stufe als einzigen Teil des Schirms unverändert
  klein — ausgerechnet den Teil, der getroffen werden muss. Gedeckelt, weil
  drei ungebremste Ziffern nebeneinander breiter wären als der Schirm.

- Kleineres: Das Zählwerk sagt, wie viele Stellen es hat; der gesperrte
  Sicherungsknopf sagt, was ihm fehlt, statt nur „abgeblendet" zu sein.

_Geprüft: 172 Prüfungen in `PulseCore` (6 neu), 60 im Klick-Dummy (4 neu),
Syntax aller iOS-Quellen. Zwei neue Oberflächenprüfungen — die tote Taste und
die Ansage des Zählwerks — laufen in der CI._

---

## 0.35.0 — 2026-08-10

**Die Grenze zwischen Kostenlos und Pro stand bisher nur im Dokument. Jetzt
steht sie im Code — und sie nimmt niemandem etwas weg.**

Bis heute war in PulseMeter alles kostenlos. `docs/04-monetarisierung.md`
beschreibt seit dem 4. August zwei Zähler frei und den Rest hinter einem
Einmalkauf; in der App gab es dazu **keine einzige Zeile** — kein `isPro`,
keine Grenze, keine Sperre. Der Weg zu 1.0 führte das als „Paywall, StoreKit 2,
Kaufwiederherstellung", also als den Verkaufsteil. Der Sperrteil fehlte
vollständig und ist der größere von beiden.

### Neu

- **`AccessPolicy` in `PulseCore`** — die Grenze an einer Stelle, ohne
  Simulator prüfbar. `ProFeature` zählt die sechs Leistungen auf und trägt
  ihre Beschriftungen selbst; vorher standen dieselben Wörter in drei
  Fassungen (Dokument, App, Entwurf), und drei Fassungen laufen auseinander.
- **Vier Sperren in der App:** der dritte Zähler, das zweite Zählwerk (Tag- und
  Nachtstrom, Einspeisung), der Abschnitt Preise, der PDF-Bericht.
- **Eine Kaufseite**, die erklärt statt zu drängen: kein Countdown, keine
  durchgestrichenen Preise. Die Leistung, an der es gerade hakte, steht zuerst
  — wer am dritten Zähler hängt, will nicht über PDF-Berichte lesen. Daneben
  ein Absatz darüber, was **dauerhaft kostenlos** bleibt.
- **`PurchaseGateway`** als Protokoll mit einer ehrlichen Fassung ohne Kauf.
  Solange die App nicht im Store ist, zeigt die Kaufseite **keinen** Knopf, der
  ins Leere greift, sondern den Grund. StoreKit ist damit eine Datei und kein
  Umbau — es braucht nur noch das Apple Developer Program.
- **Zwei neue Bildschirmfotos** in Hell und Dunkel: die Grenze am
  Zähler-Schirm und die Kaufseite. Beide gehen später in den App Store, und
  beide sind die einzige Stelle, an der sich sehen lässt, ob eine Sperre
  einladend wirkt oder nach Erpressung aussieht.

### Die Regel, auf die es ankommt

**Gesperrt ist das Anlegen, nie das Benutzen.** Was schon da ist, bleibt
vollständig zugänglich: Ein Zähler mit Nachtstrom behält seinen Schalter, ein
Zähler mit Preisen behält seinen Preisabschnitt, alle Ablesungen bleiben
erfassbar, der Export bleibt offen.

Ein Bestand über der Grenze ist real — über iCloud, über die Beispieldaten,
über einen Kauf auf einem anderen Gerät, der noch nicht angekommen ist. Nähme
die App dem Nutzer dann seine eigenen Zahlen weg, wäre das ein Vertrauensbruch
und kein Verkaufsargument (Produktprinzip 5). Dass Pro ein **Einmalkauf** ist
und nicht abläuft, macht die Regel obendrein billig: Aus Pro kann niemand
herausfallen.

Der Export bleibt kostenlos, und zwei Prüfungen halten das fest — eine im
Rechenkern gegen die Aufzählung selbst, eine an der fertigen Oberfläche. Sie
sind die Bremse gegen den Tag, an dem jemand ihn „auch noch" hinter die
Schranke zieht.

### Geändert

- Die Bildschirmfotos und alle Oberflächenprüfungen starten mit `-pulse-pro`.
  Die Beispieldaten liegen vollständig über der Grenze — vier Zähler, Preise,
  Abschlag, Einspeisung, zwei Arbeitspreise —, und ohne den Schalter zeigten
  sämtliche Bilder eine App voller Schlösser.
- Der Klick-Dummy hat die Grenze mitbekommen, samt einem Schalter, der beide
  Seiten nebeneinanderstellt. Er ist im Entwurf sichtbar als solcher
  gekennzeichnet — in der App gibt es ihn nicht.
- `docs/07-v1-plan.md` nennt jetzt sechs offene Punkte, die dort fehlten: die
  Sperrlogik (mit dieser Version erledigt), das abgeschaltete CloudKit, den
  fehlenden Asset-Katalog, das fehlende Privacy-Manifest, die fehlende
  Berechtigungsdatei und die Barrierefreiheit von Widget und Erfassung.

### Berichtigt

- Die Behauptung, Dynamic Type sei „nie angesehen worden", war falsch. Seit
  0.27.0 fotografiert `scripts/run.sh` jeden Lauf zusätzlich in der größten
  Schriftstufe, hell und dunkel. Nachgesehen statt weitergeschrieben.

_Geprüft: 166 Prüfungen in `PulseCore` (11 neu), 56 im Klick-Dummy (12 neu),
Syntax aller iOS-Quellen. Vier neue Oberflächenprüfungen für den Zustand vor
dem Kauf — App-Build und Simulator laufen in der CI, nicht in diesem
Container._

---

## 0.34.1 — 2026-08-10

**Eine Prüfung, die zufällig fällt, ist schlimmer als keine.**

### Behoben
- Der Lauf zu 0.34.0 meldete `testAddingAMeterFromTheMetersTab` als gefallen —
  „Die Schaltfläche zum Anlegen fehlt", nach 55 Sekunden statt der üblichen
  zwanzig. Der Knopf war von 0.34.0 gar nicht berührt worden. Statt eine achte
  Vermutung zu bauen, ist **derselbe Commit ein zweites Mal gelaufen**: grün.
  Es lag nicht am Code, sondern an der Uhr.
- Die Oberflächenprüfungen laufen auf **drei geklonten Simulatoren
  gleichzeitig**. Unter dieser Last braucht ein Tabwechsel gelegentlich länger
  als die fest verdrahteten fünf Sekunden. Alle 39 dieser Wartezeiten laufen
  jetzt über eine benannte Konstante mit **zehn** Sekunden und der Begründung
  daneben.

  Der Preis ist gering: Länger gewartet wird nur dort, wo etwas **wirklich**
  fehlt — und dann stehen fünf Sekunden mehr gegen eine verlorene
  Viertelstunde. Der Nutzen ist groß: Ein roter Lauf bedeutet wieder, dass
  etwas kaputt ist. Eine Prüfung, der man nicht glaubt, prüft nichts.

### Bestätigt
- `testCreatingADualTariffMeterAsksForBothNumbers` läuft durch. Die Prüfung,
  an der sieben Vermutungen und ein halber Tag hingen, ist grün — und damit ist
  der Doppeltarif-Anlegefluss von Ende zu Ende belegt: Schalter umlegen, beide
  Preise eintragen, sichern, Karte finden, beide Zählwerke erfassen.
- **21 von 21** Oberflächenprüfungen im Wiederholungslauf, 155 in `PulseCore`.
  0.34.0 ist damit auf `main`.

_155 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `AppUITests` parsen sauber. Ob die längere Wartezeit das Flattern
tatsächlich beseitigt, lässt sich nur über mehrere Läufe belegen — dieser eine
zeigt nur, dass nichts anderes kaputtgegangen ist._

---

## 0.34.0 — 2026-08-10

**Der letzte Schirm ohne Barrierefreiheit ist durch — und elf Symbole hören
auf, ihren Dateinamen vorzulesen.**

### Hinzugefügt
- `MeasurementUnit.spokenName` in `PulseCore`: „Kilowattstunden" statt „kWh",
  „Kubikmeter" statt „m³". VoiceOver liest `m³` als „m hoch drei" und `kWh`
  buchstabenweise — beides ist keine Einheit, sondern ein Rätsel. Die Schirme
  hatten begonnen, sich eigene gesprochene Formen zu basteln; jetzt steht sie
  einmal an der Einheit selbst, ohne Xcode prüfbar.
- `testEveryUnitCanBeSpoken` geht über `allCases` und fällt, sobald eine neue
  Einheit ohne gesprochenen Namen dazukommt — oder wenn der „gesprochene" Name
  nur das Kürzel wiederholt. **155 Prüfungen** in `PulseCore`.

### Behoben
- **Der Zählerwechsel hatte als einziger Schirm überhaupt keine
  Barrierefreiheits-Arbeit gesehen.** Für VoiceOver waren „Endstand alter
  Zähler", das Eingabefeld und die Einheit **drei getrennte Stationen** — wer
  das Feld erreicht, hat die Beschriftung hinter sich und weiß nicht mehr,
  welche der beiden Zahlen er eintippt. Bei einem Zählerwechsel sind das die
  zwei Zahlen, an denen der gesamte weitere Verbrauch hängt. Beschriftung und
  Einheit hängen jetzt am Feld, wie in `MetersView` seit 0.32.0.
- Das Feld für die Gerätenummer hieß für VoiceOver **„optional"** — der
  Platzhalter wurde zum Namen, und wofür das Feld da ist, stand nur daneben.
- Die Fehlermeldung im Zählerwechsel war **roter Text und sonst nichts**. Farbe
  allein ist keine Aussage: nicht für VoiceOver, und nicht für die rund acht
  Prozent Männer mit einer Rotschwäche. Sie läuft jetzt über `StatusBanner`,
  wie überall sonst in der App.
- **Elf Symbolbilder** in Übersicht, Verlauf, Zählerverwaltung und Bericht
  waren für VoiceOver sichtbar und wurden als Symbolname vorgelesen —
  „chevron.right", „gauge.medium". Alle sind Zierrat: Die Pfeile stehen an
  Zeilen, die ohnehin als Taste angesagt werden, das Häkchen im Bericht wird
  bereits über „ausgewählt" mitgeteilt. Sie sind jetzt ausgeblendet.
- Weil der Pfeil an der Archiv-Klappe damit verschwindet, sagt der Knopf selbst,
  ob sie offen ist („ausgeklappt" / „eingeklappt") und was ein Doppeltipp
  bewirkt. Vorher war der Pfeil die einzige Auskunft darüber.

_155 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Alle iOS-Quellen und `AppUITests` parsen sauber. Die Wirkung auf
VoiceOver selbst lässt sich hier nicht messen — dafür braucht es ein Gerät oder
den Simulator mit eingeschaltetem VoiceOver; die Änderungen sind jede für sich
begründet und im Code vermerkt._

---

## 0.33.7 — 2026-08-10

**Eine Gesamtübersicht ganz oben in der Roadmap — und eine Falle fürs
Store-Material entschärft.**

### Hinzugefügt
- `docs/05-roadmap.md` beginnt jetzt mit einer **Gesamtübersicht auf einen
  Blick**: was gebaut und grün geprüft ist, was für 1.0 offen ist und bei wem
  es liegt, und was in 1.1, 1.2, 2.0 oder nie kommt. Der Inhalt stand vorher
  verteilt über vier Dokumente — wer sich orientieren wollte, musste alle vier
  lesen und selbst zusammensetzen.

### Behoben
- **Foto-Belege und Siri-Kurzbefehle standen weiter in der Pro-Liste**, obwohl
  sie mit 0.32.10 aus 1.0 gestrichen wurden. `04-monetarisierung.md` ist die
  Vorlage fürs Store-Material — von dort wäre beides ungeprüft in die
  Produktbeschreibung gewandert. Ein verkauftes Merkmal, das es nicht gibt, ist
  eine Rückerstattung, eine schlechte Bewertung und im Zweifel eine Ablehnung
  durch die Prüfung. Beide sind jetzt als „erst ab 1.1" gekennzeichnet, mit
  einem ausdrücklichen Hinweis, sie zum Start nicht zu bewerben.

  Dass Pro auch ohne sie trägt, steht daneben: unbegrenzte Zähler und
  Zählwerke, Kosten und Tarife, Abschlagsvergleich, Jahresprognose und der
  PDF-Bericht sind fünf fertige Gründe.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Diese Version ändert nur Dokumente und Versionsnummern._

---

## 0.33.6 — 2026-08-10

**Grün, zusammengeführt, aufgeräumt.**

### Bestätigt
- Der Lauf zu `28a52cf` ist **vollständig grün**: 154 Prüfungen in `PulseCore`,
  **21 von 21** Oberflächenprüfungen, 44 im Klick-Dummy, 18 Screenshots. Damit
  sind 21 Commits von 0.31.0 bis 0.33.5 nach `main` zusammengeführt — Doppeltarif
  in der App, PDF-Bericht, das ganze Werkzeug und drei neue Dokumente.
- Die Messzeile aus 0.33.4 las `breite=400 maßstab=0.673 rahmen=400×566` ab,
  also genau die erwarteten Werte. Damit war belegt: Die Breitenmessung stimmt,
  und der Fehler lag allein im Zuschnitt.

### Entfernt
- Die rote Messzeile in der Berichtsvorschau. Sie hat ihren Zweck erfüllt. Was
  bleibt, ist die Begründung im Code und die Regel in `docs/08-baukasten.md`:
  Nach dem zweiten Fehlversuch nicht weiterraten, sondern die Ansicht ihre
  eigenen Zahlen berichten lassen. Sieben Vermutungen an zwei Fehlern kosteten
  je einen Lauf und klärten nichts; zwei Messungen klärten beides.

### Geändert
- `docs/06-uebergabe.md` neu geschrieben — sie ist eine Momentaufnahme, keine
  Historie. Sie nennt jetzt den grünen Stand auf `main`, die nächsten Schritte
  aus `07-v1-plan.md` und die beiden Zweige, die sich aus der Cloud-Sitzung
  nicht löschen ließen.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Alle iOS-Quellen und `AppUITests` parsen sauber. Die Entfernung der
Messzeile berührt keine Prüfung; der macOS-Lauf auf `main` ist die Gegenprobe._

---

## 0.33.5 — 2026-08-10

**Der Zuschnitt war es: Der Bericht zeigt Inhalt. Und die Erfassung ging nie
auf, weil auf die Karte statt auf ihren Knopf getippt wurde.**

### Bestätigt
- **Der PDF-Bericht trägt Inhalt.** Das Bild aus dem Lauf zu `5f3b9af` zeigt
  sechs Seiten mit Überschriften, Tabellen und Zahlen — zum ersten Mal seit
  0.32.0 überhaupt sichtbar. `alignment: .topLeading` aus 0.33.3 war die
  Ursache: Der Inhalt wurde nicht weggelassen, sondern weggeschnitten.
- Offen bleibt allein der **Maßstab** — die Seiten sind noch etwa ein Sechstel
  zu klein. Die Messzeile aus 0.33.4 liest ihn im nächsten Lauf ab.

### Behoben
- **Die Erfassung öffnete sich nie.** `testCreatingADualTariffMeterAsksForBothNumbers`
  tippte auf die **Karte** des neuen Zählers — die öffnet aber nichts, die
  Erfassung hängt am Knopf „Stand eintragen". Alles Weitere suchte danach
  Zählwerke auf einem Schirm, der noch die Übersicht war. Belegt durch die
  Aufstellung aus 0.33.2: lauter Texte der Übersicht, kein einziger aus der
  Erfassung.

### Geändert
- **Der Knopf „Stand eintragen" sagt jetzt, für welchen Zähler er gilt.**
  Sichtbar bleibt es bei „Stand eintragen" — in der Karte ist das eindeutig,
  der Name steht zwei Zeilen darüber. Für VoiceOver war es das **nicht**: Wer
  vier Zähler hat, fand vier Knöpfe mit demselben Namen und musste sich merken,
  in welcher Karte er gerade steht. Genau die Sackgasse, die Produktprinzip 4
  ausschließt. Aufgefallen ist es einer Prüfung, die den richtigen Knopf nicht
  ansprechen konnte — ein Testproblem, das ein echtes Bedienproblem aufgedeckt
  hat.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Alle iOS-Quellen und `AppUITests` parsen sauber, Zeichenketten in
Ordnung. Die Änderung an der Beschriftung berührt zwei weitere Prüfungen, die
mitgezogen wurden; ob alle greifen, entscheidet der nächste macOS-Lauf._

---

## 0.33.4 — 2026-08-10

**Vier Vermutungen, vier Fehlschläge. Jetzt schreibt die Vorschau ihre eigenen
Zahlen aufs Bild.**

### Angemerkt
- Das Bild aus dem Lauf zu `79a71b2` widerlegt auch die Erklärung aus 0.33.2:
  Die Seiten sind nicht größer geworden, sondern **kleiner** — von rund 95 auf
  rund 60 Punkte Breite. Die Messung an der Bildlaufansicht liefert ebenfalls
  einen falschen Wert, und niemand weiß warum: Der Fühler hängt am Hintergrund
  der `ScrollView`, deren Breite von außen kommt und von nichts abhängt, was
  die Vorschau bestimmt.

| Vermutung | Version | Widerlegt durch |
|---|---|---|
| Vorschau noch nicht fertig | 0.33.1 | 15 statt 4 Sekunden, Bild unverändert |
| Inhalt fehlt | — | Der Text steht nachweislich im Baum |
| Kreisschluss bei der Breitenmessung | 0.33.2 | Seiten wurden **kleiner** |
| Ausrichtung unter `scaleEffect` | 0.33.3 | allein zu wenig |

### Hinzugefügt
- Beim Start mit `-pulse-bericht` steht über den Seiten eine rote Zeile:
  `breite=… maßstab=… rahmen=…×… seiten=…`. Sie erscheint ausschließlich beim
  Bildschirmfoto-Start und nie für einen Nutzer. Damit sagt das nächste Bild
  selbst, welche Zahl falsch ist, statt dass jemand sie errät.

  Der Grund für diesen Schritt steht in `docs/08-baukasten.md` und hat heute
  bereits einmal funktioniert: Beim Doppeltarif-Schalter klärte ein einziger
  Lauf mit Aufstellung mehr als drei Vermutungen davor. Jede weitere Vermutung
  kostet eine Viertelstunde Läuferzeit und bringt nichts.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Alle iOS-Quellen und `AppUITests` parsen sauber. Die Messzeile selbst
ist hier nicht darstellbar — sie braucht den Simulator, und genau dafür ist
sie da._

---

## 0.33.3 — 2026-08-09

**Die Vorschau schnitt ihren eigenen Inhalt weg. Gefunden, weil jemand das Bild
angesehen und die richtige Frage gestellt hat.**

### Behoben
- **Der Verbrauchsbericht zeigte leere Seiten, weil der Inhalt außerhalb des
  Zuschnitts gezeichnet wurde.** `scaleEffect` ändert die **Layoutgröße
  nicht**: Die Seite bleibt 595 × 842 Punkte groß und wird nur kleiner
  gezeichnet. Der Rahmen darunter zentrierte diese unveränderte Box, während ab
  oben links gemalt wird — der sichtbare Inhalt saß dadurch oberhalb und links
  des Zuschnitts und fiel vollständig weg. Übrig blieb der leere Seitenrahmen
  mit Haarlinie. `alignment: .topLeading` am äußeren Rahmen behebt es.

  Zusammen mit dem Kreisschluss aus 0.33.2 verstärkten sich beide Fehler: Je
  kleiner der Maßstab, desto vollständiger der Verlust. Das erklärt, warum die
  Seiten nicht bloß winzig, sondern **restlos leer** aussahen — die Frage, die
  der Gründer beim Ansehen des Bildes stellte und die den Ausschlag gab.

### Hinzugefügt
- `testTheReportCarriesBothTariffsOfADualTariffMeter` prüft jetzt `isHittable`
  statt nur `exists`. Genau diese Prüfung lief grün, während der Bericht leer
  auf dem Schirm stand: Der Text war im Zugänglichkeitsbaum vorhanden und wurde
  trotzdem weggeschnitten. Ein Bericht, den man nicht sehen kann, ist keiner —
  und `exists` allein merkt das nie. Das ist der Test, der den Fehler vorher
  gefangen hätte.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Alle iOS-Quellen und `AppUITests` parsen sauber, Zeichenketten in
Ordnung. Die Behebung selbst braucht einen Simulator und ist hier ungeprüft;
das Bild aus dem nächsten Lauf entscheidet, und es kommt auch bei Rot._

---

## 0.33.2 — 2026-08-09

**Der leere Bericht war ein Kreisschluss in der Vorschau — und der Schalter
sitzt.**

### Behoben
- **Die Vorschau des Verbrauchsberichts zeichnete die Seiten unlesbar klein.**
  `ReportView` maß die verfügbare Breite mit einem `GeometryReader` am
  Hintergrund genau des Stapels, **dessen Breite von den Seiten kommt** — und
  deren Breite kommt aus dieser Messung. Der Maßstab blieb bei einem winzigen
  Wert stehen: sechs schmale, praktisch leere Rahmen in der Mitte des Schirms.
  Gemessen wird jetzt die Bildlaufansicht, deren Breite von außen kommt, und
  `onChange` zieht bei Drehung nach statt nur beim ersten Erscheinen.

  Der Weg dorthin ist die eigentliche Geschichte: Das Bild sah aus wie ein
  leerer Bericht, war aber ein falsch skalierter. Ausgeschlossen wurde es durch
  zwei Messungen — die längere Wartezeit aus 0.33.1 änderte nichts, und
  `testTheReportCarriesBothTariffsOfADualTariffMeter` findet „Arbeitspreis
  Hochtarif" die ganze Zeit im Baum. Das **PDF in der Datei** entsteht über
  einen eigenen Weg und war nie betroffen.

### Bestätigt
- Der Tipper bei 90 % der Breite legt den Schalter um. Belegt, nicht vermutet:
  Der Fehlschlag ist von Zeile 640 auf 727 gewandert, und die Prüfung läuft
  39 statt 21 Sekunden — sie legt den Schalter um, trägt beide Preise ein,
  sichert den Zähler und findet ihn auf der Übersicht.

### Geändert
- Die verbleibende Stelle („Die Erfassung nennt das erste Zählwerk nicht")
  gibt bei einem Fehlschlag alle Texte des Schirms aus, statt eine vierte
  Vermutung zu erzeugen. Ein selbst angelegter Doppeltarifzähler benennt sein
  erstes Zählwerk vermutlich anders als der aus den Beispieldaten — der nächste
  Lauf sagt, wie.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Alle iOS-Quellen und `AppUITests` parsen sauber, Zeichenketten in
Ordnung. Beide Änderungen brauchen einen Simulator und sind hier ungeprüft; das
Bild aus dem nächsten Lauf entscheidet, und es kommt auch bei Rot._

---

## 0.33.1 — 2026-08-09

**Der Schalter wird nie umgelegt — jetzt gemessen statt vermutet. Und der
PDF-Bericht bekommt Zeit, sich zu zeigen.**

### Behoben
- `testCreatingADualTariffMeterAsksForBothNumbers`: Die Aufstellung aus 0.32.9
  hat es benannt — `("Optional("0")") ≠ ("Optional("1")")`. Der Schalter steht
  nach zwei Tippern immer noch auf „aus". Ein `tap()` landet in der **Mitte**
  des Schalters, und die liegt bei einer Formularzeile auf der Beschriftung,
  nicht auf dem Knopf. Die Prüfung tippt jetzt zusätzlich bei 90 % der Breite
  an — dort, wo der Schalter tatsächlich sitzt — und gibt bei einem Fehlschlag
  `isEnabled`, `isHittable`, Rahmen und Wert aus.
- `scripts/run.sh` kennt `PULSE_WARTEN`. Der PDF-Bericht bekommt 15 statt 4
  Sekunden. Vier genügen für jeden Bildschirm, den SwiftUI selbst zeichnet —
  nicht aber für ein Blatt, das erst gesetzt werden muss. Damit wird die Frage
  entscheidbar, die das erste Bild des Berichts aufgeworfen hat: Bleiben die
  sechs Seiten auch nach 15 Sekunden leer, rendert der Bericht leer, und das
  ist ein Produktfehler.

### Angemerkt
- Drei Diagnosen zu derselben Prüfung sind inzwischen widerlegt — 0.32.2,
  0.32.5 und 0.32.9 —, jede durch eine Messung, keine durch ein Argument. Die
  Lehre steht in `docs/06-uebergabe.md` und in `docs/08-baukasten.md`: Nach dem
  zweiten Fehlversuch nicht weiterraten, sondern die Prüfung dazu bringen, den
  Zustand zu berichten. Der eine Lauf mit Aufstellung hat mehr geklärt als drei
  Vermutungen davor.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `AppUITests` parsen sauber, Zeichenketten in Ordnung. Beide Korrekturen
brauchen einen Simulator und sind hier deshalb ungeprüft — der nächste
macOS-Lauf entscheidet, und er liefert dank 0.32.8 in jedem Fall die Bilder._

---

## 0.33.0 — 2026-08-09

**Die selbsttätige Prüfung ist zurück — und das Aufbauschema ist jetzt
übertragbar.**

### Behoben
- **Rückschritt aus 0.32.5 zurückgenommen.** Der macOS-Auftrag war auf `main`,
  Pull-Requests und Zuruf beschränkt worden, weil ein Mac dasselbe in zwei
  statt fünfzehn Minuten prüft. Das stimmt — aber nur, **wenn jemand am Mac
  sitzt.** Sonst wurde ein Arbeitszweig gar nicht mehr geprüft, und wer gerade
  nicht am Rechner ist, stand ohne jede Aussage über die App da. Genau dafür
  gibt es diesen Auftrag. Er läuft wieder bei jedem Push.
- Damit er das auch zu Ende tut, liegt die Nebenläufigkeit jetzt **je Auftrag**
  statt über dem ganzen Ablauf: Die schnelle Prüfung darf weiter abgebrochen
  werden — eine Minute, und ein überholter Stand interessiert niemanden. Der
  App-Build darf es nicht. Ein abgebrochener Build ist keine Aussage, sondern
  eine verlorene Viertelstunde; drei Läufe an einem Tag endeten so, jeder kurz
  vor dem Ziel.

### Hinzugefügt
- `docs/08-baukasten.md`: das Aufbauschema dieses Projekts, aufgeschrieben zum
  Übertragen auf ein anderes. Was allgemein ist und was ausgetauscht werden
  muss, in zehn Schritten — und die sechs Fehler, die es gekostet hat, mit
  Begründung. Sie wiederholen sich in jedem Projekt: das veraltete
  Arbeitsverzeichnis, das vollständig aussieht; der rote Lauf ohne Bilder; der
  Fehlschlag, der nur „fehlt" sagt; der Filter, der nur die erste Zeile zeigt;
  `cancel-in-progress` über dem ganzen Ablauf; der Prüfschritt, der die
  Testquellen auslässt.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `ci.yml` als YAML geprüft: kein Auslöser eingeschränkt, beide Aufträge
mit eigener Nebenläufigkeitsgruppe, `cancel-in-progress` nur beim schnellen._

---

## 0.32.10 — 2026-08-09

**Der Weg zum ersten Go-Live, mit Streichliste.**

### Hinzugefügt
- `docs/07-v1-plan.md`: Was für 1.0 wirklich hinein muss, was gestrichen wird
  und in welcher Reihenfolge. Kernaussage: Der Engpass ist kein Feature,
  sondern das Apple Developer Program — ohne das gibt es kein TestFlight,
  keinen App Store, keine Paywall und keine App-Gruppe fürs Widget.
- Zwei Posten sind für 1.0 gestrichen und stehen jetzt in 1.1: **Foto-Belege**
  (größtes Restrisiko im Umfang — Bilder in CloudKit, Speicherplatz, Export,
  Löschen, Zählerwechsel; und niemand vermisst sie, der die App noch nicht hat)
  und der **Siri-Kurzbefehl**. Dazu der Vermerk, dass beide dann auch nicht in
  der Pro-Beschreibung im Store auftauchen dürfen: Ein verkauftes Merkmal, das
  es nicht gibt, ist eine Rückerstattung und eine schlechte Bewertung.
- Benannt, was bisher nirgends stand und am meisten unterschätzt wird: das
  App-Store-Material — Icon, Bilder je Gerätegröße, Texte, Datenschutzerklärung
  mit erreichbarer URL, Support-Adresse. Es ist nicht angefangen und blockiert
  am Ende die Einreichung.

### Geändert
- `docs/05-roadmap.md` verweist für den 1.0-Umfang auf das neue Dokument und
  führt die beiden Streichungen mit Begründung.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Diese Version ändert nur Dokumente und Versionsnummern._

---

## 0.32.9 — 2026-08-09

**Der Schalter war nie umgelegt. Gemessen, nicht geraten.**

### Behoben
- `testCreatingADualTariffMeterAsksForBothNumbers` tippte auf den Schalter
  „Zwei Preise: Tag und Nacht" und lief weiter, ohne nachzusehen, ob er
  wirklich umgelegt ist. Er war es nicht: Ein `tap()` auf eine Formularzeile
  geht still ins Leere, wenn die Zeile noch in Bewegung ist — hier, weil kurz
  zuvor die Tastatur ausgeblendet wurde und das Formular zurückspringt.
  Die Prüfung suchte danach ein Feld, das die App zu Recht nicht zeigte, und
  meldete „Das Feld für den Nachtpreis fehlt". Sie prüft jetzt den Zustand des
  Schalters, versucht es bei Bedarf ein zweites Mal und sagt andernfalls genau
  das, statt einen Produktfehler zu behaupten.
- **Das Produkt war nie betroffen.** Die Aufstellung aus 0.32.7 hat es belegt:
  drei Textfelder statt vier, und das erste hieß „Arbeitspreis in Euro je kWh"
  statt „Arbeitspreis tagsüber". Beides sagt dasselbe — `hasDualTariff` stand
  auf `false`.
- Nebenbei zwei Diagnosen widerlegt, die 0.32.2 und 0.32.5 zugrunde lagen:
  Der Baum enthält genau **eine** Sammlung, also lag es nicht am Schieben auf
  der falschen Liste; und die Beschriftung hängt tatsächlich am Feld, also war
  auch `matching` statt `containing` nicht die Ursache. Beide Änderungen
  bleiben — sie sind für sich richtig —, aber sie waren nicht die Korrektur.
- Der Fehlerfilter in `scripts/test.sh` und `scripts/pruefen.sh` zeigte nur die
  **erste** Zeile einer Begründung. Ausgerechnet die Prüfung, die bei einem
  Fehlschlag den halben Zugänglichkeitsbaum ausgibt, war damit dort stumm, wo
  sie helfen sollte — die Aufstellung ließ sich nur noch aus dem Artefakt der
  CI holen. Beide zeigen jetzt zwölf Folgezeilen mit.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `AppUITests` parsen sauber. Die Korrektur selbst beruht diesmal auf
einer Messung aus einem macOS-Lauf, nicht auf einer Vermutung — belegt bleibt
sie erst mit dem nächsten Lauf._

---

## 0.32.8 — 2026-08-09

**Ein roter Lauf lieferte bisher keine einzige Aufnahme. Genau verkehrt
herum.**

### Behoben
- Die Screenshots hingen in der CI an `if: success()` und lokal an `APP_OK`.
  Eine einzige rote Prüfung unterdrückte damit **alle sechzehn Bilder** — und
  damit die produktivste Prüfung, die dieses Projekt hat: Sieben der bisher
  gefundenen Darstellungsfehler hat kein Test gefunden, sondern der Blick auf
  ein Bild. Wenn etwas nicht stimmt, braucht man die Bilder mehr als sonst,
  nicht weniger. Ein ganzer Nachmittag ist so blind vergangen: drei Läufe rot,
  kein einziges Bild, und der PDF-Bericht bis heute ungesehen — obwohl die App
  in jedem dieser Läufe gebaut und gestartet wurde.
- Sie entstehen jetzt auch bei einem gefallenen Lauf, in der CI mit
  `continue-on-error`, damit ein gescheiterter Bilderlauf das eigentliche
  Ergebnis nicht überschreibt: Rot bleibt rot, aus dem Grund, aus dem es rot
  war. Voraussetzung bleibt ein fertig gebautes Programm — ist schon die
  Übersetzung gescheitert, gibt es nichts zu fotografieren.
- Der Zweig `screenshots` sagt jetzt, aus welchem Zustand die Bilder stammen.
  Bei einem gefallenen Lauf steht ein Warnhinweis in der Kopfzeile. Ohne ihn
  läse sich der Zweig als Beleg für einen Stand, der durchgelaufen wäre.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `ci.yml` als YAML geprüft, beide Schritte auf `always()` samt
`continue-on-error` ausgelesen. Der Vermerk im Zweig ist gegen ein
Wegwerf-Repository in beiden Fällen durchgespielt — mit Warnhinweis bei „rot",
ohne bei „grün". Ungeprüft bleibt, was Xcode braucht._

---

## 0.32.7 — 2026-08-09

**Zwei Korrekturversuche an derselben Prüfung sind gescheitert. Statt eines
dritten Versuchs sagt der Fehlschlag jetzt, was tatsächlich da ist.**

### Geändert
- `testCreatingADualTariffMeterAsksForBothNumbers` gibt bei einem Fehlschlag
  jedes Textfeld im Zugänglichkeitsbaum aus — Kennung, Beschriftung,
  Platzhalter, Sichtbarkeit — und dazu die Zahl der Sammlungen. Bisher sagte
  er nur „Das Feld für den Nachtpreis fehlt", und damit blieb nur das Raten:
  Zwei plausible Diagnosen (erst die Beschriftung statt des sichtbaren Textes,
  dann `matching` statt `containing` samt oberster Sammlung beim Schieben)
  haben je einen CI-Lauf von dreizehn Minuten gekostet und beide nicht
  gestimmt. Ein Fehlschlag, der nur „fehlt" sagt, ist die eigentliche Ursache
  dieser Schleife.

### Was weiterhin offen ist
- Die Prüfung ist **rot**, und das Produkt ist nach allem, was von hier aus zu
  sehen ist, in Ordnung: `priceSection` zeigt „Arbeitspreis nachts", sobald der
  Schalter steht, und genau diesen Schalter findet und bedient dieselbe Prüfung
  zwei Zeilen vorher. 20 der 21 Oberflächenprüfungen laufen durch, darunter
  beide zum PDF-Bericht.
- **Nach `main` wird deshalb nichts zusammengeführt.** Ein roter Stand wird
  nicht zum Hauptstand gemacht, auch wenn nur eine Prüfung fällt.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `AppUITests` parsen sauber. Der nächste macOS-Lauf ist bewusst kein
Korrekturversuch, sondern eine Messung: Er liefert die Aufstellung, aus der die
Korrektur dann abzulesen ist. Am schnellsten geht das auf einem Mac —
`scripts/pruefen.sh --nur dual` prüft genau diesen einen Fall in etwa zwanzig
Sekunden statt in dreizehn Minuten._

---

## 0.32.6 — 2026-08-09

**Regel 4: Angefangenes wird zu Ende gebracht, ohne Nachfrage.**

### Hinzugefügt
- `CLAUDE.md` bekommt eine vierte Regel. Bisher endete eine Aufgabe für eine
  Sitzung faktisch mit dem Push — was danach kam, hing daran, dass der Nutzer
  nachfragte. Jetzt steht dort: Eine Aufgabe ist erst erledigt, wenn das
  Ergebnis zusammengeführt, aufgeräumt und gemeldet ist. Wer einen Lauf
  anstößt, plant die Nachschau selbst; ein grüner Lauf wird zusammengeführt,
  ein roter eingeordnet und gemeldet, ein noch offener stillschweigend erneut
  nachgesehen. Eine Zwischenmeldung ohne Ergebnis ist eine Störung.
- Dazu die Regel, die heute drei Läufe gekostet hat: **nie pushen, solange auf
  demselben Zweig ein Prüflauf läuft.** `cancel-in-progress` bewertet „neu"
  nach Startzeit und bricht den laufenden Auftrag ab — jedes Mal kurz vor dem
  App-Build, also nach der teuersten Minute und ohne je ein Ergebnis geliefert
  zu haben.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Diese Version ändert nur Dokumente und Versionsnummern; der macOS-Lauf
zu `13fc143` deckt den Code ab, den sie nicht anfasst._

---

## 0.32.5 — 2026-08-09

**Die letzte rote Prüfung berichtigt, und die CI dorthin gestellt, wo sie
Gegenprobe ist statt Warteschlange.**

### Behoben
- `testCreatingADualTariffMeterAsksForBothNumbers` blieb auch nach 0.32.2 rot
  („Das Feld für den Nachtpreis fehlt"). Das Produkt war nie betroffen: Der
  Nachtpreis steht in `priceSection`, sobald der Schalter umgelegt ist, und
  genau dieser Schalter wurde im selben Test gefunden und bedient. Falsch waren
  zwei Dinge in der Prüfung selbst:
  - `app.textFields.containing(…)` sucht die Beschriftung unter den
    **Nachfahren** des Feldes. Ein Eingabefeld hat keine — seit dem
    Barrierefreiheits-Durchgang trägt es sie selbst. Richtig ist `matching`.
    Bei den Textelementen weiter oben fällt der Unterschied nicht auf, weshalb
    dieselbe Schreibweise dort seit Langem unauffällig funktioniert.
  - Der Scroll-Helfer wischte auf `collectionViews.firstMatch`. Bei einem
    vorgeblendeten Formular ist das die Liste **dahinter**: Das Formular bewegt
    sich nicht, das Feld bleibt außerhalb des Bildes, und die Prüfung meldet
    „fehlt", obwohl es da ist. Er nimmt jetzt die oberste Sammlung — was auch
    jede künftige Prüfung an einem vorgeblendeten Formular betrifft.

- Die Syntaxprüfung ließ `AppUITests/` aus — ausgerechnet die Hälfte, deren
  Fehler am teuersten auffallen: Ein Tippfehler dort zeigte sich erst nach dem
  vollständigen App-Build. Jetzt wird auch sie geparst, in `scripts/pruefen.sh`
  und in der CI.

### Geändert
- Der macOS-Auftrag der CI läuft nicht mehr bei jedem Push auf einen
  Arbeitszweig, sondern auf `main`, bei jeder Pull-Request und auf Zuruf
  (`workflow_dispatch`). Seit 0.32.4 prüft ein Mac dasselbe in zwei statt in
  fünfzehn Minuten und liefert die Bilder mit; auf einem Arbeitszweig war der
  Auftrag damit keine Gegenprobe mehr, sondern die Warteschlange davor. Dazu
  kam, dass `cancel-in-progress` ihn bei zügiger Arbeit ohnehin abbrach —
  drei der letzten fünf Läufe endeten ohne Ergebnis und verbrauchten dabei
  eine Dreiviertelstunde macOS-Läufer.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Die Änderung an `ci.yml` ist als YAML geprüft und die Bedingung
ausgelesen. **Die beiden Korrekturen an der Oberflächenprüfung sind
Schlussfolgerung, nicht Messung** — hier gibt es keinen Simulator. Sie werden
mit dem nächsten macOS-Lauf belegt oder widerlegt; bis dahin gilt der Stand als
ungeprüft._

---

## 0.32.4 — 2026-08-09

**Der lokale Lauf liefert jetzt alles, was auch die CI liefert — die Bilder
eingeschlossen. Damit ist die CI die Gegenprobe und nicht mehr das Nadelöhr.**

### Hinzugefügt
- `scripts/pruefen.sh --melden` legt die Screenshots in den Zweig `screenshots`,
  nicht mehr nur die Ergebniszeile nach `pruefungen`. `scripts/mac-start.sh`
  ruft `--melden` von sich aus auf. Vorher war die CI der einzige Weg, wie eine
  Sitzung ohne Zugriff auf den Mac die Bilder je zu sehen bekam — fünfzehn
  Minuten für etwas, das lokal nach zwei Minuten fertig in `build/` liegt.
- `scripts/publish-shots.sh` läuft auch ohne `GITHUB_TOKEN`: Auf einem Mac
  schiebt es über `origin` mit den ohnehin eingerichteten Zugangsdaten. Die
  Kopfzeile im Zweig nennt Herkunft (CI oder Mac) und vermerkt, wenn der Lauf
  auf einem Arbeitsverzeichnis mit nicht eingecheckten Änderungen stattfand —
  sonst läse sich der Zweig später als Aussage über einen Stand, den es nie gab.

### Behoben
- **Ein liegengebliebenes Xcode-Projekt kannte Änderungen an `project.yml`
  nicht.** `scripts/pruefen.sh` und `scripts/run.sh` erzeugten es nur, wenn es
  ganz fehlte. Die CI baut immer von null und hätte den Unterschied nie
  gezeigt: Ein neues Ziel, eine neue Datei oder eine geänderte Versionsnummer
  wäre lokal stillschweigend nicht im Build gewesen — der Lauf grün, die CI
  danach rot, ohne erkennbaren Grund. Beide erzeugen jetzt auch dann neu, wenn
  `project.yml` jünger ist als das Projekt. Diese Version selbst war der erste
  Fall: Sie ändert `MARKETING_VERSION`.

### Geändert
- `README.md`, `CLAUDE.md` und `docs/06-uebergabe.md` sagen jetzt ausdrücklich,
  dass der erste Durchgang auf den Mac gehört und die CI die Gegenprobe ist.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. Der lokale Veröffentlichungsweg ist gegen ein Wegwerf-Repository
durchgespielt: Bilder landen im Zweig, die Kopfzeile nennt Stand und Herkunft,
der Vermerk „mit Änderungen" greift, und ohne `origin` oder ohne Bilder bricht
nichts ab. Die Erkennung des veralteten Projekts ist in allen drei Fällen
geprüft (Projekt fehlt, `project.yml` jünger, Projekt jünger). Ungeprüft bleibt
alles, was Xcode braucht — `sips`, `xcodegen` und der Simulator gibt es hier
nicht; das entscheidet der erste Lauf auf dem Mac._

---

## 0.32.3 — 2026-08-09

**Ein Aufruf, und ein Mac kann alles — inklusive des Schritts, der bisher
fehlte: den aktuellen Stand zu holen.**

### Hinzugefügt
- `scripts/mac-start.sh` führt in einem Durchgang zusammen, was bisher an vier
  Stellen beschrieben war: aktuellen Stand holen, Xcode-Projekt erzeugen,
  Push-Haken einrichten, alles prüfen, Screenshots ablegen und den Ordner
  öffnen. Fehlt Xcode, sagt es das in drei Zeilen statt in einer Fehlermeldung.
- `Am-Mac-starten.command` im Wurzelverzeichnis macht denselben Ablauf per
  Doppelklick im Finder erreichbar — `.command` ist die einzige Endung, die
  macOS von sich aus im Terminal öffnet. Das Fenster bleibt am Ende offen,
  sonst ist das Ergebnis weg, bevor es jemand liest.

### Geändert
- `START-HIER.md` und `README.md` beginnen jetzt mit diesem einen Schritt statt
  mit einer Reihenfolge aus vier Befehlen.
- Der Arbeitszweig ist nach `main` zusammengeführt. Der lange Zweigname in der
  Anleitung entfällt; `git clone` liefert wieder den aktuellen Stand.

### Behoben
- Eine Arbeitskopie auf einem veralteten Zweig sah vollständig aus und war zwei
  Versionen alt. Eine Sitzung hat auf diesem Weg 0.30.1 vollständig geprüft,
  grün gemeldet und für den aktuellen Stand gehalten — der Doppeltarif in der
  App und der PDF-Bericht fehlten in dieser Prüfung ersatzlos, ohne dass etwas
  rot wurde. `scripts/mac-start.sh` holt deshalb **zuerst** und prüft **danach**,
  und nennt Zweig und Version, bevor es loslegt.
- Der Wächter gegen ungesicherte Arbeit sieht nur eingecheckte Dateien an. Eine
  unbeteiligte Notiz im Projektordner hätte sonst den ganzen Ablauf blockiert,
  obwohl ein Zweigwechsel sie nicht anfasst.

_154 Prüfungen in `PulseCore`, alle grün. Klick-Dummy 44 von 44, hell und
dunkel. `PulseData`, App-Build und Oberflächentests konnten hier nicht laufen —
dieser Stand entstand in einem Linux-Container ohne Xcode; die CI deckt sie ab.
`scripts/mac-start.sh` selbst ist unter Linux bis zur Xcode-Prüfung
durchgespielt: Stand holen, Zweigwechsel mit elf neuen Commits, Wächter gegen
ungesicherte Änderungen, Versionsanzeige. Der Teil **ab** Xcode ist ungeprüft
und wird es erst mit dem ersten Lauf auf dem Mac._

---

## 0.32.2 — 2026-08-09

**Zwei Oberflächenprüfungen berichtigt — und eine Übergabe geschrieben.**

### Behoben
- `testCreatingADualTariffMeterAsksForBothNumbers` suchte nach dem sichtbaren
  Text „Arbeitspreis nachts". Den gibt es für VoiceOver seit dem
  Barrierefreiheits-Durchgang in 0.32.0 nicht mehr: Das **Eingabefeld** trägt
  die Beschriftung, der Text daneben ist versteckt. Die Prüfung hat damit eine
  echte Änderung gemeldet und die falsche Schlussfolgerung nahegelegt — sie
  sucht jetzt das Feld.
- `testTheReportCarriesBothTariffsOfADualTariffMeter` fand „Wärmepumpe"
  zweimal: einmal als Auswahl im Bericht, einmal in der Zählerauswahl des
  Verlaufs darunter. Beide sind gültig; gemeint ist die obere.
- Beim Einfügen der Scroll-Hilfe war deren Kommentar in den von `launchEmpty`
  gerutscht. Zwei Funktionen, ein Kommentar, und der stand über der falschen.

### Neu
- **`docs/06-uebergabe.md`** — der laufende Zustand für eine Sitzung, die
  diesen Verlauf nicht kennt: was gebaut, was ungeprüft, was zuletzt rot war
  und warum, worauf zu achten ist. Der **dauerhafte** Teil steht ohnehin in
  Strategie, Architektur, Datenmodell, `CHANGELOG.md` und den Kommentaren im
  Code; diese Datei trägt nur, was sich nicht dorthin schreiben lässt, und
  wird bei jeder Übergabe überschrieben statt fortgeschrieben.

**Weiter offen und ehrlich benannt:** Der PDF-Bericht ist durchgerechnet und
auf den Cent belegt, aber **noch nie als PDF gesehen worden** — das geht nur
auf einem Mac. Dasselbe gilt für die beiden hier berichtigten Prüfungen.

---

## 0.32.1 — 2026-08-09

**Ein Befehl statt fünfzehn Minuten Warten.** Vom Gründer angestoßen, kaum
dass er am Mac saß: Warum auf die CI warten, wenn der Rechner hier steht?

### Neu
- **`scripts/pruefen.sh`** — alles, was die CI prüft, in einem Befehl:
  Zeichenketten, Syntax der iOS-Quellen, `PulseCore`, `PulseData`, App-Bau,
  Oberflächentests, Screenshots und der Klick-Dummy. Auf einem Mac ein bis zwei
  Minuten statt zwölf bis fünfzehn, weil das Ableseverzeichnis liegen bleibt
  und Xcode nur das Geänderte übersetzt.
  - `schnell` lässt den App-Bau weg und braucht Sekunden.
  - `--nur zurueck` läuft eine einzelne Oberflächenprüfung statt einundzwanzig.
  - Der Klick-Dummy läuft **nebenher**, während Xcode baut — er kostet dadurch
    keine Zeit.
  - Oberflächentests laufen auf drei geklonten Simulatoren parallel. Erlaubt
    ist das, weil jede Prüfung ihren Ausgangszustand selbst setzt; `--seriell`
    schaltet es ab.
  - Ein gefallener Schritt bricht nicht ab. Wer drei Dinge kaputt gemacht hat,
    will alle drei sehen und nicht dreimal starten.
- **Dasselbe Skript läuft unter Linux**, macht dort was ohne Xcode geht und
  **benennt**, was es überspringt. Zwei getrennte Abläufe würden auseinander-
  laufen, und dann prüft der eine etwas anderes als der andere.
- **Haken vor dem Push**: `scripts/setup-mac.sh` richtet ihn ein, die schnellen
  Prüfungen laufen vor jedem `git push`. Einmalig überspringen mit
  `--no-verify`.
- **`swiftc -parse` auf den iOS-Quellen**, in der CI und lokal. Ohne SDK, ohne
  Typprüfung, in drei Sekunden — und trotzdem eine ganze Fehlerklasse: ein
  Block, der in der falschen Struktur gelandet ist.

- **Der Zweig `pruefungen`** — eine Zeile je lokalem Lauf: Zeitpunkt, Stand,
  Ergebnis, Umfang, Dauer, Rechner, und ob das Arbeitsverzeichnis sauber war.
  Geschrieben vom Haken vor dem Push. Damit sieht eine Sitzung, die den Mac
  nicht erreicht, ob ein Stand dort schon geprüft wurde — statt auf eine CI zu
  warten, deren Ergebnis längst vorliegt. **Auch Fehlschläge werden gemeldet:**
  Ein Zweig, in dem nur die grünen Läufe stehen, sähe aus wie eine lückenlose
  Erfolgsreihe und sagte damit das Falsche.

- **`.claude/settings.json`** — die Befehle dieses Projekts laufen in einer
  lokalen Sitzung ohne Rückfrage: `scripts/*`, `swift`, `xcodebuild`,
  `xcodegen`, `xcrun`, `git`, Lesen und Schreiben im Projekt. `sudo` bleibt
  gesperrt; es wird hier nirgends gebraucht, und `setup-mac.sh` sagt selbst
  Bescheid, wenn der Nutzer es einmal von Hand braucht. Persönliche
  Abweichungen gehören in `.claude/settings.local.json` und sind nicht
  eingecheckt.
- **`CLAUDE.md` benennt, wo eine Sitzung läuft.** Am Mac mit vollem Zugriff, in
  der Cloud in einem Linux-Container ohne Xcode und ohne Verbindung zu diesem
  Rechner. Die beiden sehen einander nicht — und eine Cloud-Sitzung darf nicht
  behaupten, sie könne dort etwas ausführen.

### Behoben
- **0.32.0 ist auf der CI nicht übersetzt.** Beim Barrierefreiheits-Durchgang
  landete `spokenValue(for:)` in `YearBars` statt in `PeriodBars` — die
  Textersetzung traf das zweite `upperBound` im selben File. Genau der Fall,
  den die neue Syntaxprüfung in drei Sekunden meldet statt nach fünfzehn
  Minuten.

---

## 0.32.0 — 2026-08-09

**Der PDF-Bericht — und ein Durchgang durch Verlauf und Zählerverwaltung.**
Damit ist die Tabelle „Was der Rechenkern kann und die App nicht" leer, bis
auf die Foto-Belege.

### Neu — Verbrauchsbericht
- **Zeitraum und Umfang zur Wahl**, bevor das Dokument entsteht. Oben steht
  das **Abrechnungsjahr des Versorgers**, nicht das Kalenderjahr: Es beginnt
  bei Strom oft im April und bei Gas im Oktober, und wer seine Rechnung prüfen
  will, braucht *ihren* Zeitraum. Für einen gemeinsamen Bericht über mehrere
  Zähler gibt es keinen gemeinsamen Rhythmus — das steht auch so da.
- **Echte A4-Seiten.** Zusammenfassung mit Kosten, Abschlägen und Saldo; je
  Zähler Menge, Zählernummer, Anfangs- und Endstand je Zählwerk, Monatstabelle
  mit Vorjahresvergleich und die Kosten aufgeschlüsselt; zum Schluss eine Seite
  darüber, wie die Zahlen entstehen.
- **Vorschau und Teilen** in der App, Einstieg im Verlauf unter dem Export.
- `ReportBuilder` in `PulseCore`: Der rechnende Teil ist ohne Xcode prüfbar.
  Ein Bericht wird gedruckt und weitergereicht — eine falsche Zahl darin wiegt
  schwerer als eine auf dem Bildschirm.

### Geändert — Barrierefreiheit, dritter Durchgang
- **Diagrammbalken sagen, was im Bild steckt:** Wert *mit Einheit*, Vorjahr und
  „unvollständiger Abschnitt". Vorher las VoiceOver eine nackte Zahl vor — in
  einer App, in der kWh und m³ nebeneinanderstehen, ist das keine Auskunft.
- **Tabellenzeilen als ein Satz.** Der Hinweis „nur 1. bis 15. Januar" stand
  neben der Zahl, ohne erkennbar dazuzugehören — und genau er ist der Grund,
  warum die Zahl kleiner ist.
- **Preisfelder tragen ihre Beschriftung selbst.** Vorher waren es drei
  Stationen: „Arbeitspreis", „0,00, Textfeld", „Euro je Kilowattstunde". Wer
  das Feld erreicht, hatte die Beschriftung schon hinter sich.
- Zählerauswahl meldet, welcher Zähler gewählt ist; Legendenfarben, Kopf- und
  Summenzeile, Vergleichskarte entsprechend zusammengefasst.

### Geändert — Entwurf
- **Der Bericht rechnete noch mit `registers[0]` und dem Zählerpreis.** Beim
  Doppeltarifzähler stand dort der Hochtarif zum falschen Preis, und der
  Niedertarif kam gar nicht vor. Jetzt über den ganzen Zähler, mit einem
  Arbeitspreis je Zählwerk und Ständen je Zählwerk.

### Behoben
- Drei Oberflächenprüfungen fielen in 0.31.0 — alle drei zu Recht:
  - Der neue Abschnitt „Tag und Nacht" schob das Preisfeld unter den
    Bildschirmrand. Ein `Form` baut nur, was sichtbar ist; was darunter liegt,
    existiert für die Prüfung nicht. Die Prüfungen scrollen jetzt.
  - Die Abschlagsprüfung zählte zwei Zähler und fand drei — die neue
    Wärmepumpe hat einen Abschlag. Die Erwartung ist nachgezogen.

### Geprüft
- `PulseCore`: **154 Prüfungen**, elf davon neu für den Bericht. Darunter: Der
  Grundpreis fällt einmal an, die Monatstabelle nimmt nur vollständige Monate,
  in den Saldo fließen nur Zähler mit Abschlag, und über einen Rücksprung
  hinweg wird kein Zählerstand eingesetzt.
- Zwei neue Oberflächenprüfungen: Der Bericht bietet Zeiträume an und erzeugt
  ein Dokument; bei einem Doppeltarifzähler stehen **beide** Arbeitspreise
  darin.
- Zwei neue Bilder (`screenshot-bericht-*`) über den Schalter `-pulse-bericht`.
- Klick-Dummy: 44 Prüfungen in Hell und Dunkel.

---

## 0.31.0 — 2026-08-09

**Doppeltarif (HT/NT) in der App.** Ein Gerät, zwei Arbeitspreise — der
klassische Nachtspeicher- und Wärmepumpentarif. Der Rechenkern konnte das seit
dem ersten Tag, der Entwurf seit 0.30.0; was fehlte, war die Möglichkeit, so
einen Zähler überhaupt **anzulegen** — und alles, was danach kommt.

### Neu
- **Schalter „Zwei Preise: Tag und Nacht"** im Zähler-Editor, neben dem für die
  Einspeisung. Weder „Doppeltarif" noch „HT/NT": Beides sind Wörter von der
  Rechnung. Der Nutzer weiß, dass sein Strom nachts weniger kostet.
- **Zwei Arbeitspreise**, „tagsüber" und „nachts". Der erste heißt erst dann
  „Arbeitspreis tagsüber", wenn es einen zweiten gibt.
- Beide Zahlen werden **in einem Vorgang** erfasst — derselbe Ablauf wie beim
  Zweirichtungszähler, mit dem Weg zurück aus 0.30.1.
- Ein Doppeltarifzähler in den Beispieldaten: **Wärmepumpe**, mit denselben
  Preisen wie im Entwurf.

### Geändert — und das ist der eigentliche Teil
- **`ConsumptionEngine.consumption(meteringPoint:…)`**: Der Verbrauch eines
  Zählers ist die Summe seiner Bezugs-Zählwerke, **zugeschnitten auf den
  Zeitausschnitt, den alle abdecken**. Wer den Hochtarif bis August abgelesen
  hat und den Niedertarif bis Mai, hat für den Zähler eine Aussage bis Mai. Die
  Summe über zwei verschieden lange Zeiträume wäre keine — das ist die
  wiederkehrende Fehlerklasse aus `CLAUDE.md`, und sie steht jetzt als Prüfung
  im Rechenkern.
- Karte, Vorjahresvergleich, Zwölf-Monats-Linie, Verlauf, Vergleichskarte und
  **Widget** rechnen über den Zähler statt über sein erstes Zählwerk. Bei einem
  gewöhnlichen Zähler und beim Zweirichtungszähler ändert sich dadurch nichts:
  Die Einspeisung ist kein Bezug und zählt nicht mit.
- **Der Export verliert nichts mehr.** Bisher ging nur das erste Zählwerk in
  die CSV-Datei — bei einem Doppeltarifzähler die Hälfte der Daten, und die
  Datei sah vollständig aus. Neue Spalte „Bezeichnung", aber nur bei Zählern
  mit mehr als einer Zahl. Gilt in App **und** Entwurf; dort war derselbe
  Fehler.
- **Ein Tarif je Zählwerk**, und der Grundpreis steht nur am ersten: Er gehört
  zum Anschluss, und der Anschluss ist einer.

### Behoben
- Beim Zweirichtungszähler blieb die neue Spalte im Entwurf für den Bezug
  **leer** — daneben stand „Einspeisung", und niemand konnte das Leerfeld
  deuten. Ohne eigenen Namen ergibt er sich jetzt aus der Richtung.

### Geprüft
- `PulseCore`: **143 Prüfungen**, acht davon neu. Darunter die Fehlerklasse als
  Prüfung: Hochtarif bis August, Niedertarif bis Mai — 2.541 kWh bis zum
  1. Juni, nicht 2.916 kWh über zwei verschiedene Zeiträume.
- **Kosten auf den Cent gegen die Handrechnung**: 1.232,0 × 0,31 € +
  1.309,0 × 0,21 € = 656,81 €, Grundpreis 8,90 €/Monat × 12 ÷ 365 × 151 Tage
  = 44,18 €, zusammen **700,99 €** — derselbe Betrag, den der Entwurf zeigt.
- Klick-Dummy: **44 Prüfungen** in Hell und Dunkel, vier davon neu für den
  Export.
- Neue Oberflächenprüfung: Zähler mit zwei Preisen anlegen, beide Felder
  vorhanden, Erfassung fragt Hochtarif und Niedertarif nacheinander.

---

## 0.30.1 — 2026-08-09

**Aus der Erfassung führt wieder ein Weg zurück.** Vom Gründer beim
Ausprobieren gefunden: Wer bei einem Zähler mit zwei Zählwerken den ersten
Stand eingetippt, „Weiter" gedrückt und dann den Tippfehler bemerkt hat, kam
nicht mehr zurück. Der einzige Ausweg war Abbrechen — also alles noch einmal.
Das verstößt gegen Prinzip 4, „keine Sackgasse".

### Behoben
- **„Zurück" ab dem zweiten Zählwerk**, links in der Kopfzeile, „Abbrechen"
  daneben. Im ersten Schritt bleibt es bei „Abbrechen" allein: Dort wäre
  „Zurück" dasselbe und damit eine Wahl ohne Unterschied.
- **Der bereits eingetippte Wert steht beim Zurückspringen wieder da.** Ihn zu
  leeren hieße, die Korrektur mit einer zweiten Eingabe zu bezahlen.
- Gilt in beiden Fassungen — `App/CaptureView.swift` und der Entwurf.

### Geprüft
- Vier neue Prüfungen in `scripts/check-prototype.mjs`: der Weg zurück
  erscheint, „Abbrechen" bleibt daneben erreichbar, der Rücksprung landet beim
  ersten Zählwerk, und der Wert ist wieder da. 36 Prüfungen in Hell und
  Dunkel, alle grün.
- **Oberflächenprüfung** in `testCapturingBothDirectionsInOneGo`: „Zurück" ist
  da, „Abbrechen" bleibt daneben erreichbar, der Rücksprung landet beim ersten
  Zählwerk, und „Weiter" ist wieder freigeschaltet — was nur geht, wenn der
  Wert noch im Zählwerk steht.
- **Zwei neue Bilder** (`screenshot-zurueck-*`) über den Schalter
  `-pulse-capture-step2`. Ohne ihn kam der zweite Schritt auf kein einziges
  Bildschirmfoto: `simctl` kann nicht tippen, und alle Bilder zeigten Schritt 1
  von 2. Ein Knopf, den niemand ansieht, ist ein Knopf, in dem sich ein Fehler
  beliebig lange hält.
- **Eigene Zahlenprobe zum Doppeltarif.** Gemeinsamer Ausschnitt 1.1.–1.6.2026,
  151 Tage: Hochtarif 1.232,0 kWh, Niedertarif 1.309,0 kWh, zusammen
  2.541,0 kWh. Arbeitspreis 1.232,0 × 0,31 € + 1.309,0 × 0,21 € = 656,81 €,
  Grundpreis 8,90 €/Monat × 12 ÷ 365 × 151 = 44,18 €, zusammen **700,99 €** —
  auf den Cent das, was der Entwurf zeigt. Der Grundpreis wird **einmal**
  berechnet, nicht je Zählwerk.
- Danach durch die Erfassung getippt, mit absichtlichem Tippfehler und
  Korrektur über „Zurück": Der falsche Wert wird nicht gesichert. Der
  gemeinsame Ausschnitt reicht dann bis heute (215 Tage), Menge 3.116,0 kWh,
  Kosten 889,97 € — Abweichung zur Handrechnung 0,0000 €.

**Und ein Fehler in meiner eigenen Rechnung, der Regel „Wiederkehrende
Fehlerklasse" bestätigt:** Beim ersten Anlauf habe ich den Hochtarif bis zu
seiner letzten Ablesung am 1.8. gegen den Niedertarif bis 1.6. gerechnet und
kam auf 2.916 kWh statt 2.541. Der Entwurf schneidet richtig auf den
Ausschnitt zu, den **beide** Zählwerke abdecken. Zum elften Mal derselbe
Fehlertyp — diesmal in der Prüfung, nicht im Code.

---

## 0.30.0 — 2026-08-07

**Doppeltarif (HT/NT) im Entwurf.** Ein Gerät, zwei Arbeitspreise — der
klassische Nachtspeicher- und Wärmepumpentarif. Der Rechenkern kann es seit
dem ersten Tag; hier kommt der Entwurf zuerst, weil ein Fehler darin in einer
Minute auffällt statt in zwanzig.

### Geändert
- **Der Arbeitspreis hängt jetzt am Zählwerk, nicht am Zähler.** Bisher gab es
  einen Preis je Zähler plus einen Sonderfall für die Einspeisung. Ein zweiter
  Sonderfall hätte die Stelle unlesbar gemacht; ein Preis je Zählwerk deckt
  beides ab — wie `CostEngine.price(for:tariff:)`.
- **Der Verbrauch eines Zählers ist die Summe seiner Bezugs-Zählwerke.** Bei
  HT/NT ist beides Bezug, und die Karte zeigt, was verbraucht wurde.

### Die Fehlerklasse, zum zehnten Mal
- **Beide Zählwerke müssen denselben Ausschnitt beschreiben.** Im
  Ausgangszustand reicht der Hochtarif bis August, der Niedertarif bis Juni.
  Sie einfach zu addieren ergäbe 2.916 kWh — eine Zahl, in der ein Teil drei
  Monate weiter reicht als der andere. Beschnitten auf den gemeinsamen
  Ausschnitt sind es 2.541 kWh für Januar bis Juni.

  Bemerkenswert: **Meine eigene Nachrechnung war die falsche Seite.** Ich hatte
  2.916 erwartet und musste feststellen, dass ich damit genau den Fehler
  reproduziert hatte, gegen den der Code gebaut ist.
- **Und dabei fiel ein echter Fehler auf, den ich selbst eingebaut hatte:** Die
  Kosten nahmen weiter den Ausschnitt des ersten Zählwerks. Auf einer Karte
  stand damit eine Menge für Januar bis Juni neben einem Betrag für Januar bis
  August. Aufgefallen beim Nachrechnen, nicht in einer Prüfung — 560,20 € statt
  700,99 €.

### Geprüft
- 28 Prüfungen des Entwurfs grün, hell und dunkel.
- Kosten von Hand nachgerechnet, auf dem gemeinsamen Ausschnitt: 700,99 €
  berechnet, 700,99 € erwartet.

### Offen
- In der **App** fehlt der Doppeltarif noch. Der Entwurf zeigt jetzt, wie es
  aussieht und wo die Fallen liegen — genau dafür gibt es ihn.

## 0.29.0 — 2026-08-07

**Barrierefreiheit, dritter Durchgang: der Erfassungsschirm.** Damit ist der
Bildschirm versorgt, an dem das Produkt gewinnt oder verliert.

### Behoben
- **Das Zeichen im Prüf-Banner wuchs nicht mit der Schrift** — feste 13 Punkt
  neben einer Zeile, die auf die dreifache Höhe wachsen kann. Derselbe Fehler
  wie beim Punkt der Statuszeile in 0.28.0, gefunden beim gezielten Suchen
  danach. Das ist der Wert einer benannten Fehlerklasse: Der zweite Fund
  kostet Minuten statt einer Runde.

### Geändert
- Das Zeichen wird nicht mehr vorgelesen. Der Text sagt bereits, ob der Wert
  plausibel ist; vorgelesen wäre es eine Unterbrechung mitten im Satz.
- **Zählwerkname und Fortschritt lesen sich als ein Satz** — „Einspeisung,
  Zählwerk 2 von 2". Getrennt käme der Fortschritt als eigener Brocken nach
  dem Namen, und wer nicht sieht, wie die beiden zusammenhängen, hört zwei
  Angaben statt einer Ortsbestimmung.

### Vorher bemerkt
- Die zwei Prüfungen des zweistufigen Erfassungsflusses suchten „Bezug" und
  „Zählwerk 1 von 2" als getrennte Elemente. Sie prüfen jetzt, dass **beides
  gesagt wird**, nicht in wie vielen Elementen. Vierte Wiederholung dieser
  Lehre, zweite Mal vorher gezogen.

## 0.28.1 — 2026-08-07

### Behoben
- **Die Startzeit-Prüfung flatterte, und der Fehler war meiner.** Sie fiel mit
  15,57 s gegen eine Grenze von 15 s. Im Kommentar derselben Prüfung stand,
  die Zahl schwanke auf einem geteilten Läufer um ein Vielfaches — und dann
  habe ich die Schranke mitten ins Rauschband gelegt.

  Die Korrektur ist nicht, die Zahl zu erhöhen. Der Denkfehler war die zweite
  Schranke: Ein hängender Start heißt, dass die Übersicht **nie** kommt, und
  das prüft `waitForExistence` bereits mit verständlicher Meldung. Eine zweite
  Prüfung derselben Bedingung fügt nichts hinzu außer Flattern.

  Was bleibt, ist die Zahl im Protokoll. Sie ergibt einen Verlauf, und ein
  Verlauf zeigt Verschlechterungen, die keine einzelne Schranke je zuverlässig
  gefunden hätte.

### Stand
- 17 von 18 Oberflächenprüfungen liefen; die eine war diese. Die
  Barrierefreiheits-Änderungen aus 0.28.0 sind damit alle durchgelaufen,
  einschließlich der beiden Tests, die ich vorher angepasst hatte.

## 0.28.0 — 2026-08-06

**Barrierefreiheit, zweiter Durchgang** — und der erste Befund, den die
Großschrift-Bilder aus 0.27.2 geliefert haben.

### Behoben
- **Der Punkt vor der Statuszeile wuchs nicht mit der Schrift.** Neun Punkt
  Größe und sechs Punkt Abstand standen fest im Code. Bei der größten Stufe
  blieb er winzig und schwebte oben neben einem Absatz, dessen erste Zeile
  dreimal so hoch war — er gehört an diese Zeile, nicht an den oberen Rand.
  Beides skaliert jetzt mit `@ScaledMetric`.

  Bemerkenswert daran ist nicht der Fehler, sondern wie lange er unsichtbar
  war: Die Zusage „Dynamic Type bis zur größten Stufe" stand seit dem ersten
  Entwurf im Dokument, und niemand hat je hingesehen. Ein Bild hat gereicht.

### Geändert
- **Der Punkt wird nicht mehr vorgelesen.** Er wiederholt farblich, was der
  Text sagt; vorgelesen wäre er eine Unterbrechung.
- **Eine Zeile im Zähler-Schirm liest sich als ein Satz** — „Gas, 8.285,100 m³
  am 1. Mai 2026" — mit dem Hinweis, was ein Tippen bewirkt. Die beiden
  Symbole tragen nichts bei, was der Text nicht schon sagt.

### Vorher bemerkt statt vom Lauf gemeldet
- Zwei Oberflächenprüfungen suchten den Zählernamen als eigenes Element und
  wären an der zusammengefassten Zeile zerbrochen. Sie prüfen jetzt über den
  Anfang der Beschriftung — dass der Zähler in der Liste steht, nicht wie die
  Liste innen gebaut ist. Das dritte Mal dieselbe Lehre in dieser Sitzung, und
  das erste Mal, dass sie vor dem Lauf gezogen wurde.

### Weiterhin offen
- Erfassungsschirm und Verlauf sind noch nicht durchgegangen. Der Ziffernblock
  und die Diagrammspalten waren bereits versorgt — geprüft, nicht vermutet.
- Die 800 ms auf einem **Gerät**.

## 0.27.2 — 2026-08-06

### Behoben
- **Der Abschlagstest zählt jetzt über den Jahresbetrag.** Das Protokoll aus
  0.27.1 hat die offene Frage beantwortet: Je Zeile stehen zwei Einträge — der
  reine Text und das zusammengefasste Element, das ihn enthält. Das
  Zusammenfassen wirkt also wie gewollt; XCUITest zeigt zusätzlich die
  darunterliegende Ansicht, VoiceOver benutzt den Zugänglichkeitsbaum. Es war
  die harmlose der beiden Deutungen — aber jetzt belegt statt vermutet.
- Meine Kürzung auf 30 Zeichen aus 0.27.1 schnitt genau dort, wo sich die
  beiden Erscheinungsformen unterscheiden. Der Jahresbetrag ist das, was eine
  Abschlagszeile ausmacht; über ihn gezählt fallen sie zusammen.

## 0.27.1 — 2026-08-06

### Behoben
- **Ein Test zählte Elemente statt Aussagen.** Seit dem Zusammenfassen der
  Fußzeile für VoiceOver sieht XCUITest zwei Einträge je Zeile — das
  zusammengefasste Element und seinen Text — und kam auf vier statt zwei.
  Geprüft wird jetzt über die Menge der **verschiedenen** Beschriftungen: Die
  Aussage lautet „genau zwei Zähler zeigen eine Vorschau", nicht „vier
  Elemente". So bleibt sie richtig, unabhängig davon, wie die Oberfläche innen
  aufgebaut ist.
- Der Test schreibt die gefundenen Beschriftungen ins Protokoll. Beim
  Fehlschlag stand nur „4 ist nicht 2" da, und ob VoiceOver die Zeile nun
  doppelt vorliest oder bloß der Test zu genau hinsieht, ließ sich ohne
  Simulator nicht entscheiden. Beim nächsten Mal steht die Antwort da.

### Stand
- 17 der 18 Oberflächenprüfungen liefen bereits; dieser eine war der
  Unterschied. Die Startzeit-Messung ist dabei zum ersten Mal gelaufen.

## 0.27.0 — 2026-08-06

**Barrierefreiheit und Startzeit** — der erste Schritt an einer Zusage, die in
`00-produktstrategie.md` als „nicht verhandelbar" steht und bis heute nie
geprüft wurde.

### Geändert
- **Die Übersichtskarte liest sich als ein Satz.** Zeitraum, Zahl, Einheit und
  Erläuterung waren vier eigene Elemente; VoiceOver las vier Fetzen vor —
  „1. Januar bis 1. Mai", „ungefähr", „1.181", „m³" —, und der Zusammenhang,
  auf den es hier ankommt, ging genau dabei verloren.
- **Jede Fußzeile ebenfalls.** „Kosten bis 1. Mai" und „1.399,41 €" gehören
  zusammen. Getrennt gelesen stünde der Betrag ohne seinen Zeitraum da — das
  ist die wiederkehrende Fehlerklasse dieses Projekts, nur mit den Ohren statt
  mit den Augen.

### Hinzugefügt
- **Zwei Bilder bei der größten Schriftgröße**, die iOS anbietet. „Dynamic Type
  bis zur größten Stufe" stand als Zusage da, ohne dass je jemand hingesehen
  hätte. Ein Bild kostet zwei Sekunden und zeigt sofort, was abgeschnitten
  wird. Der Simulator wird danach zurückgestellt, damit nicht alle künftigen
  Bilder verfälscht sind.
- **Eine Messung der Startzeit** bis zur ersten lesbaren Zahl, die ins
  Protokoll geht.

### Ehrlich gesagt
- **Die Startzeit-Messung prüft die 800-ms-Zusage nicht.** Die gilt für ein
  Gerät; hier läuft ein Simulator auf einem geteilten Läufer, und die Zahl
  schwankt um ein Vielfaches. Wer sie dafür hielte, hätte eine grüne Prüfung
  und keine Gewissheit. Sie taugt für einen Verlauf und dafür, einen
  *hängenden* Start zu fangen — die Grenze ist deshalb bewusst weit gesetzt.
  Die eigentliche Messung gehört auf ein Gerät und bleibt offen.
- Ein Oberflächentest prüfte den Kartentext über den **genauen** Wortlaut und
  wäre am Zusammenfassen zerbrochen. Er prüft jetzt über `CONTAINS` — die
  Aussage statt der Bauform. Vorher bemerkt statt vom Lauf gemeldet; dieselbe
  Lehre wie bei „Kosten seit Jahresbeginn" in 0.21.5.

## 0.26.2 — 2026-08-06

### Behoben
- **Der Wechselschirm ließ sich nicht übersetzen.** `guard let register`
  packte den Wert oben aus, drei Zeilen später band ich ihn noch einmal:
  „initializer for conditional binding must have Optional type, not
  'Register'". Ein Fehler, den ein Compiler in einer Sekunde findet — und der
  hier vier Fassungen lang unentdeckt blieb, weil kein Lauf durchkam.

### Bemerkenswert
- **Die Protokollkorrektur aus 0.22.4 hat sich sofort ausgezahlt.** Der Lauf
  nannte Datei, Zeile, Spalte und Grund. Vorher hätte dort „TEST FAILED"
  gestanden und sonst nichts.
- **Der neue Linux-Auftrag für den Entwurf war in 59 Sekunden grün** — beim
  allerersten Lauf, und während der macOS-Auftrag noch baute.
- Vier Fassungen ohne Bestätigung übereinander, und der Rückstau bestand aus
  **genau einer** falschen Zeile. Das ist ein besserer Ausgang als erwartet,
  ändert aber nichts am Befund: So lange ohne Übersetzer weiterzubauen war
  riskant, und dass es gutging, war zum Teil Glück.

## 0.26.1 — 2026-08-06

**Ein frisch angelegter Zähler ließ sich nicht ablesen.** Gemeldet vom
Gründer beim Ausprobieren — nicht von mir beim Testen. Der erste Schritt, den
ein neuer Nutzer überhaupt macht, und er führte ins Leere.

Es waren zwei Fehler übereinander:

### Behoben
- **`judge()` griff auf `last.value` zu, ohne zu prüfen, ob es eine vorherige
  Ablesung gibt.** Bei einem neuen Zähler stürzte die Plausibilitätsprüfung
  still ab, und „Sichern" blieb gesperrt. Der ältere der beiden Fehler, und
  der, den der Gründer gesehen hat.
- **Der Editor legte ein halbes Zählwerk an** — `{ label: "", readings: [] }`,
  ohne Einheit, ohne Stellen, ohne Kennung. Solange der Ziffernblock diese
  Werte beim *Zähler* holte, fiel das nicht auf; seit 0.26.0 holt er sie beim
  *Zählwerk*, und dann nahm die Eingabe keine Ziffer mehr an. Dieser Fehler
  ist meiner, aus der Runde davor.

  Die Lehre steckt nicht im Tippfehler, sondern im halb gefüllten Gebilde: Ein
  Zählwerk, dem Felder fehlen, die jedes andere hat, ist eine Falle, die auf
  ihre Gelegenheit wartet. Beim Ändern der Zählerart ziehen die Felder jetzt
  ebenfalls mit.

### Hinzugefügt
- **`scripts/check-prototype.mjs` und ein eigener CI-Auftrag auf Linux.** Der
  Entwurf ist der produktivste Fehlerfinder dieses Projekts und wurde bisher
  nur geprüft, wenn ich daran dachte. Vierzehn Prüfungen je Erscheinungsbild,
  darunter genau dieser Weg: Zähler anlegen, ersten Stand eintippen, sichern.
- Der Auftrag läuft auf `ubuntu-latest` und braucht keinen macOS-Läufer. Er
  ist in einer Minute durch, auch wenn der App-Build stundenlang in der
  Warteschlange hängt — was heute mehrfach der Fall war.

### Warum es niemandem auffiel
Jeder Zähler im Entwurf hatte zwei Jahre Historie. Den Fall „noch nie
abgelesen" gab es in der Erfassung schlicht nicht — dieselbe Ursache wie bei
dem Absturz in `lastReading`, der vor ein paar Fassungen an derselben Stelle
saß. Ein Ausgangszustand, der nur den eingeschwungenen Fall zeigt, versteckt
den Anfang.

## 0.26.0 — 2026-08-06

**Der Entwurf erfasst beide Zählwerke.** Die zweistufige Erfassung gibt es in
der App seit 0.22.0 — im Klick-Dummy nicht. Er schrieb ausschließlich nach
`registers[0]`, und die Einspeisung des PV-Zählers ließ sich dort gar nicht
eintragen. Eine Abweichung, die niemandem auffiel, weil man sie nur beim
Durchklicken bemerkt.

### Geändert
- Erfassung läuft über alle Zählwerke nacheinander: Zählwerkname, „Zählwerk 1
  von 2", Knopf „Weiter" statt „Sichern". Gesichert wird erst am Ende und dann
  alles zusammen — ein Abbruch nach dem ersten darf keine halbe Ablesung
  hinterlassen.
- **Stellen und Einheit kommen jetzt vom Zählwerk, nicht vom Zähler.** Vorher
  nahm der Ziffernblock `capMeter.int`/`capMeter.frac`; bei einem Zähler,
  dessen Zählwerke sich darin unterscheiden, hätte er die falsche Maske
  gezeigt. Aufgefallen beim Umbau, nicht im Betrieb.

### Geprüft
- Beide Zählwerke einmal wirklich durchgeklickt: „Bezug / Zählwerk 1 von 2 /
  Weiter", dann „Einspeisung / Zählwerk 2 von 2 / Sichern". Beide Reihen
  wachsen um genau eine Ablesung, kein Überlauf, keine JS-Fehler.

## 0.25.0 — 2026-08-06

**Widget für Sperr- und Startbildschirm.** Der zweite Hebel für Wiederkehr:
Erinnerungen holen jemanden zurück, der die App vergessen hat — ein Widget
sorgt dafür, dass er sie gar nicht erst vergisst.

### Hinzugefügt
- `WidgetSummary` in `PulseCore` mit sechs Prüfungen: eine kleine, für sich
  lesbare Zusammenfassung mit Menge, Zeitraum, Fälligkeit und Symbol.
- `WidgetBridge` schreibt sie nach jeder Änderung als Datei in die App-Gruppe;
  das Widget liest sie und rechnet nichts.
- Zwei Größen. Die kleine zeigt den dringendsten Zähler, die mittlere bis zu
  drei.

### Entschieden
- **Das Widget bekommt keinen Zugriff auf den Speicher.** Eine Erweiterung ist
  ein eigener Prozess mit knappem Speicher und wenigen Millisekunden Zeit.
  Zöge sie SwiftData samt CloudKit auf, um drei Zahlen anzuzeigen, wäre sie
  das langsamste und fehleranfälligste Stück der App — und der häufigste Grund
  für ein leeres Widget ist genau das.
- **Die Zusammenfassung entsteht in `PulseCore`, nicht in der App.** Würde sie
  in der Erweiterung noch einmal formuliert, liefen die beiden auseinander,
  und das Widget zeigte eine andere Zahl als der Bildschirm daneben. Aus
  demselben Grund ist `periodCaption` aus der Übersicht herausgelöst und wird
  nun von beiden benutzt.
- **Fälligkeit hat Vorrang vor dem Zeitraum.** Wer im Vorbeigehen liest, liest
  eine Zeile. Stünde dort der Zeitraum, während ein Zähler seit drei Monaten
  überfällig ist, hätte das Widget die falsche Zeile gewählt.
- **Ohne Daten sagt es, was zu tun ist**, statt leer zu bleiben. Ein leeres
  Widget wird entfernt.
- **Ein Schreibfehler bleibt folgenlos.** Ohne App-Gruppe — etwa in der CI,
  wo ohne Signatur gebaut wird — landet die Datei im eigenen Ordner der App.
  Das Widget sieht sie dann nicht, aber die App läuft. Ein Absturz an dieser
  Stelle wäre absurd: Niemand verliert etwas, wenn ein Widget leer bleibt.
- **Die Datei trägt eine Fassungsnummer**, und eine neuere wird nicht geraten.
  Ein Widget läuft weiter, während die App schon aktualisiert ist — dann
  lieber der leere Zustand als eine Zahl, deren Bedeutung sich verschoben hat.
- Geschrieben wird **atomar**: Läse das Widget genau während des Schreibens,
  bekäme es sonst eine halbe Datei.

### Vorsichtsmaßnahmen ohne Compiler
Das Widget ist das erste Ziel, das ohne lokalen Übersetzer entsteht. Zwei
Stellen habe ich deshalb entschärft, bevor der Lauf sie findet:
- Ein Helfer mit `@ViewBuilder` an einem `some View`-Parameter ist gültiges
  Swift, aber die ausgefallenste Konstruktion der Datei. Ein `if let` kostet
  drei Zeilen mehr und kann nicht überraschen.
- `periodCaption(for:)` gab es nach dem Herauslösen zweimal — mit `MeterRow`
  und mit `ConsumptionResult?`. In einem Abschluss wäre das eine Einladung an
  den Typprüfer, die falsche zu wählen. Die zweite heißt jetzt `periodText`.

### Offen
- Die App-Gruppe braucht ein Entwicklerkonto, um auf einem Gerät zu greifen.
  Im Simulator und in der CI läuft der Ersatzpfad. Das Widget ist damit
  gebaut und übersetzt, aber erst mit dem Apple Developer Program wirklich
  gefüllt.

`PulseCore` steht bei 135 Prüfungen.

## 0.24.0 — 2026-08-06

**Der Entwurf rechnet wie der Rechenkern.** Die offene Abweichung aus 0.23.0
ist geschlossen — und zwar an der Wurzel, nicht durch Nachbauen der Oberfläche.

### Geändert
- **Der Klick-Dummy bildet jetzt eine aufsummierte Reihe**, wie
  `ConsumptionSeries` in `PulseCore`. Vorher rechnete er Verbrauch als
  Differenz zweier **roher** Zählerstände. Das trägt genau so lange, wie der
  Zähler nur steigt; ein Gerätewechsel oder ein Überlauf machte jeden
  Verbrauch negativ. Und weil der Entwurf beides nicht kannte, konnte er
  Fehler darin auch nicht finden — genau dafür gibt es ihn aber.
- `step` spiegelt die Regeln eins zu eins: erklärter Rücksprung bei
  Gerätewechsel, Überlauf ab 90 % der Kapazität, sonst null statt Raten.
  Schwelle und Kapazität sind gegen `PulseCore` abgeglichen.
- Getrennt in `cumulativeAt` (aufgelaufener Verbrauch) und `readingAt`
  (roher Stand). Der Bericht braucht den Stand, alles andere den Verbrauch.
  Die beiden zu verwechseln hieße, nach einem Wechsel den Stand des neuen
  Geräts als Verbrauch auszuweisen.

### Hinzugefügt
- **Der Zählerwechsel ist im Entwurf anklickbar.** Dieselbe Sackgasse wie in
  der App bis 0.23.0: Die Frage „Wurde der Zähler gewechselt?" stand da und
  ließ sich nur mit „Ziffer verirrt" beantworten. Jetzt steht ein Ausweg
  darunter.
- Neue Ablesungen übernehmen die Gerätekennung der vorherigen — sonst risse
  die Kette beim nächsten Rücksprung wieder.

### Geprüft
- Alle Zahlen der Übersicht sind vor und nach dem Umbau **identisch**. Das war
  die Anforderung: Ohne Wechsel und ohne Überlauf muss die Reihe genau
  dasselbe liefern.
- Vier Fälle einzeln durchgerechnet — ohne Wechsel 600, mit Wechsel 800,
  unerklärter Rücksprung 800, Überlauf 550. Bei zweien wich das Ergebnis von
  meiner Erwartung ab, und **beide Male lag die Erwartung falsch**, nicht der
  Code: Nach einem unerklärten Rücksprung zählt `PulseCore` weiter, statt zu
  verwerfen, und beim Überlauf hatte ich schlicht falsch addiert.
- Der Wechsel einmal wirklich durchgeklickt, hell und dunkel: Verbrauch bleibt
  bei 1.607 kWh, der Stand springt von 49.157,4 auf 42. Zwischen Endstand und
  Anfangsstand vergeht kein Verbrauch — richtig so.

## 0.23.0 — 2026-08-06

**Zählerwechsel.** Der Erfassungsschirm fragte seit jeher „Wurde der Zähler
gewechselt, oder hat sich eine Ziffer verirrt?" — und nahm die Antwort nicht
entgegen. Eine Frage ohne Antwortmöglichkeit ist eine Sackgasse, und die sind
in diesem Produkt ausgeschlossen (Produktprinzip 4). `MeterDevice`,
`Reading.deviceID` und `MeteringPoint.device(on:)` lagen im Rechenkern seit
dem ersten Tag bereit; die App benutzte davon nichts.

Ein Wechsel ist kein Randfall: Netzbetreiber tauschen turnusmäßig, und beim
Einbau eines digitalen Zählers fängt der Stand wieder bei null an.

### Hinzugefügt
- **Ein Wechselschirm mit zwei Zahlen** — Endstand des alten Geräts,
  Anfangsstand des neuen, dazu die Gerätenummer. Zwei und nicht eine: Ein
  Wechsel ist kein Nullsetzen. Beide Stände beschreiben denselben Moment, und
  nur mit beiden bleibt der Verbrauch bis zum Wechseltag erhalten.
- **Zwei Einstiege.** Im Erfassungsschirm erscheint „Der Zähler wurde
  gewechselt", sobald der neue Stand unter dem alten liegt — genau dort, wo
  die Frage steht. Und im Zählereditor, für den, der es einträgt, während der
  Monteur noch da ist.
- Jede neue Ablesung trägt jetzt die Kennung des verbauten Geräts. Ohne sie
  risse die Kette nach dem Wechsel wieder: Der Rechenkern erkennt den
  erklärten Rücksprung nur, wenn **beide** benachbarten Ablesungen wissen, auf
  welchem Gerät sie entstanden sind.

### Entschieden
- **Die Zeitstempel der beiden Stände werden von Hand gesetzt.** Beide liegen
  am selben Tag, und dann entscheidet `createdAt` über die Reihenfolge.
  Zweimal `Date()` kann denselben Augenblick liefern, und Swifts `sorted` ist
  **nicht stabil** — die Reihenfolge wäre undefiniert gewesen. Stünde der
  Anfangsstand vor dem Endstand, sähe der Rechenkern einen Absturz von 50.600
  auf 0. Eine Prüfung hält fest, dass die umgekehrte Reihenfolge tatsächlich
  ein anderes Ergebnis liefert — sonst prüfte der Zeitstempel nichts.
- **Vor dem ersten Wechsel wird das ausgebaute Gerät nachgetragen**, mit der
  ersten Ablesung als Einbaudatum. Alte Ablesungen behalten ihre leere
  Kennung; der Übergang von leer auf gesetzt ist ein normaler Zuwachs. Eine
  Prüfung deckt genau diese Kette ab — die bestehende setzte eine Historie
  voraus, in der jede Ablesung schon ein Gerät kennt, und so sieht kein
  gewachsener Bestand aus.

### Offen und benannt
- **Der Entwurf bildet den Wechsel noch nicht ab.** Er interpoliert direkt auf
  den Zählerständen, während `PulseCore` über eine aufsummierte Reihe rechnet.
  Ein Rücksprung machte dort jeden Verbrauch negativ. Nachzuziehen heißt, im
  Entwurf zuerst dieselbe kumulative Reihe einzuführen — ein Umbau seines
  Kerns, kein Zusatz, und deshalb nicht nebenbei am Ende einer Runde. Es ist
  der nächste Schritt am Entwurf, bevor eine weitere Fähigkeit dazukommt.

`PulseCore` steht bei 129 Prüfungen.

## 0.22.4 — 2026-08-06

### Behoben
- **Ein abgebrochener Lauf hinterließ keine Spur.** Die Korrektur aus 0.21.5
  leitete die gesamte Ausgabe in eine Datei und gab die Begründungen nur im
  **Fehlerzweig** aus. Ein Lauf, der abgebrochen wird statt fehlzuschlagen,
  erreicht diesen Zweig nie — auf der Konsole stand dann nichts, und ohne
  Zugriff auf die Artefakte war nicht einmal zu sehen, wie weit er gekommen
  war. Eine Blindstelle gegen eine andere getauscht.

  Jetzt über `tee`: Die Datei bleibt vollständig, und auf der Konsole läuft
  mit, welche Prüfung gerade lief. Der Exitcode kommt über `PIPESTATUS`
  durch — gegengeprüft mit einem Versuchsaufbau, der 65 zurückgibt.

### Bemerkenswert
- Drei Läufe hintereinander sind an GitHubs Infrastruktur gescheitert, nicht
  am Code: „Failed to resolve action download info. Service Unavailable",
  zweimal noch vor `actions/checkout`, einmal als Abbruch mitten in den
  Oberflächentests. Der letzte inhaltlich vollständige Lauf ist 39 auf
  0.22.1 — grün.

## 0.22.3 — 2026-08-06

### Behoben
- **Die Abschlagsvorschau rechnete beim PV-Zähler, als gäbe es die Anlage
  nicht.** Sie bekam nur die Ablesungen des Bezugs; die Einspeisung fiel
  stillschweigend weg. Aufgefallen ist es daran, dass auf der Karte **auf den
  Cent** derselbe Wert stand wie vor der Einrichtung — 90,30 € Guthaben —
  während der Entwurf an derselben Stelle 283 € zeigte. Ohne den Abgleich mit
  dem Klick-Dummy wäre die Zahl plausibel durchgegangen.

### Entschieden
- **Die beiden Ablesungslisten heißen jetzt `primary` und `everything`.**
  Beide hießen `readings`, und beim Umstellen auf den Zweirichtungszähler habe
  ich an einer von vier Stellen die falsche stehenlassen. Ein Name, der die
  Verwechslung nicht bemerkbar macht, ist ein Fehler, der auf seine
  Gelegenheit wartet. Menge, Stand und Vorjahresvergleich gehören zum Bezug —
  sonst stünde bei einem PV-Zähler der Einspeisestand auf der Karte. Kosten,
  Vorschau und Einspeisezeile gehören zur Messstelle.

### Bemerkenswert
- Der Grundpreis läuft über den Zeitraum **bis heute**, der Arbeitspreis nur
  über den abgelesenen. Beim Stromzähler sind das fünf Tage und 2,12 € — die
  Kostenzeile heißt „bis 1. August" und enthält Grundpreis bis zum 6. Der
  Unterschied ist gewollt: Der Grundpreis läuft auch weiter, wenn niemand
  abliest. Hier festgehalten, damit ihn niemand später als Fehler „korrigiert".

## 0.22.2 — 2026-08-06

Der zweistufige Erfassungsschirm aus 0.22.0 war weder fotografiert noch
geprüft. `-pulse-capture` öffnet den ersten Zähler, und das ist Gas mit einem
einzigen Zählwerk — der neue Ablauf kam auf keinem der zehn Bilder vor.

Das ist dieselbe Lücke wie beim Zähler-Schirm in 0.21.4, nur eine Ebene
tiefer: Ein Ablauf, den niemand ansieht, ist einer, in dem sich ein Fehler
beliebig lange hält. Heute haben Bildschirmfotos vier Fehler gefunden, drei
davon in derselben Stunde.

### Hinzugefügt
- `-pulse-capture-pv` öffnet die Erfassung beim Zweirichtungszähler. Zwei
  weitere Bilder je Lauf, hell und dunkel — damit sind es zwölf.
- Zwei Oberflächenprüfungen: der Weg über beide Zählwerke („Bezug", „Weiter",
  „Einspeisung", „Sichern") und die Einspeisezeile auf der Karte.

### Behoben
- Über `testCostIsLabelledWithThePeriodItCovers` standen seit 0.21.5 zwei
  Dokumentationskommentare übereinander — beim Ersetzen der Funktion war der
  alte stehengeblieben.

## 0.22.1 — 2026-08-06

Zwei Fehler aus 0.22.0, beide vom ersten Bildschirmfoto gefunden, das den
neuen Zähler zeigte. Auf der Stromkarte stand „Einspeisung 2.086 kWh ≈ 79,02 €
vergütet" — bei 8,2 ct hätten es 171 € sein müssen. Die Differenz war beide
Male derselbe Betrag: ein Grundpreisanteil von 89,90 €.

### Behoben
- **Ein Zweirichtungszähler zahlte den Grundpreis zweimal.** Die Rechnung über
  eine ganze Messstelle summierte die Grundpreise ihrer Zählwerke. Der
  Grundpreis gehört aber zum Anschluss, nicht zum Zählwerk — ein Gerät bekommt
  eine Rechnung. Gezählt wird jetzt je Tarifabschnitt: dieselbe Tarifkennung
  im selben Zeitraum ist derselbe Grundpreis. Zwei Zählwerke mit **eigenen**
  Tarifen behalten dagegen jeder seinen; eine zweite Prüfung hält das fest,
  damit die Korrektur nicht ins Gegenteil überschießt.
- **Die Einspeisevergütung auf der Karte nahm den Gesamtbetrag statt des
  Arbeitspreisanteils.** In `total` steckt auch der Grundpreis, und der wurde
  dadurch von der Gutschrift abgezogen.

### Bemerkenswert
- **Der Entwurf hatte hier recht und der Rechenkern unrecht.** Der Klick-Dummy
  rechnet den Grundpreis seit jeher einmal je Zähler. Bisher lief die Prüfung
  meist andersherum — das ist das erste Mal, dass die kürzere Fassung die
  gründlichere geschlagen hat.
- Beide neuen Prüfungen schlagen auf der alten Fassung fehl: 240 € statt 120 €
  Grundpreis, 500 € statt 380 € gesamt. Ein Test, der auch vorher grün gewesen
  wäre, hätte nichts bewiesen.

## 0.22.0 — 2026-08-06

**Photovoltaik.** Der Rechenkern konnte Zweirichtungszähler seit dem ersten
Tag, der Entwurf zeigte sie — nur die App kannte sie nicht. Wer eine PV-Anlage
hat, konnte seinen Zähler damit gar nicht abbilden, und in Deutschland ist das
längst keine Randgruppe mehr.

### Hinzugefügt
- **Ein Schalter „Einspeisung ins Netz"** im Zählereditor, sichtbar nur bei
  Strom. Dazu ein Feld für die Einspeisevergütung.
- **Der Erfassungsschirm fragt nacheinander nach beiden Zahlen** — erst Bezug,
  dann Einspeisung, mit „Weiter" statt „Sichern" dazwischen. Keine Auswahl
  davor: Wer vor dem Zähler steht, liest beide Zahlen in einem Zug ab; eine
  Auswahl hieße erst entscheiden, dann tippen, dann noch einmal öffnen.
- **Die Übersichtskarte zeigt die Einspeisung** mit Menge und Vergütung, und
  zwar **über** den Kosten: Der Betrag darunter ist bereits netto.
- Der Ausgangszustand enthält jetzt einen Stromzähler mit PV — sonst sähe
  weder ein Bildschirmfoto noch ein Test den Fall je.

### Behoben
- **Die Abschlagsvorschau rechnete bei PV systematisch falsch.** Sie nahm die
  Nettokosten der ganzen Messstelle — Bezug minus Vergütung — und skalierte
  sie mit dem Hochrechnungsfaktor des **Bezugs**. Das stimmt nur, wenn beide
  Zählwerke denselben Ausschnitt abdecken; Bezug und Einspeisung laufen aber
  gegenläufig durchs Jahr. Im August ist der Bezug fast durch, die Einspeisung
  noch lange nicht. Es ist die wiederkehrende Fehlerklasse aus CLAUDE.md, zum
  neunten Mal: eine Aussage über einen Zeitraum, den die Zahl nicht abdeckt.
  Jedes Zählwerk bekommt jetzt seine eigene Hochrechnung.

  Zwei Prüfungen halten das fest; die eine schlägt auf der alten Fassung mit
  483,98 € gegen erwartete 422,81 € fehl. Nachgerechnet von Hand — und die
  erste Handrechnung war falsch, nicht der Rechenkern.
- **Der Entwurf rechnete die Abschlagsvorschau brutto**, während die
  Kostenzeile derselben Karte netto war. Zwei Zahlen nebeneinander, die sich
  widersprachen. Beim Stromzähler springt das Guthaben dadurch von 90 € auf
  283 € — 193 € hochgerechnete Jahresvergütung, von denen bis zum 1. August
  134 € aufgelaufen sind. 69 % des Jahresertrags bis Ende Juli, für eine
  PV-Anlage die richtige Größenordnung.
- **Zwei Ablesungen desselben Geräts werden zusammen festgeschrieben.** Bisher
  sicherte der Speicher jeden Wert einzeln; ein Fehler beim zweiten Zählwerk
  hätte den ersten allein stehen lassen. Er sähe aus wie eine vollständige
  Ablesung, und der Rechenkern bildete daraus einen Verbrauch für einen
  Zeitraum, in dem die Gegenrichtung fehlt.

### Entschieden
- **Die Einspeisung lässt sich nicht mehr abschalten, sobald Werte dafür
  vorliegen.** Der Schalter ist dann gesperrt, mit Begründung. Ein Zählwerk zu
  entfernen, an dem Ablesungen hängen, hieße Daten zu verlieren, die der
  Nutzer selbst eingetragen hat.
- **Kein Wort über Zählwerke in der Oberfläche.** Der Nutzer sieht ein Gerät
  mit zwei Zahlen darauf, und genau so steht es da: „Für Zähler, die in beide
  Richtungen zählen." Beim Zweirichtungszähler heißt das erste Zählwerk
  „Bezug" — allein wäre das Wort nichtssagend, neben „Einspeisung" sagt es
  alles.

## 0.21.5 — 2026-08-06

### Behoben
- **Ein Oberflächentest hielt die falsche Formulierung fest.** Er prüfte auf
  den Wortlaut „Kosten seit Jahresbeginn" und ist deshalb an der Korrektur aus
  0.21.4 zerbrochen — zu Recht. Er prüft jetzt die Eigenschaft statt des
  Satzes: dass eine Kostenzeile da ist, dass ein Betrag dabeisteht, und dass
  beim überfälligen Zähler ein Enddatum genannt wird. Bewusst als vorhandene
  Aussage und nicht als fehlende: Am Ersten eines Monats wäre „seit
  Jahresbeginn" beim Stromzähler richtig, und eine Verneinung hinge am
  Kalender.
- **Die CI verschwieg, warum eine Prüfung gefallen ist.** `-quiet` nennt die
  Namen der gefallenen Tests, aber keine Begründung. Ein Lauf, der „testX ist
  gefallen" sagt und den Grund für sich behält, kostet zwanzig Minuten fürs
  Raten — genau das ist heute einmal passiert. Das Protokoll geht jetzt
  vollständig in eine Datei, und bei einem Fehlschlag stehen die Begründungen
  auf der Konsole. Die Datei liegt zusätzlich im Artefakt.

### Geändert
- Die Roadmap stand auf 0.9.0 und behauptete, `PulseUI` und der
  Erfassungsschirm seien offen. Sie führt jetzt den tatsächlichen Stand — und
  eine Tabelle, die nebeneinanderstellt, was der Rechenkern kann und was die
  App davon anbietet. Dieser Abstand ist der gefährlichste Zustand im Projekt:
  Er sieht in den Tests grün aus und ist trotzdem nicht da. Am größten ist er
  beim Zweirichtungszähler — `PulseCore` rechnet die Einspeisung seit dem
  ersten Tag, der Entwurf zeigt sie, die App kennt sie nicht.

## 0.21.4 — 2026-08-06

Die erste Runde, in der die zurückgeholten Screenshots wieder Fehler gefunden
haben — beide in derselben Stunde, in der sie wieder sichtbar wurden.

### Behoben
- **„Kosten seit Jahresbeginn" stimmte nicht.** Auf der Karte des Gaszählers
  stand am 6. August der Zeitraum „1. Januar bis 1. Mai" — richtig, denn seit
  dem 1. Mai gab es keine Ablesung. Zwei Zeilen tiefer standen 1.399,41 €
  „seit Jahresbeginn". Drei Monate, die der Betrag nicht enthält. Die Zahl war
  richtig, der Satz darüber nicht; es ist die wiederkehrende Fehlerklasse aus
  CLAUDE.md, diesmal in der Beschriftung statt in der Rechnung. Die Zeile
  nennt jetzt denselben Ausschnitt wie die Kopfzeile der Karte.
- **Die Bildschirmfotos hingen voneinander ab.** `-pulse-reset` wurde in
  `OverviewView` ausgewertet, und SwiftUI baut einen Tab erst, wenn er
  sichtbar wird. Ein Lauf, der direkt im Zähler-Schirm begann, erreichte diese
  Stelle nie und zeigte, was der vorherige Start hinterlassen hatte — nach
  `-pulse-empty` also „Noch kein Zähler", während die Übersicht drei Zähler
  führte. Der Verlauf-Schirm war nur durch die Reihenfolge zufällig richtig.
  Der Ausgangszustand entsteht jetzt in `LaunchFixture` beim Start der App.

### Entschieden
- **Ein fehlgeschlagener Ausgangszustand bricht ab, statt weiterzulaufen.**
  Stillschweigend leer weiterzumachen sähe auf dem Bild aus wie der Kaltstart
  — also wie ein gültiger Zustand. Genau daran wäre der Fehler wieder
  unsichtbar. Erreichbar ist die Stelle nur über einen Startschalter, den kein
  Nutzer setzt.

### Geändert
- Der Klick-Dummy zeigt jetzt ebenfalls Stand und Kosten auf der Karte. Beide
  Zeilen gab es bisher nur in der App — und es waren ausgerechnet die zwei,
  an denen der Beschriftungsfehler saß. Im Entwurf hätte ihn niemand sehen
  können, weil es sie dort nicht gab.
- Die Einspeisung steht im Entwurf **über** den Kosten, nicht darunter: Der
  Betrag ist bereits netto. Darunter zöge jeder Leser die Vergütung ein
  zweites Mal ab.
- Der Hinweis über der Übersicht sagt im Entwurf „Vorschau" statt „Prognose",
  wie in der App.

## 0.21.3 — 2026-08-06

Keine Produktänderung — eine Prüfung, die verlorengegangen war, ist wieder da.

### Hinzugefügt
- **Die Screenshots jedes Laufs liegen jetzt im Zweig `screenshots`.** Bisher
  gab es sie nur als Artefakt, und an ein Artefakt komme ich aus der
  Entwicklungsumgebung heraus nicht heran: Der Weg zur GitHub-API ist dort
  gesperrt, git dagegen läuft. Damit war die produktivste Prüfung dieses
  Projekts stillschweigend ausgefallen — sieben der bisher gefundenen
  Darstellungsfehler hat kein Test gefunden, sondern der Blick auf ein Bild.
- `scripts/publish-shots.sh` verkleinert die zehn Bilder auf 1000 Pixel Höhe
  und legt sie als JPEG ab. Aus über drei Megabyte werden rund dreihundert
  Kilobyte; für Anordnung, Kontrast und Zahlen reicht das bei weitem.

### Entschieden
- **Der Zweig trägt immer nur einen Stand.** Ein frisch angelegtes Repository
  wird mit `--force` geschoben, damit weder Historie noch Objektlager wachsen.
  Wer einen älteren Stand braucht, findet ihn im Artefakt des jeweiligen Laufs.

### Behoben
- Die README behauptete, Verlauf und Zähler seien Platzhalter. Das stimmt seit
  0.18.0 nicht mehr — beide sind vollwertige Bildschirme.

## 0.21.2 — 2026-08-06

### Behoben
- **Die Erinnerungen ließen sich immer noch nicht übersetzen — und meine
  Diagnose in 0.21.1 war falsch.** Nicht die Rückgabewerte waren das Problem,
  sondern das `@MainActor` am Typ `Reminders`. Es ordnet `center` dem
  Hauptakteur zu, und weil die Methoden von `UNUserNotificationCenter` nicht
  isoliert sind, wird **jeder** Aufruf zum Grenzübertritt — auch der, bei dem
  nur der Empfänger hinübergereicht wird (`sending 'self.center' risks causing
  data races`). Die Rückrufe aus 0.21.1 haben ein Symptom kuriert.

### Entschieden
- **Ein Typ, der nur eine threadsichere Systemschnittstelle umhüllt, bekommt
  keine Isolation.** `UNUserNotificationCenter` ist selbst threadsicher;
  `@MainActor` darüberzulegen macht die Sache nicht sicherer, sondern nur
  unübersetzbar. `Reminders` reicht jetzt ausschließlich `Sendable`-Werte
  heraus — Status als Aufzählung, Anzahl als Zahl —, und die Oberfläche wartet
  vom Hauptakteur aus darauf. Die Begründung steht im Kopf der Datei, damit
  der dritte Anlauf nicht nötig wird.

## 0.21.1 — 2026-08-06

### Behoben
- **Die Erinnerungen aus 0.21.0 ließen sich nicht übersetzen.**
  `UNNotificationSettings` und `[UNNotificationRequest]` sind nicht
  `Sendable`; unter Swift 6 dürfen sie die Isolationsgrenze nicht überqueren,
  und ein `await` vom Hauptakteur aus scheitert daran. Jetzt läuft beides über
  den Rückruf, und herüber kommt nur, was unbedenklich ist: der Status als
  Aufzählung und die Anzahl als Zahl.

Diese Fehlerklasse kann ich unter Linux nicht finden — `UserNotifications`
gibt es dort nicht, und `PulseCore` allein zu übersetzen sagt darüber nichts.
Sie fällt erst auf dem macOS-Läufer auf.

## 0.21.0 — 2026-08-06

**Erinnerungen.** Der Retention-Motor: Ohne sie kommt niemand nach drei
Monaten zurück, und dann laufen alle anderen Funktionen leer — der Verlauf
bleibt kurz, der Vorjahresvergleich entsteht nie, die Abschlagsvorschau rechnet
ins Blaue.

### Hinzugefügt
- `ReminderEngine` in `PulseCore` mit neun Prüfungen. Rechnet aus, wann ein
  Zähler wieder abgelesen werden sollte.
- Lokale Mitteilungen, abends um 18 Uhr im Rhythmus jedes Zählers. Ohne Konto,
  ohne Server, ohne Netz.
- Ein Schalter auf dem Zähler-Schirm statt in Einstellungen: Dort denkt der
  Nutzer ohnehin über Ableserhythmen nach, und die Systemfrage nach Erlaubnis
  wird nur **einmal** gestellt — sie soll in einem Moment kommen, in dem klar
  ist, wofür.
- Nach jeder Ablesung werden die Termine neu geplant. Eine stehengebliebene
  alte Mitteilung käme sonst, wenn längst nichts mehr fällig ist.

### Entschieden
- **Fälligkeit auf dem Schirm und Erinnerung rechnen jetzt über dieselbe
  Funktion.** Vorher waren es zwei getrennte Rechnungen für dieselbe Frage;
  die laufen früher oder später auseinander, und dann kommt eine Mitteilung,
  während auf dem Schirm nichts fällig ist. Ein Test prüft an sieben Tagen um
  die Grenze herum, dass beide dieselbe Antwort geben.
- **Ein überfälliger Zähler wird heute erinnert, nicht rückwirkend.** Eine
  Mitteilung für einen vergangenen Tag lässt sich nicht zustellen — der Zähler
  bliebe für immer stumm, und zwar genau der, der die Erinnerung am nötigsten
  hat.
- **Höchstens 32 Termine gleichzeitig.** iOS nimmt 64 lokale Mitteilungen an;
  wer sehr viele Zähler führt, bekäme sonst irgendwann keine mehr, und welche
  wegfallen, entschiede das System statt der App.
- **18 Uhr, nicht morgens.** Ein Zählerstand wird abgelesen, wenn jemand zu
  Hause ist und in den Keller gehen kann.

### Behoben
- `ReminderEngine.schedule` war als verkettete Ausdrucksfolge geschrieben, an
  der der Typprüfer über zwei Minuten rechnete und dann aufgab. Mit benannten
  Zwischenschritten übersetzt dasselbe in Sekunden.

## 0.20.0 — 2026-08-06

### Hinzugefügt
- **Menge / Kosten** in der Verlaufstabelle. Der Umschalter erscheint nur,
  wenn für den Zähler ein Tarif hinterlegt ist — ohne Preise gäbe es nichts
  umzuschalten.
- Nur in der Tabelle, nicht im Diagramm: Ein Balken, der mal kWh und mal Euro
  bedeutet, sieht in beiden Fällen gleich aus. In einer Tabelle steht die
  Einheit in der Kopfzeile, und der Oberflächentest prüft genau das —
  Euro-Beträge dürfen nicht unter „Verbrauch" stehen.
- Abschnitte ohne verwertbaren Tarif bleiben in der Kostenspalte leer statt
  null, und die Summe darunter sagt „unvollständig". Eine Null wäre die
  Aussage „hat nichts gekostet", die niemand gemacht hat.

### Behoben
- **Jeder Push löste zwei CI-Läufe aus**, solange eine Pull-Request offen war:
  einmal `push`, einmal `pull_request`. Beide lagen in verschiedenen
  Nebenläufigkeitsgruppen und bauten dieselbe App zweimal. Die Gruppe ist
  jetzt auf den Zweignamen normalisiert.

### Geändert
- Der Arbeitszweig ist nach dem Zusammenführen frisch von `main` aufgesetzt.

_Am Klick-Dummy ändert sich nichts: Menge und Kosten gibt es dort seit 0.9.
Diesmal hat die App aufgeholt, nicht der Entwurf._

## 0.19.1 — 2026-08-06

### Behoben
- **Der Abschlag auf der Karte war zu klein.** Bei 160 € im Monat stand dort
  „Abschlag 1.146,74 € im Jahr" — sieben Zwölftel. Ich hatte
  `runningBillingPeriod` verwendet, das den Zeitraum **am heutigen Tag
  abschneidet**, wo der ganze Abrechnungszeitraum gemeint war. Die Folge war
  nicht nur eine falsche Beschriftung: Hochgerechnete Jahreskosten wurden
  gegen sieben Monate Abschlag gestellt, und aus einem Guthaben wurde eine
  Nachzahlung. Es ist die wiederkehrende Fehlerklasse aus CLAUDE.md in neuem
  Gewand — eine Aussage über einen Zeitraum, den die Zahl nicht abdeckt.
  `MeteringPoint.currentBillingPeriod(on:)` liefert jetzt den ganzen Zeitraum,
  und der Unterschied zu `runningBillingPeriod` ist in beiden Dokumentationen
  benannt.
- **Ein volles Jahr ergab 12,03 Monate.** `lengthInMonths` zählte über
  `dayCount` und damit beide Grenztage. Ein Abrechnungszeitraum ist aber
  halboffen — der nächste Stichtag gehört zum Folgejahr, so wie
  `BillingCycle.period(containing:)` ihn auch liefert. Aus zwölf Abschlägen zu
  160 € wurden dadurch 1.925,26 € statt 1.920 €. Auf einer Karte, die Geld
  anzeigt, ist das der Unterschied zwischen „stimmt" und „stimmt fast".

### Geändert
- Die Testvorrichtung für Abrechnungsjahre lief bisher vom 1. Januar bis zum
  **31. Dezember** und damit über 364 Tage. Jetzt bis zum 1. Januar, wie jede
  Verbrauchsrechnung im Projekt einen Zeitraum versteht. Neun Erwartungswerte
  haben sich dadurch um einen Tag verschoben; alle neun sind nachgerechnet:
  365 Tage × 10 kWh = 3.650, davon 30 % = 1.095 €, gegen 1.200 € Abschlag
  ergibt 105 € Guthaben.
- Der Gas-Abschlag in den Beispieldaten steht auf 230 € statt 160 € — bei
  diesem Verbrauch war der alte Wert unrealistisch niedrig und erzeugte eine
  Nachzahlung, die nur aus der Vorrichtung stammte.

Zwei neue Prüfungen halten die Unterscheidung fest, damit sie nicht wiederkommt.

## 0.19.0 — 2026-08-06

Der Abschlag — und damit die Frage, für die Verbrauchszahlen überhaupt
interessieren: Kommt am Jahresende Geld zurück oder muss ich nachzahlen?

### Hinzugefügt
- **Abschlag und Abrechnungsjahr im Zähler-Editor.** Der Monat, in dem das
  Abrechnungsjahr des Versorgers beginnt, ist wählbar — bei vielen ist es
  nicht der Januar.
- **„≈ 168 € Nachzahlung" auf der Karte**, sobald ein Abschlag hinterlegt ist.
  Das „≈" steht dort, weil die Zahl den restlichen Zeitraum hochrechnet und
  nicht misst (Produktprinzip 7).
- Ein Oberflächentest, der die längste Kette der App abgeht: Ablesungen →
  Hochrechnung → Kosten je Tarifabschnitt → gegen die Abschläge. Er prüft
  zusätzlich, dass der Wasserzähler **ohne** Abschlag auch keine Vorschau
  zeigt — eine Null wäre dort eine Aussage, die niemand gemacht hat.
- Der Abschlag lässt sich auch im Klick-Dummy eintragen. Gegengerechnet: 60 €
  mehr im Monat ergeben 720 € mehr im Jahr, und aus 90 € Guthaben werden 810 €.

### Entschieden
- **Ohne Abschlag bekommt ein Zähler keinen Abrechnungsrhythmus.** Sonst
  entstünden Zeiträume, gegen die es nichts zu rechnen gibt. Bei den
  Beispieldaten läuft Wasser deshalb bewusst ohne — so stehen beide Fälle auf
  demselben Bildschirmfoto nebeneinander.

## 0.18.0 — 2026-08-05

Preise und Kosten. Der Rechenkern (`CostEngine`) stand seit 0.4 und war
getestet — es fehlte der Weg, ihm überhaupt einen Preis mitzuteilen.

### Hinzugefügt
- **Arbeitspreis und Grundpreis im Zähler-Editor.** Zwei Zahlen von der
  Jahresrechnung, freiwillig: Ohne sie funktioniert die App vollständig, nur
  ohne Beträge. Deshalb steht der Abschnitt unten und blockiert nichts.
- **Zustandszahl und Brennwert bei Gas.** Gas wird in m³ gemessen und in kWh
  abgerechnet; ohne diese beiden Zahlen lässt sich aus einem Zählerstand kein
  Betrag bilden. Der Rechenkern verweigert die Auskunft — die Oberfläche sagt
  jetzt, was fehlt, statt ein leeres Feld zu zeigen.
- **Kosten seit Jahresbeginn** auf jeder Übersichtskarte, sobald ein Preis
  hinterlegt ist.
- Die Beispieldaten haben Preise in der Größenordnung einer deutschen
  Jahresrechnung, damit die Kosten auf den Bildschirmfotos auch zu sehen sind.
- Zwei Oberflächentests: Steht mit hinterlegtem Tarif ein Betrag auf der
  Karte, und lässt sich beim neuen Zähler ein Preis eintragen?

### Behoben
- **Der Klick-Dummy konnte die Art eines Zählers nicht erkennen.** Sie stand
  nur implizit in der Kennung, nicht als Feld. Der neue Editor fiel deshalb
  bei jedem Zähler auf „Strom" zurück und zeigte beim Gaszähler weder
  Zustandszahl noch Brennwert. Jeder Beispielzähler trägt seine Art jetzt
  ausdrücklich.

## 0.17.0 — 2026-08-05

Der kalte Start — die App einmal so durchgegangen, wie ein neuer Nutzer sie
antrifft: ohne einen einzigen Zähler, ohne eine einzige Ablesung. Bis hierher
hat diesen Zustand weder ein Test noch ein Bildschirmfoto je gesehen, weil
jeder Lauf mit zwei Jahren Beispielhistorie begann.

Vier Fehler, alle im ersten Bildschirm, den jemand zu Gesicht bekommt.

### Behoben
- **Die Statuszeile meldete „Alles im Rahmen. Alle Zähler sind aktuell." für
  einen Zähler, der noch nie abgelesen wurde.** Die Bedingung fragte nach den
  Tagen seit der letzten Ablesung; ohne Ablesung gibt es die nicht, und der
  Fall fiel stillschweigend durch. Jetzt steht dort „… wurde noch nie
  abgelesen. Trag den ersten Stand ein, dann fängt der Verlauf an."
- **Auf der Karte stand aus demselben Grund „Noch kein Vergleichswert"**,
  obwohl „Noch nie abgelesen" gemeint war.
- **Der Verlauf zeigte „0" für einen Zähler ohne Historie** — eine Zahl, die
  aussieht wie eine Messung und keine ist. Jetzt steht dort, was fehlt: die
  erste Ablesung, oder die zweite.
- **Der leere Zustand bot „Beispieldaten anlegen" als einzige Möglichkeit an.**
  Entwicklersprache an genau der Stelle, an der ein neuer Nutzer zum ersten
  Mal etwas tut. Die Hauptsache heißt jetzt „Ersten Zähler anlegen" und führt
  direkt dorthin; die Beispieldaten bleiben als kleine Nebenzeile.

### Hinzugefügt
- Mit genau einer Ablesung sagt die Karte, was fehlt: „Der Verbrauch ergibt
  sich aus zwei Ablesungen." Für den Rechenkern sind null und eine Ablesung
  derselbe Fall — für den Nutzer nicht.
- Zwei Oberflächentests, die den ganzen Weg abgehen: leerer Start, Zähler
  anlegen, erste Ablesung eintippen, und die Karte muss den zweiten Schritt
  nennen. Das ist Produktprinzip 1 als ausführbare Prüfung.
- Bildschirmfotos vom leeren Zustand (`-pulse-empty`).
- Derselbe leere Zustand im Klick-Dummy, erreichbar durch Löschen aller
  Zähler. Vorher blieb die Übersicht dann einfach leer.

### Geändert
- Das Zeitlimit der CI steht auf 45 Minuten. Zehn Bildschirmfotos brauchen auf
  dem Läufer gut 16 Minuten, und mit dem Build wurden die 30 zu knapp.

## 0.16.1 — 2026-08-05

### Behoben
- **Ein deutsches Anführungszeichen zerriss eine Swift-Zeichenkette.** In
  `„Strom"` schließt das gerade Anführungszeichen das Literal — richtig ist
  das typografische `„Strom“`. Die App ließ sich nicht übersetzen; gefunden
  hat es der CI-Lauf nach zwei Minuten auf einem gemieteten macOS-Läufer.

### Hinzugefügt
- `scripts/check-strings.py`, als erster Schritt in der CI. Prüft in einer
  Sekunde, was sonst einen ganzen Lauf kostet. Die erste Fassung zählte nur
  Anführungszeichen je Zeile und fand den eigenen Anlassfall nicht — die
  Zeichen ergänzten sich zufällig zu einer geraden Zahl. Jetzt wird geprüft,
  was tatsächlich schiefgeht: ein `„` innerhalb einer Zeichenkette, das von
  einem geraden Anführungszeichen geschlossen wird.

Ohne Compiler für iOS-Code unter Linux ist die CI der einzige Ort, an dem
solche Fehler auffallen — und der teuerste. Diese Klasse fällt jetzt vorher.

## 0.16.0 — 2026-08-05

Der **Zähler**-Tab ist kein Platzhalter mehr. Damit ist die App zum ersten Mal
ohne Beispieldaten benutzbar — vorher kam man überhaupt nur über
„Beispieldaten anlegen" zu einem Zähler, und Produktprinzip 1 (60 Sekunden bis
zur ersten Ablesung) hing an einer Ansicht, die es nicht gab.

### Hinzugefügt
- Zähler anlegen, umbenennen und einordnen. Name und Art genügen; Einheit,
  Stellenzahl und Ableserhythmus sind aus der Art vorbelegt.
- Archivieren und Löschen als getrennte Wege. Archivieren nimmt den Zähler aus
  der Übersicht und behält alles; Löschen entfernt auch die Ablesungen und
  fragt vorher nach.
- Ein Oberflächentest, der einen Zähler anlegt und in der Liste wiederfindet.
- Bildschirmfotos vom Zähler-Tab (`-pulse-zaehler`).

### Behoben
- **Der Klick-Dummy stürzte ab, sobald ein Zähler ohne Ablesung existierte.**
  `lastReading` lief über eine leere Liste und gab `undefined` zurück, woran
  die nächste Zeile zerbrach. Aufgefallen ist das erst jetzt: Bis eben hatte
  jeder Zähler im Entwurf zwei Jahre Historie, und den Fall „noch nie
  abgelesen" gab es schlicht nicht — obwohl er für jeden neuen Nutzer der
  erste ist.

### Entschieden
- **Die Art eines Zählers lässt sich nicht mehr ändern, sobald Ablesungen
  vorliegen.** Sie bestimmt die Einheit, und ein nachträglicher Wechsel würde
  bestehende Werte stillschweigend umdeuten — aus 8.285 m³ Gas würden 8.285
  kWh Strom. Die Oberfläche sagt, warum es gesperrt ist, statt es nur zu
  verbieten.

## 0.15.1 — 2026-08-05

### Behoben
- **Das Verlaufsdiagramm zeigte zwölf Balken, wo es vier gibt.** Hinter jedem
  Monat stand eine hohe helle Spur. Auf dem ersten Bildschirmfoto des Verlaufs
  las sich das Jahr dadurch als zwölf Balken, von denen vier farbig waren —
  tatsächlich hat der Gaszähler seit Mai keine Ablesung. Statt der Spuren gibt
  es jetzt eine durchgehende Grundlinie; ein Abschnitt ohne Ablesung zeigt
  nichts. Der ausgewählte Abschnitt bekommt eine blasse Fläche, damit ein Tipp
  auf einen leeren Monat sichtbar bleibt.
- Die Legende erklärte „unvollständig" auch dann, wenn kein Abschnitt
  angebrochen war, und nannte in der Jahresansicht ein Vorjahr, das dort als
  eigener Balken steht.

Wieder ein Fund aus dem Bild, nicht aus einem Test: Die Zahlen waren richtig,
die Form log.

## 0.15.0 — 2026-08-05

Alle Zahlen und der Export — die Ansicht, nach der du früh gefragt hattest
(„gesamtzahl pro jahr, monat, quartal und exports").

### Hinzugefügt
- Umschalter **Diagramm / Alle Zahlen** im Verlauf. Die Tabelle listet jeden
  Abschnitt mit Verbrauch und Gesamtsumme; unvollständige Abschnitte tragen
  darunter den Ausschnitt, den sie wirklich abdecken.
- **Export als CSV**, Ablesungen und Auswertung getrennt, über das Teilen-Blatt
  des Systems. Semikolon und Dezimalkomma, damit Excel die Datei im
  deutschsprachigen Raum ohne Importdialog öffnet.
- `TableExport` in `PulseCore` mit sieben Prüfungen. Nachgestellte Nullen
  bleiben stehen (`8000,250`), weil ein exportierter Zählerstand ein Beleg ist
  und die Genauigkeit des Geräts zeigen soll.
- Bildschirmfotos vom Verlauf, in Hell und Dunkel (`-pulse-verlauf`).

### Behoben
- **Die Jahresansicht hätte einen einzelnen Balken gezeigt.** Ein Jahr hat
  genau einen Abschnitt — als Diagramm ist das keine Aussage. „Jahr" stellt
  jetzt drei Jahre nebeneinander.
- **Der Export des Klick-Dummys wich von dem der App ab**: andere Spalten,
  abgekürzte Monatsnamen und eine Kreuztabelle statt einer Zeile je Abschnitt.
  Jetzt liefern beide dieselbe Datei. Die Kreuztabelle liest sich schöner,
  kann aber je Zelle nicht sagen, ob ein Abschnitt vollständig ist — und genau
  daran hing in diesem Projekt bisher jeder Fehler.
- **„Zählwerk" stand in der Kopfzeile des Exports.** Eine exportierte Datei
  ist ein Dokument, und für Dokumente gilt dieselbe Wortliste wie für die
  Oberfläche (CLAUDE.md, Abschnitt „Sprache").

## 0.14.1 — 2026-08-05

### Behoben
- **Im Erfassungsschirm stand eine handbreite Leere zwischen Zählwerk und
  Ziffernblock.** Die Korrektur aus 0.13.1 hatte den Block nach unten
  geschoben, das Zählwerk aber oben kleben lassen — ein Fehler gegen einen
  anderen getauscht. Das Zählwerk schwebt jetzt zwischen zwei Abstandhaltern
  über dem Block, wie die Anzeige über den Tasten eines Rechners.

Nur die App. Der Klick-Dummy hatte den Fehler nie: Sein Bogen ist so hoch wie
sein Inhalt, während die App den Schirm ganz füllt und den Platz verteilen
muss.

## 0.14.0 — 2026-08-05

Der **Verlauf** ist kein Platzhalter mehr.

### Hinzugefügt
- Verlauf-Tab in der App: Zählerwahl, Balken je Monat / Quartal / Jahr mit dem
  Vorjahr als Marke im Balken, und die Liste aller Ablesungen hinter einer
  Zeile. Ein Tipp auf einen Abschnitt öffnet den Vergleich über drei Jahre.
- `PeriodEngine` in `PulseCore`: zerlegt eine Zeitreihe in Monate, Quartale
  und Jahre und vergleicht denselben Abschnitt über mehrere Jahre. 14 neue
  Prüfungen.
- Zwei Oberflächentests für den Verlauf.

### Behoben
- **Ein laufender Monat wurde gar nicht verglichen.** Der Klick-Dummy schrieb
  „wird nachgetragen, sobald der Monat abgeschlossen ist" — richtig gerechnet,
  aber genau der Monat, der den Nutzer am meisten interessiert, blieb leer.
  Jetzt wird das Vorjahr auf denselben Ausschnitt beschnitten: halber Februar
  gegen halben Februar, und darunter steht, welcher Ausschnitt gemeint ist.
- **Eine Zahl konnte aus einer Geraden über ein ganzes Jahr stammen und sah
  aus wie eine Messung.** Wer am 1. Februar 2025 und dann erst am 1. Februar
  2026 abliest, bekam für den Februar 2025 einen anteilig ausgeschnittenen
  Jahresschnitt — formal gedeckt, inhaltlich nichts. Ergebnisse führen jetzt
  den größten benutzten Ableseabstand mit, und ein Abschnitt gilt nur als
  vergleichbar, wenn er auf Ablesungen aus seiner Nähe beruht. Die Grenze
  liegt beim Doppelten der Zeitraumlänge — großzügig genug für jeden üblichen
  Ableserhythmus.

Beides fand derselbe Test, der eigentlich nur prüfen sollte, dass ein Jahr mit
halben Daten nicht wie ein sparsames Jahr aussieht.

## 0.13.1 — 2026-08-05

Drei Fehler, alle drei erst auf dem ersten Bildschirmfoto des
Erfassungsschirms zu sehen — er wurde in 0.13.0 überhaupt zum ersten Mal
automatisch fotografiert.

### Behoben
- **„Sichern" war im dunklen Erscheinungsbild kaum zu lesen.** Die gesperrte
  Schaltfläche legte die Akzentfarbe mit 32 % Deckkraft unter helle Schrift —
  im Dunkeln ergab das dunkelbraun auf braun. Gesperrt heißt jetzt gedämpfte
  Fläche mit gedämpfter Schrift, in beiden Erscheinungsbildern lesbar. Im
  Klick-Dummy steckte derselbe Fehler.
- **Ziffernblock und „Sichern" standen im oberen Drittel**, darunter ein
  Drittel leere Fläche. Genau verkehrt herum für einen Schirm, den man
  einhändig im Keller bedient: Was angetippt wird, gehört in Daumenreichweite.
  Beides sitzt jetzt am unteren Rand, auf kleinen Geräten greift weiter der
  Bildlauf.
- **Derselbe Zählerstand stand in zwei Schreibweisen in der App**: auf der
  Übersicht „8.285,1 m³", im Erfassungsschirm „8.285,100 m³". Die Übersicht
  schreibt ihn jetzt mit den Nachkommastellen des Zählwerks — so, wie er am
  Gerät abzulesen ist. Der Klick-Dummy machte das schon richtig.

## 0.13.0 — 2026-08-05

### Behoben
- **Die große Zahl auf der Übersicht sagte nicht, welchen Zeitraum sie
  abdeckt.** Beim Gaszähler stand „1.181 m³" — dieselbe Form wie „1.607 kWh"
  beim Strom, obwohl die eine Zahl bis Anfang Mai reicht und die andere bis
  August. Wer beide Karten untereinander sieht, vergleicht zwangsläufig, und
  der Vergleich war falsch. Gefunden wurde das nicht von einem Test, sondern
  beim Ansehen des Bildschirmfotos: Beide Zahlen waren für sich korrekt
  gerechnet. Es ist der siebte Fall derselben Fehlerklasse und der erste, der
  nicht im Rechenkern lag, sondern in der Anzeige.
- Ohne Daten für das laufende Jahr stand eine „0" da. Jetzt steht ein Strich —
  unbekannt ist nicht dasselbe wie nichts verbraucht.

### Hinzugefügt
- Über jeder großen Zahl steht der Zeitraum, den sie tatsächlich abdeckt:
  „Seit Jahresbeginn", sonst als Spanne wie „1. Januar bis 1. Mai".
  Ausgeschrieben statt als Vorbehalt, weil vier Tage Rückstand normal sind und
  drei Monate nicht — als Spanne ist der Unterschied ohne ein Wort zu sehen.
- Ein „≈" vor Werten, die nicht ausschließlich auf gemessenen Ständen beruhen
  (Produktprinzip 7). Kleiner und blasser als die Zahl gesetzt: Bei einem
  länger geführten Zähler ist es fast immer da, weil der Wert zum 1. Januar
  zwischen zwei Ablesungen liegt.
- `ConsumptionResult.coverage` in `PulseCore` — als Aufzählung, damit ein
  vollständiger `switch` die Oberfläche zwingt, den unvollständigen Fall zu
  beschriften. Ein `if isComplete` ließ sich vergessen, ein fehlender Fall
  übersetzt nicht. Sechs neue Prüfungen, darunter der Gasfall von oben.
- Bildschirmfotos zeigen jetzt auch den Erfassungsschirm, in Hell und Dunkel
  (`-pulse-capture`). Er ist der wichtigste Schirm der App und war auf keinem
  automatisch erzeugten Bild zu sehen.

### Geändert
- Die Bildschirmfotos starten die App mit frischen Beispieldaten. Vorher zeigten
  sie, was die Oberflächentests im Simulator hinterlassen hatten.

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
  räumt eine Ablesung den Hinweis wieder weg?
- Die Oberflächentests setzen den Bestand beim Start zurück. Ohne das hing
  jeder Test davon ab, was der vorherige hinterlassen hat — der Erfassungstest
  trug beim obersten Zähler einen Stand ein und räumte damit genau die
  Fälligkeit weg, die der nächste erwartete. Ein grüner Lauf hätte dann nichts
  über den einzelnen Fall ausgesagt.
- `deleteEverything` im Repository. Wird für den Rücksetzer gebraucht und
  gehört später ohnehin in die Einstellungen.

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
