# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-11-11, Version 0.148.0

---

## Wozu dieses Dokument

Eine neue Sitzung startet kalt. Sie kennt keinen Chatverlauf — weder den auf
dem Mac noch den in der Cloud. Was sie kennt, ist das Repository.

**Wer hier ankommt, liest diese Datei zuerst und danach `CLAUDE.md`.** Danach
weiß sie, wo die Arbeit steht und wie hier gearbeitet wird. Alles andere ergibt
sich aus der Tabelle unten.

**Das Repository ist öffentlich** (am 31. August nachgemessen: `"private":
false`). Jede Datei hier ist ohne Konto lesbar, und der Einstieg lässt sich als
Verweis weitergeben:
`https://github.com/SKKJbeer/PulseMeter/blob/main/docs/06-uebergabe.md`

Der **dauerhafte** Teil steht längst im Repository und ist ausführlich:

| Was | Wo |
|---|---|
| **Arbeitsweise, Sprachregeln, Prüfschritte, die vier Regeln** | `CLAUDE.md` |
| **Jede Änderung mit Begründung, neueste oben** | `CHANGELOG.md` |
| Warum es dieses Produkt gibt, für wen, wogegen es sich entscheidet | `docs/00-produktstrategie.md` |
| Jede technische Entscheidung mit Begründung | `docs/01-architektur.md` |
| Domänenmodell, Rechenkern, Randfälle | `docs/02-datenmodell.md` |
| Navigation, Kernscreens, Design-System | `docs/03-ux-konzept.md` |
| Free / Pro / Bündel und warum welcher Preis | `docs/04-monetarisierung.md` |
| Was für 1.0 fehlt und was gestrichen ist | `docs/07-v1-plan.md` |
| Alle Store-Texte, fertig zum Einfügen | `docs/09-appstore.md` |
| Vom Code in den App Store, ohne Mac | `docs/12-auslieferung.md` |

Dazu die Kommentare im Code: Sie begründen durchgehend das **Warum**, nicht das
Was.

Was **nicht** im Repository steht, ist der laufende Zustand. Genau dafür ist
diese Datei. Sie wird bei jeder Übergabe **überschrieben**, nicht
fortgeschrieben — eine Übergabedatei, die wächst, ist nach dem dritten Mal ein
Archiv und keine Auskunft mehr.

---

## Das Wissen zum Mitnehmen

**Wer ein zweites Vorhaben anfängt, braucht von hier nur eine Datei:**

```
.claude/skills/projekt-baukasten/SKILL.md
```

1272 Zeilen, in sich geschlossen, ohne Bezug zu diesem Produkt. Darin: wie ein
Projekt aufgebaut und dokumentiert wird, wie Konzepte entstehen, wie ohne Mac
bis in TestFlight ausgeliefert wird, was bei Apple, App Store Connect,
Profilen, Berechtigungen und Käufen schiefgeht — und die Fehlerklassen, die in
diesem Projekt jede mindestens dreimal zugeschlagen haben.

Die drei anderen Skills sind kleiner und ebenfalls übertragbar:

| Datei | Wofür | Übertragbar? |
|---|---|---|
| `.claude/skills/projekt-baukasten/SKILL.md` | das gesammelte Vorgehen | **unverändert** |
| `.claude/skills/release-discipline/SKILL.md` | Version, Release Notes und Tests als Pflicht je Änderung | **unverändert** |
| `.claude/skills/selbstsprechend/SKILL.md` | Regeln für jeden Text, den ein Nutzer sieht | unverändert, wenn die App Deutsch spricht |
| `.claude/skills/xcode-workflow/SKILL.md` | Bauen und Prüfen auf einem Mac | nur bei iOS, Pfade anpassen |

**Automatisch übertragen** wird das alles mit

```
scripts/neues-projekt.sh <ordner> <Name>
```

Das legt den Ordner **neben** diesem Projekt an (nie hinein), kopiert die vier
Skills, den Melder, den Push-Haken und **vier Prüfungen, die sofort tragen** —
`check-strings.py`, `check-namen.py`, `check-sicherheit.sh`,
`check-trefferflaechen.py` —, schreibt ein `pruefen.sh`, eine CI-Beschreibung
und eine `CLAUDE.md` und macht `git init`. Was danach von Hand kommt, sagt es
zum Schluss selbst.

Welche Prüfung was fängt und was es gekostet hat, bevor es sie gab, steht als
Tabelle im Baukasten unter „Die Prüfungen".

---

## Wo die Arbeit steht

Neu geschrieben am 11. November im Review „Stand und Roadmap“. Die Fassung
davor stand auf dem 22. Oktober und nannte 1.6 noch „eingereicht“.

### Im Laden und in TestFlight

| | |
|---|---|
| **Im Laden** | **1.6** seit 3. November (Bau 48): Mit Kamera ablesen, eigener Kauf 1,99 €, im Bündel. Davor 1.5.1 (19.10.), 1.5 Import (14.10.) |
| **In TestFlight** | **Bau 49** (0.144.0, 11.11.): Kamera schlägt keine Zahl vor, die auch zum anderen Zählwerk passt |
| **iCloud-Abgleich** | behoben am 10. November ohne neuen Bau (Schema in der Produktion), vom Gründer am 11. November auf zwei Geräten bestätigt |
| **Im Rückstand** | `zahlen.yml` (Berichtsschlüssel mit Rolle Admin fehlt, `13-zugaenge.md` Punkt 5); am 8. November abgeschaltet, Reichweite nur aus Bewertungen und Website-Zahlen |

### Offene Pull Requests (Stand 11. November, abends)

| PR | Inhalt | Stand |
|---|---|---|
| #17 | 1.7: neuer Preis ab einem Tag, Gas und Heizöl in kWh (0.145.x bis 0.147.0), dazu Website Wärmepumpe | in Arbeit im Thread zu 1.7, CI läuft |
| #13 | Ratgeberseite „Nachzahlung prüfen“ (0.143.0) | CI rot seit 10. November. Muss vor Januar live sein, sonst verpasst sie die Abrechnungszeit |
| Review | Zwei Rechenfehler auf Übersicht und im Bericht (0.148.0), diese Übergabe | dieser Zweig |

**Versionsnummern bei parallelen Zweigen:** Jeder offene PR reserviert seine
Nummern (0.143.0 für #13, 0.145.x bis 0.147.0 für #17). Wer einen neuen Zweig
anfängt, nimmt die nächste freie Nummer über allen offenen PRs, nicht über
`main`.

### Der Plan (Einzelheiten in `05-roadmap.md`)

| Fassung | Einreichen | Inhalt |
|---|---|---|
| 1.7 | 02.12. | Neuer Preis ab einem Tag, Gas und Heizöl auch in kWh (aus der Mail eines Käufers) |
| 1.8 | 16.12. | Puffer für 1.7 |
| 1.9 | 13.01. | Heizungswechsel: alter und neuer Zähler verbunden, Vorher-Nachher-Karte. Neuer Kauf „Wärmepumpe“ 4,99 € |
| Wechsel-Paket | Feb. bis Apr. 2027 | Heizlast, Gegenprobe für Angebote, Mappe für den Fachbetrieb, 14,99 € |
| 2.0 | Sommer 2027 | Jahresarbeitszahl aus eigenen Zählern |
| Kamera Stufe 2 | nach 1.9 | zwei Zählwerke auf einem Bild |

Der Bericht zum Review vom 11. November (Befunde zu Bedienung, Rechnung,
Roadmap und Dokumenten) liegt als Dokument beim Gründer; die Befunde, die
Arbeit bedeuten, stehen in der Roadmap.

### Daueraufgaben

- **Strompreis-Grafik:** Eurostat ergänzt zweimal im Jahr ein Halbjahr. Dann
  `scripts/strompreis-holen.py`; schlägt `check-website.mjs` an, Sätze und
  Kacheln auf `strompreis-entwicklung.html` nachziehen.
- **co2online:** Erlaubnis seit 13. Oktober, Bedingung ist die Quellenangabe
  „co2online gGmbH“ (`check-website.mjs` hält sie fest). Heizspiegel jährlich
  Ende September, Stromspiegel alle zwei Jahre (zuletzt 2025): Werte
  übernehmen.
- **Händlerangaben:** Telefonnummer in App Store Connect gegen eine nicht
  private tauschen, aber nur, wenn keine Einreichung läuft.

## Was zuletzt gefunden wurde, und warum es zählt

Am 29. August hat ein Audit die Website Satz für Satz gegen den Quelltext
gehalten. Von rund dreißig Zusagen waren **drei falsch und vier zu absolut** —
bei einer Prüfsuite, die an dem Tag alles grün meldete.

| Befund | Behoben in |
|---|---|
| Der Knopf „Beispieldaten anlegen" verschenkte drei von fünf Käufen | 0.104.0 |
| „Ein Feld auf dem Sperrbildschirm" war beworben und gab es nicht | 0.104.0, gebaut |
| Die Hilfeseite bot Erinnerungen kostenlos an, die 0,99 € kosten | 0.103.1 |
| Die Store-Beschreibung trug dieselben drei falschen Zusagen und war 152 Zeichen zu lang | 0.104.2 |
| An der Fassung 1.0 hing Bau 24 statt Bau 25 | 0.105.1 |

**Die Lehre, die bleibt:** Die Prüfsuite prüft die Innenseite — ob die App tut,
was der Code sagt. Ob der Code tut, was die Verkaufsseite verspricht, prüfte
nichts. Seit 0.103.1 tut es `scripts/check-versprechen.py`.

---

## Worauf besonders zu achten ist

**Die wiederkehrende Fehlerklasse.** Bisher entstand *jeder* gefundene
Rechenfehler dadurch, dass ein Zeitraum, den die Daten abdecken, gegen einen
verglichen wurde, den sie nicht abdecken. Bei jedem neuen Vergleich, jeder
Hochrechnung und jeder Summe gilt deshalb: Beide Seiten müssen denselben
Zeitausschnitt beschreiben — bei saisonalen Zählern denselben Ausschnitt des
Jahres.

**Zählen ist nicht wissen.** Dreimal in einer Woche stand eine Anzahl für eine
Tatsache: „fünf Einträge" hieß nicht „die Fassung ist dabei", „ein Preisplan
existiert" hieß nicht „der Preis stimmt", „Bau hängt dran" hieß nicht „der
richtige Bau hängt dran". Jedes Nachlesen stellt zwei Fragen: Ist es da, und
ist es richtig?

**Ein Fehlschlag auf der eigenen Seite ist keine Auskunft über die Gegenseite.**
Eine gescheiterte Anfrage darf nie als Aussage über die Welt herauskommen —
„in 0 Ländern verkäuflich" war einmal eine 400er-Antwort auf einen Filter, den
es nicht gibt.

**Zwei Orte, die einander nicht sehen.** Der Mac des Gründers und die
Cloud-Sitzung. Eine Cloud-Sitzung erfährt nur über den Zweig `pruefungen` oder
durch eine Nachricht, was am Mac passiert ist — und darf nie behaupten, sie
könne dort etwas ausführen.

```bash
git fetch origin pruefungen && git show origin/pruefungen:README.md | tail -5
```

---

## Wie die beiden Orte zusammenarbeiten

| | Am Mac | In der Cloud |
|---|---|---|
| Xcode, Simulator, Screenshots | ✓ | ✗ |
| `PulseCore`, Klick-Dummy, Website | ✓ | ✓ |
| `PulseData` (SwiftData) | ✓ | ✗ |
| Abläufe anstoßen und nachsehen | ✓ | ✓ |

Auf einem frisch übernommenen Mac: `scripts/mac-start.sh`. Es holt zuerst den
aktuellen Stand und ruft dann Einrichtung und Prüfung auf — der Schritt
existiert, weil ein Arbeitsverzeichnis auf einem veralteten Zweig vollständig
aussieht.

Unter Linux macht `scripts/pruefen.sh` alles, was ohne Xcode geht, und
**benennt**, was es überspringt.
