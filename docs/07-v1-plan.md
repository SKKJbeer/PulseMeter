# 07 – Der Weg zum ersten Go-Live

Stand: 2026-08-10, Version 0.36.0
Ziel: **1.0 im App Store**, mit dem kleinsten Umfang, der das Produktversprechen einlöst.

---

## Leitsatz

Nicht alles muss zum ersten Release fertig sein. Fertig muss sein, was ein
Nutzer am ersten Tag braucht — und alles, was Apple verlangt.

Der Rest ist 1.1, und 1.1 kommt schneller, wenn 1.0 draußen ist. Die größte
Gefahr bleibt Risiko R7 aus `00-produktstrategie.md`: eine Version 1, die nie
fertig wird.

---

## 1. Der Engpass ist kein Feature

**Apple Developer Program, 99 € im Jahr.** Ohne das gibt es kein TestFlight,
keinen App Store, keine Paywall und keine App-Gruppe fürs Widget. Es blockiert
allein, es lässt sich nicht vorarbeiten, und die Verifizierung dauert
gelegentlich Tage.

Das ist Schritt eins. Alles andere läuft parallel.

---

## 2. Was bereits steht

Erfassung, Übersicht, Verlauf, Zählerverwaltung, Tarife, Kosten, Prognose,
Abschlagsvergleich, Zweirichtungszähler, Doppeltarif, Zählerwechsel,
CSV-Export, Erinnerungen, Widget, PDF-Bericht. Rechenkern mit 172 Prüfungen,
`PulseData` auf macOS geprüft, Design-System in Hell und Dunkel.

Das ist mehr Umfang, als die meisten 1.0 haben.

---

## 3. Was für 1.0 noch hinein muss

Diese Liste ist am 10. August **am Code nachgesehen** worden, nicht
fortgeschrieben. Dabei kamen sechs Punkte dazu, die hier fehlten — zwei davon
größer als alles, was vorher dastand.

| Was | Zustand | Wer |
|---|---|---|
| ~~Sperrlogik: dritter Zähler, zweites Zählwerk, Preise, Bericht~~ | **erledigt mit 0.35.0** | — |
| StoreKit 2: Produkt, Kauf, Kaufwiederherstellung | offen, aber vorbereitet — `PurchaseGateway` ist eine Datei | Mac, nach dem Programm |
| **CloudKit einschalten** — steht auf `false`, weil die Berechtigung fehlt | nie gelaufen | Mac, nach dem Programm |
| **App-Icon und Asset-Katalog** — es gibt im Repo keine `.xcassets` | nicht angefangen | gemeinsam |
| **`PrivacyInfo.xcprivacy`** — Apple verlangt es seit Mai 2024 | fehlt | Mac |
| **`.entitlements`** — App-Gruppe fürs Widget, iCloud | fehlt | Mac, nach dem Programm |
| ~~Barrierefreiheit: Widget und Erfassung~~ | **erledigt mit 0.36.0** | — |
| **App-Store-Material** — Bilder je Gerätegröße, Texte, Datenschutzerklärung mit URL, Support-URL | **nicht angefangen** | gemeinsam |
| App-Privacy-Angaben | offen | Nutzer |
| 800 ms Kaltstart auf einem **Gerät** | nie gemessen | Nutzer |
| **Zwei Wochen echte Eigennutzung** | offen | Nutzer |

### Die zwei, die vorher fehlten und wehtun

**Die Sperrlogik** stand nur als „Paywall" da — das ist der Verkaufsteil. Der
Sperrteil, also die Stellen, an denen die App tatsächlich nein sagt, war
ungeschrieben. Mit 0.35.0 ist er fertig und geprüft; übrig bleibt der Kauf
selbst, und der ist eine Datei hinter dem Developer Program.

**CloudKit ist abgeschaltet.** `App/PulseMeterApp.swift` ruft
`PulseStore.container(cloudKit: false)`, sauber begründet: Ohne die
iCloud-Berechtigung scheitert schon der Aufbau des Speichers beim ersten Start.
Der Abgleich ist laut ADR-002 aber genau das, was den Einmalkauf trägt — ein
Kauf, der nur auf einem Gerät gilt, ist keiner. Und er ist **bis heute nie
gelaufen**. Ein Schalter ist das nicht; eine SwiftData-Schemamigration über
CloudKit ist eine eigene Testrunde.

### Was das Nachsehen für die Barrierefreiheit zutage gefördert hat

Eine **Taste, die nichts tat** — Kamerasymbol, für VoiceOver als „Belegfoto"
angekündigt, ohne Wirkung. Sie stand seit der ersten Fassung des
Erfassungsschirms dort und ist keinem Test und keinem Bildschirmfoto
aufgefallen, weil beide nur prüfen, was passiert, und nicht, was ausbleibt.

Das ist die Regel dahinter, und sie gilt über die Barrierefreiheit hinaus:
**Ein Platzhalter für eine gestrichene Funktion ist in der ausgelieferten App
ein Versprechen.** Bei der nächsten Durchsicht vor der Einreichung gehört
danach gesucht.

**Das Widget bleibt ohne Berechtigungsdatei still leer.**
`Shared/WidgetBridge.swift` erwartet die App-Gruppe `group.com.pulsemeter.app`
und fällt ohne sie auf den app-eigenen Ordner zurück — mit Absicht, damit die
App in der CI läuft. Auf einem Gerät hieße das: Das Widget zeigt dauerhaft
nichts, ohne Fehlermeldung, ohne Absturz. Genau die Sorte Fehler, die kein Test
findet und die erst auf dem Gerät auffällt.

### Warum die Eigennutzung ganz oben mitsteht

Sieben der bisher gefundenen Darstellungsfehler hat kein Test gefunden, sondern
der Blick auf einen Screenshot. Und der eine Fehler, der den Erfassungsfluss zur
Sackgasse machte, fiel auf, weil jemand die App **benutzt** hat.

Zwei Wochen mit den eigenen Zählerständen finden mehr als jede weitere Runde
Tests. Das Zeitfenster für die Reparaturen danach gehört fest eingeplant — es
füllt sich zuverlässig.

### Was am meisten unterschätzt wird

Das App-Store-Material. Icon, sechs bis acht Bilder je Gerätegröße, Kurz- und
Langbeschreibung, Schlagworte, eine erreichbare Datenschutzerklärung und eine
Support-Adresse. Das ist kein Nachmittag, und es blockiert am Ende die
Einreichung, wenn man zu spät anfängt.

---

## 4. Was gestrichen wird

| Gestrichen | Nach | Warum das trägt |
|---|---|---|
| **Foto-Belege** | 1.1 | Größtes Restrisiko im ganzen Umfang: Bilder in CloudKit, Speicherplatz, Export, Löschen, Zählerwechsel. Viel Arbeit für ein Pro-Merkmal, das niemand vermisst, der die App noch nicht hat |
| **Siri-Kurzbefehl** | 1.1 | Wer die App nicht kennt, richtet keinen Kurzbefehl ein |
| **Widget** | 1.0, aber ohne Gnade | Ist gebaut. Zickt die App-Gruppe, fliegt es raus, statt den Start zu verschieben |
| Vermieter, iPad, Import | 1.1 | War nie in 1.0 |

Foto-Belege sind der einzige Streichposten, bei dem es weh tut: Sie stehen in
`04-monetarisierung.md` in der Pro-Liste. Pro trägt aber auch ohne sie —
unbegrenzte Zähler, Kosten und Tarife, Abschlagsvergleich, Jahresprognose und
der PDF-Bericht sind fünf Gründe, und keiner davon ist ein Versprechen auf
später.

**In der Pro-Beschreibung im Store dürfen sie deshalb nicht auftauchen.** Ein
verkauftes Merkmal, das es nicht gibt, ist eine Rückerstattung und eine
schlechte Bewertung.

---

## 5. Reihenfolge

1. **Apple Developer Program kaufen.** Blockiert alles Weitere.
2. **Die App benutzen** — ab sofort, parallel, mit echten Zählerständen.
3. **StoreKit, CloudKit, Berechtigungen**, sobald das Programm da ist — die
   drei hängen am selben Nagel. Die Sperrlogik steht bereits.
4. **Reparieren, was Punkt 2 gefunden hat.** Dieses Fenster nicht wegplanen.
5. **800 ms auf dem Gerät messen.** Die Barrierefreiheit steht seit 0.36.0.
6. **App-Store-Material.** Früher anfangen, als es sich anfühlt.
7. **TestFlight** an fünf bis zehn Leute, zwei Wochen.
8. **Einreichen.** Die erste Ablehnung ist normal und eingeplant.

---

## 6. Was ohne den Nutzer geht — und was nicht

| Ort | Kann |
|---|---|
| Cloud-Sitzung (Linux) | Rechenkern, Klick-Dummy, Dokumente, Werkzeug, CI |
| Sitzung am Mac | Paywall, Barrierefreiheit, App-Build, Bilder fürs Material |
| **Nur der Nutzer** | Developer Program, Messung auf dem Gerät, zwei Wochen Eigennutzung, und die Entscheidung, was gut genug ist |

---

## 7. Zeitrahmen, ehrlich

**Vier bis sechs Wochen bis zur Einreichung**, wenn das Programm diese Woche
gekauft und die App tatsächlich benutzt wird. Der Code ist nicht das Problem —
Material, Eigennutzung und Review sind es.

Ein Vorbehalt gehört dazu: Die App lief noch nie auf einem echten Gerät. Das
kann diesen Plan ändern — genau deshalb steht die Eigennutzung so weit vorn.

Der zweite Vorbehalt ist inzwischen erledigt: Der PDF-Bericht war bis 0.33.3
unsichtbar und wird seither auf jedem Lauf fotografiert, hell und dunkel.
