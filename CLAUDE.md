# Arbeitsweise in diesem Projekt

## Regel 1 — Jede Änderung kommt sofort in den Klick-Dummy

Sobald sich etwas am Produkt ändert — neue Ansicht, geänderter Ablauf, andere
Berechnung, angepasstes Design — wird `docs/prototype/index.html` im selben
Zug aktualisiert und als Artifact neu veröffentlicht.

**Keine Produktänderung wird nur beschrieben.** Wenn sie nicht anklickbar ist,
ist sie nicht fertig.

### Jede Veröffentlichung ist ein **neues** Artifact

Vom Nutzer ausdrücklich so gewünscht und zweimal bestätigt: Ein erneutes
Veröffentlichen auf denselben Pfad ließ sich bei ihm **nicht öffnen** — es kam
eine Anmeldemaske. Ein frisch erzeugtes Artifact geht dagegen sofort auf.

- **Nie** auf einen bereits benutzten Pfad erneut veröffentlichen und **nie**
  den `url`-Parameter verwenden.
- Stattdessen jedes Mal ein neuer Dateiname im Scratchpad:
  `pulsemeter-klickdummy-<n>.html`, fortlaufend hochzählen.
- **Die zurückgegebene URL prüfen.** Ein neuer Dateiname allein genügt nicht:
  Bei `pulsemeter-klickdummy-7.html` kam die URL des vorherigen Standes
  zurück, also eine Aktualisierung statt einer Neuanlage — genau das, was beim
  Nutzer die Anmeldemaske auslöst. Kommt dieselbe URL wie zuletzt zurück, noch
  einmal unter einem deutlich anderen Dateinamen veröffentlichen
  (`entwurf-v0130-zeitraum.html` hat eine frische URL erzeugt) und erst diese
  weitergeben.
- `title` immer identisch setzen: „PulseMeter – Klickbarer Entwurf".
  `favicon` bleibt ⚡. `label` kurz und beschreibend.
- Danach dieselbe Datei nach `docs/prototype/index.html` kopieren und
  mitcommitten — der Container wird irgendwann abgeräumt, das Repo nicht.

Der Preis ist bekannt und in Kauf genommen: Es gibt keinen Versionswähler über
alle Stände hinweg. Ältere Links bleiben gültig und wirken als Momentaufnahmen —
das ist die Historie.

## Regel 1a — Der Link steht in jeder Antwort

Die **neue** URL gehört **an den Anfang jeder Antwort**, in der sich etwas am
Produkt geändert hat. Nicht als Verweis auf das Seitenpanel, nicht am Ende,
sondern als anklickbare Zeile ganz oben:

```
🔗 Klick-Dummy: <URL der soeben erzeugten Veröffentlichung>
```

Die zuletzt gültige URL steht in der README.

Die Datei zusätzlich per SendUserFile mitzuliefern ist nicht nötig, aber auf
Nachfrage sinnvoll: Sie ist in sich geschlossen und läuft ohne Login und ohne
Netz. GitHub Pages scheidet vorerst aus — das Repo ist privat, und Pages setzt
dafür GitHub Pro voraus.

## Regel 1b — Version und Release Notes

Jede Änderung bekommt eine Version und einen Eintrag in `CHANGELOG.md`, und
jede Änderung wird getestet — ohne dass der Nutzer danach fragt. Der Ablauf
steht in `.claude/skills/release-discipline/SKILL.md` und gilt auch für kleine
Änderungen.

## Regel 1c — Teuer Gelerntes kommt in den Baukasten

`.claude/skills/projekt-baukasten/SKILL.md` ist die eine Datei, die das
gesammelte Vorgehen trägt: Aufbau, Dokumentation, Konzeptarbeit, Auslieferung
über einen macOS-Läufer, die Schnittstelle von Apple samt Berechtigungen und
Käufen, die wiederkehrenden Fehlerklassen und die Art zu ermitteln, wenn etwas
nicht geht. Sie ist absichtlich in sich geschlossen und lässt sich in ein
anderes Projekt kopieren.

**Was einen Lauf, einen Bau oder mehr als eine Stunde gekostet hat, wird dort
nachgetragen — im selben Commit wie die Änderung**, ohne dass der Nutzer danach
fragt. Auch die Vermutung, die falsch war. Wird eine Zeile widerlegt, wird sie
geändert, nicht ergänzt.

In ein anderes Vorhaben kommt sie über `scripts/neues-projekt.sh --einrichten`.
Das läuft **einmal** auf einem Rechner und setzt drei Dinge: den Verweis unter
`~/.claude/skills`, eine Regel in `~/.claude/CLAUDE.md` — die wird in jeder
Sitzung gelesen, auch im leeren Ordner — und die Funktion `neu` in der Shell.
Danach fängt ein Vorhaben mit `neu <name>` an, und das Gerüst steht.

Eine Cloud-Sitzung liest `~/.claude` **nicht**. Sie sieht nur das geklonte
Repository — dort liegt der Baukasten dann aber schon, weil das Aufsetzen ihn
hineinschreibt.

## Regel 2 — Der Prototyp rechnet echt

Der Klick-Dummy enthält eine verkürzte Fassung von `PulseCore` in JavaScript.
Er zeigt keine Platzhalterzahlen, sondern rechnet mit echten Zeitreihen über
drei Jahre. Das ist Absicht: Bisher hat jede Runde am Prototyp einen echten
Fehler im Rechenkern aufgedeckt, den kein ausgedachter Unit-Test gefunden hätte.

Ändert sich Logik in `PulseCore`, wird sie im Prototyp nachgezogen — und
umgekehrt. Weichen beide voneinander ab, ist das ein Fehler, kein Zustand.

## Regel 3 — Nichts gilt als fertig ohne Prüfung

**Ein Befehl deckt alles ab, was auch die CI prüft:**

```bash
scripts/pruefen.sh            # alles — auf einem Mac in ein bis zwei Minuten
scripts/pruefen.sh schnell    # ohne App-Build, in Sekunden
scripts/pruefen.sh --nur zurueck   # eine einzelne Oberflächenprüfung
```

Auf einem frisch übernommenen Mac steht davor `scripts/mac-start.sh`: Es holt
zuerst den aktuellen Stand und ruft dann die Einrichtung und diese Prüfung auf.
Der Schritt existiert, weil ein Arbeitsverzeichnis auf einem veralteten Zweig
vollständig aussieht — eine Sitzung hat so 0.30.1 geprüft und für den aktuellen
Stand gehalten.

Das Skript läuft an beiden Orten. Auf einem Mac macht es alles; unter Linux
macht es, was ohne Xcode geht, und **benennt**, was es überspringt. Es ist
absichtlich dasselbe Skript wie in der CI-Beschreibung — zwei Abläufe würden
auseinanderlaufen, und dann prüft der eine etwas anderes als der andere.

Auf einem Mac läuft `scripts/pruefen.sh schnell` zusätzlich als Haken vor
jedem Push (`scripts/setup-mac.sh` richtet ihn ein, `git push --no-verify`
überspringt ihn einmalig).

| Was | Wie |
|---|---|
| Vor jeder Runde | `git status` — das Arbeitsverzeichnis muss auf dem committeten Stand sein. Ein zurückgefallener Container sah schon einmal wie verlorene Arbeit aus |
| Alles auf einmal | `scripts/pruefen.sh` — Zeichenketten, `PulseCore`, `PulseData`, App-Build, Oberflächentests, Screenshots, Klick-Dummy |
| `PulseCore` allein | `swift test --package-path Packages/PulseCore` — muss vollständig grün sein |
| Prototyp allein | `node scripts/check-prototype.mjs` — Hauptflüsse, JS-Fehler, horizontaler Überlauf, in Hell **und** Dunkel |
| Zahlen im Prototyp | Vor dem Veröffentlichen einmal ausrechnen lassen und auf Plausibilität ansehen |
| Erst wenn das grün ist | pushen. Die CI ist die Gegenprobe auf einem frischen Rechner, nicht der erste Durchgang |

### Wo diese Sitzung läuft

Zwei Orte, und sie können einander **nicht** sehen:

- **Am Mac** (`claude` im Projektordner, Desktop-App, IDE-Erweiterung): voller
  Zugriff auf Dateien, Terminal, Xcode, Simulator. `.claude/settings.json` lässt
  die Befehle dieses Projekts ohne Rückfrage durch.
- **In der Cloud** (claude.ai/code): Linux-Container, kein Xcode, keine
  Verbindung zum Rechner des Gründers. `PulseCore` und der Klick-Dummy laufen
  hier vollständig; alles mit SwiftUI oder SwiftData nicht.

Eine Cloud-Sitzung erfährt **nur über den Zweig `pruefungen`** oder durch eine
Nachricht, was am Mac passiert ist. Sie darf nicht behaupten, sie könne dort
etwas ausführen.

### Wurde ein Stand schon auf dem Mac geprüft?

Eine Sitzung in einem Linux-Container sieht den Mac des Gründers **nicht**. Sie
erfährt nur davon, wenn er es schreibt — oder hier:

```bash
git fetch origin pruefungen && git show origin/pruefungen:README.md | tail -5
```

Der Zweig `pruefungen` bekommt eine Zeile je lokalem Lauf: Zeitpunkt, Stand,
Ergebnis, Umfang, Dauer, Rechner. Geschrieben wird sie vom Haken vor dem Push
(`scripts/pruefen.sh --melden`). Steht der aktuelle Stand dort grün, ist das
Warten auf die CI überflüssig.

Ein **vollständiger** Lauf mit `--melden` legt zusätzlich die Screenshots in den
Zweig `screenshots` — dieselben Bilder, die sonst nur die CI liefert. Damit ist
die CI für nichts mehr das Nadelöhr: `scripts/mac-start.sh` ruft `--melden` von
sich aus auf.

## Regel 4 — Angefangenes wird zu Ende gebracht, ohne Nachfrage

Der Nutzer erinnert nicht. Wer einen Lauf anstößt, sieht auch nach — und wer
etwas gebaut hat, bringt es bis aufs Telefon, ohne dass jemand danach fragt.

**Fertig heißt: in TestFlight.** Am 24. August ausdrücklich verlangt und als
Dauerauftrag erteilt: „mach es dass du immer alles ohne meine weiteren
Anweisungen alles grün und dann auf main so dass es in TestFlight ist."

Eine Aufgabe ist also **nicht** erledigt, wenn der Zweig gepusht ist, und auch
nicht, wenn sie in `main` liegt. Sie ist erledigt, wenn ein Bau verarbeitet in
TestFlight steht und das gemeldet ist — belegt mit „Bau N: VALID" aus dem
Protokoll, nicht mit einer Vermutung.

Konkret, nach jedem Push und jedem angestoßenen Lauf:

1. **Nachschau planen**, bevor der Zug endet — `send_later` in dieser Umgebung,
   `CronCreate` als Ausweichweg, wenn `send_later` eine Genehmigung verlangt.
   Nie auf eine Erinnerung warten und nie mit `sleep` blockieren.
2. **Grün** → zusammenführen, TestFlight-Lauf anstoßen, Zeile in
   `docs/12-auslieferung.md` nachtragen, zusammengeführte Arbeitszweige
   löschen, Bilder holen, Ergebnis melden.
3. **Rot** → Begründung aus dem Protokoll holen, einordnen (Prüf- oder
   Produktfehler), **beheben** und wieder von vorn. Melden, was los war, statt
   auf eine Freigabe zu warten — die ist erteilt.
4. **Noch offen** → nächste Nachschau planen und **nichts** melden. Eine
   Zwischenmeldung ohne Ergebnis ist eine Störung.

**Was nicht nach TestFlight geht:** eine Version, die nur Dokumente,
Prüfskripte oder den Klick-Dummy anfasst. Sie endet in `main`. Alles, was am
App-Bau etwas ändert — `App/`, `Packages/`, `project.yml`, `Widget/` —, geht
den ganzen Weg. Mehrere Versionen dürfen in **einem** Bau zusammenkommen; jeder
Bau kostet einen gemieteten Mac und eine Nummer, die verbraucht ist.

**Und nach jedem Bau:** den Schritt „Testhinweise eintragen" im Protokoll
ansehen. Ein Bau ohne Hinweistext ist bei den Testern ein Bau ohne Auskunft —
zehn Bauten lang stand dort nichts, und niemandem ist es aufgefallen.

### Pushen während eines laufenden Prüflaufs ist erlaubt

**Diese Regel stand hier umgekehrt und war überholt.** Sie lautete „nie pushen,
solange ein Prüflauf läuft", weil `cancel-in-progress` an einem einzigen Tag
drei Läufe gekostet hatte — jeden abgebrochen kurz vor dem App-Build, also nach
der teuersten Minute und ohne je ein Ergebnis. Behoben wurde das damals mit
**zwei Gruppen** in `ci.yml`, und die Regel blieb trotzdem stehen. Sie hat
danach nur noch Wartezeit gekostet.

| Auftrag | Gruppe | Bei neuem Push |
|---|---|---|
| `prototype` (Ubuntu, Minuten) | `entwurf-<zweig>` | wird abgebrochen — soll er, er läuft gleich wieder |
| `build-and-test` (macOS, teuer) | `app-<zweig>` | `cancel-in-progress: false` — **reiht sich an**, beide laufen durch |

Der teure Auftrag ist also geschützt. Wer wartet, wartet umsonst.

```bash
git fetch origin screenshots && git show origin/screenshots:README.md | head -3
```

**Nicht als Ersatz lesen, sondern als Vorsprung.** Ein Lauf „mit Änderungen"
sagt über den committeten Stand nichts, und `schnell` sagt nichts über die App
im Simulator. Beides steht in der Zeile.

Swift-Toolchain unter Linux: `/opt/swift/usr/bin` (Swift 6.0.3).
Chromium für Playwright: `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`.

## Sprache

- **Oberfläche und Dokumente:** Deutsch, in der Sprache des Nutzers.
  Verbotene Wörter in der UI: Messstelle, Zählwerk, Register, OBIS, Entität,
  Datensatz, Synchronisation.
- **Code, Bezeichner, Commit-Nachrichten:** Englisch.
- **Kommentare im Code:** Deutsch, und sie begründen *warum*, nicht *was*.

### Tonfall in allem, was der Nutzer liest

Vom Gründer am 15. August ausdrücklich verlangt, nachdem die erste Fassung der
Website „steril und wie von einer Maschine" klang. Betrifft Website,
App-Store-Texte, Oberfläche und Mitteilungen — **nicht** die Dokumente in
`docs/` und nicht die Kommentare im Code, die dürfen weiter erklären.

Woran man den maschinellen Klang erkennt und was stattdessen dasteht:

| Nicht so | Sondern |
|---|---|
| Jeder Satz begründet sich selbst mit einem Gedankenstrich | Behaupten und weitergehen. Die Begründung nur, wo sie überrascht |
| „Ein großer Ziffernblock, bedienbar bei schlechtem Licht" | „Groß genug, dass man ihn im Keller einhändig trifft" |
| Gleich lange, gleich gebaute Sätze | Kurz. Dann einer, der ausholt und die Sache zu Ende bringt. Dann wieder kurz |
| Merkmale aufzählen | Die Lage beschreiben, in der jemand steckt |
| „ermöglicht", „bietet", „verfügt über" | „macht", „zeigt", „rechnet", „fragt nach" |
| Alles abwägen und absichern | Einen Standpunkt haben |

Konkrete Zahlen, konkrete Orte, konkrete Gegenstände: Keller, Sicherungskasten,
Februar, Kubikmeter, Wallbox in der Garage. Sie tragen den Text, nicht die
Adjektive.

#### Nachgeschärft am 28. August: nicht nach Werbeagentur

Die Zeile „jeder Satz begründet sich selbst mit einem Gedankenstrich" stand
oben schon — und die Website hatte trotzdem **25 Striche auf 1150 Wörter**,
einen alle 46. Eine Regel, die niemand zählt, wird nicht befolgt. Deshalb zählt
`check-website.mjs` jetzt mit: höchstens einer je 250 Wörter, Titel und Fußzeile
ausgenommen, dazu eine Liste von Wörtern, die auf jede App passen.

Vom Gründer wörtlich: „Schreibe so, wie ein Mensch einem anderen Menschen die
App erklären würde. Wenn eine einfache Aussage ausreicht, nimm die einfache
Aussage."

| Nicht so | Sondern |
|---|---|
| „PulseMeter ermöglicht dir eine intelligente Analyse deiner Verbrauchsdaten" | „PulseMeter zeigt dir, wie sich dein Verbrauch und deine Kosten entwickeln" |
| „Keine stillen Annahmen." | „Wenn PulseMeter einen Wert schätzt, siehst du das." |
| „Deine Daten gehören dir." | „Deine Zählerstände bleiben bei dir." |
| „Eine Zahl eintragen. Den Überblick behalten." | „Du trägst deinen Zählerstand ein, PulseMeter macht den Rest." |

Außerdem draußen: „smart", „intelligent", „nahtlos", „mühelos", „erlebe",
„entdecke", „revolutionieren", „maximieren" — und Dreierketten wie „Verbrauch.
Kosten. Kontrolle." Ein kurzer Satz darf stehen, wenn er einen konkreten
Gedanken trägt. Drei hintereinander tun das nie.

**Wenn eine klügere und eine natürlichere Formulierung zur Wahl stehen, nimm die
natürlichere.**

Was sich dabei **nicht** ändert: Nichts versprechen, was es nicht gibt
(`09-appstore.md`), und geschätzte Zahlen bleiben gekennzeichnet
(Produktprinzip 7). Lockerer Ton ist kein Freibrief für großzügige Aussagen.

### Selbstsprechend statt erklärt

Vom Gründer am 22. August verlangt: „es soll eigentlich alles immer
selbstsprechend sein." Der Anlass: Über einer Zahl stand „August", die Zahl
meinte drei Tage, und ein Satz darunter erklärte das. Die Zahl war richtig, die
Überschrift falsch — und der Erklärsatz hat den Fehler nicht behoben, sondern
verdeckt.

> **Wenn ein Text erklären muss, was daneben steht, stimmt die Beschriftung
> nicht.** Erst die Beschriftung richtig machen, dann den Text streichen.

Der Ablauf dazu steht in `.claude/skills/selbstsprechend/SKILL.md` und gilt für
jede Überschrift, jede Beschriftung und jede Erklärzeile.

### Keine Annahmen in Texten, die jemand anderes liest

Am 16. August ausdrücklich verlangt, nachdem im Impressum „Kleinunternehmer im
Sinne von § 19 UStG" stand. Niemand hatte das gesagt — es klang plausibel, und
es war falsch.

**Was über den Gründer, sein Gewerbe, seine Anschrift, seine Geräte oder seine
Zahlen behauptet wird, muss von ihm bestätigt sein.** Sonst gilt:

1. **Weglassen** ist die erste Wahl. Ein fehlender Absatz ist harmlos, ein
   falscher nicht.
2. Geht es nicht ohne, dann als **Platzhalter in eckigen Klammern** mit einem
   `PLATZHALTER`-Kommentar daneben — sichtbar, zählbar, prüfbar.
3. In den Dokumenten unter `docs/` darf eine Annahme stehen, wenn sie **als
   solche gekennzeichnet** ist („Wette", „geschätzt", „nicht gemessen").

Das gilt besonders für Rechtstexte. Ein Impressum ist keine Textsorte, in der
sich etwas plausibel ergänzen lässt.

## Wo was liegt

```
docs/00-produktstrategie.md   Problem, Markt, Zielgruppen, Prinzipien, Risiken
docs/01-architektur.md        Technische Entscheidungen als ADR
docs/02-datenmodell.md        Domänenmodell, Rechenkern, Randfälle
docs/03-ux-konzept.md         Navigation, Kernscreens, Design-System
docs/04-monetarisierung.md    Free / Pro / Vermieter
docs/05-roadmap.md            v1-Umfang, Ausschlüsse, Reihenfolge
docs/prototype/index.html     Klick-Dummy, in sich geschlossen
Packages/PulseCore/           Domäne und Rechenkern, nur Foundation
Packages/PulseData/           SwiftData und CloudKit, braucht Xcode
Packages/PulseUI/             Design-System, nur iOS
App/                          App-Target, wird vollständig eingelesen
project.yml                   Beschreibung des Xcode-Projekts (XcodeGen)
scripts/                      setup-mac, test, run — die Automatisierung
```

Auf einem Mac gilt zusätzlich `.claude/skills/xcode-workflow/SKILL.md`:
Bauen, Testen und Screenshots laufen über `scripts/`, nicht über die
Xcode-Oberfläche. `PulseMeter.xcodeproj` wird erzeugt und ist deshalb nicht
eingecheckt — neue Dateien gehören in den Ordner, nie ins Projekt.

## Produktprinzipien, gegen die jede Änderung geprüft wird

1. **60 Sekunden** von Installation bis zur ersten Ablesung, ohne Konto.
2. **3 Berührungen** von App-Start bis zur gesicherten Folge-Ablesung.
3. **5 Sekunden** Blickzeit für „Ist alles im Rahmen?" — ohne Scrollen.
4. **Keine Sackgasse** — jede angezeigte Zahl ist antippbar und erklärt sich.
5. **Datenfreiheit** — Export bleibt dauerhaft kostenlos.
6. **Kein technisches Vokabular** — die Struktur lebt im Datenmodell, nicht in
   der Oberfläche.
7. **Nie stillschweigend rechnen** — geschätzte, interpolierte und
   hochgerechnete Werte sind immer als solche gekennzeichnet.

## Wiederkehrende Fehlerklasse

Bisher entstanden alle gefundenen Rechenfehler dadurch, dass ein Zeitraum, den
die Daten abdecken, gegen einen verglichen wurde, den sie nicht abdecken.
Bei jedem neuen Vergleich, jeder Hochrechnung und jeder Prüfung gilt deshalb:

> Beide Seiten müssen denselben Zeitausschnitt beschreiben — und bei
> saisonalen Zählern denselben Ausschnitt des Jahres.
