# Testkonzept

Stand 0.164.0, 12. November 2026. Auftrag des Gründers am selben Tag: „erweitere
das testkonzept und erweitere weitere tests. prio ist die qualität und vor allem
einfaches und user freundliches interface für einfache bedienung."

Diese Datei sagt, **was** an Zählora geprüft wird, **wo** und **warum dort**.
Wie eine einzelne Änderung durch die Prüfungen geht, steht in
`.claude/skills/release-discipline/SKILL.md`; wie der Mac-Lauf funktioniert, in
`CLAUDE.md`, Regel 3.

`scripts/check-testkonzept.py` hält diese Datei ehrlich: Jeder Test und jedes
Skript, das hier in Backticks steht, muss es geben, und jedes Prüfskript unter
`scripts/check-*` muss hier stehen. Ein Konzept, das auf Tests zeigt, die es
nicht mehr gibt, ist schlimmer als keins.

---

## 1. Was „geprüft" hier heißt

Drei Fragen, in dieser Reihenfolge:

1. **Kann man es bedienen?** Am Zähler, einhändig, bei schlechtem Licht, mit
   großer Schrift, ohne zu wissen, was ein Zählwerk ist. Und wenn man sich
   vertippt, abbricht oder etwas Unerwartetes tut: Fängt die App einen auf?
2. **Rechnet es richtig?** Und sagt es, wenn es schätzt (Prinzip 7)?
3. **Kommt es heil beim Nutzer an?** Daten überstehen ein Update, der Abgleich
   zwischen Geräten läuft, Kauf und Website versprechen dasselbe.

Die zweite Frage war bisher am besten abgedeckt (350 Tests im Rechenkern). Die
erste und die dritte hatten Lücken, die beide Kunden zuerst gesehen haben: Der
iCloud-Abgleich lief von 1.0 bis 1.6 nie, und im Ziffernblock stand
„rund 3.039,2× dein üblicher Verbrauch". Beides ist mit 0.164.0 geprüft
(Abschnitt 5).

---

## 2. Die Ebenen

Sortiert nach Kosten. Was in einer Sekunde bricht, soll in einer Sekunde
brechen.

| Ebene | Was | Wo | Dauer |
|---|---|---|---|
| Sofortprüfungen | Texte, Namen, Versionen, Berechtigungen, Schema | Linux und Mac, CI-Auftrag `prototype` | Sekunden |
| Rechenkern | `PulseCore`: Verbrauch, Kosten, Hochrechnung, Plausibilität, Kamera | Linux und Mac | 1 Minute |
| Speicher | `PulseData`: SwiftData, CloudKit-Regeln | nur Mac | 30 Sekunden |
| Klick-Dummy | Wege, Bedienbarkeit, Fehlerfälle, Kamera-Leser | Linux (Chromium) | 1 bis 2 Minuten |
| Website | Inhalte, Versprechen, Darstellung in Chromium und WebKit | Linux | 1 Minute |
| App-Oberfläche | `LaunchTests`, `BedienungTests` auf iPhone und iPad | Mac (Simulator) | 10 bis 15 Minuten |
| Bilder | Bildschirmfotos auf vier Geräten, angesehen statt geprüft | Mac | 5 Minuten |
| Wachen | CloudKit-Produktion jede Woche und vor jedem TestFlight-Bau | Mac, eigener Ablauf | 1 Minute |
| Am Gerät | Was kein Simulator kann (Abschnitt 6) | iPhone des Gründers | je Fassung |

Alles bis „Bilder" läuft mit `scripts/pruefen.sh` und in `.github/workflows/ci.yml`,
dieselben Schritte an beiden Orten.

### Die Sofortprüfungen im Einzelnen

| Skript | Hält fest |
|---|---|
| `scripts/check-strings.py` | Swift-Zeichenketten heil, verbotene Wörter (Messstelle, Zählwerk, …) nirgends in der Oberfläche |
| `scripts/check-namen.py` | kein unbekannter Name in den Python-Skripten |
| `scripts/check-verwaiste-namen.py` | keine Swift-Verwendung eines gelöschten Namens |
| `scripts/check-trefferflaechen.py` | jeder Knopf ist auf seiner ganzen Fläche antippbar |
| `scripts/check-aktualisierung.py` | Änderungen erreichen jeden Reiter, der sie zeigt |
| `scripts/check-sicherheit.sh` | Berechtigungen und Datenschutzangaben so klein wie beschrieben |
| `scripts/check-versprechen.py` | Website verspricht nur, was die App kann, zu den Preisen der App |
| `scripts/check-store-texte.py` | Klang der Store-Texte |
| `scripts/check-versionen.py` | CHANGELOG, `project.yml`, README und Klick-Dummy nennen dieselbe Version |
| `scripts/check-cloudkit-schema.py` | nichts aus der CloudKit-Produktion umbenannt; vor TestFlight alles dort |
| `scripts/check-kamerafotos.py` | jedes fremde Foto mit Lizenz und Namensnennung |
| `scripts/check-kamera-js.mjs` | Kamera-Leser im Klick-Dummy liest dieselben Fälle wie Swift |
| `scripts/check-buendel.mjs` | das Website-Bündel ist vollständig |
| `scripts/check-entwuerfe.mjs` | die Entwürfe unter `docs/entwuerfe` laufen ohne Fehler |

---

## 3. Bedienung: woran „einfach" gemessen wird

Der Gründer hat „einfach und nutzerfreundlich" zur Priorität gemacht. Damit das
nicht Geschmack bleibt, steht hier je Anspruch die Prüfung, die ihn hält. Wo
„—" steht, gibt es (noch) keine.

| Anspruch | App | Klick-Dummy |
|---|---|---|
| Prinzip 1: erste Ablesung in 60 Sekunden, ohne Konto | `testColdStartOffersToCreateAMeter`, `testFirstMeterThenFirstReadingThenConsumption` | `scripts/check-prototype.mjs` |
| Prinzip 2: Folge-Ablesung in 3 Berührungen | `testCapturingAReadingClearsTheNotice` | `scripts/check-nichtfunktional.mjs` (gezählt) |
| Prinzip 3: „Ist alles im Rahmen?" ohne Scrollen, schnell | `testLaunchReachesTheFirstFigureQuickly` | `scripts/check-nichtfunktional.mjs` |
| Prinzip 4: keine Sackgasse | `testAMeterRowOpensWhereverItIsTapped`, `testTappingAMeterCardOpensItsHistory`, `testATooSmallNumberIsQuestionedRightAwayAndCancellingKeepsNothing` | `scripts/check-nichtfunktional.mjs`, `scripts/check-bedienung.mjs` |
| Prinzip 5: Export kostet nie | `testTheReportIsWatermarkedAndTheExportNeverCosts` | — |
| Prinzip 6: kein technisches Vokabular | `scripts/check-strings.py` (verbotene Wörter) | — |
| Prinzip 7: Geschätztes ist gekennzeichnet | `testCostIsLabelledWithThePeriodItCovers`, `testTheRunningMonthNamesItsExpectedTotal` | `scripts/check-prototype.mjs` |
| Trefferflächen mindestens 44 × 44 Punkte | `scripts/check-trefferflaechen.py`, `testTheKeypadHasNoDeadKey` | `scripts/check-nichtfunktional.mjs` |
| Lesbar: Kontrast 4,5:1 | — (Bilder werden angesehen) | `scripts/check-nichtfunktional.mjs`, hell und dunkel |
| Größte Schrift: nichts ragt über den Rand | `testNoTextReachesPastTheEdge` | `scripts/check-prototype.mjs` (Überlauf) |
| Vorlesefunktion: jede Fläche hat einen Namen | `testTheCounterAnnouncesItsValue` | `scripts/check-nichtfunktional.mjs` |
| Tippfehler wird sofort und in Worten beanstandet | `testATooSmallNumberIsQuestionedRightAwayAndCancellingKeepsNothing`, `testAnUnchangedReadingIsQuestionedInPlainWords` | `scripts/check-bedienung.mjs` |
| Ein gesperrter Knopf sagt, warum | `testSaveWaitsForANumberAndSaysWhy` | `scripts/check-bedienung.mjs` |
| „Abbrechen" sichert nichts | `testATooSmallNumberIsQuestionedRightAwayAndCancellingKeepsNothing` | `scripts/check-bedienung.mjs` |
| Rückgängig nach dem Löschen und Importieren | `testImportingATableCreatesMetersAndCanBeUndone`, `testAReadingCanBeCorrectedAndDeleted` | `scripts/check-prototype.mjs` |
| iPad im Querformat nutzt die Breite | `testTabletUsesItsWidthInLandscape` | — |

### Regeln für Texte, die eine Prüfung sieht

- **Nachfragen, nicht verbieten.** Eine Rückfrage („Stimmt die Zahl?") lässt
  den Nutzer trotzdem sichern; er steht vor dem Zähler und weiß es besser.
  `scripts/check-bedienung.mjs` und `BedienungTests` prüfen das bei jeder
  Rückfrage.
- **Mengen statt Faktoren.** „Das wären 20.000 kWh in einem Tag, sonst sind es
  rund 7 kWh" statt „rund 3.039,2×". Ein Vielfaches muss man zurückrechnen.
- **Jede Rückfrage hat eine Antwort.** Wer „Wurde der Zähler gewechselt?"
  fragt, bietet den Zählerwechsel als Knopf an.

---

## 4. Wann welcher Test

| Was sich ändert | Was dazukommt |
|---|---|
| eine Rechnung in `PulseCore` | ein Test in `Packages/PulseCore/Tests`, **und** dieselbe Rechnung im Klick-Dummy mit einer Prüfung in `scripts/check-prototype.mjs` |
| ein sichtbarer Text, eine Rückfrage, eine Fehlermeldung | eine Prüfung, die den Satz liest: im Klick-Dummy (`scripts/check-bedienung.mjs` oder `scripts/check-prototype.mjs`) und in der App (`AppUITests`) |
| ein neuer Weg durch die App | ein Oberflächentest in `LaunchTests` (Hauptweg) oder `BedienungTests` (Abweg, Fehler, Abbruch) |
| ein neues Feld im Datenmodell | `cloudkit/schema.ckdb` neu (`CloudKitSchemaTests` sagt, was hineingehört), danach in die CloudKit-Produktion, bevor ein TestFlight-Bau kommt |
| ein Text auf der Website | `scripts/check-website.mjs`, bei Preisen `scripts/check-versprechen.py` |
| ein Fehlerbericht vom Gerät | zuerst der Test, der ihn rot zeigt, dann die Korrektur |

### Drei Regeln, die immer gelten

1. **Jeder neue Test wird einmal rot gesehen.** Am einfachsten, indem man die
   Korrektur kurz zurücknimmt. Ein Test, der nie anschlägt, prüft nichts.
   Prüfskripte mit eigener Logik haben einen `--selbsttest`.
2. **Ein Test, der zufällig fällt, ist ein Fehler** — im Test oder in der App,
   und er wird so behandelt. Längere Wartezeiten nur mit Messung
   (`LaunchTests.erscheint`). Antwortet die App nur nicht rechtzeitig, weil sie
   im Debug-Bau schwer rechnet, wartet der Test mit `wartetGeduldig` und lässt
   genau diesen einen Fehler durch, sonst keinen. So beim Kameratest seit 0.164.0.
3. **Eine Regel, die nur als Satz dasteht, wird nicht befolgt.** Was sich
   zählen lässt, zählt ein Skript (Gedankenstriche auf der Website, Versionen,
   verbotene Wörter, Regeln für CloudKit).

---

## 5. Fehlerklassen und ihre Wachen

Jede Zeile ist einmal passiert. Die Wache steht daneben.

| Was passiert ist | Seit wann geprüft |
|---|---|
| Der iCloud-Abgleich lief von 1.0 bis 1.6 nie: In der CloudKit-Produktion stand kein Schema, SwiftData sicherte still lokal weiter (Käufermeldung 14. Oktober). | 0.142.0 `CloudKitSchemaTests` (Datei = Modell); 0.164.0 `scripts/check-cloudkit-schema.py` mit Ablage `cloudkit/produktion.ckdb`, `.github/workflows/cloudkit-wache.yml` jeden Montag gegen die echte Produktion, Riegel in `.github/workflows/testflight.yml` |
| Ein Feld des Modells verstößt gegen die Regeln von CloudKit; in der CI ohne iCloud fiele das nie auf. | 0.164.0 `testTheModelFollowsTheRulesOfCloudKit`, gegengeprüft mit `testEachRuleIsSeenWhenBroken` |
| Im Ziffernblock stand „rund 0× dein üblicher Verbrauch" und „rund 3.039,2×". Richtig gerechnet, unverständlich gesagt. | 0.164.0 `scripts/check-bedienung.mjs`, `testAnUnchangedReadingIsQuestionedInPlainWords`, `testATenfoldTypoNamesTheUsualAmountForTheSameDays` |
| Die Kopfzeile des Klick-Dummys stand sechs Versionen lang auf 0.138.0. | 0.164.0 `scripts/check-versionen.py` |
| Ein Zeitraum mit Daten wurde gegen einen ohne verglichen (die wiederkehrende Fehlerklasse aus `CLAUDE.md`). | `ScenarioMatrixTests`, `PeriodEngineTests` |
| Die Website versprach Preise und Umfang, die es nicht gab. | 0.103.1 `scripts/check-versprechen.py` |
| Bau 24 lag in TestFlight, der Schritt danach starb an einem fehlenden `import re`. | `scripts/check-namen.py` |

---

## 6. Was nur am Gerät geht

Kein Simulator hat ein iCloud-Konto, eine Kamera vor einem echten Zähler oder
einen echten Kauf. Diese drei Punkte prüft der Gründer je Fassung am iPhone,
**bevor** sie eingereicht wird, und die Sitzung trägt das Ergebnis in
`docs/12-auslieferung.md` ein:

1. **Abgleich**: Auf dem iPhone einen Stand eintragen, auf dem zweiten Gerät
   (iPad) nach spätestens einer Minute sehen. Zuletzt vom Gründer bestätigt am
   11. November.
2. **Kamera**: einmal am eigenen Zähler ablesen.
3. **Kauf**: mit einem Testkonto in TestFlight einen Kauf auslösen und
   wiederherstellen.

Was die Wachen davon abnehmen: Die CloudKit-Wache prüft jede Woche die
Voraussetzung für Punkt 1, die Kamera-Messungen in `docs/kamera/README.md` die
für Punkt 2.

---

## 7. Lücken, nach Gewicht

Ehrlich, was noch fehlt. Wer eine davon schließt, streicht die Zeile und trägt
die Prüfung oben ein.

1. **App und Klick-Dummy rechnen nicht nachweislich gleich.** Regel 2 in
   `CLAUDE.md` verlangt es, geprüft wird es nur für die Kamera
   (`docs/kamera/vektoren.json`). Das Review vom 11. November fand zwei
   Abweichungen (Kosten je Monat ohne Ablesung, Gas im Bericht in m³). Vorschlag:
   gemeinsame Rechenfälle als JSON, die `PulseCore` und der Klick-Dummy beide
   rechnen müssen. Kommt nach PR #18, der dieselben Rechnungen gerade anfasst.
2. **Daten überstehen ein Update — nur angenommen.** Kein Test öffnet einen
   Speicher, den eine ältere Version geschrieben hat. SwiftData übernimmt
   Zusätze leichtgewichtig, ein umbenanntes Feld aber nicht. Vorschlag: eine
   Speicherdatei aus 1.6 als Vorlage in `PulseData` und ein Test, der sie mit
   dem aktuellen Modell öffnet und alle Stände wiederfindet.
3. **Käufe sind in den Oberflächentests nur geschaltet** (`-pulse-pro`), nie
   gekauft. Vorschlag: eine StoreKit-Testkonfiguration und ein Test, der
   kauft, wiederherstellt und die Freischaltung sieht.
4. **Dunkles Erscheinungsbild in der App** wird nur auf Bildern angesehen, im
   Klick-Dummy dagegen gemessen. Vorschlag: `testNoTextReachesPastTheEdge` und
   die Kontrastmessung auch im dunklen Erscheinungsbild.
5. **Der Abgleich selbst ist nur am Gerät prüfbar.** Dass er still scheitert,
   sieht der Nutzer bis heute nicht. Ob die App das anzeigen soll, ist eine
   Produktfrage und steht beim Review von Stand und Roadmap.
