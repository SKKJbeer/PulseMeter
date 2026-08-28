# 09 – Material für den App Store

Stand: 2026-08-16, Version 0.53.0

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
PulseMeter – Zählerstände
```

25 Zeichen. Der Zusatz kostet nichts und bringt das wichtigste Suchwort in das
Feld, das am stärksten gewichtet wird. „PulseMeter" allein sucht niemand.

### Untertitel (max. 30 Zeichen)

```
Zähler ablesen, Kosten sehen
```

28 Zeichen. Zwei Suchwörter und ein Nutzen in einer Zeile. Nicht „Die App für
Ihre Zählerstände" — das sagt dasselbe und nutzt nichts.

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
Du trägst eine Zahl ein. PulseMeter sagt dir, ob alles im Rahmen ist.

Zählerstände landen auf einem Zettel am Sicherungskasten, in einer Tabelle, die
niemand pflegt, oder nirgends. Und im Frühjahr kommt die Abrechnung, und man
glaubt ihr einfach. PulseMeter macht aus zehn Sekunden am Zähler eine Zahl, mit
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
Zeitraum des Vorjahres. Mai gegen Mai, bei der Heizung sogar Heizperiode gegen
Heizperiode. Klingt selbstverständlich. Ist es nicht.

Tipp einen Monat an, und du siehst, woher der Unterschied kommt.


DIE NACHZAHLUNG SIEHST DU IM OKTOBER

Zwei Zahlen von deiner Rechnung genügen: Arbeitspreis und Grundpreis. Ab da
rechnet PulseMeter mit. Kommt dein Abschlag hin, oder legst du im Frühjahr
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

Monatlich, vierteljährlich oder wann du willst: Die App meldet sich, wenn eine
Ablesung fällig ist. Ein Widget auf dem Startbildschirm zeigt, ob etwas
ansteht.


WIR WISSEN NICHT, WIE VIEL STROM DU VERBRAUCHST

Und das soll so bleiben. Kein Konto, keine Anmeldung, keine Werbung, kein
Tracking, keine Absturzberichte. Deine Ablesungen liegen auf deinem Telefon
und, wenn du magst, in deiner eigenen iCloud. Auf unseren Servern liegen sie
nicht — wir haben keine. Deshalb steht über dieser App im Store „Keine Daten
erfasst", und nicht die lange Liste, die du sonst kennst.

Du entfernst die App, und die Daten sind weg. Es gibt keine Kopie, die
irgendwer behalten könnte.

Und du kommst jederzeit wieder heraus. Der Export als Tabelle ist kostenlos und
bleibt es, auch wenn du nie einen Cent ausgibst. Apps, die die eigenen Daten
als Pfand nehmen, sind der Grund, warum so viele Leute lieber bei Excel
bleiben.


EIN PAAR EURO, EINMAL. KEIN ABO.

Kostenlos bleiben: zwei Zähler, so viele Ablesungen du willst, der ganze
Verlauf, der Vorjahresvergleich, Erinnerungen und der Export.

Wenn dir später etwas fehlt, kaufst du genau das frei — und nicht ein Paket, in
dem drei Dinge stecken, die du nie brauchst. Unbegrenzt viele Zähler. Zähler
mit zwei Zahlen. Kosten und Preise. Den Verbrauchsbericht ohne Schriftzug. Je
1,99 €, alle vier zusammen 4,99 €. Einmal bezahlt, auf allen
deinen Geräten, und es bleibt.

Den Bericht kannst du dir immer ansehen und ausdrucken. Freischalten musst du
ihn erst, wenn du ihn jemandem geben willst.
```

3844 Zeichen. Aufbau mit Absicht: Die ersten zwei Zeilen stehen in der
Vorschau, bevor jemand „mehr" tippt — sie müssen allein tragen. Der Preis
steht ganz unten, weil bis dorthin nur liest, wer die App ohnehin will.

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
| In-App-Käufe | Fünf nicht verbrauchbare Produkte: vier zu 1,99 €, Bündel 4,99 € | Begründung in `04-monetarisierung.md` |
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
> Kaufseite, und dort steht heute „Der Kauf steht bereit, sobald PulseMeter im
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

Ins Feld „Notes" bei der Einreichung:

```
Die App braucht kein Konto und keine Anmeldedaten.

Beim ersten Start ist sie leer. Um alle Funktionen zu sehen, genügt auf dem
Startbildschirm der Knopf „Stattdessen Beispieldaten anlegen": Er legt vier
Zähler mit gut zwei Jahren Verlauf an, darunter einen mit Photovoltaik und
einen mit Tag- und Nachtstrom.

Die In-App-Käufe sind fünf Einmalkäufe ohne Abo — vier einzelne Funktionen und
ein Bündel darüber. Ohne jeden Kauf bleiben zwei Zähler, alle Ablesungen, der
gesamte Verlauf und der Export dauerhaft nutzbar. Der Verbrauchsbericht lässt
sich auch ungekauft öffnen, blättern und drucken; er trägt dann ein
Wasserzeichen.
```

Der Hinweis auf die Beispieldaten ist kein Beiwerk: Ein Prüfer, der eine leere
App startet und nicht weiß, wo etwas herkommt, bewertet eine leere App.

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

- [ ] **Datenschutzerklärung und Support-Seite müssen im Netz stehen.** Apple
      will zwei URLs, und beide zeigen auf die Website. Sie ist gebaut und
      geprüft, aber nicht veröffentlicht — und in `datenschutz.html` steht noch
      ein `PLATZHALTER`. Ohne diese zwei Felder gibt es keine Einreichung.
- [ ] **Kontakt für die Prüfung** — Name, Telefon, E-Mail. Das sind Angaben
      über den Gründer und werden nicht erfunden (CLAUDE.md, „Keine Annahmen in
      Texten, die jemand anderes liest").
- [ ] **Zwei Wochen echte Eigennutzung** — der Punkt, der bisher am meisten
      gefunden hat, und eine Entscheidung, kein Arbeitsschritt.
- [ ] **800 ms Kaltstart** auf einem Gerät messen. Im Simulator sagt die Zahl
      nichts.

### Was am Mac einmal nachzusehen ist

- [ ] **`PrivacyInfo.xcprivacy` im gebauten Bündel.** Sie liegt seit 0.55.0 in
      `App/` und `Widget/`; dass XcodeGen sie als Ressource mitnimmt, ist
      angenommen und nicht geprüft:
      `find build/DerivedData -name PrivacyInfo.xcprivacy`

**Gefunden werden** ist ein eigenes Thema und steht in
[`10-sichtbarkeit.md`](10-sichtbarkeit.md): welche Felder der App Store
überhaupt durchsucht (die Beschreibung gehört **nicht** dazu), welche Wörter
ins Schlagwortfeld gehören, warum die Anzeigenamen der fünf Käufe fünf
zusätzliche Suchfelder sind, und wann veröffentlicht wird — diese App hat eine
Saison, und sie liegt im Januar.
