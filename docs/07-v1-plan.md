# 07 – Der Weg zum ersten Go-Live

Stand: 2026-08-16, Version 0.56.0
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

Diese Liste ist am 16. August erneut **am Code nachgesehen** worden, nicht
fortgeschrieben. Sechs Punkte sind seit der letzten Fassung weggefallen, und
kein neuer ist dazugekommen.

| Was | Zustand | Wer |
|---|---|---|
| ~~Sperrlogik: dritter Zähler, zweites Zählwerk, Preise, Bericht~~ | **erledigt mit 0.35.0** | — |
| ~~Barrierefreiheit: Widget und Erfassung~~ | **erledigt mit 0.36.0** | — |
| ~~App-Icon und Asset-Katalog~~ | **erledigt** — `Assets.xcassets/AppIcon.appiconset`, erzeugt aus `scripts/icon.mjs` | — |
| ~~App-Store-Texte, Kategorien, Datenschutzangaben~~ | **erledigt mit 0.44.0** — `09-appstore.md`, Beschreibung 3.844 von 4.000 Zeichen | — |
| ~~Bildschirmfotos fürs Material~~ | **erledigt** — `scripts/store-shots.mjs` liefert 1320 × 2868, das Pflichtmaß für 6,9 Zoll | — |
| ~~Datenschutzerklärung und Support-Seite als Text~~ | **erledigt mit 0.43.0** — `docs/website/`, es fehlt nur noch die Veröffentlichung | — |
| ~~Sicherheitsprüfung~~ | **erledigt mit 0.47.0**, erweitert in 0.53.0 — `11-sicherheit.md`, acht Prüfungen bei jedem Lauf | — |
| ~~**`PrivacyInfo.xcprivacy`**~~ | **erledigt mit 0.55.0** — je eines für App und Widget, geprüft von `check-sicherheit.sh`. Auf dem Mac ist einmal nachzusehen, dass es im gebauten Bündel landet | — |
| **Website veröffentlichen** — Cloudflare Pages, Ausgabeordner `docs/website` | offen, hängt **nicht** am Programm | Nutzer |
| StoreKit 2 | **Code steht seit 0.56.0** (`App/StoreKitGateway.swift`), nie übersetzt und nie gegen den Sandkasten geprüft. Offen bleibt: die fünf Produkte in App Store Connect anlegen | Nutzer + Mac |
| **CloudKit** | **Seit 0.56.0 eingeschaltet**, mit Rückfall auf lokal ohne Abgleich. Nie gelaufen — die Schemamigration ist die eigentliche Unbekannte | Nutzer + Mac |
| ~~**`.entitlements`**~~ | **erledigt mit 0.56.0.** Die Kennungen legt Xcode beim ersten Gerätebau selbst an — kein Weg über das Portal | — |
| 800 ms Kaltstart auf einem **Gerät** | nie gemessen | Nutzer, nach dem Programm |
| **Zwei Wochen echte Eigennutzung** | offen | Nutzer, nach dem Programm |

**Zwei davon warten auf niemanden.** Das Privacy-Manifest ist eine
Plist-Datei im Bündel und braucht kein Programm; die Website braucht nur ein
Cloudflare-Konto. Beides lässt sich vorziehen, und beides blockiert am Ende
die Einreichung — die Datenschutz-URL ist ein Pflichtfeld in App Store
Connect.

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
`Shared/WidgetBridge.swift` erwartet die App-Gruppe `group.de.karjoth.pulsemeter`
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

### Was am meisten unterschätzt wurde — und was jetzt an seiner Stelle steht

Hier stand bis 0.53.0 das **App-Store-Material**: Icon, Bilder je Gerätegröße,
Beschreibung, Schlagworte, Datenschutzerklärung, Support-Adresse. Die Warnung
war richtig, und sie ist abgearbeitet — seit 0.44.0 steht alles in
`09-appstore.md`, die Bilder erzeugt `scripts/store-shots.mjs` im Pflichtmaß.

An seiner Stelle steht jetzt der **iCloud-Abgleich**. Er ist bis heute nie
gelaufen, er trägt laut ADR-002 den Einmalkauf, und eine
SwiftData-Schemamigration über CloudKit ist keine Einstellung, sondern eine
eigene Testrunde. Wer ihn für einen Schalter hält, plant eine Woche zu wenig
ein.

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

**Hängt nicht am Programm — jederzeit:**

1. **Website veröffentlichen.** Cloudflare Pages auf dieses Repo, Ausgabeordner
   `docs/website`. Danach den Namen des Hosters in der Datenschutzerklärung
   bestätigen und mit `PULSE_WEBSITE_LIVE=1 node scripts/check-website.mjs`
   gegenprüfen. Die Datenschutz-URL ist ein Pflichtfeld — ohne sie keine
   Einreichung.

**Sobald das Programm freigeschaltet ist, in dieser Reihenfolge.** Die
Reihenfolge ist nicht beliebig: Jeder Schritt setzt voraus, dass der vorige
steht, und Schritt 2 ist der, der die anderen erst prüfbar macht.

2. **Kennungen im Entwicklerportal anlegen** — die App-ID `de.karjoth.pulsemeter`,
   die App-Gruppe `group.de.karjoth.pulsemeter` (fürs Widget) und den
   iCloud-Container. **Erst danach** die `.entitlements` schreiben: Eine
   Berechtigungsdatei, die auf eine nicht angelegte Kennung zeigt, lässt die
   Signierung scheitern, und die Fehlermeldung sagt nicht, welche der drei
   fehlt.
3. **Die App aufs eigene Telefon** — `scripts/aufs-handy.sh` — und ab da
   benutzen, mit echten Zählerständen. **Nicht erst nach StoreKit.** Dieser
   Punkt hat bisher am meisten gefunden, und er braucht das Telefon, nicht den
   Kauf.
4. **CloudKit einschalten.** `App/PulseMeterApp.swift` ruft
   `PulseStore.container(cloudKit: false)`. Das ist der Schritt mit dem
   größten Rest an Unbekanntem — siehe oben.
5. **StoreKit.** Fünf Produkte in App Store Connect anlegen, dann
   `StoreKitGateway` gegen das bestehende `PurchaseGateway`-Protokoll
   schreiben. Die Sperrlogik steht seit 0.35.0; es fehlt nur der Kauf selbst.
6. **Reparieren, was Schritt 3 gefunden hat.** Dieses Fenster nicht wegplanen.
7. **800 ms Kaltstart auf dem Gerät messen.** Die Barrierefreiheit steht seit
   0.36.0.
8. **Bildschirmfotos neu erzeugen**, nachdem StoreKit steht — die Kaufseite
   sieht dann anders aus.
9. **TestFlight** an fünf bis zehn Leute, zwei Wochen.
10. **Einreichen.** Die erste Ablehnung ist normal und eingeplant.

**Warum Schritt 3 vor 4 und 5 steht.** Die App auf dem Telefon zu haben kostet
zwanzig Minuten und ist die einzige Voraussetzung dafür, dass die zwei Wochen
Eigennutzung überhaupt anfangen können. CloudKit und StoreKit dauern zusammen
eine Woche — wer sie vorzieht, verliert diese Woche für die Eigennutzung und
merkt am Ende zwei Wochen später, was er sonst am ersten Abend gesehen hätte.

---

## 6. Was ohne den Nutzer geht — und was nicht

| Ort | Kann |
|---|---|
| Cloud-Sitzung (Linux) | Rechenkern, Klick-Dummy, Dokumente, Werkzeug, CI |
| Sitzung am Mac | Paywall, Barrierefreiheit, App-Build, Bilder fürs Material |
| **Nur der Nutzer** | Developer Program, Messung auf dem Gerät, zwei Wochen Eigennutzung, und die Entscheidung, was gut genug ist |

---

## 7. Zeitrahmen, ehrlich

**Drei bis fünf Wochen ab dem Tag, an dem das Programm freigeschaltet ist.**
Das Material ist seit 0.44.0 fertig und fällt damit als Engpass weg — geblieben
sind StoreKit und CloudKit (eine Woche, wenn nichts dazwischenkommt), zwei
Wochen Eigennutzung, die sich nicht abkürzen lassen, und ein bis zwei Wochen
Prüfung bei Apple.

Ein Vorbehalt gehört dazu, und er ist derselbe wie im August: **Die App lief
noch nie auf einem echten Gerät.** Weder der Kaltstart noch das Widget noch der
iCloud-Abgleich sind je gemessen worden. Genau deshalb steht die Eigennutzung
so weit vorn — sie ist der Punkt, an dem sich dieser Zeitrahmen entscheidet,
nicht StoreKit.

Zwei frühere Vorbehalte sind erledigt: Der PDF-Bericht war bis 0.33.3
unsichtbar und wird seither auf jedem Lauf fotografiert, hell und dunkel. Und
das App-Store-Material, das hier als „am meisten unterschätzt" stand, ist seit
0.44.0 geschrieben und seither dreimal nachgezogen worden.
