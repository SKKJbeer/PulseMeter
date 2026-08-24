# PulseMeter

Die App zur Erfassung, Analyse und Dokumentation von Zählerständen.

> **Positionierung:** PulseMeter ist das Haushaltsbuch für Verbrauch — du trägst eine Zahl ein,
> und die App sagt dir, ob alles im Rahmen ist.

## Am Mac loslegen

```bash
git clone https://github.com/SKKJbeer/PulseMeter.git
cd PulseMeter && scripts/mac-start.sh
```

Das ist alles: Stand holen, Xcode-Projekt erzeugen, Push-Haken einrichten, alles
prüfen, Screenshots ablegen. Ohne Terminal geht es auch — im Finder
**`Am-Mac-starten.command`** doppelklicken. Der ausführliche Einstieg steht in
[START-HIER.md](START-HIER.md).

Danach ist `scripts/pruefen.sh` der eine Befehl für alles: Zeichenketten, `PulseCore`,
`PulseData`, App-Build, Oberflächentests, Screenshots und der Klick-Dummy. Die
CI macht dasselbe auf einem frischen Rechner und braucht dafür zwölf bis
fünfzehn Minuten — lokal bleibt das Ableseverzeichnis liegen, und Xcode baut
nur das Geänderte.

| Aufruf | Was er tut | Ungefähr |
|---|---|---|
| `scripts/mac-start.sh` | Stand holen, einrichten, alles prüfen, fotografieren | 2–3 min |
| `scripts/pruefen.sh` | alles | 1–2 min |
| `scripts/pruefen.sh --melden` | alles, und Ergebnis samt Bildern in die Zweige | +10 s |
| `scripts/pruefen.sh schnell` | ohne App-Build | 20 s |
| `scripts/pruefen.sh app` | nur App-Build und Oberflächentests | 1 min |
| `scripts/pruefen.sh --nur zurueck` | eine einzelne Oberflächenprüfung | 20 s |
| `scripts/run.sh` | App im Simulator starten, Screenshots ablegen | 40 s |
| `scripts/go-live.sh` | die ganze Kette bis aufs Telefon, jeder Schritt geprüft | 3 min |
| `scripts/aufs-handy.sh` | auf ein angestecktes iPhone bauen und installieren | 2 min |
| `node scripts/check-website.mjs` | die Website prüfen, hell und dunkel, 320–1280 px | 20 s |
| `node scripts/check-entwuerfe.mjs` | die Entwürfe unter `docs/entwuerfe/` durchklicken | 20 s |
| `scripts/check-sicherheit.sh` | Angriffsfläche: kein Netz, kein Tracking, keine fremden Pakete, iCloud nur privat, Privacy-Manifeste | 1 s |
| `scripts/domain-setzen.sh` | die Adresse der Website an allen Stellen umstellen | 1 s |

**Die CI ist die Gegenprobe, nicht der erste Durchgang.** Der lokale Lauf prüft
dasselbe und ist in zwei statt in fünfzehn Minuten fertig; er schreibt sein
Ergebnis in den Zweig [`pruefungen`](../../tree/pruefungen) und seine Bilder in
[`screenshots`](../../tree/screenshots) — dieselben zwei Zweige, die sonst nur
die CI füllt. Damit sieht auch eine Sitzung, die diesen Rechner nicht erreicht,
das Ergebnis sofort, ohne dass jemand auf einen gemieteten macOS-Läufer wartet.

Vor jedem `git push` laufen zusätzlich die schnellen Prüfungen als Haken und
schreiben ihre Zeile nach `pruefungen`.
Überspringen: `git push --no-verify`. Nichts melden: `git config --unset
core.hooksPath`.

Voraussetzung ist Xcode aus dem App Store, einmal geöffnet und mit bestätigter
Lizenz. Alles Weitere richtet das Skript ein.

### Ohne eigenen Mac

Geht auch. `.github/workflows/testflight.yml` baut, signiert und lädt die App
auf dem macOS-Läufer von GitHub nach TestFlight hoch — gestartet mit einem
Knopf im Browser, auch vom Telefon aus. Einmalig sind vier Angaben aus App
Store Connect als Repository-Geheimnisse zu hinterlegen; der Kopf der
Workflow-Datei sagt welche, die Anleitung führt hindurch.

Davor einmal `.github/workflows/zertifikat.yml` laufen lassen: Es legt das
Signaturzertifikat **ein einziges Mal** an und hinterlegt es als Geheimnis.
Ohne das erzeugt jeder Bau ein neues, und nach dem dritten ist Schluss —
Apple erlaubt nicht mehr.

Der Preis: zwanzig Minuten je Bau statt zwei, und Apple prüft danach noch
einmal. Dafür braucht es kein Kabel und kein Xcode.

### Auf ein echtes iPhone

Ohne Terminal: im Finder **`Aufs-iPhone.command`** doppelklicken. Es holt den
aktuellen Stand und ruft dann das Skript auf:

```bash
scripts/aufs-handy.sh
```

Dafür genügt eine gewöhnliche Apple-ID in Xcode unter Einstellungen › Accounts
— **das Apple Developer Program braucht es dafür nicht.** Am Telefon vorher
einmal Einstellungen › Datenschutz & Sicherheit › **Entwicklermodus**
einschalten, nach dem ersten Start unter Einstellungen › Allgemein › VPN &
Geräteverwaltung dem Entwickler vertrauen.

Was ohne Programm nicht geht, weil die Berechtigungen dafür daran hängen: Die
App läuft nach **sieben Tagen** ab und wird dann neu installiert (die Daten
bleiben), das Widget bleibt leer, weil es über eine App-Gruppe liest, und
iCloud-Abgleich wie Käufe lassen sich noch nicht ausprobieren.

## Status

Version **0.76.1**. Strategie, Datenmodell und Rechenkern stehen, der Klick-Dummy
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
curl -fsSL https://claude.ai/install.sh | bash   # einmalig, ohne Node
cd PulseMeter
claude                                           # und los
```

Wer Node ohnehin hat, kann auch `npm install -g @anthropic-ai/claude-code`
nehmen — nötig ist es nicht. Node braucht dieses Projekt nur für die Prüfung
des Klick-Dummys, nicht für den App-Build und nicht für die Installation aufs
Telefon.

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

**[Zuletzt veröffentlichter Entwurf →](https://claude.ai/code/artifact/c1e76ce7-3ec7-4ce8-bd69-3a1d33cf366b)**

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
| [06 – Übergabe](docs/06-uebergabe.md) | Der laufende Zustand für eine Sitzung, die den Verlauf nicht kennt |
| [07 – Weg zum Go-Live](docs/07-v1-plan.md) | Was für 1.0 hinein muss, was gestrichen ist, in welcher Reihenfolge |
| [Anleitung: in den App Store](docs/go-live-anleitung.html) | Elf Schritte zum Abarbeiten — plus der Weg ganz ohne eigenen Mac |
| [08 – Baukasten](docs/08-baukasten.md) | Dieses Aufbauschema auf ein anderes Projekt übertragen |
| [09 – App Store](docs/09-appstore.md) | Texte, Icon, Bilder, Datenschutzangaben — fertig zum Einreichen |
| [10 – Sichtbarkeit](docs/10-sichtbarkeit.md) | Gefunden werden ohne Werbebudget: Suchwörter, Bewertungen, Zeitpunkt |
| [11 – Sicherheit](docs/11-sicherheit.md) | Was angreifbar wäre, was behoben ist, was erst am Gerät prüfbar wird |
| [12 – Auslieferung](docs/12-auslieferung.md) | Vom Code in den App Store ohne Mac — die sechs Befunde aus fünf Fehlläufen |
| [Website](docs/website/) | Startseite, Hilfe, Datenschutz, Impressum — statisch, ohne fremde Server |
| [Entwürfe](docs/entwuerfe/) | Vorschläge zum Anfassen, solange noch nicht entschieden ist |
| [Website: was noch fehlt](docs/website/EINTRAGEN.md) | Die vier Stellen, die vor dem Onlinegehen ausgefüllt werden müssen |
| [Datenschutzerklärung](docs/datenschutz.md) | Der Text, der als URL im Store hinterlegt wird |
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
