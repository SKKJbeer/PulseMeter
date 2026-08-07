# 05 – Roadmap und v1-Scope

Status: laufend gepflegt
Letzte Änderung: 2026-08-06

---

## Leitsatz

Der v1-Scope ist bewusst schmerzhaft klein. Jede Funktion, die wir vor dem ersten echten Nutzer bauen, ist eine Wette ohne Rückmeldung. Die größte Gefahr für dieses Projekt ist nicht ein fehlendes Feature — es ist eine Version 1, die nie fertig wird (Risiko R7).

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

## Aktueller Stand — Version 0.28.0

| Schritt | Stand |
|---|---|
| 1. `PulseCore` + Tests | **fertig** — 135 Prüfungen, alle Randfälle aus `02`, Abschnitt 3 |
| 2. `PulseData` + Repositories | **fertig** — auf macOS geprüft |
| 3. `PulseUI` Design-System | **fertig** — Hell und Dunkel, auf jedem Lauf fotografiert |
| 4. Erfassungsfluss | **fertig** — Zählwerk-Optik, Plausibilisierung, Vorbelegung |
| 5. Übersicht | **fertig** — Statuszeile, Karten, Kosten, Abschlagsvorschau |
| 6. Verlauf und Zählerverwaltung | **fertig** — Monat/Quartal/Jahr, Diagramm und Tabelle, Menge oder Kosten, CSV-Export; Zählerverwaltung mit Preisen, Abschlag, Archiv |
| 7. Tarife, Kosten, Prognose | **fertig** — saisonale Hochrechnung, Abschlagsvergleich |
| 8. Widgets, Kurzbefehle, Erinnerungen | Erinnerungen und Widget **fertig**; Siri offen |
| 9. Paywall und StoreKit | offen — braucht das Apple Developer Program |
| 10. Politur | **angefangen** (0.27.0) — Karte und Fußzeilen lesen sich für VoiceOver als ein Satz, Bilder bei größter Schrift, Startzeit im Protokoll. Die 800 ms auf einem **Gerät** sind weiter offen |

### Was die App noch nicht kann, obwohl der Rechenkern es kann

Diese Liste ist wichtiger als sie aussieht: Was in `PulseCore` steht und in
der Oberfläche fehlt, sieht in den Tests grün aus und ist trotzdem nicht da.

| Fähigkeit | Rechenkern | App | Entwurf |
|---|---|---|---|
| Zweirichtungszähler (PV-Einspeisung) | ja | ja | ja |
| Doppeltarif (HT/NT) | ja | **nein** | nein |
| Zählerwechsel | ja | ja | ja |
| PDF-Bericht | — | **nein** | ja |
| Foto-Belege | — | nein | nein |

Der Zweirichtungszähler ist mit 0.22.0 geschlossen, der Zählerwechsel mit
0.23.0 — dort allerdings **nur in der App**.

Mit 0.24.0 ist auch der Entwurf nachgezogen: Er rechnet jetzt über dieselbe
aufsummierte Reihe wie `PulseCore`, mit Gerätewechsel und Zählerüberlauf, und
der Wechsel lässt sich anklicken. Damit gilt Regel 2 wieder ohne Einschränkung.

Offen bleibt der **Doppeltarifzähler**, und dort fehlt er auf beiden Seiten —
in der App und im Entwurf. Der Entwurf sollte zuerst drankommen: Ein Fehler
fällt dort schneller auf und kostet weniger.

Zusätzlich entstanden, weil der Prototyp es nötig machte: Datenansicht mit
Monats-, Quartals- und Jahresvergleich, Verbrauchsbericht mit Zeitraumwahl,
CSV-Export, `BillingCycle`, `ScaledDecimal`, `PulseSnapshot`.

Das Xcode-Projekt entsteht aus `project.yml`, und eine CI auf einem
macOS-Läufer baut, testet und startet die App bei jedem Push. Sie legt
Screenshots in Hell und Dunkel ab — damit lässt sich das Ergebnis auch ohne
Mac beurteilen.

### Die nächsten drei Schritte

1. **Barrierefreiheit weiterführen.** Mit 0.27.0 ist der Anfang gemacht;
   Erfassungsschirm, Verlauf und Zählerverwaltung sind noch nicht durchgegangen.
   Die Bilder bei größter Schrift zeigen, wo es klemmt — sie werden ab dem
   nächsten Lauf mitgeliefert.

2. **Doppeltarif (HT/NT).** Fehlt auf beiden Seiten; der Entwurf sollte zuerst
   drankommen, weil ein Fehler dort schneller auffällt.

Danach Paywall und StoreKit, sobald das Apple Developer Program vorliegt. Das
Widget wartet ebenfalls darauf: Die App-Gruppe greift ohne Entwicklerkonto
nicht, im Simulator läuft der Ersatzpfad.

### Wo gearbeitet wird

`PulseCore` und der Klick-Dummy lassen sich unter Linux vollständig prüfen —
Swift-Toolchain unter `/opt/swift/usr/bin`, Chromium für Playwright unter
`/opt/pw-browsers`. Alles mit SwiftUI, SwiftData oder CloudKit braucht Xcode
auf einem Mac.

Wer dort mit Claude Code weiterarbeitet, findet die Arbeitsweise in `CLAUDE.md`
und den Ablauf für Versionen, Release Notes und Tests in
`.claude/skills/release-discipline/SKILL.md`. Beides wird automatisch gelesen.
