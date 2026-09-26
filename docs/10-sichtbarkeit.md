# 10 – Sichtbarkeit: gefunden werden, ohne Werbebudget

Stand: 2026-09-26, Version 0.117.1.

Die Frage: **Wie erfährt jemand von Zählora, der uns nicht kennt?** Bezahlte
Werbung ist keine Antwort (Abschnitt 8).

> **Diese Fassung ist aus der Sicht der Suchmaschine geschrieben.** Die vom
> Vortag (0.116.4) hatte zwei Fehler, beide vom Gründer am 25. September
> benannt:
>
> 1. **„Gefunden wird Zählora zwischen Oktober und März." Falsch.** Abgelesen
>    wird immer, der Vertrag wird jederzeit gewechselt, umgezogen wird das ganze
>    Jahr. Und die Jahresabrechnung kommt nicht im Frühjahr, sondern zum Ende
>    des eigenen Abrechnungsjahrs, und das beginnt, wann der Vertrag begann.
>    Die App selbst rechnet genau so, mit einem Stichtag je Zähler. Die These
>    widersprach dem eigenen Produkt.
> 2. **Der App Store stand vorn, das Netz dahinter.** Umgekehrt ist richtig:
>    Im Store sucht nur, wer schon weiß, dass er eine App will. Die meisten
>    Leute mit einer Zählerfrage wissen das nicht. Sie fragen Google, oder eine
>    KI, und bekommen eine Seite (Abschnitt 2).

> **Was gemessen ist und was nicht.** Gemessen am 24. und 25. September: die
> Produktseite im App Store, die ausgelieferte Website, die Suchfelder, die
> Konkurrenz im Store und in der Websuche. **Aus App Store Connect**, vom
> Gründer am 25. September als Bildschirmfoto geschickt: die Zahlen in
> Abschnitt 1. **Nicht gemessen:** Suchvolumen, Suchwörter, ob Google die
> Seite schon führt. Was nach Rangfolge klingt, ist eine begründete Schätzung.

---

## 0. Die Botschaft, in dieser Reihenfolge

Vom Gründer am 26. September: nicht nur Abschlag und Kosten, sondern
**Transparenz über den tatsächlichen Verbrauch**, weil „man unterschätzt, wie
viele nicht sagen können, was sie unterjährig verbrauchen". Und **stärker
herausstellen, dass wir keine Zählerstände tracken oder besitzen.**

| Rang | Aussage | Warum an dieser Stelle |
|---|---|---|
| 1 | **Du weißt jeden Monat, was du verbrauchst**, nicht erst mit der Jahresabrechnung | Das Problem, das fast jeder hat und kaum jemand benennt. Wer fragt „Was verbrauchen wir eigentlich?", bekommt sonst einmal im Jahr eine Antwort |
| 2 | **Deine Zählerstände haben wir nicht.** Kein Konto, kein Server, keine Kopie | Der Unterschied zur Konkurrenz, der sich prüfen lässt: „Keine Daten erfasst" im App Store gegen Standort, Geräte-ID und Nutzungsdaten beim größten Mitbewerber |
| 3 | **Die Nachzahlung siehst du vorher** | Der Nutzen, der Geld wert ist. Er folgt aus 1: Wer den Verbrauch kennt, kennt den Abschlag |

Die Reihenfolge gilt überall, wo jemand zum ersten Mal von Zählora liest: Kopf
der Startseite, Werbetext, erster Absatz der Store-Beschreibung, Vorschaubild
zum Teilen, Presseseite. `check-website.mjs` hält auf der Startseite fest, dass
zuerst der Verbrauch kommt und direkt danach, als einziger dunkler Abschnitt,
der Datenschutz.

**Was dabei nicht passiert:** Der Datenschutz wird nicht größer behauptet, als
er ist. „Wir sehen deine Zählerstände nie" stimmt, weil es keinen Server gibt,
die iCloud privat ist und `check-sicherheit.sh` jeden Netzverkehr verbietet.
„Unknackbar" oder „sicherste App" stimmt so nicht und steht nirgends.

### Die Rechner: auf einen Blick

Ebenfalls vom 26. September: „nicht zu viel Text", „auf einen Blick mit Daten
erkennbar", „klare Benennungen". Seitdem:

- **Der Rechner steht direkt unter der Überschrift**, davor ein Satz.
- **Das Ergebnis sind Kacheln**: oben der Name („Passender Abschlag", „Am Tag",
  „Im Jahr"), groß die Zahl, klein der Bezug („im Monat", „hochgerechnet").
  Gerechnetes trägt ein ≈, Gemessenes nicht.
- **Feldhinweise höchstens fünf Wörter**, neben den Kacheln höchstens
  fünfzehn. Beides zählt `check-website.mjs`.
- Formel, Beispiel und Erklärung stehen darunter, für den, der es wissen will.

---

## 1. Befund

### Was die Zahlen sagen

App Store Connect, Übersicht, Stand 23. September, also rund drei Wochen seit
dem Start am 4. September:

| Zahl | Wert | Anteil |
|---|---|---|
| Impressionen (Zählora stand in einer Liste oder wurde angezeigt) | **275** | |
| Produktseitenaufrufe | **52** | 19 % der Impressionen |
| Erstmalige Downloads | **10** | 19 % der Aufrufe |
| Konversionsrate laut Apple (Tagesdurchschnitt) | **6,1 %** | |
| Aktualisierungen | 6 | |
| Erlöse | 2 $ | ein bis zwei Käufe |

**Was das heißt:**

- **Wer die Seite sieht, lädt oft.** Jeder fünfte Aufruf wird ein Download,
  bei einer App ohne Sterne. An der Produktseite liegt es nicht.
- **Wer Zählora in einer Liste sieht, tippt oft.** Auch jeder fünfte. Symbol,
  Name und Untertitel tragen.
- **Es sehen sie nur fast keine Leute.** 275 Impressionen in drei Wochen sind
  rund 13 am Tag, im ganzen deutschen App Store. Das passt genau zum Loch im
  Schlagwortfeld: Wer „Zählerstand" sucht, bekommt uns nicht angezeigt.

> **Der Engpass ist die Reichweite, nicht die Überzeugung.** Das Schlagwortfeld
> mit 1.3 ist deshalb der wichtigste Einzelschritt im Store, und die Website
> der wichtigste außerhalb. An Bildern und Texten zu feilen lohnt erst, wenn
> mehr Leute kommen.

Die Zahlen sind klein und schwanken mit jedem einzelnen Download. Als Anteil
gelesen sind sie Richtwerte, keine Messung auf das Prozent.

### Im App Store

| Befund | Stand |
|---|---|
| **`zählerstand` stand in keinem durchsuchten Feld.** Seit der Umbenennung heißt die App „Zähler & Verbrauch"; die Schlagwortliste war gegen den alten Namen „Zählerstände" geschrieben. Apple zerlegt deutsche Zusammensetzungen nicht. Dasselbe für `stromzähler` | **behoben in 0.116.4**, wirksam mit 1.3 |
| **Eine einzige Bewertung.** Unter zehn zeigt die Suchliste keinen Stern; daneben steht „Zählerstände \| Ablesen, sparen" mit 4,5 aus 41. Die Bewertungsfrage stand seit August als Punkt 1 im Konzept und wurde nie gebaut | im Plan für 1.3 |
| **Der Werbetext ist vom Start** („Neu: Du kaufst nur, was dir fehlt") | Vorschlag in 4.3 |
| **„Keine Daten erfasst"** steht auf unserer Seite. Beim größten Mitbewerber: Standort, Geräte-ID, Nutzungs- und Absturzdaten, dazu ein Abo nur für Werbefreiheit | ein Vorteil, den vor dem Tipp niemand sieht |

### Auf der Website

| Befund | Stand |
|---|---|
| Canonical und Sitemap der ausgelieferten Seite zeigen auf die Adressen ohne `.html`. Geprüft; umgeschrieben wird beim Ausliefern (`scripts/website-fertig.sh`) | in Ordnung |
| **App-Store-Banner fehlte** | **behoben in 0.116.4** |
| **Zwei Antwortseiten** (`gas-in-kwh`, `abschlag-zu-hoch`), richtig gebaut und viel zu wenige | Abschnitt 3 |
| **Adresse `zaehlora.pages.dev`**: geteilte Domain, einzelne Unterseiten sperrt Malwarebytes wegen Phishing. `zaehlora.de` hat keinen DNS-Eintrag, ist also **vermutlich** frei | Entscheidung beim Gründer, 3.6 |
| **Ob Google die Seite führt, ist unbekannt.** Ohne Search Console gibt es keine Zahl | 3.7 |

### Wer bei Google die Antworten gibt

Nachgesehen für die Fragen, die zu Zählora führen könnten:

| Frage | Wer vorn steht | Was das heißt |
|---|---|---|
| „Stromzähler ablesen", „Zählerstand melden Anbieterwechsel" | Versorger (Yello, RheinEnergie), Finanztip, Vergleichsportale | **Nicht zu gewinnen.** Große Seiten mit alter Verlinkung, und die Antwort ist kurz |
| „Gas m³ in kWh umrechnen" | GASAG, Vattenfall und ein halbes Dutzend Rechnerseiten | schwer. Unsere Seite muss **besser rechnen** als die anderen, nicht nur gleich gut erklären |
| „Übergabeprotokoll Zählerstände Vorlage" | PDF-Formulare einzelner Stadtwerke, Vorlagenseiten | **offen.** Lauter Formulare zum Ausdrucken von Versorgern, die für ihre eigenen Kunden gemacht sind |
| „Nebenkostenabrechnung zu hoch" | Mineko, Finanztip, Verbraucherzentrale, Rechtsschutz | schwer im Allgemeinen, offen im Besonderen (Strom und Gas nachrechnen, nicht Hausmeister und Aufzug) |

**Gewinnen lassen sich die genauen Fälle**, an denen die großen Seiten dünn
werden: Zweirichtungszähler ablesen, Zähler mit Hoch- und Niedertarif,
Zustandszahl auf der Rechnung finden, Zählerwechsel, der Verbrauch einer
Wärmepumpe im eigenen Haus. Genau die Fälle, die Zählora besser kann als die
anderen Apps (Website, „Besondere Fälle").

---

## 2. Die Perspektive: Wer bei Google sucht, sucht keine App

Wer „Zählerstand beim Auszug" eintippt, will wissen, was er aufschreiben muss,
wem er es schickt und was passiert, wenn er es vergisst. Er sucht keine App,
und eine Seite, die mit einer App anfängt, schließt er.

> **Die Website ist die beste Antwort auf eine Lage, in der jemand gerade
> steckt. Die App steht am Ende als das Werkzeug, mit dem es beim nächsten Mal
> von selbst geht.**

### Anlässe statt Saison

Gesucht wird, wenn etwas passiert, und das passiert das ganze Jahr:

| Anlass | Was jemand in dem Moment wissen will |
|---|---|
| **Umzug**, Ein- und Auszug | Was schreibe ich auf, wem melde ich es, wie beweise ich es |
| **Anbieterwechsel** | An welchem Tag ablese ich, wer bekommt den Stand |
| **Brief mit Preiserhöhung** oder neuem Abschlag | Stimmt der neue Abschlag für meinen Verbrauch |
| **Jahresabrechnung**, zum Ende des eigenen Abrechnungsjahrs | Stimmt die Zahl, war das mehr als letztes Jahr |
| **Neuer Zähler** oder Smart Meter | Was muss ich vom alten aufschreiben |
| **Neue Anlage**: PV, Wärmepumpe, Wallbox | Was verbraucht, was bringt sie wirklich |
| **Die Frage zwischendurch** | Ist mein Verbrauch normal |

Einen Kalender gibt es trotzdem, nur schwächer: Um den Jahreswechsel lesen
mehr Leute ab, und im Winter steigt der Gasverbrauch. Das sind Spitzen auf
einer Grundlast, keine Saison.

### Drei Arten von Seiten

1. **Anlassseiten**: eine Lage, eine Antwort, eine Rechnung, am Ende die App.
   So sind die zwei bestehenden gebaut.
2. **Rechner, die im Browser rechnen**: Gas von Kubikmetern in kWh mit den
   eigenen Werten, Abschlag prüfen, ist mein Verbrauch normal. Sie helfen
   ohne App, sie werden verlinkt, und wer sie zweimal benutzt hat, versteht,
   wozu die App gut ist. **Mit derselben Rechnung wie die App**, wie der
   Klick-Dummy (Regel 2 gilt sinngemäß). Ohne fremde Skripte und ohne
   Speicherung; `check-website.mjs` prüft beides schon.
3. **Vorlagen**: ein Übergabeprotokoll für Zählerstände zum Ausdrucken, für
   jeden Versorger, sauber gesetzt. Genau das fehlt in den Ergebnissen, und
   wer es ausdruckt, hat die Seite in der Hand.

### Und die KI-Antworten

„Google und Co." heißt inzwischen auch: die Zusammenfassung über den
Ergebnissen, ChatGPT, Perplexity. Sie zitieren Seiten, die eine Frage genau,
mit Zahlen und mit Quelle beantworten. **Dafür gibt es keinen zweiten Satz
Regeln.** Dieselben Seiten tragen beides, solange sie:

- die Frage im ersten Absatz beantworten und danach erst ausholen,
- Richtwerte mit Quelle nennen (Verbraucherzentrale, Stromspiegel) statt mit
  eigenem Gefühl,
- eine Rechnung zeigen, die jemand nachrechnen kann.

---

## 3. Hebel 1 — die Website

### 3.1 Die nächsten Seiten

Geordnet nach Wirkung je Aufwand; die Suchmenge ist geschätzt, nicht gemessen.

| Seite | Art | Warum sie zuerst dran ist |
|---|---|---|
| `verbrauch-berechnen`: **„Was verbrauche ich eigentlich?"** | Rechner | **erledigt 0.117.1.** Botschaft 1 als Werkzeug: zwei Stände mit Datum, heraus kommt Tag, Monat, Jahr |
| `zaehlerstand-umzug` mit **Übergabeprotokoll zum Ausdrucken** | Anlass + Vorlage | ganzjährig, dünn besetzt, ein Ding zum Mitnehmen |
| `gas-in-kwh` **als Rechner** ausbauen | Rechner | die Seite gibt es schon; mit einem Rechner, der Zustandszahl und Brennwert von der eigenen Rechnung nimmt, wird sie besser als die meisten davor |
| `abschlag-zu-hoch` **als Rechner** ausbauen | Rechner | dasselbe; das ist die Frage nach jedem Brief mit neuem Abschlag |
| `stromverbrauch-normal` | Rechner + Richtwerte | „ist das viel?" ist die häufigste Frage zwischendurch; Richtwerte nach Haushaltsgröße mit Quelle |
| `zaehlerstand-anbieterwechsel` | Anlass | kurz, mit dem, was die großen Seiten weglassen: was man tut, wenn der Altanbieter einen anderen Stand abrechnet |
| `zweirichtungszaehler-ablesen` | genauer Fall | PV-Besitzer, wenig Konkurrenz, genau unser Fall |
| `zaehlerwechsel` | Anlass | Verlauf reißt nicht ab |
| `waermepumpe-stromverbrauch` | genauer Fall | Hoch- und Niedertarif, Hochrechnung, die den Winter kennt |

**Eine Seite je Woche**, nicht zwanzig auf einmal. Google braucht Wochen, bis
eine neue Seite auftaucht; was jetzt steht, wirkt ab dem Winter und dann
dauerhaft.

**Was nicht passiert:** dünne Seiten für jedes Suchwort, Texte von der Stange,
Vergleiche mit fremden Marken.

### 3.2 Die Produktseite im App Store ist selbst ein Google-Treffer

Der App Store durchsucht die Beschreibung nicht, **Google schon**:
`apps.apple.com` steht bei „Zählerstand App iPhone" auf der ersten Seite, mit
den Seiten der Mitbewerber. Dort zeigt Google Titel, Untertitel und den Anfang
der Beschreibung.

Unsere Beschreibung beginnt mit „Du trägst eine Zahl ein. Zählora sagt dir, ob
alles im Rahmen ist." Das ist ein guter Satz für jemanden, der schon da ist,
und für Google ein Satz ohne ein Wort, nach dem jemand sucht. **Vorschlag für
1.3:** Der erste Satz nennt, was es ist, der zweite, was es tut:

```
Deine Zählerstände für Strom, Gas und Wasser an einem Ort. Du trägst eine
Zahl ein, Zählora sagt dir, ob alles im Rahmen ist.
```

Entscheidung beim Gründer, weil sich damit der Anfang eines Textes ändert, den
er abgenommen hat.

### 3.3 Verlinkung

Eine neue Seite findet Google über Verweise. Die kostenlosen und ehrlichen:

- **Von der eigenen Startseite und untereinander.** Jede Anlassseite verweist
  auf den passenden Rechner und umgekehrt.
- **Aus Antworten in Foren**, wenn die Seite die Antwort ist (Abschnitt 5).
- **Die Vorlage selbst.** Wer ein gutes Übergabeprotokoll findet, verlinkt es
  in Umzugslisten und Mietergruppen.

Nicht: gekaufte Verweise, Verzeichnisse, Tausch.

### 3.4 Technik: gemessen an der ausgelieferten Seite

**Hier stand „Technik, die schon stimmt" und „mehr Technik bringt hier
nichts". Das war zu früh gesagt.** Am 25. September an der echten Seite
nachgemessen, nicht am Quelltext:

| Befund | Folge bei Google | Seit 0.117.0 |
|---|---|---|
| **Jede unbekannte Adresse lieferte die Startseite mit Status 200** (Cloudflare fällt ohne `404.html` auf die Startseite zurück) | beliebig viele Kopien der Startseite, „Soft 404" | eigene Seite `404.html` mit `noindex`, antwortet mit 404 |
| **`/favicon.ico` lieferte ebenfalls die Startseite**, das Symbol stand nur eingebettet in der Seite | kein Symbol neben dem Treffer; Google holt es nur als Datei | `favicon.ico` (48 × 48), `favicon.svg`, `apple-touch-icon.png`, `icon-512.png` |
| Vorschaubild war ein hochkantes Telefonbild | beschnitten in Messengern und Netzwerken | `bilder/teilen.jpg`, 1200 × 630, mit Maßen und Beschreibung |
| Bilder mit `max-age=0` | jeder Aufruf lädt rund 600 KB neu; Ladezeit zählt | eine Woche Zwischenspeicher; Bilder unterhalb des ersten Bildschirms laden erst beim Scrollen |
| Verweise mit Sprungmarke (`index.html#preise`) blieben beim Ausliefern relativ | auf der 404-Seite unter `/ratgeber/xyz` tote Verweise | werden mit umgeschrieben |
| Startseite beschrieb nur die App | kein Bezug zwischen Website, Herausgeber und App | `WebSite`, `Organization`, `SoftwareApplication` mit Verweis auf den App Store |
| Titel der Startseite ohne das Wort, nach dem gesucht wird | | „Zählora: die Zählerstand-App für Strom, Gas und Wasser" |

**Bewusst nicht:** keine Sternebewertung im Markup. Google zeigt Sterne für
Apps nur mit Bewertungen, und es gibt eine. Erfundene wären ein Grund, die
Seite abzustrafen. Kein `HowTo`-Markup für die Rechner: Google zeigt es seit
2023 nicht mehr an.

Alles davon prüft `check-website.mjs` bei jedem Lauf, und `website.yml` misst
nach jedem Veröffentlichen an der echten Seite, ob eine unbekannte Adresse
404 antwortet, das Symbol ein Bild ist und die Bilder zwischengespeichert
werden.

### 3.4a IndexNow: melden statt warten

Nach jedem Veröffentlichen meldet `scripts/indexnow.sh` alle Adressen der
Sitemap an IndexNow. Das nehmen Bing, Yandex, Seznam und Naver an; über Bing
kommen DuckDuckGo, Ecosia und die Websuche von ChatGPT mit. **Google nimmt
IndexNow nicht an.** Der Schlüssel liegt öffentlich als Datei auf der Seite,
so ist das Verfahren gedacht.

### 3.5 Keine Besucherzählung

Auch keine „datenschutzfreundliche". Eine Seite, die mit „wir sehen nichts"
wirbt, zählt ihre Besucher nicht. Gemessen wird über Search Console, die nur
sieht, was Google ohnehin sieht, und nichts auf die Seite setzt.

### 3.6 Eine eigene Adresse

`zaehlora.de` statt `zaehlora.pages.dev`. Alles, was Google über die Seite
lernt, hängt an der Adresse. **Vor den neuen Seiten ist der billigste
Zeitpunkt**, danach nimmt jeder Umzug etwas mit. Dazu das Vertrauen: Eine
Adresse unter `pages.dev` sieht in einer Mail an eine Redaktion aus wie ein
Versuch.

Rund 5 bis 15 € im Jahr. Die Seite bleibt bei Cloudflare. Die Adresse steht an
drei Orten, `check-strings.py` hält sie zusammen. Die Eintragung beim
Registrar kann nur der Gründer machen. **Entscheidung beim Gründer.**

### 3.7 Search Console: der offizielle Weg in Googles Verzeichnis

Google führt eine Seite auch ohne Anmeldung, wenn es sie findet. Mit der
Search Console sagt man ihm, dass es sie gibt, reicht die Sitemap ein, sieht,
welche Seiten im Index sind und für welche Suchen sie erscheinen. **Das
Anmelden geht nur mit dem Google-Konto des Gründers.**

1. https://search.google.com/search-console öffnen, „Property hinzufügen",
   **„URL-Präfix"** wählen und `https://zaehlora.pages.dev/` eintragen.
   (Die Variante „Domain" braucht einen DNS-Eintrag, und `pages.dev` gehört
   Cloudflare. Mit einer eigenen Adresse ginge es später auch so.)
2. Als Bestätigung **„HTML-Tag"** wählen. Google zeigt eine Zeile
   `<meta name="google-site-verification" content="…">`. Der Wert nach
   `content=` kommt auf die Startseite. Er ist nicht geheim, er steht danach
   für jeden lesbar im Quelltext.
3. Nach dem Veröffentlichen „Bestätigen" drücken.
4. Unter „Sitemaps" `sitemap.xml` einreichen.
5. Unter „URL-Prüfung" die Startseite und `/ratgeber` eintragen und
   „Indexierung beantragen".

Danach **Bing Webmaster Tools** (https://www.bing.com/webmasters): Dort gibt
es „Aus Google Search Console importieren", ein Klick.

Stand: offen, beim Gründer. Sobald der Wert aus Schritt 2 da ist, steht er
eine Minute später auf der Seite.

---

## 4. Hebel 2 — der App Store

Kurz, weil er an zweiter Stelle steht: **Apple durchsucht die Beschreibung
nicht**, sondern Name, Untertitel, Schlagwortfeld und die Anzeigenamen der
fünf Käufe. In der Liste sieht man Symbol, Name, Untertitel, Sterne und die
ersten Bilder.

### 4.1 Die Wörter — erledigt in 0.116.4

```
zählerstand,stromzähler,gaszähler,wasserzähler,nebenkosten,abrechnung,abschlag,photovoltaik
```

Begründung und Zählung in `09-appstore.md`, wirksam mit 1.3. Ändert sich Name
oder Untertitel, wird diese Liste im selben Zug neu geprüft.

### 4.2 Bewertungen

Gefragt wird **nach der dritten gespeicherten Ablesung**, höchstens einmal je
Fassung, über `requestReview`. Nie beim Start, nie nach dem Kauf, nie gegen
eine Freischaltung, nie mit einer Vorfrage, die Unzufriedene umleitet. Eine
Änderung von einem Nachmittag, im Plan für 1.3. Die Sterne zeigen sich auch
bei Google neben der Produktseite.

### 4.3 Der Werbetext — sofort änderbar

Seit 26. September eingetragen, 131 Zeichen:

```
Du siehst jeden Monat, was du an Strom, Gas und Wasser verbrauchst. Deine
Zählerstände bleiben auf deinem Gerät, wir sehen sie nie.
```

Botschaft 1 und 2 aus Abschnitt 0. Die Fassung vom 25. September sprach vom
Abschlag, die davor „schon im Oktober" und hing an der falschen Saison-These.

### 4.4 Die Bilder

Mit 1.3 neu: zuerst die Übersicht mit der Abschlagsvorschau, dann der
Ziffernblock, dann der Bericht; im iPad-Satz das Querformat mit zwei Spalten
vorn. Den Produktseiten-Test erst, wenn es genug Aufrufe gibt. Bei 50 im Monat
misst er nur Zufall.

### 4.5 Ereignisse und eigene Produktseiten

**In-App-Ereignisse** (Karte in Suche und Produktseite, kostenlos) nur für
Dinge, die in der App tatsächlich passieren. Ein Kandidat: „Zum Jahreswechsel
ablesen", Ende Dezember. Nicht mehr als das.

**Eigene Produktseiten** mit eigenen Bildern für Photovoltaik und Wärmepumpe,
verlinkt aus den passenden Seiten der Website. Erst, wenn die Seiten stehen.

---

## 5. Hebel 3 — Presse und Foren

### 5.1 Redaktionen

Fünf gezielte Mails an deutschsprachige Apple-Seiten, nicht fünfzig. Der
Aufhänger ist nicht „noch eine App für Zählerstände", sondern: **„Die App, die
dir Monate vorher sagt, ob eine Nachzahlung kommt."** Dazu kein Konto, kein
Abo, keine Daten, Export dauerhaft frei.

Der Zeitpunkt hängt nicht an einer Jahreszeit, sondern daran, dass es etwas zu
zeigen gibt und die Produktseite nicht leer aussieht: **nach 1.4**, mit
Bewertungsfrage, neuen Bildern, einer Presseseite und den ersten Rechnern auf
der Website. Eine Redaktion verlinkt lieber auf einen Rechner als auf eine
Produktseite.

### 5.2 Foren

Photovoltaikforum, Haustechnikdialog, Mieter- und Umzugsgruppen. **Antworten,
nicht werben.** Wer fragt, bekommt die Rechnung und den Link auf die Seite, die
sie erklärt; die App nur, wenn sie zur Antwort gehört. Das macht der Gründer
selbst. Ein Forenbeitrag von einer Maschine ist genau das, was dort niemand
will.

---

## 6. Hebel 4 — Empfehlung aus der App

Der Verbrauchsbericht geht an Vermieter, Partner, Versorger. **Vorschlag:** in
der Fußzeile klein „Erstellt mit Zählora", ohne Link. Im ungekauften Bericht
steht ohnehin der Schriftzug darüber; offen ist nur der gekaufte.
**Entscheidung beim Gründer.**

---

## 7. Woran wir merken, ob es wirkt

| Quelle | Was sie sagt | Zugang |
|---|---|---|
| Search Console | Welche Seiten Google zeigt, für welche Fragen, wie oft geklickt | fehlt, 3.7 |
| App Store Connect | Impressionen, Aufrufe, Laden, je Quelle: Suche im Store, Verweis von einer Website | **fehlt.** Rolle für Nutzungsberichte am Schlüssel, beim Gründer offen |
| Bewertungen | Anzahl und Schnitt | öffentlich, heute 1 |

**Die Kette, und wo sie heute reißt:**

    Suche im Store → Impression → Produktseite → Download
         ?              275           52           10

    Frage bei Google → Seite von uns → Produktseite → Download
         ?                 ?               ?             ?

Die Fragezeichen sind die Arbeit. Für die obere Kette fehlt, **welche Wörter**
die 275 Impressionen gebracht haben; das zeigt App Store Connect unter
„Quellen" nur mit der Rolle für Nutzungsberichte. Für die untere fehlt alles,
bis Search Console läuft. **Das Ziel für Ende November:**
Search Console zeigt, dass die neuen Seiten für ihre Fragen auftauchen, und
App Store Connect zeigt Verweise von der Website als eigene Quelle. Erst dann
lohnt es, an Bildern und Wörtern zu drehen.

---

## 8. Was nicht gemacht wird

**Bezahlte Werbung, auch nicht Apple Search Ads.** Ein Nutzer kostet in dieser
Kategorie erfahrungsgemäß mehrere Euro, das teuerste Stück Zählora 4,99 €, und
nur ein Teil kauft. Neu zu prüfen, wenn Abschnitt 7 zeigt, wie viele Besucher
kaufen.

Außerdem nicht: gekaufte Bewertungen oder Verweise, fremde Marken im
Schlagwortfeld, Wörter für Dinge, die es noch nicht gibt (`siri` erst mit 1.3),
eine Besucherzählung auf der Website.

---

## 9. Reihenfolge

| Wann | Was | Wer |
|---|---|---|
| **erledigt, 0.116.4** | `zählerstand` und `stromzähler` ins Schlagwortfeld; App-Store-Banner | — |
| **jetzt** | eigene Adresse entscheiden und eintragen; Search Console; Rolle für Nutzungsberichte | Gründer |
| **erledigt, 0.116.7** | Werbetext aus 4.3 (freigegeben am 25.09., im Laden eingetragen); erster Satz der Beschreibung (kommt mit 1.3); Seite „Zählerstände beim Umzug" mit Protokoll zum Ausdrucken; Rechner auf der Gas- und der Abschlagsseite; Übersichtsseite „Ratgeber"; strukturierte Daten (Artikel, Brotkrumen) auf allen Ratgeberseiten | — |
| **ab nächster Woche, eine je Woche** | die übrigen Seiten aus 3.1: Stromverbrauch normal, Anbieterwechsel, Zweirichtungszähler, Zählerwechsel, Wärmepumpe | ich |
| **mit 1.3, 07.10.** | Bewertungsfrage, neue Bilder, neues Schlagwortfeld, neuer Beschreibungsanfang | ich |
| **nach 1.4** | Presseseite, fünf Mails | ich schreibe vor, Gründer schickt |
| **laufend** | Antworten in Foren | Gründer |
| **Ende November** | erster Messpunkt aus Abschnitt 7 | ich |
