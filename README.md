# PulseMeter

Die App zur Erfassung, Analyse und Dokumentation von Zählerständen.

> **Positionierung:** PulseMeter ist das Haushaltsbuch für Verbrauch — du trägst eine Zahl ein,
> und die App sagt dir, ob alles im Rahmen ist.

## Am Mac loslegen

```bash
git clone https://github.com/SKKJbeer/PulseMeter.git
cd PulseMeter && git checkout claude/pulsemeter-kickoff-dns3am
scripts/setup-mac.sh        # prüft Xcode, erzeugt das Projekt, testet
scripts/run.sh              # startet die App im Simulator, legt einen Screenshot ab
```

Voraussetzung ist Xcode aus dem App Store, einmal geöffnet und mit bestätigter
Lizenz. Alles Weitere richtet das Skript ein.

## Status

Version **0.16.1**. Strategie, Datenmodell und Rechenkern stehen, der Klick-Dummy
rechnet echt. Übersicht und Erfassung laufen als SwiftUI-App im Simulator und
werden auf jedem Lauf fotografiert; Verlauf und Zähler sind noch Platzhalter.
Siehe [CHANGELOG.md](CHANGELOG.md).

## Klick-Dummy

**[Zuletzt veröffentlichter Entwurf →](https://claude.ai/code/artifact/d569263c-bfe5-4f1e-9e29-afe15237c664)**

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
