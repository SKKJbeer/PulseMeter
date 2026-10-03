# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-10-03, Version 0.118.11

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

### Im Laden und in TestFlight

- **1.2** im Laden seit 24. September (Bau 36).
- **Bau 38** (0.118.1) in TestFlight, VALID: Siri, Bewertungsfrage, Einheit
  in der Tabelle. Davor Bau 37 (0.117.8): größte Schrift auf iPad und iPhone
  SE. Auf `entwicklung.html` steht dafür „Im Test".
- **1.3** wird am **7. Oktober** eingereicht, nur mit Freigabe des Gründers
  (Regel 4a). Darin: Erinnerung und Sperrbildschirm öffnen den Ziffernblock
  (0.116.0), Umschalter im iPad-Hochformat, **Siri** und die
  **Bewertungsfrage** (beide 0.118.0), dazu das neue Schlagwortfeld und die
  Beschreibung aus `09-appstore.md`, die erst mit einer neuen Fassung gelten.

### Offen beim Gründer — nicht vergessen, bei jeder Meldung erinnern

Am 26. September zugesagt, am 28. mit „merk dir das" bestätigt. Alle sechs mit
direktem Link in **`docs/13-zugaenge.md`**. Was danach von allein läuft, steht
dort je Punkt.

| # | Was | Folge, solange es fehlt |
|---|---|---|
| 1 | ~~Analytics Engine bei Cloudflare einschalten~~ | **erledigt am 30. September.** Der Gründer hat den Datensatz `zaehlora_aufrufe` mit der Bindung `ZAEHLUNG` angelegt |
| 2 | ~~Cloudflare-Leseschlüssel `CLOUDFLARE_STATISTIK_TOKEN`~~ | **erledigt am 30. September.** Erster Bericht lief: „Website-Zahlen" von Hand startbar, sonst montags |
| 3 | Search Console: Bestätigungscode in den Chat | Google führt die Seite nicht offiziell, keine Suchbegriffe |
| 4 | Google-Dienstkonto `GOOGLE_SC_SCHLUESSEL` | keine Google-Zahlen im Wochenbericht, Sitemap nicht automatisch gemeldet |
| 5 | App-Store-Berichtsschlüssel (Rolle Admin) `ASC_BERICHT_KEY_ID`/`_P8` | `zahlen.yml` scheitert täglich mit 403 |
| 6 | Anbieterkennung `pt` in den Chat | Laden-Knopf auf der Website ohne Kampagne |
| 7 | Domain `zaehlora.de` | **erledigt am 3. Oktober**: Website unter `zaehlora.de`, `zaehlora.pages.dev` und `www` leiten mit 301 weiter |

Sobald einer davon kommt: Punkt 1 → `website.yml` von Hand anstoßen und live
`x-zaehlung` prüfen; Punkt 3 → Meta-Zeile in `index.html`, veröffentlichen,
Gründer „Bestätigen" sagen lassen; Punkt 6 → `APPSTORE_PT` in `website.yml`;
Punkte 2, 4, 5 → die Berichte einmal von Hand starten und nachsehen.

### Entschieden am 28. September: Einheit in der Tabelle

„ok mach" auf den Vorschlag vom 26. September. Seit 0.118.1 steht unter dem
Tabellenkopf im Verlauf „in kWh" (klein, nicht in Versalien), in App und
Klick-Dummy. Der Satz „Alle Werte in …" unter der Tabelle im Entwurf ist weg.

### Als Nächstes

1. **1.4 Rundgang** (Einreichen 21. Oktober): nach dem Sichern „Weiter mit
   Wasser", bis alle fälligen Zähler durch sind. Baut auf dem Weg aus
   `AppAddress` und `Wegweiser` auf.
2. **Neue Bilder für den Laden** zu 1.3 (`10-sichtbarkeit.md` 4.4).
3. **Ratgeberseiten**, eine je Woche: stromverbrauch-normal, anbieterwechsel,
   zweirichtungszaehler, zaehlerwechsel, waermepumpe.

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
