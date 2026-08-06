---
name: xcode-workflow
description: Bauen, Testen und Ausführen von PulseMeter auf einem Mac mit Xcode. Diese Skill verwenden, sobald am App-Target, an SwiftUI-Code, an PulseData oder am Xcode-Projekt gearbeitet wird — also bei allem, was nicht reines PulseCore oder der Klick-Dummy ist. Auch verwenden, wenn nach einem Screenshot, einem Simulator-Lauf, einem Build-Fehler oder „läuft die App?" gefragt wird, und wenn das Xcode-Projekt fehlt oder neu erzeugt werden muss.
---

# Arbeiten mit Xcode

Alles läuft über Skripte in `scripts/`, nicht über die Xcode-Oberfläche. Grund:
Was sich als Befehl ausführen lässt, kann eine Sitzung ohne Bildschirm selbst
prüfen — und was geprüft werden kann, wird nicht geraten.

## Einmalig einrichten

```bash
scripts/setup-mac.sh
```

Prüft Xcode und Swift, installiert bei Bedarf XcodeGen, erzeugt
`PulseMeter.xcodeproj` und lässt die Paket-Tests laufen. Mehrfach ausführbar.

## Der tägliche Ablauf

```bash
scripts/test.sh              # alles: PulseCore, PulseData, App im Simulator
scripts/test.sh core         # nur die Domäne, wenige Sekunden
scripts/test.sh data         # nur die Persistenz
scripts/test.sh app          # nur die App-Tests im Simulator

scripts/run.sh               # bauen, starten, Screenshot nach build/screenshot-light.png
scripts/run.sh dark          # dasselbe im Dunkelmodus
```

Den Screenshot danach **ansehen**. Ein grüner Build sagt nichts über Layout,
Kontrast oder abgeschnittene Beschriftungen. Beide Erscheinungsbilder prüfen —
das verlangt schon `CLAUDE.md`, Regel 3.

## Das Projekt ist erzeugt, nicht gepflegt

`PulseMeter.xcodeproj` liegt **nicht** im Repository. Die Wahrheit steht in
`project.yml`; das Projekt entsteht daraus mit `xcodegen generate`.

Daraus folgt: **Neue Dateien niemals im Projekt eintragen, sondern in den
Ordner legen.** `App/` wird vollständig eingelesen. Wer stattdessen in Xcode
eine Datei hinzufügt, verliert sie beim nächsten Erzeugen.

Ändert sich etwas an Zielen, Abhängigkeiten oder Einstellungen, gehört das in
`project.yml` — danach `xcodegen generate`.

## Wenn es klemmt

| Fehlerbild | Ursache und Behebung |
|---|---|
| `xcodebuild: command not found` | Xcode fehlt oder `xcode-select` zeigt auf die Developer Tools: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `No such module 'PulseCore'` | Projekt veraltet → `xcodegen generate` |
| Signierfehler beim Simulator | `CODE_SIGNING_ALLOWED=NO` fehlt; die Skripte setzen es bereits |
| Kein Simulator gefunden | Xcode → Settings → Components → iOS Simulator installieren. Ein bestimmtes Gerät erzwingen: `PULSE_SIMULATOR=<udid> scripts/run.sh` |
| `ModelContainer` schlägt beim Start fehl | CloudKit ist eingeschaltet, aber die iCloud-Berechtigung fehlt. Entweder Capability eintragen oder `cloudKit: false` lassen. |

## CloudKit einschalten

Vorerst aus, damit die App ohne Konfiguration startet. Zum Einschalten:

1. In `project.yml` beim Target die Berechtigung ergänzen (iCloud mit CloudKit,
   Container `iCloud.com.pulsemeter.app`, dazu Background Modes → Remote
   notifications), `xcodegen generate`
2. In `App/PulseMeterApp.swift` `cloudKit: false` entfernen
3. Mit zwei Geräten oder Simulatoren am selben iCloud-Konto prüfen

Ohne echten Test über zwei Geräte gilt die Synchronisation als ungeprüft — sie
ist laut `docs/00-produktstrategie.md` das Risiko R3 und darf nicht als fertig
gemeldet werden, nur weil es kompiliert.

## Was diese Skill nicht ersetzt

Die Regeln aus `CLAUDE.md` und `release-discipline` gelten unverändert: Version
vergeben, `CHANGELOG.md` ergänzen, Tests ausführen **und erweitern**, und jede
Produktänderung in den Klick-Dummy übernehmen. Ein Screen, der in SwiftUI
entsteht, gehört auch weiterhin in `docs/prototype/index.html` — sonst laufen
Entwurf und App auseinander.
