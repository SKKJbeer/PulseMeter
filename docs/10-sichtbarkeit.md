# 10 – Sichtbarkeit: gefunden werden, ohne Werbebudget

Stand: 2026-08-13, Version 0.42.0

Dieses Dokument beantwortet eine Frage: **Wie erfährt jemand von PulseMeter,
der uns nicht kennt?** Es ist bewusst kein Marketingplan mit Kanälen und
Budgets — für eine App, deren teuerstes Stück 4,99 € kostet, rechnet sich
bezahlte Werbung nicht (Abschnitt 7 rechnet es vor).

> **Was hier gemessen ist und was nicht.** Die Struktur des App Stores, die
> Zeichengrenzen und die Frage, welche Felder durchsucht werden, sind
> nachprüfbare Tatsachen. **Suchvolumen ist es nicht.** Aus diesem Container
> lässt sich nicht ermitteln, wie oft jemand „zählerstand app" tippt. Alles,
> was hier nach Rangfolge aussieht, ist begründet geschätzt und ausdrücklich
> als solches gekennzeichnet — genau die Unterscheidung, die uns bei der
> Prognose schon einmal um die Ohren geflogen ist (`08-baukasten.md`).

---

## 1. Wo Installationen herkommen

Für eine App ohne Marke und ohne Budget gibt es praktisch drei Quellen:

| Quelle | Was sie bringt | Was sie kostet |
|---|---|---|
| **Suche im App Store** | Der weitaus größte Teil. Wer sucht, hat ein Problem und will es jetzt lösen | Arbeit an drei Textfeldern, einmalig |
| **Empfehlung** | Wenig Menge, beste Qualität — diese Leute bleiben und bewerten | Eine App, die den Ärger wert ist, weitergesagt zu werden |
| **Fachöffentlichkeit** | Ein Ausschlag, dann flach. Trägt die ersten Bewertungen | Ein Presseset und ein paar Mails |

Was hier **nicht** steht: „Stöbern" (Kategorien, Redaktionsplätze). Ohne
Bekanntheit landet dort niemand, und die Redaktion wählt aus, statt sich
bewerben zu lassen.

Daraus folgt die Reihenfolge dieses Dokuments. Die drei Textfelder sind die
Arbeit, alles andere ist Zugabe.

---

## 2. ASO ist keine SEO — und der Unterschied entscheidet alles

Der wichtigste Satz für jeden, der von Websites kommt:

> **Der App Store durchsucht die Beschreibung nicht.**

Google Play tut es, Apple nicht. Bei Apple wird durchsucht:

1. **Name** (30 Zeichen) — am stärksten gewichtet
2. **Untertitel** (30 Zeichen)
3. **Schlagwortfeld** (100 Zeichen, für niemanden sichtbar)
4. **Anzeigenamen der In-App-Käufe**
5. Der Entwicklername

Die 4000 Zeichen Beschreibung sind für **Überzeugung** da, nicht fürs
Gefundenwerden. Wer sie mit Suchwörtern vollstopft, gewinnt nichts und
verliert den Text.

Punkt 4 wird fast immer übersehen und ist bei uns bares Geld: **fünf**
Produkte mit je einem Anzeigenamen, also fünfmal Platz für Wörter, die sonst
nirgends hinpassen. Abschnitt 4 nutzt das aus.

### Was die Reihenfolge sonst noch bestimmt

Neben den Wörtern zählt, wie gut die Ergebnisseite umsetzt: Wer draufklickt
und lädt, hebt die App für dieses Wort. Wer weiterscrollt, senkt sie.
Deshalb hängen Abschnitt 5 (Bilder) und Abschnitt 6 (Bewertungen) direkt am
Ranking und sind kein Beiwerk.

---

## 3. Die Wörter

### Wonach diese Zielgruppe sucht

Drei Suchabsichten, und sie sind sehr verschieden:

| Absicht | Beispiele | Wettbewerb | Passt zu uns |
|---|---|---|---|
| **Werkzeug** | zählerstand, stromzähler, ablesen | mittel | genau |
| **Problem** | nebenkostenabrechnung prüfen, abschlag zu hoch, stromverbrauch senken | gering | genau — und hier steht kaum jemand |
| **Kategorie** | haushaltsbuch, energie, verbrauch | hoch | nur am Rand |

**Die Wette dieses Dokuments:** Der zweite Bereich ist der wertvollste. Wer
„zählerstand" tippt, sucht einen Notizblock. Wer „nebenkostenabrechnung
prüfen" tippt, hat gerade einen Brief in der Hand, ist wütend und sucht ein
Mittel — das ist unsere Beschreibung Wort für Wort. Und dort steht fast
niemand, weil die meisten Zähler-Apps sich als Notizblock verstehen.

Belegt ist diese Wette nicht. Sie ist in vier Wochen nach der
Veröffentlichung nachprüfbar (Abschnitt 8), und dann wird das Schlagwortfeld
danach geändert — es lässt sich mit jeder Version neu setzen.

### Die Kandidatenliste

Geordnet nach vermuteter Nützlichkeit, nicht nach Volumen:

**Kern** (muss vorkommen)
`zählerstand` · `stromzähler` · `gaszähler` · `wasserzähler` · `ablesen` ·
`verbrauch`

**Problem** (die Wette)
`nebenkosten` · `abrechnung` · `abschlag` · `heizkosten` · `stromkosten` ·
`jahresabrechnung`

**Fälle, die andere nicht abdecken** (wenig Volumen, hohe Trefferquote)
`photovoltaik` · `einspeisung` · `nachtstrom` · `wärmepumpe` · `wallbox` ·
`brennwert` · `zustandszahl` · `zählerwechsel`

**Umfeld** (nur, wenn Platz bleibt)
`energie` · `haushaltsbuch` · `mietwohnung` · `vermieter` · `protokoll`

### Regeln, gegen die jede Fassung geprüft wird

- **Keine Wiederholung** aus Name und Untertitel. Apple wertet die ohnehin;
  ein zweites Mal ist verschenkter Platz.
- **Keine Einzahl und Mehrzahl** desselben Worts. Apple bildet die Formen.
- **Keine Leerzeichen** nach den Kommas — jedes ist ein Zeichen weniger.
- **Kombinationen entstehen von selbst.** Aus `zählerstand` und `ablesen`
  bildet Apple „zählerstand ablesen". Wortpaare gehören nicht ins Feld.
- **Keine fremden Marken.** Kein `tibber`, kein `enbw`, kein `verivox`. Das
  ist ein Ablehnungsgrund und kein Kavaliersdelikt.
- **Keine Wörter für Dinge, die es nicht gibt.** `beleg`, `foto`, `siri`
  stehen für 1.1 an und haben bis dahin nichts im Feld zu suchen.

### Der Vorschlag, der eingetragen wird

Name und Untertitel bleiben wie in `09-appstore.md`:

```
PulseMeter – Zählerstände
Zähler ablesen, Kosten sehen
```

Schlagwortfeld, 98 von 100 Zeichen:

```
nebenkosten,abrechnung,abschlag,heizkosten,gaszähler,wasserzähler,photovoltaik,einspeisung,wallbox
```

**Warum `zählerstand`, `stromzähler`, `ablesen` und `verbrauch` fehlen:** Sie
stehen bereits in Name und Untertitel und wären dort doppelt. Genau dieser
Fehler kostet die meisten Apps ein Viertel ihres Feldes.

**Und warum `nachtstrom` nicht dabei ist:** Die erste Fassung dieser Liste
endete darauf und war damit **101** Zeichen lang — eine zu viel. Aufgefallen
ist das erst beim Nachzählen in 0.44.0; hier stand „99 von 100", und das war
schlicht falsch gezählt. App Store Connect hätte stillschweigend abgeschnitten.
Das Wort ist über den Anzeigenamen des Kaufs ohnehin abgedeckt (Abschnitt 4).
An seiner Stelle steht jetzt `wallbox`.

Jede künftige Fassung dieses Feldes wird **nachgezählt**, bevor sie hier
steht. Ein Feld, das eine Zeichengrenze hat, ist der klassische Ort für einen
Fehler, den niemand sieht.

---

## 4. Die In-App-Käufe als fünf zusätzliche Suchfelder

Anzeigenamen sind durchsuchbar und dürfen sich ändern — **die Kennungen
nicht.** `de.karjoth.pulsemeter.pdfreport` bleibt für immer, wie sie ist; was im
Store darübersteht, ist frei.

| Produkt | Name in der App (`ProductID.title`) | Name in App Store Connect |
|---|---|---|
| `additionalmeters` | Unbegrenzt viele Zähler | Unbegrenzt viele Zähler |
| `multipleregisters` | Tag- und Nachtstrom, Einspeisung | Nachtstrom & Einspeisung erfassen |
| `costsandtariffs` | Kosten und Preise | Stromkosten & Gaskosten berechnen |
| `pdfreport` | Bericht ohne Wasserzeichen | Verbrauchsbericht als PDF |
| `everything` | Alles freischalten | PulseMeter komplett |

Zwei verschiedene Namen für dasselbe Produkt sind kein Widerspruch: In der App
steht, **was es tut**; im Store steht zusätzlich, **wonach jemand sucht**. Die
App-Fassung ist kürzer, weil sie in eine Zeile neben einen Preis muss.

---

## 5. Die Ergebnisliste: zwei Bilder entscheiden

In der Suchliste sieht man **Symbol, Name, Untertitel und die ersten beiden
Bildschirmfotos** — mehr nicht. Alles Weitere sieht nur, wer schon getippt hat.

Daraus folgen drei Dinge, die in `scripts/store-shots.mjs` bereits so
umgesetzt sind und hier ihre Begründung bekommen:

1. **Bild 1 ist die Übersicht mit Zahlen**, nicht ein leerer Startbildschirm.
   Wer eine leere App sieht, sieht Arbeit.
2. **Bild 2 ist der Ziffernblock.** Er beantwortet die stille Frage „wie
   mühsam ist das jedes Mal?" in einer Sekunde.
3. **Jedes Bild hat eine Überschrift**, weil die Oberfläche allein auf
   Daumennagelgröße nicht lesbar ist.

Dazu kommt ein Merkmal, das man nicht selbst setzt und das trotzdem verkauft:
die Kennzeichnung **„Keine Daten erfasst"**. Sie steht auf der Produktseite,
wir bekommen sie umsonst (ADR-002), und die Konkurrenz in dieser Kategorie
bekommt sie meistens nicht. Sie gehört deshalb auch als Satz in die
Beschreibung — dort steht sie bereits.

---

## 6. Bewertungen sind der Hebel, nicht die Belohnung

Unter zehn Bewertungen zeigt der Store gar keinen Stern. Eine App ohne Sterne
neben einer mit 4,6 verliert, auch wenn sie besser ist.

**Wann gefragt wird:** Nicht beim ersten Start. Nicht nach dem Kauf — das wirkt
gekauft. Sondern **nach der dritten gespeicherten Ablesung**: Wer dreimal
wiedergekommen ist, hat die App in seinen Alltag gelassen und weiß, was er
bewertet. Höchstens einmal pro Version, und `SKStoreReviewController`
entscheidet ohnehin selbst, ob es angezeigt wird.

Das ist eine **Produktänderung** und steht als solche in `07-v1-plan.md`; sie
lässt sich ohne das Developer Program bauen und prüfen.

**Was nie passiert:** gekaufte Bewertungen, Bewertungen im Tausch gegen
Freischaltungen, ein Dialog, der vor der schlechten Bewertung zum
Support-Formular umleitet. Alle drei sind Verstöße gegen die Richtlinien, und
alle drei fliegen irgendwann auf.

---

## 7. Außerhalb des Stores

### Eine eigene Seite — der Punkt mit dem größten Nebennutzen

Apple verlangt zur Einreichung **zwei erreichbare URLs**: Datenschutz und
Support. Beide sind heute offen (`09-appstore.md`, Abschnitt 6). Eine einzige
Seite erledigt beide — und ist zugleich die einzige Fläche, auf der
tatsächlich klassische Suchmaschinenoptimierung greift.

Denn was Google findet, sind nicht Apps, sondern Seiten. Und die Fragen, die
Menschen dort eintippen, sind länger und genauer als im App Store:

- „nebenkostenabrechnung prüfen zählerstand"
- „gaszähler kubikmeter in kwh umrechnen"
- „abschlag zu hoch was tun"
- „zählerstand vorjahresvergleich"

Für jede dieser Fragen kann eine kurze, ehrliche Antwortseite stehen, an deren
Ende die App erwähnt wird. Das ist langsam — Monate, nicht Tage — und
kostenlos, und es wirkt weiter, wenn man aufhört.

**Wo sie liegen kann:** Cloudflare Pages oder Netlify, beide kostenlos und
ohne Anmeldemaske davor. GitHub Pages scheidet aus, solange das Repository
privat ist (`CLAUDE.md`).

### Fachöffentlichkeit

Deutschsprachige Apple-Seiten nehmen kleine, gut gemachte Apps auf, wenn man
ihnen die Arbeit abnimmt: ein Absatz, drei Bilder, ein Satz zum Besonderen,
Freischaltcodes zum Ausprobieren. Kein Massenversand — fünf gezielte Mails
sind besser als fünfzig.

Das Besondere ist bei uns nicht „App für Zählerstände". Es ist: **kein Konto,
kein Abo, keine Datenerfassung, Export dauerhaft frei** — und eine Rechnung,
die Zustandszahl, Brennwert und Einspeisung tatsächlich kennt.

### Gemeinschaften

Dort, wo die Fälle besprochen werden, die andere Apps nicht können:
Photovoltaik-Foren, Haustechnik-Foren, Mietrechtsgruppen. **Nicht als Werbung
posten**, sondern die Frage beantworten und die App erwähnen, wenn sie zur
Antwort gehört. Alles andere wird gelöscht und zu Recht.

### Der Zeitpunkt

Diese App hat eine Saison, und sie ist scharf:

| Zeit | Was passiert | Was das heißt |
|---|---|---|
| **Oktober–November** | Heizperiode beginnt, Vermieter kündigen Ablesungen an | Guter Zeitpunkt zum Veröffentlichen |
| **Januar–März** | Jahresabrechnungen kommen ins Haus | **Der Höhepunkt.** Hier wird gesucht |
| **April–September** | Ruhe | Zeit zum Bauen |

Wer im Februar erscheint, verpasst die Welle, weil der Store neue Apps erst
einordnen muss. **Im Herbst veröffentlichen, im Januar geerntet.**

### Was nicht gemacht wird

**Bezahlte Werbung.** Ein installierter Nutzer kostet in dieser Kategorie
erfahrungsgemäß mehrere Euro. Bei einem Durchschnittsumsatz von wenigen Euro
je Käufer — und nur ein Bruchteil kauft überhaupt — müsste jeder zweite
Angeworbene das Bündel nehmen, damit es aufgeht. Das tut niemand. Bezahlte
Werbung lohnt sich bei Abos, und ein Abo wollen wir ausdrücklich nicht
(`04-monetarisierung.md`).

---

## 8. Woran wir merken, ob es wirkt

Alles hier ist eine Vermutung, bis Zahlen vorliegen. App Store Connect liefert
sie kostenlos, und drei davon genügen:

| Zahl | Was sie beantwortet | Wenn sie schlecht ist |
|---|---|---|
| **Impressionen** | Werden wir überhaupt gefunden? | Die Wörter stimmen nicht → Abschnitt 3 |
| **Produktseitenaufrufe je Impression** | Überzeugen Symbol, Name, die zwei Bilder? | Bilder und Untertitel → Abschnitt 5 |
| **Installationen je Seitenaufruf** | Überzeugt die Seite? | Beschreibung, Bewertungen → Abschnitt 6 |

Die drei Zahlen trennen sauber, **wo** es klemmt. Nur die Summe anzusehen ist
der übliche Fehler: Eine App mit vielen Impressionen und schlechter Umsetzung
braucht bessere Bilder, keine anderen Wörter — und umgekehrt.

Vier Wochen nach der Veröffentlichung wird das Schlagwortfeld zum ersten Mal
überarbeitet. Danach höchstens alle zwei bis drei Monate: Jede Änderung
braucht Zeit, bis der Store sie eingeordnet hat, und wer alle vierzehn Tage
dreht, misst nur sich selbst.

---

## 9. Reihenfolge

Was ohne das Developer Program fertig werden kann, in dieser Reihenfolge:

1. **Bewertungsfrage nach der dritten Ablesung** — Produktänderung, baubar und
   prüfbar (Abschnitt 6)
2. **Die eigene Seite** — erledigt Datenschutz- und Support-URL und ist die
   Grundlage für alles unter Abschnitt 7
3. **Presseset** — ein Absatz, drei Bilder, ein Satz zum Besonderen

Was auf das Programm wartet: die Anzeigenamen der Käufe (Abschnitt 4, sie
entstehen erst in App Store Connect), die neuen Bildschirmfotos und jede Zahl
aus Abschnitt 8.
