# 09 – Material für den App Store

Stand: 2026-08-30, Version 0.105.2

Alles, was App Store Connect zur Einreichung verlangt, fertig zum Einfügen.
Was hier steht, ist geprüft gegen das, was die App **heute** kann — nicht
gegen die Roadmap.

> ⚠️ **Die eine Regel, an der Einreichungen scheitern:** Nichts bewerben, was
> es nicht gibt. **Foto-Belege** und **Siri-Kurzbefehle** sind aus 1.0
> gestrichen (`07-v1-plan.md`) und stehen deshalb in keinem Text hier. Wer sie
> später doch einträgt, kassiert eine Rückerstattung, eine schlechte Bewertung
> und im Zweifel eine Ablehnung.

---

## 1. Die Textfelder

### Name (max. 30 Zeichen)

```
Zählora – Zähler & Verbrauch
```

28 Zeichen von 30. Vom Gründer am 28. August gewählt. Der Zusatz trägt die
beiden Wörter, nach denen jemand sucht: „Zählora" allein sucht niemand, weil es
das Wort vorher nicht gab. Geprüft am selben Tag über die Suche des App Store —
in Deutschland gibt es keine App dieses Namens.

### Untertitel (max. 30 Zeichen)

```
Strom, Gas und Wasser ablesen
```

29 Zeichen. **Geändert mit dem Namen:** Vorher stand hier „Zähler ablesen,
Kosten sehen", und beide Wörter stehen seit der Umbenennung schon im Namen.
Apple wertet jedes Feld einmal; dasselbe Wort zweimal ist ein verschenktes Feld.
Die drei Energiearten sind das, was jemand tatsächlich eintippt.

### Werbetext (max. 170 Zeichen, jederzeit ohne neue Version änderbar)

```
Neu: Du kaufst nur, was dir fehlt. Ein paar Euro, kein Abo. Den
Verbrauchsbericht kannst du immer ansehen und drucken — freischalten musst du
ihn erst zum Weitergeben.
```

Dieses Feld ist der einzige Text, der sich **ohne** neue Version ändern lässt.
Es gehört deshalb dem jeweils Neuesten, nicht der Dauerbeschreibung.

### Schlagworte (max. 100 Zeichen, komma-getrennt, ohne Leerzeichen)

```
nebenkosten,abrechnung,abschlag,heizkosten,gaszähler,wasserzähler,photovoltaik,einspeisung,wallbox
```

98 Zeichen. Regeln, gegen die das geprüft ist: keine Wörter aus Name und
Untertitel wiederholen (Apple wertet sie ohnehin), keine Mehrzahl **und**
Einzahl desselben Worts, keine Wortpaare — die bildet Apple selbst —, keine
fremden Markennamen. Der letzte Punkt ist ein Ablehnungsgrund und kein
Kavaliersdelikt.

**Bis 0.43.1 stand hier eine andere Liste**, die mit `zählerstand`,
`stromzähler`, `ablesen` und `verbrauch` begann. Alle vier stehen bereits in
Name und Untertitel und waren damit doppelt — ein Viertel des Feldes für
nichts. An ihrer Stelle steht jetzt, worauf `10-sichtbarkeit.md` setzt: die
Wörter, die jemand tippt, der gerade eine Abrechnung in der Hand hält, und die
Fälle, die andere Apps nicht abdecken. Nachprüfbar wird die Wette vier Wochen
nach der Veröffentlichung.

`nachtstrom` stand in der ersten Fassung dieser Liste und ist wieder heraus:
Die Liste kam damit auf **101** Zeichen, also eine zu viel — App Store Connect
hätte sie beim Einfügen abgeschnitten, und zwar stillschweigend am Ende. Das
Wort ist ohnehin abgedeckt, weil der Anzeigename des Kaufs
„Nachtstrom & Einspeisung erfassen" ebenfalls durchsucht wird
(`10-sichtbarkeit.md`, Abschnitt 4). An seiner Stelle steht `wallbox` — ein
Fall, den kaum eine andere Zähler-App kennt.

### Beschreibung (max. 4000 Zeichen)

```
Du trägst eine Zahl ein. Zählora sagt dir, ob alles im Rahmen ist.

Zählerstände landen auf einem Zettel am Sicherungskasten, in einer Tabelle, die
niemand pflegt, oder nirgends. Und im Frühjahr kommt die Abrechnung, und man
glaubt ihr einfach. Zählora macht aus zehn Sekunden am Zähler eine Zahl, mit
der sich etwas anfangen lässt.


ZEHN SEKUNDEN AM ZÄHLER

App öffnen, Zahl eintippen, sichern. Das Datum steht schon auf heute, der
Ziffernblock ist groß genug, dass man ihn einhändig trifft. Auch im
Halbdunkel und mit klammen Fingern.

Und bevor der Wert in deinen Daten landet, sieht die App ihn sich an. Eine Zahl
unter dem letzten Stand, eine Zahl weit über dem, was bei dir üblich ist — dann
fragt sie nach. Am Zähler kannst du noch einmal hinsehen, im Februar vor dem
Diagramm nicht mehr.


FÜNF SEKUNDEN, UND DU WEISST, WO DU STEHST

Ganz oben steht, was zählt: Verbrauch seit Jahresbeginn, daneben das Vorjahr,
darunter die Kosten. Kein Scrollen, kein Menü.

Jede Zahl sagt dazu, welchen Zeitraum sie meint. Ein Jahreswert, der im Mai
endet, gibt sich nicht als Jahreswert aus. Was geschätzt ist, steht als
geschätzt da. Diese App rechnet nie still.


VERLAUF, DER ETWAS ZEIGT

Monat, Quartal oder Jahr, als Diagramm oder als Tabelle, immer neben demselben
Zeitraum des Vorjahres. Mai gegen Mai — und wenn der Mai noch läuft, gegen
denselben Ausschnitt. Klingt selbstverständlich. Ist es nicht.

Trag den Stichtag deines Versorgers ein, und Bericht und Vorschau rechnen nach
deinem Abrechnungsjahr. Bei Gas fängt das oft im Oktober an.

Tipp einen Monat an, und du siehst, woher der Unterschied kommt.


DIE NACHZAHLUNG SIEHST DU IM OKTOBER

Zwei Zahlen von deiner Rechnung genügen: Arbeitspreis und Grundpreis. Ab da
rechnet Zählora mit. Kommt dein Abschlag hin, oder legst du im Frühjahr
nach? Die Antwort steht auf der Übersicht, das ganze Jahr über.

Bei Gas mit Zustandszahl und Brennwert. Wer Kubikmeter einfach mal zehn nimmt,
liegt daneben.


AUCH DIE FÄLLE, DIE ANDERE APPS NICHT KENNEN

• Photovoltaik: ein Zähler, zwei Richtungen — Bezug und Einspeisung, mit
  Vergütung
• Tag- und Nachtstrom: zwei Preise an einem Gerät, für Nachtspeicher,
  Wärmepumpe oder die Wallbox in der Garage
• Zählerwechsel: alter Endstand rein, neuer Anfangsstand rein — der Verlauf
  reißt nicht ab
• Gas, Wasser, Warmwasser, Fernwärme, Heizöl, Regenwasser, Betriebsstunden


DAMIT DU NICHT DARAN DENKEN MUSST

Wöchentlich, monatlich, vierteljährlich oder jährlich, je Zähler: Die App
meldet sich abends, wenn eine Ablesung fällig ist. Und ein Feld auf dem
Sperrbildschirm zeigt es auch ohne Mitteilung.


WIR WISSEN NICHT, WIE VIEL STROM DU VERBRAUCHST

Und das soll so bleiben. Kein Konto, keine Anmeldung, keine Werbung, kein
Tracking, keine Absturzberichte. Deine Ablesungen liegen auf deinem Telefon
und, wenn du magst, in deiner eigenen iCloud. Auf unseren Servern liegen sie
nicht — wir haben keine. Deshalb steht über dieser App im Store „Keine Daten
erfasst", und nicht die lange Liste, die du sonst kennst.

Du entfernst die App, und die Daten auf dem Gerät sind weg. Nutzt du iCloud,
löschst du die Kopie dort in den Einstellungen mit. Bei uns gibt es keine.

Und du kommst jederzeit wieder heraus. Der Export als Tabelle ist kostenlos und
bleibt es, auch wenn du nie einen Cent ausgibst.


EIN PAAR EURO, EINMAL. KEIN ABO.

Kostenlos bleiben: zwei Zähler, so viele Ablesungen du willst, der ganze
Verlauf, der Vorjahresvergleich und der Export.

Wenn dir später etwas fehlt, kaufst du genau das frei — und nicht ein Paket, in
dem drei Dinge stecken, die du nie brauchst. Unbegrenzt viele Zähler. Zähler
mit zwei Zahlen. Kosten und Preise. Den Verbrauchsbericht ohne Schriftzug. Je
1,99 €. Die Erinnerung, wenn ein Zähler dran ist, kostet 0,99 €. Alle fünf
zusammen 4,99 €. Einmal bezahlt, auf allen deinen Geräten, und es bleibt.

Den Bericht kannst du dir immer ansehen und ausdrucken. Freischalten musst du
ihn erst, wenn du ihn jemandem geben willst.
```

Aufbau mit Absicht: Die ersten zwei Zeilen stehen in der Vorschau, bevor jemand
„mehr" tippt — sie müssen allein tragen. Der Preis steht ganz unten, weil bis
dorthin nur liest, wer die App ohnehin will.

**Die Zeichenzahl steht hier nicht mehr.** Sie stand als „3844 Zeichen" da, von
Hand gepflegt, und war beim nächsten Satz falsch. Beim Nachschärfen am
29. August lag die Beschreibung bei **4152** — Apple hätte sie abgelehnt, und
zwar erst am Ende einer Einreichung. Seit 0.104.2 zählt `check-strings.py` mit:
Es liest die Grenze aus der Überschrift („max. 4000 Zeichen") und misst den
Block darunter. Jedes Feld hier trägt seine Grenze im Namen; keins muss von
Hand nachgezählt werden.

**Zum Ton dieser Texte.** Seit 0.44.0 stehen sie im selben Register wie die
Website: konkrete Lage statt Merkmalsliste, kurze Sätze neben langen, ein
Standpunkt. Die Regel steht in `CLAUDE.md`, Abschnitt „Tonfall". Sie gilt für
alles, was ein Käufer liest — **nicht** für die Hinweise an die Prüfung weiter
unten. Ein Prüfer will wissen, wo er tippen muss, und sonst nichts.

Name, Untertitel und Schlagwortfeld sind davon ausgenommen: Sie werden
durchsucht, nicht gelesen (`10-sichtbarkeit.md`). Ein hübscherer Untertitel,
der `Zähler` und `Kosten` verliert, kostet mehr, als er einbringt.

### Neue Funktionen (Versionshinweise)

Für 1.0:

```
Die erste Fassung. Zählerstände eintragen, Verbrauch und Kosten sehen, den
Verlauf vergleichen, alles als Tabelle mitnehmen.

Wenn etwas fehlt oder stört, schreib mir. Hinter dem Support-Link sitzt kein
Ticketsystem, sondern der Entwickler.
```

Ab 1.1 gilt: Der Text kommt aus `CHANGELOG.md`, in der Sprache des Nutzers und
ohne Versionsnummern von Bibliotheken. „Fehlerbehebungen und Verbesserungen"
ist keine Versionsinformation, sondern deren Verweigerung.

---

## 2. Einordnung

| Feld | Wert | Warum |
|---|---|---|
| Primäre Kategorie | **Dienstprogramme** | Dort sucht, wer ein Werkzeug will |
| Sekundäre Kategorie | **Finanzen** | Kosten und Abschlagsvergleich; bringt eine zweite Bestenliste |
| Altersfreigabe | **4+** | Keine Inhalte, die etwas anderes rechtfertigten |
| Preis | **Kostenlos** mit In-App-Käufen | Der Einstieg darf nichts kosten, sonst gibt es keinen |
| In-App-Käufe | Sechs nicht verbrauchbare Produkte: vier zu 1,99 €, Erinnerungen 0,99 €, Bündel 4,99 € | Begründung in `04-monetarisierung.md` |
| Länder | Zunächst **Deutschland, Österreich, Schweiz** | Die App ist deutsch, die Rechnungslogik auch |

---

## 3. Datenschutz — die Angaben im Fragebogen

App Store Connect fragt Punkt für Punkt. Die Antwort ist überall dieselbe, und
das ist keine Bequemlichkeit, sondern die Architektur (ADR-002).

| Frage | Antwort |
|---|---|
| Werden Daten erfasst? | **Nein** |
| Tracking über Apps und Websites hinweg? | **Nein** |
| Analyse- oder Werbe-SDKs? | **Keine** |
| Konto erforderlich? | **Nein** |
| Daten an Dritte? | **Nein** |

Das ergibt im Store die Kennzeichnung **„Keine Daten erfasst"** — das
stärkste Merkmal, das eine App dieser Kategorie haben kann, und ein Grund, es
in der Beschreibung zu nennen.

**Wichtig zur iCloud-Synchronisation:** Sie zählt nicht als Erfassung. Die
Daten liegen in der **privaten** iCloud-Datenbank des Nutzers, auf die der
Entwickler keinen Zugriff hat. Genau das ist der Grund für CloudKit statt
eines eigenen Servers. Wer hier „Ja" ankreuzt, weil irgendwo „Cloud" steht,
verschenkt die Kennzeichnung.

### Datenschutzerklärung

Pflichtfeld, muss eine **erreichbare URL** sein. Der Text steht fertig in
[`datenschutz.md`](datenschutz.md).

Wo er liegen kann, wenn es keine eigene Domäne gibt:
- ein GitHub-Gist oder ein öffentliches Repository mit GitHub Pages (dieses
  hier ist privat, Pages bräuchte dafür GitHub Pro),
- eine kostenlose Seite bei Netlify oder Cloudflare Pages,
- eine Unterseite einer bestehenden Website.

Was **nicht** geht: eine PDF-Datei in einer Cloud-Freigabe. Apple prüft die
URL, und ein Anmeldedialog davor ist ein Ablehnungsgrund.

### Support-URL

Ebenfalls Pflicht. Eine Seite mit einer erreichbaren Kontaktmöglichkeit
genügt; eine reine `mailto:`-Adresse akzeptiert Apple nicht als URL.

---

## 4. Bilder

### App-Icon

Erzeugt aus `scripts/icon.mjs`, liegt in `Assets.xcassets/AppIcon.appiconset`.
Drei Fassungen, wie iOS 18 sie verlangt: hell, dunkel, getönt.

Die Zeichnung ist der Name: ein **Bogen** — die Skala eines Messwerks — und
ein **Puls**, die Linie darin. Bernstein auf warmem Dunkel, weil die Kategorie
blau und grün ist und ein warmer Ton in der Ergebnisliste auffällt.

Ändern heißt: `scripts/icon.mjs` bearbeiten und neu laufen lassen. Nie eine
der PNG-Dateien von Hand austauschen — die drei Fassungen liefen sonst
auseinander.

### Bildschirmfotos

```bash
scripts/run.sh              # legt die Simulator-Bilder in build/ ab
node scripts/store-shots.mjs # setzt sie für den Store
```

Ergebnis: `build/appstore/*.png` in **1320 × 2868** — das Maß für 6,9 Zoll und
seit 2024 das einzige Pflichtmaß fürs iPhone. Apple rechnet die kleineren
Geräte selbst herunter.

Die Reihenfolge ist die Verkaufsreihenfolge und in `store-shots.mjs`
begründet. Nur die **ersten beiden** erscheinen in der Suchliste; sie müssen
allein tragen.

> ⚠️ **Nach dem Einbau von StoreKit neu erzeugen.** Das sechste Bild zeigt die
> Kaufseite, und dort steht heute „Der Kauf steht bereit, sobald Zählora im
> App Store ist". Im Store selbst wäre dieser Satz absurd — und er stünde
> ausgerechnet auf dem Bild, das verkaufen soll.

**iPad-Bilder sind nicht nötig.** Seit 0.37.0 ist die App auf iPhone
beschränkt (`TARGETED_DEVICE_FAMILY: "1"`). Vorher stand dort „1,2", also
universal — Apple hätte iPad-Bilder verlangt und die App auf einem iPad
geprüft, für das sie nicht gebaut ist. iPad steht in `07-v1-plan.md` für 1.1.

### App-Vorschau (Video)

Optional und für 1.0 **gestrichen**. Ein schlechtes Video schadet mehr als
kein Video, und gute Bilder tragen diese App.

---

## 5. Hinweise für die Prüfung

Ins Feld „Notes" bei der Einreichung.

**Auf Englisch, und das ist eine Entscheidung.** Bis 0.105.8 stand hier ein
deutscher Text. Am 3. September kam die Ablehnung nach Richtlinie 2.1 —
„Information Needed" —, und darin fragt Apple sieben Punkte auf Englisch ab.
Wer eine Rückfrage in der Sprache beantwortet, in der sie gestellt wurde, wird
sicher verstanden. Die Oberfläche der App bleibt deutsch; **die Wörter, die ein
Prüfer auf dem Bildschirm sucht, stehen deshalb mit Umlaut darin** und nicht in
Umschrift. Genau daran wäre der Text sonst wertlos geworden.

**Der Text beantwortet alle sieben Punkte der Rückfrage.** Er gehört nicht nur
in dieses Feld, sondern zusätzlich als Antwort ins Lösungscenter — Apple
verlangt beides ausdrücklich.

```
NO ACCOUNT, NO LOGIN, NO CREDENTIALS. The app has no sign-in and no user
accounts, and therefore no account deletion flow. It has no user-generated
content, no messaging and no social features.

SEEING EVERYTHING TAKES TEN SECONDS. The app starts empty. On the start screen,
tap "Stattdessen Beispieldaten anlegen" ("Create sample data instead"). That
creates four meters with more than two years of history, one of them with
photovoltaic feed-in and one with day/night electricity registers.

1. PURPOSE AND AUDIENCE
Zählora is a German-language app for private households who read their own
electricity, gas and water meters. People write readings on paper or not at
all, and only learn at the annual bill whether their consumption and their
monthly instalment were realistic. Zählora records a reading in seconds on a
large keypad, shows consumption per day, month and year, compares only periods
that cover the same span of time, and projects the year end. Every estimated,
interpolated or projected number is labelled as an estimate.

2. MAIN FEATURES AND WHERE THEY ARE
Three tabs at the bottom.
- "Übersicht" (Overview): current status, projection for the year, and the
  printable consumption report.
- "Verlauf" (History): all readings, consumption per period, charts.
- "Zähler" (Meters): the list of meters. Tap a meter to enter a reading on a
  large numeric keypad. This tab also holds settings, CSV export, reminders and
  the purchase screen.

3. EXTERNAL SERVICES, TOOLS AND PLATFORMS
None. The app contains no networking code at all - there is not a single
URLSession call in the source. The one external system is Apple's own CloudKit
private database, used solely to sync the user's own data between the user's
own devices. No servers of ours, no analytics, no advertising, no tracking, no
AI service, no data provider, no authentication service, and no payment
processor other than Apple's In-App Purchase.

4. REGIONAL DIFFERENCES
None. Features and content are identical in every region. The interface is
German only, and monetary amounts are always formatted as Euro in German
notation, everywhere.

5. REGULATED INDUSTRY OR PROTECTED MATERIAL
Neither. The app provides no regulated service. It bundles no licensed media:
the interface uses Apple's SF Symbols and contains no image assets of its own.

6. IN-APP PURCHASES AND HOW TO REACH THEM
Six non-consumable one-time purchases, no subscriptions:
- Unbegrenzt viele Zähler (unlimited meters), EUR 1.99
- Tag- und Nachtstrom, Einspeisung (several registers per meter), EUR 1.99
- Kosten und Preise (enter tariffs, see costs), EUR 1.99
- Bericht ohne Wasserzeichen (report without watermark), EUR 1.99
- Erinnerung, wenn ein Zähler dran ist (reminders), EUR 0.99
- Alles freischalten (bundle of all five), EUR 4.99
To reach them: tab "Zähler", then the card with the shopping-cart icon
("Alles freischalten"). A single purchase also opens from the place where the
feature is used, for example when adding a third meter or entering a price.
Without any purchase the app stays fully usable: two meters, unlimited
readings, the complete history and CSV export are free forever. The consumption
report can be opened, browsed and printed without buying; it then carries a
watermark.
```

Der Hinweis auf die Beispieldaten ist kein Beiwerk: Ein Prüfer, der eine leere
App startet und nicht weiß, wo etwas herkommt, bewertet eine leere App.

**Jede Zahl darin ist aus dem Quelltext geholt, nicht erinnert.** Der alte Text
sprach von „fünf Einmalkäufe — vier einzelne Funktionen und ein Bündel". Es
sind **sechs**: fünf einzelne und ein Bündel darüber. `Entitlement.swift` führt
`additionalMeters`, `multipleRegisters`, `costsAndTariffs`, `pdfReport`,
`reminders` und `everything`, und die Summe der Einzelnen ergibt 8,95 € — was
mit 4 × 1,99 € nicht aufgeht. In App Store Connect standen die ganze Zeit sechs
Käufe auf `READY_TO_SUBMIT`; die Zahl im Text hat ihnen nur nie jemand
gegenübergestellt.

**Was der Text nicht behauptet:** dass der Bau auf einem echten Gerät geprüft
wurde. Das kann nur der Gründer sagen, und ungefragt steht es hier nicht
(Regel: keine Annahmen in Texten, die jemand anderes liest).

### Was nur der Gründer liefern kann

Punkt 1 der Rückfrage ist eine **Bildschirmaufnahme auf einem echten Gerät**,
und kein Skript erzeugt sie. Sie muss mit dem Start der App beginnen und den
üblichen Weg zeigen; für Zählora reicht eine Minute:

1. App starten (leerer Zustand), „Stattdessen Beispieldaten anlegen" antippen.
2. Einen Zähler öffnen, einen Stand über den Ziffernblock eintragen, sichern.
3. Auf „Verlauf" wechseln, durch den Verlauf und ein Diagramm blättern.
4. Auf „Zähler" die Karte mit dem Einkaufswagen antippen — die sechs Käufe
   erscheinen. Einen Kauf antippen, bis Apples Kaufblatt kommt.
5. Zurück auf „Übersicht", den Verbrauchsbericht öffnen und blättern.

Schritt 4 ist der wichtige: Apple fragt ausdrücklich nach dem Weg zu den
Käufen.

**Und genau deshalb steht der Text nicht mehr nur hier.** Bis 0.98.2 hat ihn
niemand eingetragen: Der Lauf schrieb ihn nicht und fragte auch nicht danach,
15 Punkte standen grün, und dieser fehlte, ohne dass er jemandem abging.
`--fuellen` überträgt jetzt diesen Block, und der Leser zählt seine Zeichen.

---

## 6. Was vor dem Einreichen noch fehlt

**Diese Liste stand hier von Hand — und war beim Nachsehen falsch.** StoreKit
war als offen eingetragen, obwohl die fünf Käufe seit Tagen bereit sind und
sich in TestFlight kaufen lassen. Eine Liste, die nachgeführt werden muss, ist
am Tag nach dem Nachführen wieder veraltet.

Gefragt wird jetzt Apple:

```
Actions › Einreichung nachsehen › Run workflow
```

Sekunden, schreibt nichts, sagt in drei Blöcken, was steht, was ich mache und
was nur der Gründer liefern kann. `scripts/asc-einreichung.py` ist dasselbe
Skript und läuft überall, wo der Schlüssel liegt.

### Was kein Skript beantworten kann

- [x] **Datenschutzerklärung und Support-Seite stehen im Netz.** Beide URLs
      zeigen auf `zaehlora.pages.dev`, der Platzhalter in `datenschutz.html`
      ist raus, und beide Felder sind bei Apple eingetragen.
- [ ] **Telefonnummer für die Prüfung.** Name und E-Mail stehen im Impressum
      und werden von dort gelesen; eine Nummer steht dort nicht, und § 5 DDG
      verlangt sie dort auch nicht. **Apple nimmt den Kontakt nur vollständig** —
      ein Versuch ohne Nummer kam zurück mit „You must provide a value for the
      attribute 'contactPhone'". Solange sie fehlt, steht bei Apple gar kein
      Kontakt.

      Ein Handgriff, einmal, unter
      `Settings → Secrets and variables → Actions → New repository secret`:

      | Geheimnis | Wert |
      |---|---|
      | `ASC_KONTAKT_TELEFON` | die Nummer, etwa `+49 151 12345678` |
      | `ASC_KONTAKT_MAIL` | nur nötig, wenn die Prüfung eine **andere** Adresse erreichen soll als das Impressum |

      Danach „Einreichung nachsehen" mit Häkchen starten — der Rest läuft. Ohne
      `ASC_KONTAKT_MAIL` nimmt der Lauf die Adresse aus dem Impressum.

      Beides liegt bewusst **nicht** im Repository: private Kontaktdaten gehören
      in keine Datei, die später einmal öffentlich stehen könnte.
- [ ] **Händlerstatus nach dem Digitale-Dienste-Gesetz der EU.** Der Punkt, der
      leicht mit dem Kontakt oben verwechselt wird und in die andere Richtung
      geht: Die Angaben zur Prüfung sieht **nur Apple**, die Angaben zum
      Händlerstatus stehen **öffentlich** auf der Produktseite in der EU.

      Apple verlangt bei einer Einzelperson Anschrift oder Postfach,
      Telefonnummer und E-Mail und schreibt dazu: „Apple will publish this
      information on your App Store product page when your app is distributed
      in any of the 27 territories of the EU." Anschrift und E-Mail stehen
      ohnehin schon im Impressum; **die Telefonnummer wäre neu öffentlich.**

      Ob der Gründer Händler ist, entscheidet er, nicht dieses Dokument. Apple
      nennt als Merkmal, ob mit der App Einnahmen erzielt werden — Käufe in der
      App zählen ausdrücklich dazu. Wer nichts angibt, wird beim Einreichen
      danach gefragt; ohne Angabe nimmt Apple Apps in EU-Ländern aus dem
      Verkauf.

      Einzustellen unter `Business → Agreements → Compliance → Digital Services
      Act`, je App zusätzlich unter `App Information → Digital Services Act`.

      **Auch hier kommt kein Schlüssel daran**, am 29. August geprüft:
      `appTraderDeclaration`, `traderDeclaration` und `appTraderDeclarations`
      antworten alle mit „does not exist".

      **Kein Skript kann das nachsehen.** Die Schnittstelle von Apple bietet
      dafür nichts an; „Einreichung nachsehen" wird diesen Punkt also nie
      melden, weder grün noch rot. Deshalb steht er hier und nicht dort.

      **Eintragen ist nicht gelten — und das hat den Starttermin gekostet.**
      Der Gründer hat die Angaben am 27. August gemacht. Am 30. August stand
      unter `Agreements → Compliance` bei „Gesetz über digitale Dienste"
      immer noch **In Prüfung**, während in derselben Tabelle Verträge,
      Bankkonto, beide Steuerformulare und die DAC7-Richtlinie auf „Aktiv"
      standen. Apple prüft den Händlerstatus, und wie lange, bestimmt Apple.

      Solange dort „In Prüfung" steht, scheitert jede Einreichung an

          appStoreVersions with id '…' is not in valid state.

      — einer Meldung, die den Händlerstatus mit keinem Wort erwähnt. Die
      Compliance-Zeile ist die **einzige** Stelle, an der die Sperre sichtbar
      wird.

      > Beim nächsten Vorhaben gehört dieser Punkt an den Anfang, Wochen vor
      > dem geplanten Start. Er ist der einzige der ganzen Auslieferung, den
      > man nicht durch Arbeit beschleunigen kann.
- [ ] **Der Datenschutz-Fragebogen in App Store Connect.** Etwas anderes als
      die Datenschutz-URL, die längst gesetzt ist: Apple fragt in einem
      eigenen Formular ab, welche Daten die App erfasst. Für Zählora ist die
      Antwort durchgehend **„Keine Daten erfasst"** — kein Konto, keine
      Werbung, kein Tracking, keine Absturzberichte.

      **Ohne ihn lässt sich nicht einreichen, und kein Schlüssel kommt daran.**
      Am 29. August gemessen, nicht vermutet — acht Pfade, acht Absagen:

      | Gefragt | Apple |
      |---|---|
      | `apps/{id}/appDataUsagesPublishState` | does not exist |
      | `apps/{id}/appDataUsagePublishState` | does not exist |
      | `apps/{id}/appDataUsages` | does not exist |
      | `apps/{id}/dataUsages` | does not exist |
      | `v1/appDataUsages` | does not exist |
      | `v1/appDataUsageCategories` | does not exist |
      | `v1/appDataUsagePurposes` | does not exist |
      | `v1/appDataUsageDataProtections` | does not exist |

      `App Store → App-Datenschutz → Bearbeiten`, dann veröffentlichen.

- [ ] **Zwei Wochen echte Eigennutzung** — der Punkt, der bisher am meisten
      gefunden hat, und eine Entscheidung, kein Arbeitsschritt.
- [ ] **800 ms Kaltstart** auf einem Gerät messen. Im Simulator sagt die Zahl
      nichts.

### Was am Mac einmal nachzusehen ist

- [x] **`PrivacyInfo.xcprivacy` im gebauten Bündel.** Seit 0.101.3 sieht die
      CI nach jedem App-Bau nach und bricht ab, wenn keine im Paket liegt. Der
      Punkt stand hier über sechs Wochen als „angenommen und nicht geprüft" —
      vor dem Verkaufsstart ist das die falsche Sorte Zuversicht, und der Build
      steht ohnehin schon da.

**Gefunden werden** ist ein eigenes Thema und steht in
[`10-sichtbarkeit.md`](10-sichtbarkeit.md): welche Felder der App Store
überhaupt durchsucht (die Beschreibung gehört **nicht** dazu), welche Wörter
ins Schlagwortfeld gehören, warum die Anzeigenamen der fünf Käufe fünf
zusätzliche Suchfelder sind, und wann veröffentlicht wird — diese App hat eine
Saison, und sie liegt im Januar.
