---
name: release-discipline
description: Pflichtablauf für jede Änderung an PulseMeter — Version vergeben, Release Notes in CHANGELOG.md schreiben, Tests ausführen und erweitern. Diese Skill greift bei JEDER Änderung am Code, am Prototyp oder an den Dokumenten dieses Projekts, auch bei kleinen: also immer wenn etwas implementiert, korrigiert, umgebaut, entfernt oder committet wird. Auch dann verwenden, wenn der Nutzer nur „mach das", „bau das ein" oder „fix das" sagt, ohne Version oder Tests zu erwähnen — beides gehört zum Liefergegenstand und wird nicht separat angefordert.
---

# Release-Disziplin

Jede Änderung an diesem Projekt endet mit drei Dingen, nicht mit einem:
**geprüftem Code**, **einem Eintrag in den Release Notes** und **einer Version**.

Warum so streng: Dieses Projekt ist ein Produkt, das über Jahre gepflegt werden
soll. Ohne Änderungshistorie weiß in sechs Monaten niemand mehr, warum eine
Zahl anders berechnet wird als vorher — und ohne Tests merkt es auch niemand,
wenn sie plötzlich wieder falsch ist. Der Aufwand pro Änderung ist klein, der
Verlust ohne ihn ist nicht wiederherstellbar.

---

## 1. Tests — vor dem Committen, immer, ohne Aufforderung

Der Nutzer fordert Tests nicht an. Sie sind Teil der Lieferung, so wie
kompilierender Code Teil der Lieferung ist.

### Was ausgeführt wird

| Was geändert wurde | Was laufen muss |
|---|---|
| `Packages/PulseCore` | `cd Packages/PulseCore && swift test` — vollständig grün |
| `Packages/PulseData` | dito; unter Linux nicht baubar, dann ausdrücklich vermerken |
| `docs/prototype/index.html` | Headless in Chromium: Hauptflüsse klicken, auf JS-Fehler und horizontalen Überlauf prüfen, in Hell **und** Dunkel |
| Zahlen im Prototyp | Einmal ausrechnen lassen und auf Plausibilität ansehen |

Swift-Toolchain: `/opt/swift/usr/bin` · Chromium: `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`

### Was ergänzt wird

**Neues Verhalten bekommt einen Test im selben Commit.** Nicht später, nicht
in einem Folgeticket. Ein Feature ohne Test ist ein Feature, dessen Korrektheit
niemand mehr überprüfen kann, sobald der Kontext verloren ist.

**Jeder gefundene Fehler bekommt einen Test, der ihn vorher gefangen hätte.**
Erst den Test schreiben, der fehlschlägt, dann die Korrektur. Ein Fehler ohne
Regressionstest kommt wieder — das ist keine Vermutung, das ist Erfahrung.

**Der Test benennt den Fall, nicht die Methode.** `testStaleReadingDoesNotDepressProjection`
sagt, was schiefgehen kann. `testForecast2` sagt nichts. Wer den Test in zwei
Jahren liest, soll ohne den Code verstehen, worum es geht.

### Die wiederkehrende Fehlerklasse dieses Projekts

Bisher entstand **jeder** gefundene Rechenfehler dadurch, dass ein Zeitraum,
den die Daten abdecken, gegen einen verglichen wurde, den sie nicht abdecken.
Fünfmal in verschiedener Verkleidung: Hochrechnung, Vorjahresvergleich,
Plausibilitätsprüfung, Tabellensummen, Abschlagssaldo.

Bei jedem neuen Vergleich, jeder Hochrechnung und jeder Summe gilt deshalb:

> Beide Seiten müssen denselben Zeitausschnitt beschreiben — und bei
> saisonalen Zählern denselben Ausschnitt des Jahres.

Wenn eine Änderung etwas vergleicht, gehört ein Test dazu, der genau diese
Falle prüft. Nicht weil es Vorschrift ist, sondern weil es hier schon fünfmal
passiert ist.

---

## 2. Version vergeben

Semantische Versionierung, solange die App nicht veröffentlicht ist im
`0.MINOR.PATCH`-Bereich:

| Erhöhen | Wann |
|---|---|
| **MINOR** (`0.8.0` → `0.9.0`) | Neue Fähigkeit: eine Ansicht, ein Paket, ein Rechenweg, ein Format |
| **PATCH** (`0.9.0` → `0.9.1`) | Korrektur, Feinschliff, Aufräumen ohne neue Fähigkeit |
| **MAJOR** (`0.x` → `1.0.0`) | Erst zur Einreichung im App Store |

Eine Korrektur an einem Rechenweg ist **PATCH**, auch wenn sie inhaltlich
schwer wiegt — sie stellt her, was ohnehin gelten sollte. Ändert sich dagegen,
*was* gerechnet wird, ist es MINOR.

Die Version steht an **fünf** Stellen und muss überall gleich sein:

1. `CHANGELOG.md` — als Überschrift des Eintrags
2. `project.yml` — `MARKETING_VERSION`, **zweimal**: App und Widget
3. `README.md` — die Zeile „Version **x.y.z**."
4. `docs/prototype/index.html` — in der Kopfzeile neben „Klickbarer Entwurf"
5. Der Commit, der die Änderung enthält

Die Liste stand bis 0.69.2 auf drei Stellen und verschwieg damit ausgerechnet
die einzige, die beim Nutzer ankommt: `MARKETING_VERSION` ist die Zahl, die in
TestFlight und im App Store steht. Wer sie vergisst, liefert einen neuen Stand
unter der alten Nummer aus — und niemand sieht es, weil alle anderen Stellen
stimmen.

Zum Prüfen genügt ein Griff:

```bash
grep -rn "0\.71\.2" project.yml README.md docs/prototype/index.html
```

---

## 3. Release Notes schreiben

`CHANGELOG.md` im Wurzelverzeichnis, neueste Version oben.

### Aufbau

```markdown
## 0.9.0 — 2026-08-04

### Hinzugefügt
- Kurz, in einem Satz, aus Sicht des Nutzers.

### Geändert
- Was sich anders verhält als vorher, und warum.

### Behoben
- Was falsch war, was jetzt stimmt, und was der Fehler bewirkt hätte.

### Entfernt
- Was weggefallen ist und wohin es gewandert ist.
```

Leere Abschnitte weglassen. Sprache: Deutsch, wie alle Dokumente.

### Was einen guten Eintrag ausmacht

Ein Eintrag beschreibt die **Wirkung**, nicht den Handgriff. Wer ihn liest,
soll wissen, ob ihn die Änderung betrifft.

**Schlecht:** `ConsumptionEngine.yearOverYear angepasst`
Sagt nichts. Man muss den Commit lesen, um irgendetwas zu erfahren.

**Gut:** `Der Vorjahresvergleich verglich bei einem überfälligen Zähler eine
halbe Heizperiode mit einem vollen Jahr und meldete +33 %, wo es −3 % sind.`
Die Zahlen machen den Fehler greifbar und belegen, dass er verstanden wurde.

Bei **Behoben** gehört dazu, was der Fehler angerichtet hätte, wenn er
unbemerkt geblieben wäre. Das ist keine Dramatik — es ist die Information, die
später entscheidet, ob jemand eine ältere Fassung noch verwenden darf.

Am Ende jedes Versionseintrags eine Zeile zum Prüfstand:

```markdown
_82 Tests in PulseCore, alle grün. Prototyp in Hell und Dunkel geprüft._
```

---

## 4. Was ausgeliefert wurde, wird festgehalten

`CHANGELOG.md` sagt, **was sich geändert hat**. Es sagt nicht, **was auf einem
Telefon gelandet ist** — und das ist eine andere Frage. Nicht jede Version geht
nach TestFlight, und die Buildnummer dort kommt aus der Laufnummer des
Arbeitsablaufs, hat also mit der Version nichts zu tun.

Nach **jedem** TestFlight-Lauf kommt deshalb eine Zeile in die Tabelle in
`docs/12-auslieferung.md`, Abschnitt „Was wann in TestFlight lag": Buildnummer,
Version, Datum, Ergebnis, und in einem Halbsatz, was neu war. Auch bei einem
gescheiterten Lauf — gerade dann, denn die Nummer ist verbraucht und der Grund
ist die eigentliche Auskunft.

Ohne diese Tabelle lässt sich eine Rückmeldung vom Gerät nicht mehr zuordnen.
„Bei mir sieht das anders aus" ist ohne die Frage „welcher Build?" nicht zu
beantworten, und die Antwort steht sonst nirgends.

**Und sie wird vorher gelesen, nicht nur hinterher gefüllt.** Vor jedem
TestFlight-Lauf: nachsehen, ob für diesen Stand schon einer läuft oder gelaufen
ist — in der Tabelle und über `list_workflow_runs` mit Status `in_progress`
**und** `completed`. In 0.71.1 ist genau das schiefgegangen: Eine geplante
Nachschau hatte den Bau schon angestoßen, ich habe denselben Commit ein zweites
Mal geschickt, und Build 11 war ein Doppel, das abgebrochen werden musste.

---

## 5. Ablauf

Für jede Änderung, in dieser Reihenfolge:

1. **Ändern.** Bei einer Fehlerkorrektur zuerst den fehlschlagenden Test.
2. **Tests ergänzen** für alles, was neu ist oder falsch war.
3. **Tests ausführen.** Nicht grün heißt nicht fertig.
4. **Prototyp nachziehen**, falls sich am Produkt etwas ändert
   (siehe `CLAUDE.md`, Regel 1 — inklusive neuer Veröffentlichung).
5. **Version festlegen** und in Prototyp-Kopfzeile eintragen.
6. **`CHANGELOG.md` ergänzen.**
7. **Committen**, Version in der Commit-Nachricht nennen.
8. **In der Antwort** die Version und den Prüfstand nennen — der Nutzer soll
   nicht nachfragen müssen, ob getestet wurde.
9. **Nach einem TestFlight-Lauf** die Zeile in `docs/12-auslieferung.md`
   nachtragen (Abschnitt 4).

### Wenn etwas nicht geprüft werden kann

Vorkommen: `PulseData` braucht Xcode, unter Linux ist es nicht baubar.

Dann **nicht schweigen und nicht so tun, als wäre es geprüft.** In den Release
Notes und in der Antwort ausdrücklich vermerken, was ungeprüft ist und warum,
und wo der Fehler am ehesten zu erwarten ist. Eine ehrliche Lücke ist
handhabbar, eine verschwiegene nicht.

---

## Zusammengefasst

Der Nutzer soll nie fragen müssen „hast du getestet?" oder „was hat sich
geändert?". Beides steht in der Antwort, in `CHANGELOG.md` und im Prototyp.
