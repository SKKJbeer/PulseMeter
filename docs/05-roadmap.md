# 05 – Roadmap und v1-Scope

Status: laufend gepflegt
Letzte Änderung: 2026-08-10

---

## Leitsatz

Der v1-Scope ist bewusst schmerzhaft klein. Jede Funktion, die wir vor dem ersten echten Nutzer bauen, ist eine Wette ohne Rückmeldung. Die größte Gefahr für dieses Projekt ist nicht ein fehlendes Feature — es ist eine Version 1, die nie fertig wird (Risiko R7).

---

## Gesamtübersicht auf einen Blick

Für den schnellen Einstieg. Die Begründungen stehen weiter unten und in
[`07-v1-plan.md`](07-v1-plan.md); hier steht nur, **was da ist und was nicht.**

### Gebaut und grün geprüft

| Bereich | Was |
|---|---|
| **Fundament** | `PulseCore` (155 Prüfungen) · `PulseData` mit SwiftData und CloudKit · `PulseUI` in Hell und Dunkel, Dynamic Type |
| **Übersicht** | Statuszeile, Zähler-Karten, Kosten, Abschlagsvorschau, Fällig-Hinweis |
| **Erfassung** | Zählwerk-Optik, Live-Plausibilisierung, Vorbelegung, mehrere Zählwerke in einem Vorgang, Weg zurück |
| **Verlauf** | Monat/Quartal/Jahr, Diagramm und Tabelle, Menge oder Kosten, Vorjahresvergleich |
| **Zählerverwaltung** | Preise, Abschlag, Archiv, Zählerwechsel |
| **Rechnen** | Tarife und Kosten · saisonale Jahresprognose · Abschlagsvergleich · Zweirichtungszähler (PV) · Doppeltarif (HT/NT) · Zählerwechsel · Zählerüberlauf |
| **Ausgabe** | CSV-Export *(frei)* · PDF-Bericht mit Zeitraumwahl · Erinnerungen · Home- und Lock-Screen-Widget |
| **Werkzeug** | `pruefen.sh` als ein Befehl für alles · `mac-start.sh` und Doppelklick-Start · CI auf Linux und macOS · Bilder auch bei rotem Lauf · Zweige `screenshots` und `pruefungen` · Klick-Dummy mit echtem Rechenkern (44 Prüfungen) |

### Für 1.0 offen

| Was | Bei wem |
|---|---|
| **Apple Developer Program** (99 €) | **Nutzer** — blockiert alles Weitere und lässt sich nicht vorarbeiten |
| Paywall, StoreKit 2, Kaufwiederherstellung | Sitzung am Mac, sobald das Programm da ist |
| **App-Store-Material** — Icon, Bilder je Gerätegröße, Texte, Datenschutzerklärung, Support-Adresse | gemeinsam, **nicht angefangen** |
| App-Privacy-Angaben | Nutzer |
| Barrierefreiheit zu Ende | Sitzung am Mac |
| 800 ms Kaltstart auf einem **Gerät** | Nutzer |
| **Zwei Wochen echte Nutzung** | Nutzer |

### Nach 1.0

| Version | Inhalt |
|---|---|
| **1.1** | Objekte und Einheiten · Mieterzuordnung mit Ein-/Auszugsprotokoll und Unterschrift · Sammelerfassung · Vermieter-Abo · iPad-Layout · Import · **Foto-Belege** und **Siri-Kurzbefehl** (aus 1.0 gestrichen) |
| **1.2** | Kamera-Erkennung des Zählerstands (on-device, immer als Vorschlag) · Erfassung aus der Benachrichtigung · Control-Center |
| **2.0** | offen, marktabhängig: Mac-App · geteilte Haushalte · optionale Live-Datenquellen · CO₂ mit belastbarer Datenquelle |
| **nie** | Watch-App · Vergleich mit anderen Haushalten · ML-Prognose |

### Was das fürs Geldverdienen heißt

**Frei bleibt dauerhaft:** bis zwei Zähler, unbegrenzte Ablesungen und
Historie, Verlauf, Vorjahresvergleich, Erinnerungen und der CSV-Export.

**Pro trägt zum Start mit fünf Dingen, die alle fertig sind:** unbegrenzte
Zähler und Zählwerke, Kosten und Tarife, Abschlagsvergleich, Jahresprognose,
PDF-Bericht.

> ⚠️ **Fürs Store-Material:** In `04-monetarisierung.md` stehen **Foto-Belege**
> und **Siri-Kurzbefehle** in der Pro-Liste. Beide sind aus 1.0 gestrichen und
> dürfen in der Store-Beschreibung nicht auftauchen. Ein verkauftes Merkmal,
> das es nicht gibt, ist eine Rückerstattung und eine schlechte Bewertung.

---

## v1.0 – „Eine Zahl, eine Antwort"

**Produktversprechen:** Zählerstand eintragen, sofort wissen, ob alles im Rahmen ist.

### Enthalten

**Fundament**
- SPM-Modulstruktur (`PulseCore`, `PulseData`, `PulseUI`, `PulseFeatures`)
- Datenmodell nach `02` inklusive Register- und Geräte-Konzept
- Rechenkern mit vollständiger Testabdeckung aller Randfälle aus `02`, Abschnitt 3
- SwiftData + CloudKit-Sync hinter Repository-Abstraktion
- Design-System, Light und Dark, Dynamic Type bis zur größten Stufe

**Funktionen**
- Onboarding mit erster Ablesung in unter 60 Sekunden
- Übersicht mit Statuszeile und Zähler-Karten
- Erfassung mit Zählwerk-Optik und Live-Plausibilisierung
- Verlauf mit Monats-/Jahresansicht und Vorjahresvergleich
- Zählerverwaltung inkl. Zählerwechsel und Mehrfach-Zählwerken (PV, HT/NT)
- Tarife, Kosten, Abschlagsvergleich, Jahresprognose *(Pro)*
- Erinnerungen
- CSV-Export *(frei)* und PDF-Bericht *(Pro)*
- Foto-Belege *(Pro)*
- Home-Screen- und Lock-Screen-Widget, Siri-Kurzbefehl *(Pro)*
- Paywall, StoreKit 2, Wiederherstellung von Käufen

**Qualitätsanforderungen (nicht verhandelbar)**
- VoiceOver vollständig in allen Hauptflüssen
- Cold Start bis interaktiv unter 800 ms
- Vollständiger Datenexport jederzeit möglich
- Keine Netzwerkanfrage außer CloudKit und StoreKit

### Nicht enthalten – mit Begründung

| Ausgeschlossen | Warum |
|---|---|
| Kamera-Erkennung (OCR) | Erwartungsmanagement-Risiko (R4). Erst wenn der Kernfluss steht und wir die Fehlerquote real messen können. |
| Vermieter-/Einheiten-UI | Datenmodell ist vorbereitet, Oberfläche folgt in v1.1 nach Rückmeldung aus dem Markt |
| Import aus anderen Apps | Wichtig für den Wechsel, aber sinnlos ohne Nutzer, deren Formate wir kennen |
| iPad-optimiertes Layout | Läuft kompatibel, wird in v1.1 richtig gemacht |
| Watch-App | Erfassung am Zähler ohne Tastatur ist unrealistisch |
| CO₂, Vergleich mit anderen Haushalten, ML-Prognose | Siehe `02`, Abschnitt 4 |

---

### Nachträglich für 1.0 gestrichen

Der Umfang oben war die Planung vor der Umsetzung. Für den ersten Go-Live ist
er bewusst weiter beschnitten worden — die Begründung je Posten steht in
[`07-v1-plan.md`](07-v1-plan.md), der ab hier den Vorrang hat:

| Gestrichen | Nach | Kurz |
|---|---|---|
| Foto-Belege *(Pro)* | 1.1 | Größtes Restrisiko, und niemand vermisst es, der die App noch nicht hat |
| Siri-Kurzbefehl *(Pro)* | 1.1 | Wer die App nicht kennt, richtet keinen Kurzbefehl ein |

Alles andere aus der Liste steht bereits. Der Engpass ist kein Feature, sondern
das Apple Developer Program.

---

## v1.1 – „Für mehr als eine Wohnung"

- Objekte und Einheiten in der Oberfläche
- Mieterzuordnung, Ein- und Auszugsprotokoll mit Unterschrift
- Sammelerfassung mehrerer Zähler in einem Durchgang
- Vermieter-Abo
- iPad-Layout mit Sidebar
- Import aus CSV und den verbreitetsten Wettbewerber-Formaten

## v1.2 – „Weniger tippen"

- Kamera-Erkennung des Zählerstands (on-device, Vision), immer als Vorschlag mit Bestätigung
- Erfassung direkt aus der Benachrichtigung
- Control-Center-Steuerung

## v2.0 – offen, marktabhängig

Kandidaten, in dieser Reihenfolge zu prüfen: Mac-App, geteilte Haushalte, optionale Live-Datenquellen (nur als zusätzliche Quelle für dasselbe Modell), CO₂ mit belastbarer Datenquelle.

---

## Reihenfolge der Umsetzung

Die Reihenfolge ist bewusst nicht „Screens von oben nach unten", sondern nach Risiko sortiert — das Unsicherste zuerst:

1. **`PulseCore` + Tests** — Der Rechenkern ist plattformunabhängig, ohne Xcode verifizierbar und der Ort, an dem Korrektheit entsteht. Wenn hier etwas falsch modelliert ist, merken wir es hier am billigsten.
2. **`PulseData` + Repositories + Migrations-/Backup-Pfad** — das größte technische Risiko (R3) früh unter Kontrolle.
3. **`PulseUI` Design-System** — bevor Features entstehen, damit sie nicht nachträglich vereinheitlicht werden müssen.
4. **Erfassungsfluss** — der Screen, an dem das Produkt gewinnt oder verliert.
5. **Übersicht.**
6. **Verlauf, Zählerverwaltung, Einstellungen.**
7. **Tarife, Kosten, Prognose.**
8. **Widgets, Shortcuts, Erinnerungen.**
9. **Paywall und StoreKit.**
10. **Politur:** Animationen, Haptik, Barrierefreiheits-Durchgang, Performance-Messung, App-Store-Material.

**Warum der Rechenkern zuerst und nicht die Oberfläche?** Weil das Datenmodell die einzige Entscheidung ist, die sich später nicht ohne Schmerzen korrigieren lässt (R2). Ein Screen wird umgebaut, ein Datenmodell wird migriert — und Migrationen bei zahlenden Nutzern sind das, was Utility-Apps ruiniert.

---

## Aktueller Stand — Version 0.114.1

> **Hier stand achtzig Versionen lang „Aktueller Stand — Version 0.34.1".**
> Darin: „Paywall und StoreKit — offen, braucht das Apple Developer Program."
> Zu dem Zeitpunkt verkaufte die App seit Wochen sechs Freischaltungen im
> App Store. Ein Dokument, das niemand liest, wird nicht gepflegt, und dann
> lügt es. Aufgefallen ist es, als der Gründer nach einer Roadmap fragte.

| | Stand am 23. September 2026 |
|---|---|
| **Im App Store** | **1.1** seit dem 10. September. Davor 1.0.1 am 7., 1.0 am 4. September |
| **In TestFlight** | Bau 36 aus 0.114.1: zwei Spalten auf dem iPad, Querformat zum ersten Mal geprüft |
| Käufe | 6 von 6 eingereicht und im Laden |
| Länder | 175, Deutschland dabei |
| `PulseCore` | grün |
| Oberflächentests | 42 Prüfungen, grün auf iPhone **und** iPad |
| Klick-Dummy | 292 Prüfungen, hell und dunkel |
| Website | 415 Prüfungen, live auf `zaehlora.pages.dev` |

Die zehn Schritte aus „Reihenfolge der Umsetzung" sind abgearbeitet, Paywall
und StoreKit eingeschlossen. Offen sind aus den alten Listen noch zwei Dinge,
und beide sind Komfort und keine Lücke:

- **Siri-Kurzbefehl** — der letzte offene Punkt aus Schritt 8.
- **Foto-Belege** — die einzige Zeile, die auch der Entwurf nie kannte.

### Öffentlich und intern

Seit dem 23. September getrennt, auf Ansage des Gründers:

| | Öffentlich (`docs/website/entwicklung.html`) | Intern (diese Datei) |
|---|---|---|
| Was schon im App Store ist | ja, je Fassung mit Datum | ja |
| Was gerade im Test ist | ja, eine Zeile „Im Test" | ja, mit Bau-Nummer |
| Was geplant ist | **nein**, nur eine Zeile „Demnächst" ohne Einzelheiten | ja, mit Begründung und Reihenfolge |
| Termine | nie | nur, wo sie feststehen |

> **Eine Zeile wandert erst auf die Website, wenn sie im Test ist.** Nicht wenn
> sie geplant ist, nicht wenn jemand daran arbeitet. Was im Test ist, kommt mit
> hoher Wahrscheinlichkeit; was geplant ist, kann sich ändern, und dann stünde
> öffentlich etwas, das nie kam.

**„Intern" heißt hier: nicht auf der Website. Es heißt nicht: geheim.** Das
Repository ist öffentlich (am 31. August nachgemessen). Wer sucht, liest diese
Datei. Soll die Planung wirklich niemand sehen, gehört sie nicht hierher,
sondern an einen privaten Ort.

### Wo gearbeitet wird

`PulseCore` und der Klick-Dummy lassen sich unter Linux prüfen, sofern eine
Swift-Toolchain da ist; `scripts/pruefen.sh` **benennt**, was es überspringt,
statt still darüber hinwegzugehen. Alles mit SwiftUI, SwiftData oder CloudKit
braucht Xcode auf einem Mac oder den macOS-Läufer der CI.

Wer hier weiterarbeitet, findet die Arbeitsweise in `CLAUDE.md`, den laufenden
Zustand in `docs/06-uebergabe.md` und den Ablauf für Versionen, Release Notes
und Tests in `.claude/skills/release-discipline/SKILL.md`.
