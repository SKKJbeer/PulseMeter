# 05 – Roadmap und v1-Scope

Status: laufend gepflegt
Letzte Änderung: 2026-10-03

---

## Leitsatz

**Alle zwei Wochen eine Fassung im App Store.** Der Zug fährt, auch wenn ein
Wagen fehlt: Was am Einreichungstag nicht grün in TestFlight steht, fährt mit
dem nächsten.

Der Leitsatz davor lautete, der Umfang von 1.0 sei „bewusst schmerzhaft
klein". Er hat seinen Zweck erfüllt: 1.0 stand am 4. September im Laden. Jetzt
ist die Gefahr eine andere. In der ersten Woche kamen drei Fassungen, danach
dreizehn Tage keine. Wer von außen hinsieht, kann eine App, an der gearbeitet
wird, nicht von einer unterscheiden, die liegengeblieben ist, außer am Takt.

---

## Entschieden am 23. September

Im Sparring mit dem Gründer, jede Frage mit Begründung vorgelegt:

| Frage | Entscheidung | Warum |
|---|---|---|
| Takt | **alle zwei Wochen**, eingereicht mittwochs | Der Takt zeigt Weiterentwicklung, nicht die Größe einer Fassung |
| Schwerpunkt | **schneller ablesen** | hält die, die schon da sind; das Monatsritual ist das Produkt |
| Vermieter | **geparkt, bis Zahlen da sind** | widerspricht sonst „Ein Abo gibt es nicht" auf der Website |
| Ablage dieser Datei | **im Repository** | jede Sitzung liest sie mit; die Offenheit ist in `CLAUDE.md` in Kauf genommen |

---

## Entschieden am 3. Oktober

Zweites Sparring mit dem Gründer, für den Winter 2026/27:

| Frage | Entscheidung | Warum |
|---|---|---|
| Ziel bis Januar | **mehr neue Nutzer** | ohne Nutzer hilft jede Funktion wenig; wer da ist, bekommt mit dem Rundgang gerade das Ritual verbessert |
| Große Funktion | **die Kamera liest den Zähler** | der größte Effekt am Zähler und das Bild, das im Laden auffällt. Abrechnung prüfen, Heizperiode und gemeinsamer Haushalt bleiben unter „Später" |
| Preis der Kamera | **eigener Kauf für 0,99 €, Teil von „Alles freischalten"** | vom Gründer: „soll auch 1 € kosten und dann im Gesamtpaket integriert werden". 0,99 € wie die Erinnerungen. Das Bündel bleibt 4,99 €; wer es hat, bekommt die Kamera ohne weiteren Kauf |
| Reihenfolge | **Import vor Kamera** | der Import ist kleiner und sicher, und die Kamera bekommt dadurch zwei Wochen mehr für eine Erkennung, die hält |
| Testbilder | **Fotos der eigenen Zähler vom Gründer**, Zählernummer geschwärzt | das Repository ist öffentlich |
| Jahreswechsel | **gestrichen am 7. Oktober** | vom Gründer: Der Jahreswechsel interessiert kaum noch jemanden, weil man den Anbieter jederzeit wechseln kann |
| Suchbegriffe im Laden | **`Zählerstand` in den Namen**: „Zählora – Zählerstand ablesen", Untertitel „Verbrauch: Strom, Gas, Wasser" | vom Gründer am 7. Oktober. Im Schlagwortfeld allein brachte das Wort keinen Platz unter den ersten 50 (`09-appstore.md`). Wirksam mit der nächsten Fassung |
| Takt | **bleibt bei zwei Wochen** | hat sich bewährt; große Funktionen werden in Stücke geteilt |

## Der Plan

Eingereicht wird mittwochs, alle zwei Wochen. Die Daten sind **Ziele für uns**
und stehen nirgends öffentlich (siehe „Öffentlich und intern" unten).

| Fassung | Einreichen | Inhalt | Stand |
|---|---|---|---|
| **1.2** | 23.09. | Zwei Spalten auf dem iPad im Querformat · Diagramm wächst mit der Breite | **im Laden** seit 24.09., Bau 36 |
| **1.3** | 03.10. | **Direkt zum Ziffernblock:** Erinnerung, Feld am Sperrbildschirm und Siri öffnen den Ziffernblock des richtigen Zählers · Umschalter im iPad-Hochformat kappen · Bewertungsfrage nach der dritten Ablesung · neues Schlagwortfeld und neue Bilder (`10-sichtbarkeit.md`) | **im Laden** seit 03.10., Bau 38 |
| **1.4** | 21.10. | **Rundgang:** nach dem Sichern „Weiter mit Wasser", bis alle fälligen Zähler durch sind | **im Laden** seit 05.10., Bau 39 |
| **1.4.1** | 07.10. | **Neue Suchbegriffe:** Name, Untertitel und Schlagworte aus `09-appstore.md`. Sonst nichts, damit eine Wirkung im Rang den neuen Wörtern zuzuordnen ist | freigegeben am 07.10., vorgezogen |
| **1.5** | 04.11. | **Import aus einer Tabelle**, für Umsteiger mit Excel-Listen oder anderen Apps | als Nächstes |
| **1.6** | 18.11. | **Kamera, Stufe 1:** Foto im Ziffernblock, die App schlägt den Stand vor, du bestätigst. Eigener Kauf 0,99 €, im Bündel enthalten | groß |
| **1.7** | 02.12. | **Kamera, Stufe 2:** Sucher mit Rahmen, zwei Zählwerke auf einem Bild (Tag/Nacht, Bezug/Einspeisung) | groß |
| **1.8** | 16.12. | offen. Der Jahreswechsel stand hier und ist am 7. Oktober gestrichen | — |
| **1.9** | 13.01. | Puffer, und was die Zahlen bis dahin sagen | — |

**Neben jeder Fassung, für neue Nutzer:**

| Was | Wann |
|---|---|
| Neue Bilder im Laden: Rundgang, später Kamera. Dazu Apples A/B-Test der Produktseite mit zwei Bildsätzen | mit 1.4 und mit 1.6 |
| Eine Ratgeberseite je Woche, nach Saison: Heizkosten im Herbst, „Zählerstand ablesen" als nächste (die Suche, auf die auch der neue Name zielt), „Nachzahlung prüfen" im Januar | laufend |
| Messen: Berichtsschlüssel für App Store Connect und Kampagnenlink (`13-zugaenge.md`, Punkte 5 und 6) | **vor 1.5**, sonst bleibt offen, ob irgendetwas davon wirkt |

### Die Website als Wachstumskanal: Rechner

Vom Gründer am 4. Oktober beauftragt: Menschen erreichen, die bei Google ein
konkretes Problem suchen („Stromkosten berechnen", „Gas m³ in kWh",
„Zählerstand beim Umzug"), mit echten kleinen Rechnern, und von dort zur App.
Grundsatz: lieber ein guter Rechner als fünf halbe, kein Massentext, nichts
versprechen, was die App nicht kann.

| Phase | Inhalt | Stand |
|---|---|---|
| 1 | Startseite erklärt in einer Zeile, was Zählora ist · Stromkostenkarte im vorhandenen Rechner-Abschnitt · **Stromkosten- und Abschlagsrechner** (der frühere Abschlagsrechner ist darin aufgegangen) · Hinweis zur App unter jedem Rechner · Rechnerseiten als Spalte in der Mitte | **online seit 4. Oktober** (0.120.0, bereinigt in 0.120.3) |
| 2 | **„Ist mein Stromverbrauch normal?"** mit den Klassen des Stromspiegels 2025 (co2online), danach eine Seite je Woche: **„Zählerstand ablesen"** für Strom, Gas und Wasser (seit 7. Oktober vorgezogen, dieselbe Suche wie der neue Name im Laden), PV-Rechner aus gemessenen Werten, Wärmepumpe, „Nachzahlung prüfen" (Januar). „Zählerstand zum Jahreswechsel" ist gestrichen | Stromverbrauch: gebaut am 4. Oktober |
| 3 | Wasser (Verbrauch und Kosten), Vorjahresvergleich, nach dem, was die Search Console an Suchbegriffen zeigt | später |

**Entschieden am 4. Oktober, für die Reichweite:** nur Inhalte und Google.
Keine Anschreiben an App-Blogs oder Presse, keine Beiträge in Foren, keine
eigene Seite „Über Zählora". Damit hängt alles an den Seiten selbst: Jede
muss eine Frage besser beantworten als das, was sonst bei Google steht, und
jede Zahl braucht eine Quelle. Gemessen wird über die Search Console, die
Zählung der Website (`?von=`) und, sobald der Gründer sie liefert, die
Kampagnenkennung `pt` und den Berichtsschlüssel.

Die Adressen bleiben flach (`/stromkosten-berechnen.html`) statt
`/rechner/…`: Die vier bestehenden Seiten stehen so im Verzeichnis von
Google, und ein Umzug kostete Weiterleitungen ohne Gewinn.

### Die Kamera: wie sie gebaut wird

**Nichts verlässt das Telefon.** Erkannt wird mit Apples Texterkennung auf
dem Gerät (Vision). Kein Bild wird gesendet oder ohne Zutun gespeichert; das
gehört zum Versprechen der App und steht so in der Datenschutzerklärung,
bevor die Funktion erscheint.

**Ein Vorschlag, keine Ablesung.** Die erkannten Ziffern landen im
Ziffernblock, gekennzeichnet als „aus dem Foto“. Die Plausibilitätsprüfung
bleibt, gesichert wird erst mit „Sichern“. Ist die Erkennung unsicher, schlägt
sie **nichts** vor: Eine falsch gelesene Ziffer ist schlimmer als keine
(Produktprinzip 7).

**Woran sie scheitern kann, und wie es geprüft wird.**

| Fall | Was dagegen hilft |
|---|---|
| Rollenzählwerk mit halb gedrehter Ziffer | Ziffer zwischen zwei Werten: nicht vorschlagen, Stelle leer lassen |
| Rote Nachkommastellen | Zahl der Vor- und Nachkommastellen kommt aus dem Zählwerk, nicht aus dem Bild |
| Zählernummer, Eichjahr, Typenschild im Bild | nur Zahlen mit der Stellenzahl des Zählwerks, nahe am letzten Stand |
| Digitale Anzeige wechselt zwischen 1.8.0 und 2.8.0 | Stufe 2: Kennzahl neben dem Wert lesen und dem richtigen Zählwerk zuordnen |
| Schlechtes Licht, Spiegelung | Taschenlampe im Sucher (Stufe 2) |

Geprüft wird mit einer Sammlung echter Fotos (vom Gründer, Zählernummer
geschwärzt) und der erwarteten Zahl je Bild. Die CI rechnet die Trefferquote
aus, und die steht in jedem Lauf. Ziel für Stufe 1: auf keinem Bild ein
falscher Vorschlag; lieber keiner.

**Der Kauf.** Eine neue Kauf-Kennung neben den fünf vorhandenen, angelegt über
die Schnittstelle (`asc-kaeufe.py`), 0,99 €. `Entitlement` bekommt einen
sechsten Fall; „Alles freischalten" schließt ihn ein, auch für alle, die das
Bündel schon gekauft haben. Die Summe der Einzelkäufe steigt auf 9,94 €, das
Bündel bleibt bei 4,99 €. Die Kaufseite, `04-monetarisierung.md`, die Website
und `check-versprechen.py` ziehen im selben Zug nach.


**Am Abend des 23. September umgeschnitten.** Mittags stand 1.3 mit Siri und
den Umschaltern im Plan und 1.4 mit „ablesen direkt aus der Erinnerung, ohne
die App zu öffnen". Beim Nachsehen im Code fiel zweierlei auf:

1. **Kein Eingang führt zu einem bestimmten Zähler.** Die Erinnerung „Strom —
   Zeit für eine Ablesung" öffnet die App dort, wo sie zuletzt stand. Das Feld
   am Sperrbildschirm ebenso. Siri gibt es nicht. Alle drei brauchen denselben
   Weg „Ziffernblock für Zähler X", und der ist einmal zu bauen, nicht dreimal.
   Das Muster steht schon in der App: Eine Karte auf der Übersicht öffnet den
   Verlauf ihres Zählers über einen Wunsch in `RootView`, der nach dem Erfüllen
   verfällt.
2. **Eine Eingabe in der Mitteilung umginge die Rückfrage.** Die App sieht sich
   einen Wert an, bevor sie ihn sichert, und fragt nach, wenn er unter dem
   letzten Stand oder weit über dem Üblichen liegt. So steht es auf der Website.
   Eine Mitteilung kann nicht zurückfragen; ein Tippfehler landete ungeprüft im
   Verlauf. **Deshalb gestrichen**, zugunsten eines Tipps, der im Ziffernblock
   ankommt.

Siri ist das größte Stück in 1.3. Braucht es länger, fährt es mit 1.4, und die
beiden Tipp-Eingänge gehen trotzdem am 7. Oktober hinaus. Der Rundgang rückt
dadurch zwei Wochen vor und baut auf demselben Weg auf.

**Warum 1.3 vor dem 1. November liegt.** Viele lesen zum Monatsanfang ab,
und ab November läuft die Heizung. Wer dann auf die Erinnerung tippt, soll im
Ziffernblock landen und nicht auf der Übersicht.

**Warum der Import zuletzt kommt.** Er gewinnt neue Nutzer, der Schwerpunkt
ist aber, die zu halten, die schon da sind. Er bleibt im Plan, weil er die
Hürde für jeden senkt, der nicht bei null anfangen will.

**Warum ein Puffer.** Ein Zug, der einmal nicht rechtzeitig fertig ist, soll
den Takt nicht reißen. Bleibt der Puffer frei, füllt ihn, was bis dahin an
kleinen Dingen zusammenkommt.

### Voraussetzung: Zahlen

**Offen beim Gründer.** Der Schlüssel für App Store Connect hat zu wenige Rechte
für Nutzungsberichte. Damit wissen wir nicht, wie viele die App laden, was sie
kaufen und wer nach vier Wochen noch abliest. Jede Entscheidung unter „Später"
und „Geparkt" wartet genau darauf. Zu ändern in App Store Connect unter
*Benutzer und Zugriff › Integrationen*: eine Rolle, die Berichte lesen darf.

### Später

| Was | Warum nicht jetzt |
|---|---|
| Jahresabrechnung prüfen: die Abrechnung eintragen, eigene Zahlen daneben | stark zur Abrechnungszeit (Januar bis März); Kandidat für 2.0 |
| Heizperiode im Blick: dieser Winter gegen den letzten | Kandidat für 2.0, zusammen mit der Abrechnung |
| Gemeinsamer Haushalt über iCloud-Freigabe | eigener Aufwand beim Abgleich; erst, wenn jemand danach fragt |
| Mehrere Wohnungen getrennt halten | wird zusammen mit „Vermieter" entschieden, sobald Zahlen da sind |

### Geparkt

Kein Signal, dass jemand danach fragt. Wieder angesehen, wenn Zahlen oder
Zuschriften etwas anderes sagen.

- **Vermieter als eigene Zielgruppe** — braucht ein eigenes Preismodell, und
  die Website sagt „Ein Abo gibt es nicht".
- Mac-App · CO₂ mit belastbarer Quelle · Foto-Belege ·
  Steuerung im Kontrollzentrum

### Nie

Watch-App · Vergleich mit anderen Haushalten · Prognose über maschinelles
Lernen. Die Begründungen stehen unter „v1.0 – Nicht enthalten".

### Wie eine Zeile nach außen wandert

| Wenn | Dann |
|---|---|
| eine Fassung in TestFlight steht | Zeile „Im Test" auf `entwicklung.html` |
| sie im App Store steht | Zeile „Fassung x.y" mit Datum auf `entwicklung.html` **und** Eintrag unter „Was zuletzt dazugekommen ist" auf der Startseite · Versionshinweise aus `09-appstore.md` |
| sie nur geplant ist | nichts. Öffentlich steht „Demnächst" |

> **Geld und Freischaltungen stehen nicht hier.** Die eine Quelle dafür ist
> `Entitlement.swift`, und `check-versprechen.py` hält die Website daran fest.
> Die Liste, die hier früher stand, führte die Erinnerungen als kostenlos. Sie
> kosten seit August 0,99 €.

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

## Die Pläne für 1.1, 1.2 und 2.0 von vor dem Start

Am 23. September durch „Der Plan" oben ersetzt. Die alte Fassung stand bis
dahin hier und ist in der Versionsgeschichte zu finden. Übernommen wurde, was
weiter trägt: iPad-Layout (in 1.1 und 1.2 umgesetzt), Sammelerfassung,
Import, Erfassung aus der Benachrichtigung, Kamera. Verschoben wurde, was an
Vermietern hängt: Objekte und Einheiten, Mieterzuordnung, das Vermieter-Abo.

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

## Aktueller Stand — Version 0.115.4

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
