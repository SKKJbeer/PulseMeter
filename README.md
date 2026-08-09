# PulseMeter

Die App zur Erfassung, Analyse und Dokumentation von Zählerständen.

> **Positionierung:** PulseMeter ist das Haushaltsbuch für Verbrauch — du trägst eine Zahl ein,
> und die App sagt dir, ob alles im Rahmen ist.

## Am Mac loslegen

```bash
git clone https://github.com/SKKJbeer/PulseMeter.git
cd PulseMeter && git checkout claude/pulsemeter-kickoff-dns3am
scripts/setup-mac.sh        # prüft Xcode, erzeugt das Projekt, richtet den Push-Haken ein
scripts/pruefen.sh          # alles, was auch die CI prüft — in ein bis zwei Minuten
```

`scripts/pruefen.sh` ist der eine Befehl für alles: Zeichenketten, `PulseCore`,
`PulseData`, App-Build, Oberflächentests, Screenshots und der Klick-Dummy. Die
CI macht dasselbe auf einem frischen Rechner und braucht dafür zwölf bis
fünfzehn Minuten — lokal bleibt das Ableseverzeichnis liegen, und Xcode baut
nur das Geänderte.

| Aufruf | Was er tut | Ungefähr |
|---|---|---|
| `scripts/pruefen.sh` | alles | 1–2 min |
| `scripts/pruefen.sh schnell` | ohne App-Build | 20 s |
| `scripts/pruefen.sh app` | nur App-Build und Oberflächentests | 1 min |
| `scripts/pruefen.sh --nur zurueck` | eine einzelne Oberflächenprüfung | 20 s |
| `scripts/run.sh` | App im Simulator starten, Screenshots ablegen | 40 s |

Vor jedem `git push` laufen die schnellen Prüfungen als Haken und schreiben ihr
Ergebnis in den Zweig [`pruefungen`](../../tree/pruefungen) — eine Zeile je
Lauf. Dadurch sieht auch eine Sitzung, die diesen Rechner nicht erreicht, ob
ein Stand hier schon geprüft wurde, statt zwölf Minuten auf die CI zu warten.
Überspringen: `git push --no-verify`. Nichts melden: `git config --unset
core.hooksPath`.

Voraussetzung ist Xcode aus dem App Store, einmal geöffnet und mit bestätigter
Lizenz. Alles Weitere richtet das Skript ein.

## Status

Version **0.32.1**. Strategie, Datenmodell und Rechenkern stehen, der Klick-Dummy
rechnet echt. Alle vier Bildschirme — Übersicht, Erfassung, Verlauf und Zähler —
laufen als SwiftUI-App im Simulator und werden auf jedem Lauf fotografiert,
hell und dunkel. Siehe [CHANGELOG.md](CHANGELOG.md).

Die Bilder des jeweils letzten Laufs liegen im Zweig
[`screenshots`](../../tree/screenshots). Er wird bei jedem Lauf überschrieben
und ist keine Historie, sondern der aktuelle Blick auf die Oberfläche.

## Mit Claude Code am Mac arbeiten

**Kurzfassung für den Anfang: [START-HIER.md](START-HIER.md).**

Das Gegenstück zu Copilot in VS Code: Claude Code läuft **lokal** auf deinem
Rechner und hat dort Zugriff auf Dateien und Terminal. Eine Sitzung in der Cloud
(claude.ai/code) kann das nicht — sie läuft in einem Container ohne Xcode und
ohne Verbindung zu deiner Maschine.

```bash
npm install -g @anthropic-ai/claude-code   # einmalig
cd PulseMeter
claude                                     # und los
```

Alternativ die Desktop-App oder die Erweiterung für VS Code bzw. JetBrains —
alle drei greifen auf dasselbe Projekt zu.

Das Repository ist darauf vorbereitet:

| Datei | Was sie bewirkt |
|---|---|
| `CLAUDE.md` | Arbeitsweise, Prüfschritte, Sprachregeln — wird automatisch gelesen |
| `.claude/settings.json` | Die Befehle dieses Projekts laufen ohne Rückfrage: `scripts/*`, `swift`, `xcodebuild`, `xcodegen`, `xcrun`, `git`. `sudo` bleibt gesperrt |
| `.claude/skills/` | `xcode-workflow` und `release-discipline` — greifen von selbst, wenn das Thema passt |

Persönliche Abweichungen gehören in `.claude/settings.local.json`; die Datei ist
nicht eingecheckt. Wer gar nicht gefragt werden will, startet mit
`claude --dangerously-skip-permissions` — dann fällt allerdings auch die
`sudo`-Sperre weg, und der Name ist ernst gemeint.

## Klick-Dummy

**[Zuletzt veröffentlichter Entwurf →](https://claude.ai/code/artifact/4fceea88-8d26-4e50-a395-9638646dba10)**

Jede Produktänderung wird sofort sichtbar gemacht — als **neue** Veröffentlichung
mit eigener URL, weil erneutes Veröffentlichen auf dieselbe Adresse nicht
zuverlässig aufgeht. Quelle ist stets `docs/prototype/index.html`.
Siehe [CLAUDE.md](CLAUDE.md), Regel 1.

## Dokumente

| Dokument | Inhalt |
|---|---|
| [00 – Produktstrategie](docs/00-produktstrategie.md) | Problem, Markt, Zielgruppen, Prinzipien, Risiken, Erfolgskriterien |
| [01 – Architektur](docs/01-architektur.md) | Technische Entscheidungen im ADR-Format |
| [02 – Datenmodell](docs/02-datenmodell.md) | Domänenmodell, Rechenkern, Randfälle |
| [03 – UX-Konzept](docs/03-ux-konzept.md) | Navigation, Kernscreens, Design-System |
| [04 – Monetarisierung](docs/04-monetarisierung.md) | Free/Pro/Vermieter, Preise, Begründung |
| [05 – Roadmap](docs/05-roadmap.md) | v1-Scope, Ausschlüsse, Umsetzungsreihenfolge |
| [CLAUDE.md](CLAUDE.md) | Arbeitsweise, Prüfschritte, Sprachregeln |
| [CHANGELOG.md](CHANGELOG.md) | Release Notes je Version |
| [project.yml](project.yml) | Beschreibung des Xcode-Projekts, Quelle für XcodeGen |

## Grundprinzipien

1. **60-Sekunden-Regel** – Installation bis erste Ablesung unter 60 Sekunden, ohne Konto.
2. **3-Tap-Regel** – App-Start bis gespeicherte Folge-Ablesung in maximal 3 Berührungen.
3. **5-Sekunden-Regel** – Der Startbildschirm beantwortet „Ist alles im Rahmen?" ohne Interaktion.
4. **Keine Sackgasse** – Jede angezeigte Zahl ist antippbar und erklärt sich.
5. **Datenfreiheit** – Export ist dauerhaft kostenlos. Nutzerdaten sind nie Verhandlungsmasse.
6. **Kein technisches Vokabular** – Die Struktur lebt im Datenmodell, nicht in der Oberfläche.
7. **Nie stillschweigend rechnen** – Geschätzte Werte sind immer als solche gekennzeichnet.
