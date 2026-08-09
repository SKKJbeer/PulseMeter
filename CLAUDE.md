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
