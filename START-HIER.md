# Claude Code auf diesem Mac starten

Ein Doppelklick. Danach steuerst du nur noch durch Sagen, nicht durch Tippen
von Befehlen.

---

## Weg A — Doppelklick (empfohlen)

Im Finder in diesem Ordner:

**`Am-Mac-starten.command`** doppelklicken.

Das holt den aktuellen Stand, erzeugt das Xcode-Projekt, prüft alles — Rechenkern,
Speicher, App, Oberflächentests, Klick-Dummy — und legt die Screenshots in
`build/` ab, hell und dunkel. Ein bis zwei Minuten. Das Fenster bleibt am Ende
offen, damit du das Ergebnis lesen kannst.

> Beim allerersten Mal fragt macOS, ob die Datei wirklich geöffnet werden soll
> (Gatekeeper). Rechtsklick → **Öffnen** → **Öffnen** bestätigt es einmalig.

Fehlt Xcode noch, sagt das Skript genau das und was zu tun ist: Xcode aus dem
App Store, einmal öffnen, Lizenz bestätigen, noch einmal doppelklicken.

## Weg B — dasselbe im Terminal

```bash
scripts/mac-start.sh          # Stand holen, einrichten, alles prüfen
```

Hast du das Repository noch gar nicht:

```bash
git clone https://github.com/SKKJbeer/Zählora.git
cd Zählora && scripts/mac-start.sh
```

---

## Claude Code selbst

Läuft **lokal** auf deinem Rechner und hat dort Zugriff auf Dateien, Terminal
und Xcode. Eine Sitzung auf claude.ai/code kann das nicht — sie läuft in einem
Linux-Container ohne Xcode und ohne Verbindung zu dieser Maschine.

- **Desktop-App:** <https://claude.com/claude-code> laden, öffnen, mit demselben
  Konto anmelden, als Projektordner **diesen Ordner** wählen.
- **Terminal:** `npm install -g @anthropic-ai/claude-code`, dann im
  Projektordner `claude`.
- **In VS Code oder JetBrains:** die Erweiterung, sie greift auf dasselbe
  Projekt zu.

Die Sitzung liest `CLAUDE.md` von selbst und kennt damit Arbeitsweise,
Sprachregeln und Prüfschritte. `.claude/settings.json` erlaubt ihr die Befehle
dieses Projekts ohne Rückfrage; `sudo` bleibt gesperrt.

## Der erste Satz an die neue Sitzung

Kopier das hinein — mehr braucht sie nicht:

> Lies CLAUDE.md, README.md und docs/06-uebergabe.md. Lass dann
> `scripts/mac-start.sh` laufen und zeig mir das Ergebnis und die Screenshots
> aus `build/`. Danach arbeite die offenen Punkte aus der Roadmap ab —
> Foto-Belege, dann Siri-Kurzbefehl —, nach den Regeln aus CLAUDE.md und
> `.claude/skills/release-discipline`.

Von da an genügt „mach weiter", „ja", „nein, anders" — so wie hier.

---

## Was schon vorbereitet ist

| Was | Wo |
|---|---|
| Alles auf einmal: holen, einrichten, prüfen, fotografieren | `Am-Mac-starten.command` bzw. `scripts/mac-start.sh` |
| Der laufende Zustand — was gebaut, was ungeprüft, was zuletzt rot war | `docs/06-uebergabe.md` |
| Arbeitsweise, Sprachregeln, Prüfschritte | `CLAUDE.md` |
| Befehle ohne Rückfrage (`scripts/*`, `swift`, `xcodebuild`, `git` …) | `.claude/settings.json` |
| Xcode-Abläufe und Release-Disziplin als Skills | `.claude/skills/` |
| Alles prüfen, was auch die CI prüft — in ein bis zwei Minuten | `scripts/pruefen.sh` |
| Haken vor jedem Push, meldet das Ergebnis in den Zweig `pruefungen` | `.githooks/pre-push` |
| Offene Punkte, begründet und sortiert | `docs/05-roadmap.md` |

## Warum das nicht von der Cloud-Sitzung aus geht

Eine Sitzung auf claude.ai/code läuft in einem Linux-Container: kein Xcode, kein
Simulator, und keine Verbindung zu diesem Rechner. Sie kann `PulseCore` und den
Klick-Dummy vollständig prüfen — alles mit SwiftUI oder SwiftData nicht. Die
beiden Sitzungen sehen einander nicht; verbunden sind sie über das Repository
und über den Zweig `pruefungen`, in dem jeder lokale Lauf eine Zeile
hinterlässt.
