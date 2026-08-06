# PulseData

Persistenzschicht: SwiftData-Modelle als Spiegel der Domänentypen aus
`PulseCore`, dahinter CloudKit.

## Prüfen in Xcode

```
open Packages/PulseData/Package.swift
```

Dann `⌘U`. Die Tests laufen gegen einen Speicher im Arbeitsspeicher, nie gegen
CloudKit — für die Testziele ist `cloudKitDatabase: .none` gesetzt.

Für den Betrieb mit Synchronisation braucht das App-Target zusätzlich:

- Capability **iCloud** mit **CloudKit**, ein Container `iCloud.<bundle-id>`
- Capability **Background Modes** → **Remote notifications**

Ohne diese Angaben schlägt `PulseStore.container(cloudKit: true)` fehl. Ein
reiner Paket-Test braucht sie nicht.

## Wo die Fehler zu erwarten sind

Dieses Paket wurde unter Linux geschrieben und konnte dort nicht übersetzt
werden — SwiftData gibt es nur auf Apple-Plattformen. Erwartbare Stolpersteine:

1. **Prädikate.** `#Predicate` ist wählerisch. Die Fremdschlüssel liegen
   deshalb als `UUID` direkt am Datensatz und nicht nur als Beziehung.
2. **Beziehungen unter CloudKit.** Alle Beziehungen zu vielen sind optionale
   Arrays mit erklärter Umkehrung; das verlangt CloudKit so.
3. **Vorgabewerte.** Jede Eigenschaft hat einen Wert oder ist optional, sonst
   kann CloudKit bestehende Datensätze nicht um Felder ergänzen.
