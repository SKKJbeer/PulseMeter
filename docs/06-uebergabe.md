# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-09-02, Version 0.105.6

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

1211 Zeilen, in sich geschlossen, ohne Bezug zu diesem Produkt. Darin: wie ein
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

**`main` ist der aktuelle Stand**, Version 0.105.6. Es gibt keinen offenen
Arbeitszweig; alles ist zusammengeführt.

| | Stand am 2. September |
|---|---|
| `PulseCore` | 231 Tests, grün |
| Klick-Dummy | 242 Prüfungen, hell und dunkel, grün |
| Website | 407 Prüfungen, grün, live auf `zaehlora.pages.dev` |
| App-Build und Oberflächentests | grün auf dem letzten macOS-Lauf |
| TestFlight | **Bau 25, VALID**, mit Testhinweisen |
| App Store Connect | 18 Angaben stehen, 0 offen |
| Käufe | 6 von 6 `READY_TO_SUBMIT` |
| Länder | 175, Deutschland dabei |
| Freigabe | `AFTER_APPROVAL` — geht sofort nach der Prüfung in den Laden |

**Der Umfang von 1.0 ist vollständig.** Es fehlt nichts mehr am Produkt.

### Die eine Sperre

Die Einreichung scheitert seit dem 29. August unverändert an:

```
appStoreVersions with id '…' is not in valid state.
This resource cannot be reviewed, please check associated errors to see why.
```

**Der Grund steht nicht in dieser Meldung, und er stand auch nicht dort, wo
diese Datei ihn bis zum 2. September vermutet hat.** Hier stand, es liege am
Händlerstatus nach dem Digitale-Dienste-Gesetz. Das war eine Vermutung, die
sich wie ein Befund las.

Am 2. September wurde stattdessen gemessen, was messbar ist:

| Geprüft | Ergebnis |
|---|---|
| Bau an der Fassung | Bau 25, `VALID` |
| Bilder | ein Satz `APP_IPHONE_67`, 5 Bilder, alle fertig |
| Altersfreigabe | vollständig beantwortet |
| Texte, Datenschutz-Adresse | gesetzt |
| `contentRightsDeclaration` | war **leer** → gesetzt |
| `usesIdfa` | war **leer** → auf „nein" gesetzt |
| `copyright` | war **leer** → „2026 Steffen Karjoth", vom Gründer |
| Danach eingereicht | **derselbe 409** |

Drei Pflichtangaben standen also wirklich leer — und keine davon war die
Ursache. Warum sie niemand gesehen hat, ist die eigentliche Lehre: Die Diagnose
blendete leere Werte aus, damit die Zeilen lesbar bleiben. Ein Pflichtfeld, das
niemand ausgefüllt hat, **ist** ein leerer Wert.

**Was die Schnittstelle nicht hergibt:**

| Weg | Antwort |
|---|---|
| Datenschutz-Fragebogen, 5 Schreibweisen | 404 — die Ressource gibt es in dieser Fassung der Schnittstelle nicht |
| Händlerstatus, 4 Wege | 404 |
| `reviewSubmissions/…/appStoreVersionForReview` | **403** |
| `reviewSubmissions/…/app` | **403** — und die App gibt es zweifelsfrei |

Der letzte Punkt ist der Maßstab für die anderen: Ein 403 auf einen Pfad, an
dem sicher etwas hängt, ist eine Auskunft über den Schlüssel, nicht über die
Fassung.

**Damit bleibt genau ein Ort, der es weiß: die Oberfläche von App Store
Connect.** Dort stehen die „associated errors" als rote Punkte neben den
Feldern. Zwei Kandidaten, die über die Schnittstelle nachweislich unsichtbar
sind:

1. **App Privacy** — der Fragebogen „Welche Daten erfasst die App?" muss
   *veröffentlicht* sein. Er ist etwas anderes als die Datenschutz-Adresse, die
   seit Wochen steht. Für Zählora lautet die Antwort: keine Daten erfasst.
2. **Agreements → Compliance**, Händlerstatus nach dem
   Digitale-Dienste-Gesetz.

**Sobald das erledigt ist:**

1. `einreichen.yml` mit `bestaetigung=einreichen` — hängt von selbst den
   neuesten tauglichen Bau an die Fassung und füllt die Pflichtangaben.
2. Nach `READY_FOR_SALE`: `live-schalten.yml` **von Hand** über
   `workflow_dispatch` auslösen. Auf den Stundenplan ist kein Verlass, gemessen
   einmal in sechs Stunden.
3. `https://zaehlora.pages.dev` abrufen und prüfen, dass dort das Abzeichen mit
   dem echten Verweis steht statt „Bald im App Store".

**Nebenbefund, damit ihn niemand noch einmal sucht:** Die leere Einreichung
`68046b63` lässt sich weder löschen (`DELETE` → 403) noch zurückziehen
(`canceled: true` → 409, „Resource is not in cancellable state"). Sie enthält
nichts und stört nachweislich nicht — der Einreichlauf nimmt die gefüllte
`5e3efe16`.

---

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
