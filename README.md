# PulseMeter

Die App zur Erfassung, Analyse und Dokumentation von Zählerständen.

> **Positionierung:** PulseMeter ist das Haushaltsbuch für Verbrauch — du trägst eine Zahl ein,
> und die App sagt dir, ob alles im Rahmen ist.

## Status

Konzeptphase. Es existieren die Strategie- und Architekturdokumente; Produktcode folgt,
sobald die offenen Entscheidungen getroffen sind.

## Klick-Dummy

**[Zuletzt veröffentlichter Entwurf →](https://claude.ai/code/artifact/6b7dd9c1-245f-4e3f-9d47-52aad1412295)**

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

## Grundprinzipien

1. **60-Sekunden-Regel** – Installation bis erste Ablesung unter 60 Sekunden, ohne Konto.
2. **3-Tap-Regel** – App-Start bis gespeicherte Folge-Ablesung in maximal 3 Berührungen.
3. **5-Sekunden-Regel** – Der Startbildschirm beantwortet „Ist alles im Rahmen?" ohne Interaktion.
4. **Keine Sackgasse** – Jede angezeigte Zahl ist antippbar und erklärt sich.
5. **Datenfreiheit** – Export ist dauerhaft kostenlos. Nutzerdaten sind nie Verhandlungsmasse.
6. **Kein technisches Vokabular** – Die Struktur lebt im Datenmodell, nicht in der Oberfläche.
7. **Nie stillschweigend rechnen** – Geschätzte Werte sind immer als solche gekennzeichnet.
