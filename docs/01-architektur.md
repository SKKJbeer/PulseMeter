# 01 – Architektur

Status: Entwurf zur Entscheidung
Letzte Änderung: 2026-08-04

Dieses Dokument enthält die grundlegenden technischen Entscheidungen im ADR-Format
(Problem → Optionen → Vor-/Nachteile → Empfehlung → Begründung → Auswirkungen).

---

## ADR-001 – Plattform und UI-Technologie

**Problem.** Die App soll sich wie eine native Apple-App anfühlen und im App Store bestehen.

**Optionen.**

| Option | Vorteile | Nachteile |
|---|---|---|
| **SwiftUI, iOS-nativ** | Bestes Gefühl, Widgets/Live Activities/Siri/Shortcuts nativ, Dynamic Type & VoiceOver kostenlos, geringste Reibung bei Apple-typischen Animationen | Nur Apple-Plattformen |
| UIKit | Maximale Kontrolle über Animationen, ausgereift | Deutlich mehr Code, langsamere Iteration, kein moderner Look ohne Mehraufwand |
| Flutter / React Native | Android später „gratis" | Fühlt sich nie ganz nativ an, Widgets/Siri/Shortcuts sind Fremdkörper, Dynamic Type/VoiceOver schwächer — widerspricht direkt der Mission |

**Empfehlung: SwiftUI, iOS-nativ, iPad und Mac (Catalyst/Designed for iPad) als kostenloser Nebeneffekt.**

**Begründung.** Die Mission lautet nicht „möglichst viele Plattformen", sondern „fühlt sich an wie eine native Apple-App". Cross-Platform würde genau das aufgeben, was unser einziger echter Wettbewerbsvorteil ist. Android ist eine spätere, eigenständige Entscheidung — nicht ein Nebenprodukt.

**Auswirkung.** Deployment-Ziel bewusst hoch ansetzen (siehe offene Frage): je höher, desto weniger Legacy-Code, desto moderner die verfügbaren APIs. Empfehlung **iOS 18+**, weil damit SwiftData deutlich stabiler ist und moderne Chart-/Navigation-APIs ohne Rückfallpfade nutzbar sind. Der Verlust an erreichbaren Geräten ist bei einer neuen App irrelevant (Nutzer, die 2026 eine neue Utility-App installieren, sind quasi vollständig auf aktuellen Systemen).

---

## ADR-002 – Persistenz und Synchronisation

**Problem.** Die App muss offline-first arbeiten, Daten dürfen niemals verloren gehen, und Nutzer erwarten iPhone↔iPad-Sync ohne Konto. Gleichzeitig sind Verbrauchsdaten sensibel (Anwesenheit, Lebensgewohnheiten, Vermögensverhältnisse lassen sich daraus ableiten).

**Optionen.**

| Option | Vorteile | Nachteile |
|---|---|---|
| **SwiftData + CloudKit (private DB)** | Sync praktisch kostenlos, kein eigener Server, keine laufenden Kosten, kein Auftragsverarbeitungsvertrag, deklarativ, sehr wenig Code | Schema-Einschränkungen unter CloudKit (keine `@Attribute(.unique)`, alle Properties benötigen Defaults/Optional, keine echten Constraints), Migrationen weniger mächtig, Reifegrad-Risiko |
| Core Data + NSPersistentCloudKitContainer | Ausgereift, dieselben Sync-Vorteile, mächtigere Migrationen | Deutlich mehr Boilerplate, älteres Programmiermodell, schlechtere Swift-Concurrency-Integration |
| GRDB (SQLite) + eigener Sync | Volle Kontrolle, exzellent testbar, echte Constraints, schnelle & präzise Migrationen | Sync selbst bauen = Backend, Konten, Konfliktauflösung, DSGVO-Verantwortung, laufende Kosten — ein Mehrfaches des restlichen Aufwands |
| GRDB + CloudKit-Dokument-Sync (Datei in iCloud Drive) | Kein Backend, volle DB-Kontrolle | Konfliktauflösung bei gleichzeitiger Bearbeitung ist ein bekanntes Minenfeld |

**Empfehlung: SwiftData + CloudKit (private Datenbank), hinter einer Repository-Abstraktion.**

**Begründung.**
1. **Kostenstruktur:** CloudKit private DB zählt gegen das iCloud-Kontingent des Nutzers, nicht gegen unser Budget. Das ist die Voraussetzung dafür, dass ein Einmalkauf (siehe `04`) wirtschaftlich funktioniert. Ein eigenes Backend würde uns in ein Abo zwingen — und damit die Monetarisierung von der Technik diktieren lassen statt vom Nutzerwert.
2. **Datenschutz:** Daten verlassen nie die Apple-Sphäre des Nutzers. Wir sind kein Datenempfänger. Das ist im DSGVO-Kontext ein enormer struktureller Vorteil und ein ehrliches Marketing-Argument.
3. **Schema-Größe:** Unser Modell ist klein (ca. 8 Entitäten). Die SwiftData-Einschränkungen tun bei dieser Größe kaum weh.

**Risiko und Gegenmaßnahme (R3).** SwiftData+CloudKit ist der riskanteste Teil des Stacks. Deshalb:
- Der gesamte Datenzugriff läuft über Protokolle (`MeterRepository`, `ReadingRepository`), nie direkt über `ModelContext` in Feature-Code. Ein späterer Wechsel zu GRDB ist damit ein begrenztes Refactoring in einem Modul statt einer Neuentwicklung.
- Die Domänenlogik (`PulseCore`) kennt **keine** Persistenztechnologie. Sie arbeitet auf reinen `struct`-Wertetypen.
- Automatisches lokales Backup (JSON-Snapshot) vor jeder Schema-Migration, plus jederzeit manuell auslösbarer Export.
- Keine Beziehung im Modell, die ohne Datenverlust nicht rekonstruierbar wäre.

**Auswirkung.** `PulseCore` ist plattformfrei und ohne Apple-Frameworks testbar — auch auf Linux/CI ohne Mac. Das ist bewusst so gewählt, damit die kritische Rechenlogik unabhängig von der Xcode-Umgebung verifiziert werden kann.

---

## ADR-003 – Modulschnitt

**Problem.** Die App muss langfristig erweiterbar bleiben (neue Zählerarten, Vermieter-Modul, ggf. Live-Datenquellen) ohne dass jede Änderung überall Wellen schlägt.

**Empfehlung: lokale Swift-Packages, streng gerichtete Abhängigkeiten.**

```
PulseMeterApp            (App-Target: nur Composition Root, App-Lifecycle, DI)
 └── PulseFeatures       (Feature-Module: Home, Capture, History, Meters, Settings, Paywall)
      ├── PulseUI        (Design-System: Farben, Typo, Komponenten, Animationen — keine Fachlogik)
      ├── PulseData      (SwiftData-Modelle, Repositories, Migrationen, CloudKit)
      └── PulseCore      (Domäne: Wertetypen, Rechenkern, Einheiten, Tarife — KEINE Abhängigkeiten)
```

**Regeln.**
- `PulseCore` importiert nur `Foundation`. Kein SwiftUI, kein SwiftData. Dadurch: schnelle Tests, kein Simulator nötig, plattformunabhängig verifizierbar.
- `PulseUI` kennt keine Fachbegriffe. Eine Komponente heißt `ValueCard`, nicht `MeterCard`.
- `PulseFeatures` sind untereinander unabhängig; Kommunikation über den Composition Root.
- Kein Modul importiert das App-Target.

**Begründung.** Der Rechenkern ist der Ort, an dem Wettbewerber Fehler machen (negative Verbräuche bei Zählerwechsel, falsche Hochrechnung über Monatsgrenzen, Rundungsfehler bei Geld). Wenn er isoliert und vollständig testbar ist, gewinnen wir dort Qualität, die man der App im Store ansieht.

**Auswirkung.** Etwas mehr Anfangsaufwand (Package-Setup), dafür bleiben Build- und Testzeiten klein und das Vermieter-Modul kann später additiv entstehen.

---

## ADR-004 – Zahlen, Geld, Zeit

Drei Entscheidungen, die klein aussehen und später jeden Bug verursachen:

**1. `Decimal` statt `Double` — überall.**
Zählerstände und Geldbeträge werden ausschließlich als `Decimal` geführt. `Double` erzeugt bei Beträgen wie `0,1 + 0,2` Rundungsartefakte, die in einer Abrechnung sichtbar werden und Vertrauen kosten. Performance ist bei unseren Datenmengen irrelevant.

**2. Ablesetage sind Kalendertage, keine Zeitpunkte.**
Eine Ablesung findet „am 3. August" statt, nicht „am 3. August um 14:22 Uhr UTC". Wird ein `Date` gespeichert, entstehen bei Zeitzonenwechsel, Sommerzeit und Gerätereisen Off-by-one-Fehler, die Verbräuche verfälschen.
→ Eigener Wertetyp `CalendarDay`, persistiert als `Int` im Format `yyyyMMdd`. Sortierbar, vergleichbar, zeitzonenfrei, migrationssicher.
Der Erfassungs-Zeitstempel (`createdAt`) wird separat als echtes `Date` geführt — für Beweiszwecke, nicht für Berechnungen.

**3. Einheiten sind Teil des Wertes, nicht ein String daneben.**
`Quantity { value: Decimal, unit: MeasurementUnit }` als Wertetyp. Verhindert die Klasse von Fehlern, bei denen m³ mit kWh addiert werden. Gas-Umrechnung (m³ → kWh) ist eine explizite, dokumentierte Konvertierung mit Zustandszahl und Brennwert — nie eine implizite.

---

## ADR-005 – Testbarkeit

**Empfehlung.**
- `PulseCore`: 100 % der Rechenwege durch Unit-Tests abgedeckt, inklusive Randfälle (Zählerwechsel, Überlauf, Tarifwechsel mitten im Zeitraum, Schaltjahr, fehlende Ablesungen, Rückwärtssprung durch Tippfehler). Diese Tests sind der Qualitätsanker des Produkts.
- `PulseData`: Repository-Tests gegen einen In-Memory-`ModelContainer`.
- `PulseFeatures`: Snapshot-Tests für die Design-System-Komponenten in Light/Dark und bei größter Dynamic-Type-Stufe. Letzteres fängt genau die Layoutbrüche, die eine App billig wirken lassen.
- Kein Test gegen echte CloudKit-Instanzen in CI.

**Begründung.** Wir testen dort, wo Fehler teuer sind (Rechnen, Layout unter Barrierefreiheits-Einstellungen), nicht überall gleichmäßig.

---

## ADR-006 – Datenschutz

**Empfehlung.**
- Kein Konto, keine Registrierung, keine E-Mail-Adresse.
- Kein Analytics-SDK von Drittanbietern. Wenn Telemetrie, dann ausschließlich Apples aggregierte App-Analytics oder eine opt-in, minimalistische Ereignisliste ohne Nutzerkennung.
- Kein Netzwerkzugriff im Kernprodukt außer CloudKit und StoreKit. Die App kann im Flugmodus vollständig genutzt werden.
- Fotos von Zählern bleiben lokal bzw. in der privaten CloudKit-Datenbank; sie werden nie an einen Dienst gesendet — auch OCR läuft später ausschließlich auf dem Gerät (Vision Framework).
- App Privacy Nutrition Label: „Keine Daten erfasst". Das ist ein Verkaufsargument und muss wörtlich stimmen.

**Begründung.** Verbrauchsdaten sind Verhaltensdaten. Der glaubwürdigste Datenschutz ist der, den wir technisch gar nicht brechen können.

---

## 7. Offene technische Fragen

1. **Minimales iOS-Ziel:** Empfehlung iOS 18+. Bestätigung nötig, da es SwiftData-Stabilität und verfügbare APIs bestimmt.
2. **SwiftData vs. GRDB:** Empfehlung SwiftData (ADR-002). Gegenargument, falls du maximale Kontrolle und Migrationssicherheit über Sync-Komfort stellst — dann GRDB ohne Sync in v1 und Sync als spätere, bewusste Investition.
3. **Entwicklungsumgebung:** Diese Session läuft auf Linux. Eine Swift-6-Toolchain ist installiert, `PulseCore` wird daher hier tatsächlich kompiliert und getestet — genau der Grund, warum die Domänenschicht keine Apple-Frameworks importiert. Alles mit SwiftUI, SwiftData oder CloudKit (`PulseUI`, `PulseData`, `PulseFeatures`) benötigt Xcode auf einem Mac; das kann ich hier schreiben, aber nicht bauen oder im Simulator prüfen.
