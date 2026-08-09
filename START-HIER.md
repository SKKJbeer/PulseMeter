# Claude Code auf diesem Mac starten

Ein Schritt. Danach steuerst du nur noch durch Sagen, nicht durch Tippen von
Befehlen.

---

## Weg A — ohne Terminal (empfohlen)

1. **Claude Code Desktop** laden und installieren: <https://claude.com/claude-code>
2. Öffnen, mit demselben Konto anmelden wie im Browser.
3. Als Projektordner **diesen Ordner** wählen — den, in dem diese Datei liegt.

Fertig. Die Sitzung liest `CLAUDE.md`, kennt damit Arbeitsweise, Sprachregeln
und Prüfschritte, und `.claude/settings.json` erlaubt ihr die Befehle dieses
Projekts ohne Rückfrage.

## Weg B — ein einziger Befehl im Terminal

```bash
npm install -g @anthropic-ai/claude-code && cd "$(dirname "$0")" && git pull && claude
```

Oder von Hand, falls du schon im Projektordner stehst:

```bash
npm install -g @anthropic-ai/claude-code
git pull
claude
```

---

## Der erste Satz an die neue Sitzung

Kopier das hinein — mehr braucht sie nicht:

> Lies CLAUDE.md, README.md und docs/05-roadmap.md. Richte dann mit
> `scripts/setup-mac.sh` die Umgebung ein und lass `scripts/pruefen.sh` einmal
> vollständig laufen. Zeig mir das Ergebnis und die Screenshots aus `build/`.
> Danach arbeite die offenen Punkte aus der Roadmap ab — Foto-Belege, dann
> Siri-Kurzbefehl —, nach den Regeln aus CLAUDE.md und
> `.claude/skills/release-discipline`.

Von da an genügt „mach weiter", „ja", „nein, anders" — so wie hier.

---

## Was schon vorbereitet ist

| Was | Wo |
|---|---|
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
