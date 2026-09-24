# 10 – Sichtbarkeit: gefunden werden, ohne Werbebudget

Stand: 2026-09-24, Version 0.116.4. Ersetzt die Fassung vom 13. August
(0.42.0). Die war vor dem Start geschrieben, vor der Umbenennung und vor der
Website, und hatte an drei Stellen den Anschluss verloren (Abschnitt 1).

Die Frage bleibt dieselbe: **Wie erfährt jemand von Zählora, der uns nicht
kennt?** Bezahlte Werbung ist weiter keine Antwort (Abschnitt 8).

> **Was gemessen ist und was nicht.** Gemessen am 24. September: die
> Produktseite im App Store, die ausgelieferte Website, die Suchfelder, die
> Konkurrenz auf ihren eigenen Produktseiten. **Nicht gemessen:** Suchvolumen,
> Impressionen, Installationen, ob Google die Seite schon führt. Dafür fehlen
> die Zugänge (Abschnitt 7). Alles, was nach Rangfolge klingt, ist eine
> begründete Schätzung und so gekennzeichnet.

---

## 1. Befund — was die Analyse am 24. September gefunden hat

### Im App Store

| Befund | Gewicht | Stand |
|---|---|---|
| **`zählerstand` stand in keinem durchsuchten Feld.** Seit der Umbenennung am 28. August heißt die App „Zähler & Verbrauch", der Untertitel nennt Strom, Gas, Wasser, ablesen. Die Schlagwortliste war gegen den alten Namen „Zählerstände" geschrieben und wurde nicht nachgezogen. Apple zerlegt deutsche Zusammensetzungen nicht. Dasselbe für `stromzähler` | **hoch.** Vermutlich das meistgetippte Wort der Kategorie, und der stärkste Mitbewerber heißt wörtlich „Zählerstände" | **behoben in 0.116.4** (`09-appstore.md`), wirksam mit der nächsten Fassung, 1.3 |
| **Eine einzige Bewertung.** Unter zehn zeigt der Store in der Suchliste keinen Stern; daneben steht „Zählerstände \| Ablesen, sparen" mit 4,5 aus 41 | **hoch.** Eine Liste ohne Sterne verliert gegen eine mit Sternen, auch wenn sie besser ist | offen. **Die Bewertungsfrage war im August Punkt 1 und wurde nie gebaut** |
| **Der Werbetext ist alt.** Dort steht „Neu: Du kaufst nur, was dir fehlt", seit dem Start. Das Feld ist das einzige, das sich ohne neue Fassung ändern lässt | mittel | Vorschlag in Abschnitt 3 |
| **Die Bildschirmfotos zeigen das iPad nur hoch.** 1.2 hat Apple mit den Bildern aus 1.1 freigegeben | mittel, auf dem iPad hoch | kommt mit 1.3 |
| **„Keine Daten erfasst"** steht auf unserer Produktseite. Beim größten Mitbewerber stehen Standort, Geräte-ID, Nutzungsdaten, Absturzdaten, dazu ein Abo nur für Werbefreiheit | **Vorteil.** Er wird in keinem Text ausgespielt, der vor dem Tipp auf die App zu sehen ist | Abschnitt 3 |

### Auf der Website

| Befund | Stand |
|---|---|
| Canonical, Sitemap und `og:url` zeigen auf die Adressen ohne `.html`, und genau die liefert Cloudflare aus. Geprüft an der ausgelieferten Seite. **Ich hatte das zuerst für einen Fehler gehalten; im Repository stehen die `.html`, umgeschrieben wird erst beim Ausliefern** (`scripts/website-fertig.sh`) | in Ordnung |
| **Kein App-Store-Banner.** Wer über eine Antwortseite auf dem iPhone kommt, musste den Knopf unten suchen | **behoben in 0.116.4**: `apple-itunes-app` auf allen Seiten außer dem Impressum |
| **Nur zwei Antwortseiten** (`gas-in-kwh`, `abschlag-zu-hoch`). Sie sind genau richtig gebaut: eine Frage, eine echte Rechnung, am Ende die App. Es sind nur zu wenige, um gefunden zu werden | Abschnitt 4 |
| **Die Adresse ist `zaehlora.pages.dev`.** Eine geteilte Domain. Einzelne Unterseiten von `pages.dev` sperrt Malwarebytes wegen Phishing, und eine Marke ist sie nicht. `zaehlora.de` hat keinen DNS-Eintrag, ist also **vermutlich** frei (nicht verbindlich geprüft) | Entscheidung beim Gründer, Abschnitt 4 |
| **Ob Google die Seite führt, ist unbekannt.** Die Suche aus diesem Container läuft über US-Ergebnisse und findet sie nicht; das sagt wenig. Ohne Search Console gibt es keine Zahl | Abschnitt 7 |

### Die Konkurrenz, auf ihren eigenen Seiten nachgesehen

| App | Was sie ausmacht | Wo wir anders sind |
|---|---|---|
| „Zählerstände \| Ablesen, sparen" | 4,5 ★ (41), Kamera-Erkennung, Wetterdaten, Werbung mit Abo zum Abschalten (0,99 €/Monat, 24,99 € dauerhaft), erfasst Standort und Geräte-ID | kein Abo, keine Werbung, keine Daten; Gas mit Zustandszahl und Brennwert; Abschlagsvorschau |
| pixometer | Kamera-Erkennung, eigentlich für Versorger gebaut | kein Konto |
| Energy Tracker, EnergyControl, Meterable | Zählerbuch mit Diagrammen | Vergleich auf gleicher Grundlage, gekennzeichnete Schätzungen, Bericht zum Prüfen der Abrechnung |

**Die eine Lücke, die sie alle offenlassen:** Keiner sagt, ob die
Jahresabrechnung stimmt. Sie zählen. Zählora rechnet nach. Das ist der Satz,
um den sich alles unten dreht.

---

## 2. Die Idee in einem Satz

> **Zählora wird dort gefunden, wo jemand gerade eine Rechnung in der Hand
> hat, und das ist zwischen Oktober und März.**

Daraus folgen drei Hebel, nach Wirkung je Aufwand geordnet: der App Store
(Abschnitt 3), Antwortseiten im Netz (Abschnitt 4), Fachöffentlichkeit und
Foren (Abschnitt 5). Dazu einer, der von selbst weiterträgt, wenn er einmal
steht: die Empfehlung aus der App heraus (Abschnitt 6).

Der Kalender dazu:

| Zeit | Was draußen passiert | Was wir tun |
|---|---|---|
| **Jetzt bis Mitte Oktober** | Nichts. Ruhe vor der Heizperiode | Hausaufgaben: Wörter, Bewertungsfrage, Bilder, drei neue Antwortseiten (1.3 am 07.10.) |
| **Mitte Oktober bis November** | Heizperiode beginnt, Gasjahre fangen am 1. Oktober an, Vermieter kündigen Ablesungen an | Presse und Foren (Abschnitt 5), mit 1.4 „Rundgang" als Anlass |
| **Ende Dezember** | Viele lesen zum Jahreswechsel ab, beim Anbieterwechsel ohnehin | **In-App-Ereignis im Store:** „Zum Jahreswechsel ablesen" (Abschnitt 3) |
| **Januar bis März** | Jahresabrechnungen kommen. Der Höhepunkt der Suche | Ernten. Antwortseiten müssen bis dahin von Google eingeordnet sein, also **vor Dezember** stehen |
| **April bis September** | Ruhe | Bauen, messen, Wörter nachschärfen |

---

## 3. Hebel 1 — der App Store

Die Grundregeln gelten weiter und stehen hier nur noch kurz: **Apple durchsucht
die Beschreibung nicht.** Durchsucht werden Name, Untertitel, das unsichtbare
Schlagwortfeld und die Anzeigenamen der fünf Käufe. In der Suchliste sieht man
Symbol, Name, Untertitel, Sterne und die ersten Bilder. Wer dort tippt, hebt
die App für dieses Wort.

### 3.1 Die Wörter — erledigt in 0.116.4

```
zählerstand,stromzähler,gaszähler,wasserzähler,nebenkosten,abrechnung,abschlag,photovoltaik
```

Begründung und Zählung in `09-appstore.md`. Wirksam mit dem Einreichen von 1.3.
**Neue Regel:** Ändert sich Name oder Untertitel, wird diese Liste im selben
Zug neu geprüft.

Name und Untertitel bleiben. „Zähler & Verbrauch" hat der Gründer am
28. August gewählt, und mit dem Schlagwortfeld ist das Loch auch ohne
Namensänderung zu.

### 3.2 Bewertungen — der größte offene Hebel

Die Regel stand seit August fest und gilt: gefragt wird **nach der dritten
gespeicherten Ablesung**, höchstens einmal je Fassung, über
`requestReview` von StoreKit, das ohnehin selbst entscheidet, ob es zeigt.
Nie beim Start, nie nach dem Kauf, nie gegen eine Freischaltung, nie mit einer
Vorfrage, die Unzufriedene zum Postfach umleitet.

**Das ist eine Produktänderung von einem Nachmittag** und gehört in 1.3. Sie
berührt den Zwei-Wochen-Plan kaum und wirkt länger als alles andere hier.

### 3.3 Der Werbetext — sofort änderbar

Vorschlag, 130 Zeichen, ohne neue Fassung eintragbar:

```
Du trägst deinen Zählerstand ein und siehst schon im Oktober, ob dein
Abschlag reicht. Ohne Abo, und deine Zahlen bleiben bei dir.
```

Er nimmt den Unterschied zur Konkurrenz auf, den heute niemand vor dem Tipp
sieht, und die eine Lücke, die sie alle offenlassen. Das Feld gehört danach
dem jeweils Neuesten, sobald es etwas gibt, das eine Nachricht wert ist
(1.3: „Tipp auf die Erinnerung, und der richtige Zähler ist offen").

### 3.4 Die Bilder

Mit 1.3 neu, und in dieser Reihenfolge:

1. **Die Übersicht mit einer Abschlagsvorschau**, Überschrift „Siehst du im
   Oktober, nicht im März". Das ist der Satz, der uns von allen Zählerbüchern
   trennt. Bisher steht die Übersicht allein da.
2. **Der Ziffernblock**, „Zehn Sekunden am Zähler".
3. **Der Bericht**, „Die Rechnung prüfen".
4. Das iPad quer mit zwei Spalten, im eigenen iPad-Satz an erster Stelle.

Danach mit dem **Produktseiten-Test** von App Store Connect (kostenlos) zwei
Fassungen des ersten Bildes gegeneinander laufen lassen. Das geht erst, wenn
es genug Aufrufe gibt, also frühestens im Januar.

### 3.5 In-App-Ereignis zum Jahreswechsel

App Store Connect bietet **In-App-Ereignisse**: eine Karte mit Bild, Titel
und Zeitraum, die in der Suche und auf der Produktseite erscheint, kostenlos.
Ein Ereignis muss etwas sein, das in der App tatsächlich passiert. Das ist
hier echt:

> **„Zum Jahreswechsel ablesen"**, 27. Dezember bis 3. Januar. Wer am
> 31. Dezember abliest, hat ein sauberes Kalenderjahr, und Zählora rechnet ab
> dann den Vergleich zum Vorjahr auf den Tag genau.

Anlegen im November. Das Bild braucht eine Stunde; das Ereignis braucht die
Freigabe durch Apple wie eine Fassung.

### 3.6 Eigene Produktseiten

Bis zu 35 zusätzliche Produktseiten mit eigenen Bildern und eigenem Werbetext,
jede mit eigener Adresse. Für uns lohnen sich zwei, weil dort andere Leute
ankommen: **Photovoltaik** (Bezug und Einspeisung, Vergütung) und
**Wärmepumpe/Nachtstrom**. Verlinkt werden sie aus den passenden Antwortseiten
und Forenbeiträgen, nicht in der Suche. Erst sinnvoll, wenn die
Antwortseiten stehen.

---

## 4. Hebel 2 — Antwortseiten im Netz

Google findet keine Apps, sondern Seiten, und dort sind die Fragen länger und
genauer. Die zwei Seiten, die es gibt, sind das Muster: eine Frage, eine echte
Rechnung zum Nachrechnen, die drei häufigsten Fehler, am Ende die App. Kein
Text, der für die Suchmaschine geschrieben ist. Der Tonfall aus `CLAUDE.md`
gilt hier genauso, und `check-website.mjs` zählt mit.

### 4.1 Die nächsten Seiten

Geordnet danach, wie gut die Frage zu dem passt, was nur Zählora rechnet
(die Suchmenge ist geschätzt, nicht gemessen):

| Seite | Die Frage dahinter | Warum wir |
|---|---|---|
| `nebenkostenabrechnung-pruefen` | „Stimmt meine Abrechnung?" | Der Bericht ist genau dafür gebaut. **Die wichtigste Seite**, mit Blick auf Strom und Gas, nicht auf Hausmeisterkosten |
| `stromverbrauch-normal` | „Ist mein Verbrauch zu hoch?" — für 1, 2, 4 Personen | Vergleich mit dem Vorjahr auf gleicher Grundlage; eine Tabelle mit Richtwerten und Quelle |
| `zaehlerstand-jahreswechsel` | „Muss ich am 31.12. ablesen?" | trägt das In-App-Ereignis, erscheint im Dezember |
| `waermepumpe-stromverbrauch` | „Was braucht meine Wärmepumpe im Winter?" | Hochrechnung, die den Winter kennt; Tag- und Nachtstrom |
| `einspeiseverguetung-berechnen` | „Was bringt meine Anlage?" | Zweirichtungszähler mit Vergütung |
| `zaehlerwechsel` | „Was muss ich beim neuen Zähler aufschreiben?" | Verlauf reißt nicht ab |

**Drei davon vor Dezember**, und zwar die ersten drei. Google braucht Wochen,
bis eine neue Seite auftaucht; wer im Januar schreibt, erntet im nächsten
Januar. Jede Seite bekommt ihre Zahlen aus derselben Rechnung wie die App,
wie die Gasseite heute (Regel 2 gilt sinngemäß).

**Was nicht passiert:** zwanzig dünne Seiten auf einmal, Texte von der Stange,
Vergleichstabellen mit fremden Marken.

### 4.2 Eine eigene Adresse

`zaehlora.de` statt `zaehlora.pages.dev`. Drei Gründe:

- **Vertrauen.** Eine Adresse unter `pages.dev` sieht in einer Mail an eine
  Redaktion und in einem Forenbeitrag aus wie ein Versuch. Einzelne
  Unterseiten derselben Domain sperren Virenschutzprogramme.
- **Beständigkeit.** Alles, was Google über die Seite lernt, hängt an der
  Adresse. Je später umgezogen wird, desto mehr geht dabei verloren. Vor den
  neuen Antwortseiten ist der billigste Zeitpunkt.
- **Kosten:** rund 5 bis 15 € im Jahr. Die Seite bleibt bei Cloudflare, nur
  die Adresse kommt dazu.

Die Adresse steht an drei Orten (`CLAUDE.md`), und `check-strings.py` hält sie
zusammen. Der Umzug ist damit eine halbe Stunde, plus die Eintragung beim
Registrar, die nur der Gründer machen kann. **Entscheidung beim Gründer.**

### 4.3 Search Console

Ohne sie wissen wir nicht, ob die Seite gefunden wird und mit welchen Wörtern.
Die Anmeldung braucht ein Google-Konto und einen Eintrag bei Cloudflare, also
den Gründer. Sie sieht nur, was Google ohnehin sieht, und setzt nichts auf die
Seite: Das Versprechen „nichts zählt mit" bleibt wahr. **Keine
Besucherzählung auf der Website**, auch keine „datenschutzfreundliche"; eine
Seite, die mit „wir sehen nichts" wirbt, zählt ihre Besucher nicht.

---

## 5. Hebel 3 — Fachöffentlichkeit und Foren

### 5.1 Redaktionen

Deutschsprachige Apple-Seiten nehmen kleine, gut gemachte Apps auf, wenn man
ihnen die Arbeit abnimmt. Fünf gezielte Mails, nicht fünfzig. Kandidaten:
iphone-ticker, ifun (hat das Thema Zählerstände schon einmal behandelt),
Apfelpage, appgefahren, Macerkopf, TheAppNote (hat Zähler-Apps getestet).

**Der Anlass** ist nicht „neue App für Zählerstände", die gibt es zu Dutzenden.
Es ist: **„Die App, die dir im Oktober sagt, ob die Nachzahlung im März
kommt."** Dazu der Rest in einem Satz: kein Konto, kein Abo, keine Daten,
Export dauerhaft frei, und eine Gasrechnung, die Zustandszahl und Brennwert
kennt.

**Das Paket:** eine Seite `presse` auf der Website mit einem Absatz, fünf
Bildern zum Herunterladen, dem Symbol, den Preisen und einer Adresse. Dazu
Codes zum Freischalten, soweit App Store Connect sie für die Käufe anbietet.

**Der Zeitpunkt:** Ende Oktober mit 1.4 („Rundgang": alle fälligen Zähler in
einem Durchgang). Da beginnt die Heizperiode, und es gibt eine Neuigkeit, die
man in einem Satz sagen kann. Vorher müssen stehen: die Bewertungsfrage (eine
Redaktion sieht die Sterne auch), die neuen Bilder, die Presseseite.

### 5.2 Foren und Gemeinschaften

Dort, wo die Fälle besprochen werden, die andere Apps nicht können:
Photovoltaikforum, Haustechnikdialog, Mieter- und Finanzgruppen.

**Nicht werben, sondern antworten.** Wer fragt „Wie rechne ich Kubikmeter in
kWh um?", bekommt die Rechnung, den Link auf die Antwortseite, und die App nur,
wenn sie zur Antwort gehört. Ein Beitrag, der nach Werbung aussieht, wird
gelöscht, und das zu Recht. Das kostet Zeit, und zwar die des Gründers: Ein
Forenbeitrag von einer Maschine ist genau das, was dort niemand will.

---

## 6. Hebel 4 — Empfehlung aus der App

Der Verbrauchsbericht ist das eine Stück Zählora, das die App verlässt. Er
geht an den Vermieter, an den Partner, an den Versorger.

**Vorschlag:** In der Fußzeile des Berichts eine Zeile „Erstellt mit
Zählora", klein, ohne Link und ohne Werbung. Im ungekauften Bericht steht
ohnehin der Schriftzug quer darüber; die Frage ist nur, ob die Fußzeile im
gekauften bleibt. **Entscheidung beim Gründer**, denn wer bezahlt, will
vielleicht gar nichts von uns auf seinem Papier.

Was nicht passiert: „Empfiehl uns weiter"-Dialoge, Belohnungen für
Empfehlungen, Teilen-Knöpfe ohne Anlass.

---

## 7. Woran wir merken, ob es wirkt

| Quelle | Was sie sagt | Zugang |
|---|---|---|
| App Store Connect, Analyse | Impressionen, Seitenaufrufe, Installationen, **je Suchwort** | **fehlt.** Der Schlüssel braucht die Rolle für Nutzungsberichte, beim Gründer offen seit dem 23. September |
| Search Console | Welche Seiten Google zeigt, für welche Fragen | fehlt, Abschnitt 4.3 |
| Bewertungen | Anzahl und Schnitt | öffentlich, heute: 1 |

Die Trennung aus der alten Fassung bleibt richtig: **Impressionen** (werden wir
gefunden?), **Seitenaufrufe je Impression** (überzeugen Symbol, Untertitel,
erste Bilder?), **Installationen je Aufruf** (überzeugt die Seite?). Nur die
Summe anzusehen führt in die Irre.

**Erster Messpunkt:** vier Wochen nach 1.3, also Anfang November. Dann zeigt
sich, ob `zählerstand` im Feld etwas bewegt. Danach Wörter höchstens alle zwei
bis drei Monate ändern; wer öfter dreht, misst nur sich selbst.

---

## 8. Was nicht gemacht wird

**Bezahlte Werbung, auch nicht Apple Search Ads.** Ein Nutzer kostet in dieser
Kategorie erfahrungsgemäß mehrere Euro, das teuerste Stück Zählora kostet
4,99 €, und nur ein Teil kauft überhaupt. Das rechnet sich bei Abos, und ein Abo
wollen wir ausdrücklich nicht (`04-monetarisierung.md`). Neu zu prüfen, wenn
Zahlen aus Abschnitt 7 zeigen, wie viele Besucher kaufen.

Außerdem nicht: gekaufte Bewertungen, fremde Marken im Schlagwortfeld,
Wörter für Dinge, die es noch nicht gibt (`siri` erst mit 1.3), eine
Besucherzählung auf der Website.

---

## 9. Reihenfolge

| Wann | Was | Wer |
|---|---|---|
| **erledigt, 0.116.4** | `zählerstand` und `stromzähler` ins Schlagwortfeld; App-Store-Banner auf der Website | — |
| **sofort** | Werbetext aus 3.3 eintragen | Gründer gibt frei, eintragen kann ich |
| **sofort** | Rolle für Nutzungsberichte am Schlüssel; Search Console anmelden | Gründer |
| **Entscheidung** | eigene Adresse `zaehlora.de`; Fußzeile im gekauften Bericht | Gründer |
| **mit 1.3, 07.10.** | Bewertungsfrage nach der dritten Ablesung; neue Bilder in der Reihenfolge aus 3.4 | ich |
| **bis Ende Oktober** | drei Antwortseiten aus 4.1; Presseseite | ich |
| **Ende Oktober, mit 1.4** | fünf Mails an Redaktionen | Gründer schickt, ich schreibe vor |
| **November** | In-App-Ereignis „Zum Jahreswechsel ablesen" anlegen; erster Messpunkt | ich, Freigabe durch Apple |
| **ab Januar** | Produktseiten-Test; eigene Produktseiten für PV und Wärmepumpe | ich |
