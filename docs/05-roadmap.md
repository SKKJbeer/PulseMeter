# 05 – Roadmap und v1-Scope

Status: Entwurf zur Entscheidung
Letzte Änderung: 2026-08-04

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

## Aktueller Stand und nächster Schritt

Erledigt ist Schritt 1 der Reihenfolge: `Packages/PulseCore` enthält das vollständige Domänenmodell und den Rechenkern, abgesichert durch 50 Unit-Tests. Abgedeckt sind alle Randfälle aus `02`, Abschnitt 3 — Zählerwechsel, Überlauf, unerklärter Rücksprung, Interpolation, Tarifwechsel im Zeitraum, Gas-Umrechnung, Einspeisegutschrift, saisonale Hochrechnung, Abschlagsvergleich.

Nächster Schritt ist `PulseData`: SwiftData-Modelle als Spiegel der Domänentypen, Repository-Protokolle, Migrations- und Backup-Pfad.

**Einschränkung der Arbeitsumgebung:** Die Session läuft auf Linux mit Swift-6-Toolchain. `PulseCore` wird hier gebaut und getestet. `PulseUI`, `PulseData` und `PulseFeatures` hängen an Apple-Frameworks — sie können hier geschrieben, aber erst in Xcode auf einem Mac kompiliert und im Simulator geprüft werden.
