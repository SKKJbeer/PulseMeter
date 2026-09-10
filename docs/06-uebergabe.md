# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-09-10, Version 0.113.13

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

**`main` ist der aktuelle Stand**, Version 0.113.13. Es gibt keinen offenen
Arbeitszweig; alles ist zusammengeführt. `claude/setup-pruefung-4qyr2u` steht
noch bei GitHub, vollständig in `main` — aus der Cloud lässt er sich nicht
löschen (`HTTP 403`), von der Weboberfläche aus mit einem Klick.

| | Stand am 10. September |
|---|---|
| **App Store** | **Zählora 1.0.1 ist freigegeben** — 7. September. 1.0 stand dort seit dem 4. September |
| `PulseCore` | grün |
| Klick-Dummy | 278 Prüfungen, hell und dunkel, grün — mit breitem Rahmen fürs Tablet |
| Website | 415 Prüfungen, grün, live auf `zaehlora.pages.dev` |
| **Oberflächentests iPhone** | **grün** — 41 Prüfungen, Lauf 409 |
| **Oberflächentests iPad** | **grün** — dieselben 41 Prüfungen, Lauf 409, zum ersten Mal zugleich mit dem iPhone |
| TestFlight | Bau 32, VALID — der erste mit iCloud-Abgleich und Widget |
| Käufe | 6 von 6, mit der Fassung eingereicht |
| Länder | 175, Deutschland dabei |

### Das iPad ist fertig — und was daran noch aussteht

Seit 0.112.0 läuft die App auf beiden Familien (`TARGETED_DEVICE_FAMILY:
"1,2"`): Seitenleiste statt Tableiste auf breiten Fenstern, Karten in einem
mitwachsenden Raster. **Grün auf beiden zugleich waren die Prüfungen zum ersten
Mal in Lauf 409.** Der Weg dahin steht in `docs/12-auslieferung.md`; die eine
Lehre daraus, in `projekt-baukasten` ausführlich: *auf einem großen Bildschirm
ist „vorne" nicht dasselbe wie „zuerst gefunden"* — der Fehler saß jedes Mal im
Griff der Prüfung, nie in der Ansicht.

**Was am iPad noch offen ist, und zwar am Produkt, nicht an den Prüfungen:**
Auf `Verlauf` und `Zähler` steht der Inhalt im oberen Drittel, darunter bleibt
auf einem 13-Zoll-Schirm die Hälfte leer. Es ist nicht falsch, aber es ist auch
nicht entworfen. Ein zweispaltiger Aufbau — links die Wahl, rechts das
Ausgewählte — wäre die naheliegende Antwort. Nicht angefangen; erst zu
entscheiden.

**Zur Einreichung fehlt der iPad-Bildersatz.** `scripts/asc-einreichung.py`
kennt ihn seit 0.113.13, unter der Kennung `APP_IPAD_PRO_3GEN_129`. Ob Apple
sie annimmt, ist **nicht nachgeschlagen, sondern auszuprobieren**: Die Kennung
steht bei Apple für 2048 × 2732, der Simulator liefert 2064 × 2752. Lehnt der
Hochladeversuch ab, steht Apples Begründung wörtlich in der offenen Liste des
Laufs — und die richtige Kennung ist daraus abzulesen, nicht zu raten.

**Der Umfang von 1.0 ist vollständig, und seit 1.0.1 kommt er auch an.** Der
iCloud-Abgleich und das Feld auf dem Sperrbildschirm waren in 1.0 eingebaut und
beworben und erreichten niemanden; warum, steht gleich darunter.

### Gelöst: Bau 32 bringt iCloud-Abgleich und Widget

**Seit dem 6. September, 05:31 UTC, belegt statt vermutet:**

```
Berechtigungen gehen mit: App/PulseMeter.entitlements, Widget/PulseWidget.entitlements
Bau 32 steht bereit, die Testhinweise sind eingetragen.
· Bau 32: VALID — hochgeladen 2026-09-05T22:32
```

Am Code lag es nie. `PulseStore.container(cloudKit: true)` war seit Monaten die
erste Stufe in `PulseMeterApp.init`; sie ist nur nie angesprungen, weil ohne
Berechtigung Stufe zwei greift — derselbe Speicher ohne Abgleich, still.

Gefehlt haben **fünf Handgriffe im Entwicklerportal**, nicht zwei: die App-Gruppe
und den iCloud-Behälter anlegen, und beide dann an drei Stellen **zuordnen** —
an der App-ID für Gruppe und Behälter, an der Widget-Kennung für die Gruppe.
Jedes Mal gefolgt vom **Save oben rechts**; an dessen Ausbleiben ist es zweimal
gescheitert. Die Bauten 27 bis 31 sind dabei verbraucht worden. Ausführlich in
`docs/12-auslieferung.md`, Abschnitt 3.4.

**Nachprüfbar ist es nicht, und das ist der Rest des Befunds.** `warum` gibt
die Fähigkeiten der App-IDs jetzt roh aus — dort steht, welche eingeschaltet
sind, aber **nicht**, welche Kennung ihnen zugeordnet ist. Am 6. September
gegengeprüft, nachdem Bau 32 mit Berechtigungen durchgegangen war: `APP_GROUPS`
kam weiter ohne Einstellungen zurück. Der Block trägt die Einstellungen einer
Fähigkeit, nicht die Kennungen dahinter. Die Probe auf die Zuordnung ist und
bleibt das Signieren.

### Fassung 1.0.1 ist freigegeben — 7. September

```
Fassung 1.0.1: READY_FOR_SALE, appVersionState READY_FOR_DISTRIBUTION
reviewSubmissions 68046b63 — submittedDate 2026-09-06T05:53:26, state COMPLETE
```

Eingereicht am 6. September um 05:53 UTC, freigegeben gut sechsundzwanzig
Stunden später. Keine Rückfrage, kein Lösungscenter. `AFTER_APPROVAL` hat
gehalten: Niemand musste einen Knopf drücken.

Damit ist zum ersten Mal beim Käufer, was seit dem 4. September in der
Beschreibung steht — der iCloud-Abgleich und das Feld auf dem Sperrbildschirm —
und dazu die Kostenspalten für Monat, Quartal und Jahr samt Erklärblatt.

**Apples öffentliches Verzeichnis hinkt hinterher, und das ist normal.** Zum
Zeitpunkt der Freigabe meldete `itunes.apple.com/lookup` noch 1.0. Der Zustand
in App Store Connect ist die Auskunft, die zählt; das Verzeichnis zieht binnen
Stunden nach. Wer vom Verzeichnis auf „noch nicht freigegeben" schließt, liest
einen Zwischenstand als Befund.

### Aufrufe und Ladungen — `zahlen.yml`

Seit 0.107.0 holt `scripts/asc-zahlen.py` die Zahlen aus App Store Connect:
Impressions, Aufrufe der Produktseite, Ladungen insgesamt und Erstinstallationen.
Ein Ablauf, täglich um 09:00 UTC, dazu ein Knopf.

**Der Grund, warum das nicht warten durfte:** Apple sammelt diese Zahlen erst,
wenn man sie anfordert. Ein Bericht mit `accessType: ONGOING` fängt am Tag der
Anforderung an; was davor liegt, kennt er nicht. Und Apple **stoppt** eine
Anforderung wieder, wenn monatelang niemand die Berichte abruft — der tägliche
Lauf hält sie am Leben.

Rückwirkend geht es über `ONE_TIME_SNAPSHOT` (bis 365 Tage), der Knopf dafür
heißt „rueckwirkend" am Ablauf.

> **Es steht noch nicht. Der Schlüssel darf nicht.** Erster Lauf am
> 5. September, jede Analytics-Anfrage:
>
> ```
> 403 FORBIDDEN_ERROR — The API key in use does not allow this request
> ```
>
> Derselbe Schlüssel legt die App an, pflegt Käufe und reicht ein — die
> Berichte hängen an seiner **Rolle**, nicht an der App. Zu ändern in App Store
> Connect unter Benutzer und Zugriff › Integrationen: Rolle des vorhandenen
> Schlüssels anheben, oder einen zweiten anlegen und als eigene drei
> Geheimnisse hinterlegen. **Das kann nur der Gründer.** Bis dahin sammelt
> Apple nichts, und jeder Tag Wartezeit ist ein Tag ohne Zahlen.

### Im Laden seit dem 4. September, 23:00 UTC

Nicht aus dem eigenen Skript gelesen, sondern von Apples öffentlichem
Verzeichnis — der Stelle, die auch ein Käufer sieht:

```
https://itunes.apple.com/lookup?id=6802262743&country=de
Zählora – Zähler & Verbrauch | 1.0 | 2026-09-04T23:00:15Z | Gratis
```

Die Adresse im Laden:
`https://apps.apple.com/de/app/id6802262743`

**Die Website hinkte einen halben Tag hinterher, und das war ein Fehler im
Ablauf.** `live-schalten.yml` hat den Knopf um 00:10 UTC richtig umgelegt und
gepusht — und ist danach rot geworden:

```
POST …/actions/workflows/website.yml/dispatches
403 Resource not accessible by integration
```

Ein Push mit dem `GITHUB_TOKEN` löst keinen weiteren Ablauf aus; deshalb stößt
der letzte Schritt die Veröffentlichung von Hand an — und genau dafür fehlte
`actions: write`. Ergebnis: Der Knopf stand im Repository auf „an", im Netz
weiter auf „Bald im App Store". Also der eine Zustand, den dieser Ablauf
verhindern soll.

Behoben in 0.106.6: die Berechtigung ergänzt, und die Veröffentlichung hängt
jetzt am **umgelegten Knopf** statt an der Freigabe — sonst stieße der
Stundenplan von der Freigabe an jede Stunde eine Veröffentlichung an, die nichts
ändert.

### Abgelehnt in der Nacht zum 3. September

```
Fassung 1.0: REJECTED
Bei der Prüfung: UNRESOLVED_ISSUES
```

**Der Grund steht nicht in der Schnittstelle.** Sechs Wege abgefragt, sechs
Absagen:

| Weg | Antwort |
|---|---|
| `appStoreVersions/…/appStoreVersionSubmission` | 404 — „no resource of type `appStoreVersionSubmissions`" |
| `appStoreVersions/…/resolutionCenterThreads` | 404 |
| `apps/…/resolutionCenterThreads` | 404 |
| `v1/resolutionCenterThreads` | 404 |
| `v1/resolutionCenterMessages` | 404 |
| `appStoreVersions/…/appStoreReviewAttachments` | 404 |

Apples Begründung liegt im **Lösungscenter** in App Store Connect und kommt per
E-Mail. Nur der Gründer kommt daran; eine Cloud-Sitzung sieht sie nie. Er hat
sie am 3. September weitergereicht:

> **Guideline 2.1 – Information Needed – New App Submission.** „This app has
> been submitted by a developer account that has a limited App Review history."

**Kein Mangel an der App.** Ein Konto ohne Prüfhistorie, sieben Fragen. Sechs
davon sind Text und stehen seit 0.105.9 im Feld „Notes" (3252 Zeichen,
englisch, vom Lauf `einreichung.yml --fuellen` eingetragen). Der Wortlaut steht
in `docs/09-appstore.md` unter „Hinweise für die Prüfung".

**Punkt 1 war eine Bildschirmaufnahme auf einem echten Gerät** — die kann kein
Skript erzeugen. Der Gründer hat sie am 3. September um 14:51 zusammen mit dem
Text im Lösungscenter beantwortet
(`ScreenRecording_09-03-2026 14-44-52_1.mp4`).

**Und das hat gereicht, um die Ablehnung aufzuheben.** Unmittelbar danach
gemessen:

```
Fassung 1.0: READY_FOR_REVIEW     (vorher REJECTED)
Bei der Prüfung: UNRESOLVED_ISSUES
```

**Hier stand, `UNRESOLVED_ISSUES` gehöre „zum alten Vorgang". Das war falsch,
und zwar aus derselben Bequemlichkeit wie dreimal vorher: eine Zustandsänderung
gesehen, den Rest dazuerzählt.** Vier Stunden später nachgemessen, was die
Einreichung tatsächlich enthält:

```
6 Einträge, alle READY_FOR_REVIEW
· … "appStoreVersion": {"data": {"id": "be468160-…"}}
⇒ beigefügt: appStoreVersions be468160 {'versionString': '1.0'}
```

Es ist **kein** alter Vorgang. Es ist derselbe, in dem Fassung 1.0 seit dem
2. September liegt, und ihre fünf Käufe daneben. `UNRESOLVED_ISSUES` heißt
„Apple hat gefragt und wartet auf Antwort" — die Antwort ist seit dem
3. September, 14:51, dort.

**Es brauchte einen Anstoß.** Vierzehn Stunden lang bewegte sich nichts, und
das war die Antwort auf die offene Frage: `UNRESOLVED_ISSUES` heißt nicht „läuft
weiter", sondern „Apple wartet auf uns". Die Antwort im Lösungscenter allein
schiebt die Einreichung nicht an.

Behoben in 0.106.2: `UNRESOLVED_ISSUES` ist aus `UNTERWEGS` heraus — sonst
meldet das Skript „steht schon bei der Prüfung" und tut nichts — und
`vorbereitete()` nimmt seitdem auch diesen Zustand an. Danach `--einreichen`
erneut angestoßen, und seitdem steht:

```
Fassung 1.0: WAITING_FOR_REVIEW
Bei der Prüfung: WAITING_FOR_REVIEW
```

Danach ging es: Apple hat am 4. September freigegeben, keine weitere Rückfrage.
Von der Ablehnung bis in den Laden waren es knapp zwei Tage.

---

### Die Sperre davor ist weg — eingereicht am 2. September, 19:05

```
✓ Fassung 1.0 der Einreichung hinzugefügt
Eingereicht. Zustand: WAITING_FOR_REVIEW
```

**Es war die Preisstufe.** Sie war nie gewählt worden. Die Oberfläche sagt es in
einem Satz — „Wähle unter ‚Preis' eine Preisstufe aus" —, die Schnittstelle
fasst es zu „appStoreVersions … is not in valid state" zusammen und nennt es
nicht.

Und im eigenen Protokoll stand es seit dem ersten Tag:

```
── Preisplan
   v1/apps/6802262743/appPriceSchedule  →  200
   {}
```

Gelesen als „vorhanden, hat eben keine Attribute". Gemeint war: **leer**. Ein
Preisplan ohne Preise ist ein Objekt, das existiert und nichts sagt.

Der Einreichlauf setzt die Stufe jetzt selbst (kostenlos, Zählora verdient über
Einmalkäufe) und liest das Ergebnis nach, statt dem 201 zu glauben. Ein
Nebenfehler dabei, der es fast noch einmal verdeckt hätte: `(preis or "")` —
`0.0 or ""` ist `""`, also fiel ausgerechnet die kostenlose Stufe durch den
eigenen Filter.

Alle drei Schritte, die hier als „was jetzt noch kommt" standen, sind erledigt:
Apple hat freigegeben, der Knopf ist umgelegt, die Seite verweist auf den Laden.
`AFTER_APPROVAL` hat gehalten, was es verspricht — die App ging von selbst
hinein, ohne dass jemand einen Knopf drücken musste.

---

### Was die Sperre vier Tage lang war — und was daran zu lernen ist

Die Einreichung scheiterte seit dem 29. August unverändert an:

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
| Kategorien | `UTILITIES` und `FINANCE` — gesetzt |
| Zielgeräte | nur iPhone (`TARGETED_DEVICE_FAMILY: "1"`), also keine iPad-Bilder nötig |
| Händlerstatus | am 2. September vom Gründer belegt: **Aktiv** |
| App Privacy | vom Gründer als veröffentlicht gemeldet |
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

**Der Ort, der es wusste, war die Oberfläche von App Store Connect.** Dort
stehen die „associated errors" als rote Punkte neben den Feldern — und dort
stand der eine Satz, der vier Tage gekostet hat: „Wähle unter ‚Preis' eine
Preisstufe aus."

> **Die Lehre für das nächste Mal: Wenn die Schnittstelle einen Zustand meldet,
> den sie nicht begründet, wird die Oberfläche einmal angesehen — nach dem
> zweiten Fehlschlag, nicht nach dem zehnten.** Vier Tage Ermittlung gegen einen
> Blick, den nur der Gründer tun kann und der eine halbe Minute dauert.

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
