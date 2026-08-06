# Änderungen

Alle nennenswerten Änderungen an PulseMeter, neueste Version oben.
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/);
bis zur Einreichung im App Store bleibt die Hauptversion `0`.

Der Ablauf, nach dem diese Datei gepflegt wird, steht in
`.claude/skills/release-discipline/SKILL.md`.

---

## 0.26.2 — 2026-08-06

### Behoben
- **Der Wechselschirm ließ sich nicht übersetzen.** `guard let register`
  packte den Wert oben aus, drei Zeilen später band ich ihn noch einmal:
  „initializer for conditional binding must have Optional type, not
  'Register'". Ein Fehler, den ein Compiler in einer Sekunde findet — und der
  hier vier Fassungen lang unentdeckt blieb, weil kein Lauf durchkam.

### Bemerkenswert
- **Die Protokollkorrektur aus 0.22.4 hat sich sofort ausgezahlt.** Der Lauf
  nannte Datei, Zeile, Spalte und Grund. Vorher hätte dort „TEST FAILED"
  gestanden und sonst nichts.
- **Der neue Linux-Auftrag für den Entwurf war in 59 Sekunden grün** — beim
  allerersten Lauf, und während der macOS-Auftrag noch baute.
- Vier Fassungen ohne Bestätigung übereinander, und der Rückstau bestand aus
  **genau einer** falschen Zeile. Das ist ein besserer Ausgang als erwartet,
  ändert aber nichts am Befund: So lange ohne Übersetzer weiterzubauen war
  riskant, und dass es gutging, war zum Teil Glück.

## 0.26.1 — 2026-08-06

**Ein frisch angelegter Zähler ließ sich nicht ablesen.** Gemeldet vom
Gründer beim Ausprobieren — nicht von mir beim Testen. Der erste Schritt, den
ein neuer Nutzer überhaupt macht, und er führte ins Leere.

Es waren zwei Fehler übereinander:

### Behoben
- **`judge()` griff auf `last.value` zu, ohne zu prüfen, ob es eine vorherige
  Ablesung gibt.** Bei einem neuen Zähler stürzte die Plausibilitätsprüfung
  still ab, und „Sichern" blieb gesperrt. Der ältere der beiden Fehler, und
  der, den der Gründer gesehen hat.
- **Der Editor legte ein halbes Zählwerk an** — `{ label: "", readings: [] }`,
  ohne Einheit, ohne Stellen, ohne Kennung. Solange der Ziffernblock diese
  Werte beim *Zähler* holte, fiel das nicht auf; seit 0.26.0 holt er sie beim
  *Zählwerk*, und dann nahm die Eingabe keine Ziffer mehr an. Dieser Fehler
  ist meiner, aus der Runde davor.

  Die Lehre steckt nicht im Tippfehler, sondern im halb gefüllten Gebilde: Ein
  Zählwerk, dem Felder fehlen, die jedes andere hat, ist eine Falle, die auf
  ihre Gelegenheit wartet. Beim Ändern der Zählerart ziehen die Felder jetzt
  ebenfalls mit.

### Hinzugefügt
- **`scripts/check-prototype.mjs` und ein eigener CI-Auftrag auf Linux.** Der
  Entwurf ist der produktivste Fehlerfinder dieses Projekts und wurde bisher
  nur geprüft, wenn ich daran dachte. Vierzehn Prüfungen je Erscheinungsbild,
  darunter genau dieser Weg: Zähler anlegen, ersten Stand eintippen, sichern.
- Der Auftrag läuft auf `ubuntu-latest` und braucht keinen macOS-Läufer. Er
  ist in einer Minute durch, auch wenn der App-Build stundenlang in der
  Warteschlange hängt — was heute mehrfach der Fall war.

### Warum es niemandem auffiel
Jeder Zähler im Entwurf hatte zwei Jahre Historie. Den Fall „noch nie
abgelesen" gab es in der Erfassung schlicht nicht — dieselbe Ursache wie bei
dem Absturz in `lastReading`, der vor ein paar Fassungen an derselben Stelle
saß. Ein Ausgangszustand, der nur den eingeschwungenen Fall zeigt, versteckt
den Anfang.

## 0.26.0 — 2026-08-06

**Der Entwurf erfasst beide Zählwerke.** Die zweistufige Erfassung gibt es in
der App seit 0.22.0 — im Klick-Dummy nicht. Er schrieb ausschließlich nach
`registers[0]`, und die Einspeisung des PV-Zählers ließ sich dort gar nicht
eintragen. Eine Abweichung, die niemandem auffiel, weil man sie nur beim
Durchklicken bemerkt.

### Geändert
- Erfassung läuft über alle Zählwerke nacheinander: Zählwerkname, „Zählwerk 1
  von 2", Knopf „Weiter" statt „Sichern". Gesichert wird erst am Ende und dann
  alles zusammen — ein Abbruch nach dem ersten darf keine halbe Ablesung
  hinterlassen.
- **Stellen und Einheit kommen jetzt vom Zählwerk, nicht vom Zähler.** Vorher
  nahm der Ziffernblock `capMeter.int`/`capMeter.frac`; bei einem Zähler,
  dessen Zählwerke sich darin unterscheiden, hätte er die falsche Maske
  gezeigt. Aufgefallen beim Umbau, nicht im Betrieb.

### Geprüft
- Beide Zählwerke einmal wirklich durchgeklickt: „Bezug / Zählwerk 1 von 2 /
  Weiter", dann „Einspeisung / Zählwerk 2 von 2 / Sichern". Beide Reihen
  wachsen um genau eine Ablesung, kein Überlauf, keine JS-Fehler.

## 0.25.0 — 2026-08-06

**Widget für Sperr- und Startbildschirm.** Der zweite Hebel für Wiederkehr:
Erinnerungen holen jemanden zurück, der die App vergessen hat — ein Widget
sorgt dafür, dass er sie gar nicht erst vergisst.

### Hinzugefügt
- `WidgetSummary` in `PulseCore` mit sechs Prüfungen: eine kleine, für sich
  lesbare Zusammenfassung mit Menge, Zeitraum, Fälligkeit und Symbol.
- `WidgetBridge` schreibt sie nach jeder Änderung als Datei in die App-Gruppe;
  das Widget liest sie und rechnet nichts.
- Zwei Größen. Die kleine zeigt den dringendsten Zähler, die mittlere bis zu
  drei.

### Entschieden
- **Das Widget bekommt keinen Zugriff auf den Speicher.** Eine Erweiterung ist
  ein eigener Prozess mit knappem Speicher und wenigen Millisekunden Zeit.
  Zöge sie SwiftData samt CloudKit auf, um drei Zahlen anzuzeigen, wäre sie
  das langsamste und fehleranfälligste Stück der App — und der häufigste Grund
  für ein leeres Widget ist genau das.
- **Die Zusammenfassung entsteht in `PulseCore`, nicht in der App.** Würde sie
  in der Erweiterung noch einmal formuliert, liefen die beiden auseinander,
  und das Widget zeigte eine andere Zahl als der Bildschirm daneben. Aus
  demselben Grund ist `periodCaption` aus der Übersicht herausgelöst und wird
  nun von beiden benutzt.
- **Fälligkeit hat Vorrang vor dem Zeitraum.** Wer im Vorbeigehen liest, liest
  eine Zeile. Stünde dort der Zeitraum, während ein Zähler seit drei Monaten
  überfällig ist, hätte das Widget die falsche Zeile gewählt.
- **Ohne Daten sagt es, was zu tun ist**, statt leer zu bleiben. Ein leeres
  Widget wird entfernt.
- **Ein Schreibfehler bleibt folgenlos.** Ohne App-Gruppe — etwa in der CI,
  wo ohne Signatur gebaut wird — landet die Datei im eigenen Ordner der App.
  Das Widget sieht sie dann nicht, aber die App läuft. Ein Absturz an dieser
  Stelle wäre absurd: Niemand verliert etwas, wenn ein Widget leer bleibt.
- **Die Datei trägt eine Fassungsnummer**, und eine neuere wird nicht geraten.
  Ein Widget läuft weiter, während die App schon aktualisiert ist — dann
  lieber der leere Zustand als eine Zahl, deren Bedeutung sich verschoben hat.
- Geschrieben wird **atomar**: Läse das Widget genau während des Schreibens,
  bekäme es sonst eine halbe Datei.

### Vorsichtsmaßnahmen ohne Compiler
Das Widget ist das erste Ziel, das ohne lokalen Übersetzer entsteht. Zwei
Stellen habe ich deshalb entschärft, bevor der Lauf sie findet:
- Ein Helfer mit `@ViewBuilder` an einem `some View`-Parameter ist gültiges
  Swift, aber die ausgefallenste Konstruktion der Datei. Ein `if let` kostet
  drei Zeilen mehr und kann nicht überraschen.
- `periodCaption(for:)` gab es nach dem Herauslösen zweimal — mit `MeterRow`
  und mit `ConsumptionResult?`. In einem Abschluss wäre das eine Einladung an
  den Typprüfer, die falsche zu wählen. Die zweite heißt jetzt `periodText`.

### Offen
- Die App-Gruppe braucht ein Entwicklerkonto, um auf einem Gerät zu greifen.
  Im Simulator und in der CI läuft der Ersatzpfad. Das Widget ist damit
  gebaut und übersetzt, aber erst mit dem Apple Developer Program wirklich
  gefüllt.

`PulseCore` steht bei 135 Prüfungen.

## 0.24.0 — 2026-08-06

**Der Entwurf rechnet wie der Rechenkern.** Die offene Abweichung aus 0.23.0
ist geschlossen — und zwar an der Wurzel, nicht durch Nachbauen der Oberfläche.

### Geändert
- **Der Klick-Dummy bildet jetzt eine aufsummierte Reihe**, wie
  `ConsumptionSeries` in `PulseCore`. Vorher rechnete er Verbrauch als
  Differenz zweier **roher** Zählerstände. Das trägt genau so lange, wie der
  Zähler nur steigt; ein Gerätewechsel oder ein Überlauf machte jeden
  Verbrauch negativ. Und weil der Entwurf beides nicht kannte, konnte er
  Fehler darin auch nicht finden — genau dafür gibt es ihn aber.
- `step` spiegelt die Regeln eins zu eins: erklärter Rücksprung bei
  Gerätewechsel, Überlauf ab 90 % der Kapazität, sonst null statt Raten.
  Schwelle und Kapazität sind gegen `PulseCore` abgeglichen.
- Getrennt in `cumulativeAt` (aufgelaufener Verbrauch) und `readingAt`
  (roher Stand). Der Bericht braucht den Stand, alles andere den Verbrauch.
  Die beiden zu verwechseln hieße, nach einem Wechsel den Stand des neuen
  Geräts als Verbrauch auszuweisen.

### Hinzugefügt
- **Der Zählerwechsel ist im Entwurf anklickbar.** Dieselbe Sackgasse wie in
  der App bis 0.23.0: Die Frage „Wurde der Zähler gewechselt?" stand da und
  ließ sich nur mit „Ziffer verirrt" beantworten. Jetzt steht ein Ausweg
  darunter.
- Neue Ablesungen übernehmen die Gerätekennung der vorherigen — sonst risse
  die Kette beim nächsten Rücksprung wieder.

### Geprüft
- Alle Zahlen der Übersicht sind vor und nach dem Umbau **identisch**. Das war
  die Anforderung: Ohne Wechsel und ohne Überlauf muss die Reihe genau
  dasselbe liefern.
- Vier Fälle einzeln durchgerechnet — ohne Wechsel 600, mit Wechsel 800,
  unerklärter Rücksprung 800, Überlauf 550. Bei zweien wich das Ergebnis von
  meiner Erwartung ab, und **beide Male lag die Erwartung falsch**, nicht der
  Code: Nach einem unerklärten Rücksprung zählt `PulseCore` weiter, statt zu
  verwerfen, und beim Überlauf hatte ich schlicht falsch addiert.
- Der Wechsel einmal wirklich durchgeklickt, hell und dunkel: Verbrauch bleibt
  bei 1.607 kWh, der Stand springt von 49.157,4 auf 42. Zwischen Endstand und
  Anfangsstand vergeht kein Verbrauch — richtig so.

## 0.23.0 — 2026-08-06

**Zählerwechsel.** Der Erfassungsschirm fragte seit jeher „Wurde der Zähler
gewechselt, oder hat sich eine Ziffer verirrt?" — und nahm die Antwort nicht
entgegen. Eine Frage ohne Antwortmöglichkeit ist eine Sackgasse, und die sind
in diesem Produkt ausgeschlossen (Produktprinzip 4). `MeterDevice`,
`Reading.deviceID` und `MeteringPoint.device(on:)` lagen im Rechenkern seit
dem ersten Tag bereit; die App benutzte davon nichts.

Ein Wechsel ist kein Randfall: Netzbetreiber tauschen turnusmäßig, und beim
Einbau eines digitalen Zählers fängt der Stand wieder bei null an.

### Hinzugefügt
- **Ein Wechselschirm mit zwei Zahlen** — Endstand des alten Geräts,
  Anfangsstand des neuen, dazu die Gerätenummer. Zwei und nicht eine: Ein
  Wechsel ist kein Nullsetzen. Beide Stände beschreiben denselben Moment, und
  nur mit beiden bleibt der Verbrauch bis zum Wechseltag erhalten.
- **Zwei Einstiege.** Im Erfassungsschirm erscheint „Der Zähler wurde
  gewechselt", sobald der neue Stand unter dem alten liegt — genau dort, wo
  die Frage steht. Und im Zählereditor, für den, der es einträgt, während der
  Monteur noch da ist.
- Jede neue Ablesung trägt jetzt die Kennung des verbauten Geräts. Ohne sie
  risse die Kette nach dem Wechsel wieder: Der Rechenkern erkennt den
  erklärten Rücksprung nur, wenn **beide** benachbarten Ablesungen wissen, auf
  welchem Gerät sie entstanden sind.

### Entschieden
- **Die Zeitstempel der beiden Stände werden von Hand gesetzt.** Beide liegen
  am selben Tag, und dann entscheidet `createdAt` über die Reihenfolge.
  Zweimal `Date()` kann denselben Augenblick liefern, und Swifts `sorted` ist
  **nicht stabil** — die Reihenfolge wäre undefiniert gewesen. Stünde der
  Anfangsstand vor dem Endstand, sähe der Rechenkern einen Absturz von 50.600
  auf 0. Eine Prüfung hält fest, dass die umgekehrte Reihenfolge tatsächlich
  ein anderes Ergebnis liefert — sonst prüfte der Zeitstempel nichts.
- **Vor dem ersten Wechsel wird das ausgebaute Gerät nachgetragen**, mit der
  ersten Ablesung als Einbaudatum. Alte Ablesungen behalten ihre leere
  Kennung; der Übergang von leer auf gesetzt ist ein normaler Zuwachs. Eine
  Prüfung deckt genau diese Kette ab — die bestehende setzte eine Historie
  voraus, in der jede Ablesung schon ein Gerät kennt, und so sieht kein
  gewachsener Bestand aus.

### Offen und benannt
- **Der Entwurf bildet den Wechsel noch nicht ab.** Er interpoliert direkt auf
  den Zählerständen, während `PulseCore` über eine aufsummierte Reihe rechnet.
  Ein Rücksprung machte dort jeden Verbrauch negativ. Nachzuziehen heißt, im
  Entwurf zuerst dieselbe kumulative Reihe einzuführen — ein Umbau seines
  Kerns, kein Zusatz, und deshalb nicht nebenbei am Ende einer Runde. Es ist
  der nächste Schritt am Entwurf, bevor eine weitere Fähigkeit dazukommt.

`PulseCore` steht bei 129 Prüfungen.

## 0.22.4 — 2026-08-06

### Behoben
- **Ein abgebrochener Lauf hinterließ keine Spur.** Die Korrektur aus 0.21.5
  leitete die gesamte Ausgabe in eine Datei und gab die Begründungen nur im
  **Fehlerzweig** aus. Ein Lauf, der abgebrochen wird statt fehlzuschlagen,
  erreicht diesen Zweig nie — auf der Konsole stand dann nichts, und ohne
  Zugriff auf die Artefakte war nicht einmal zu sehen, wie weit er gekommen
  war. Eine Blindstelle gegen eine andere getauscht.

  Jetzt über `tee`: Die Datei bleibt vollständig, und auf der Konsole läuft
  mit, welche Prüfung gerade lief. Der Exitcode kommt über `PIPESTATUS`
  durch — gegengeprüft mit einem Versuchsaufbau, der 65 zurückgibt.

### Bemerkenswert
- Drei Läufe hintereinander sind an GitHubs Infrastruktur gescheitert, nicht
  am Code: „Failed to resolve action download info. Service Unavailable",
  zweimal noch vor `actions/checkout`, einmal als Abbruch mitten in den
  Oberflächentests. Der letzte inhaltlich vollständige Lauf ist 39 auf
  0.22.1 — grün.

## 0.22.3 — 2026-08-06

### Behoben
- **Die Abschlagsvorschau rechnete beim PV-Zähler, als gäbe es die Anlage
  nicht.** Sie bekam nur die Ablesungen des Bezugs; die Einspeisung fiel
  stillschweigend weg. Aufgefallen ist es daran, dass auf der Karte **auf den
  Cent** derselbe Wert stand wie vor der Einrichtung — 90,30 € Guthaben —
  während der Entwurf an derselben Stelle 283 € zeigte. Ohne den Abgleich mit
  dem Klick-Dummy wäre die Zahl plausibel durchgegangen.

### Entschieden
- **Die beiden Ablesungslisten heißen jetzt `primary` und `everything`.**
  Beide hießen `readings`, und beim Umstellen auf den Zweirichtungszähler habe
  ich an einer von vier Stellen die falsche stehenlassen. Ein Name, der die
  Verwechslung nicht bemerkbar macht, ist ein Fehler, der auf seine
  Gelegenheit wartet. Menge, Stand und Vorjahresvergleich gehören zum Bezug —
  sonst stünde bei einem PV-Zähler der Einspeisestand auf der Karte. Kosten,
  Vorschau und Einspeisezeile gehören zur Messstelle.

### Bemerkenswert
- Der Grundpreis läuft über den Zeitraum **bis heute**, der Arbeitspreis nur
  über den abgelesenen. Beim Stromzähler sind das fünf Tage und 2,12 € — die
  Kostenzeile heißt „bis 1. August" und enthält Grundpreis bis zum 6. Der
  Unterschied ist gewollt: Der Grundpreis läuft auch weiter, wenn niemand
  abliest. Hier festgehalten, damit ihn niemand später als Fehler „korrigiert".

## 0.22.2 — 2026-08-06

Der zweistufige Erfassungsschirm aus 0.22.0 war weder fotografiert noch
geprüft. `-pulse-capture` öffnet den ersten Zähler, und das ist Gas mit einem
einzigen Zählwerk — der neue Ablauf kam auf keinem der zehn Bilder vor.

Das ist dieselbe Lücke wie beim Zähler-Schirm in 0.21.4, nur eine Ebene
tiefer: Ein Ablauf, den niemand ansieht, ist einer, in dem sich ein Fehler
beliebig lange hält. Heute haben Bildschirmfotos vier Fehler gefunden, drei
davon in derselben Stunde.

### Hinzugefügt
- `-pulse-capture-pv` öffnet die Erfassung beim Zweirichtungszähler. Zwei
  weitere Bilder je Lauf, hell und dunkel — damit sind es zwölf.
- Zwei Oberflächenprüfungen: der Weg über beide Zählwerke („Bezug", „Weiter",
  „Einspeisung", „Sichern") und die Einspeisezeile auf der Karte.

### Behoben
- Über `testCostIsLabelledWithThePeriodItCovers` standen seit 0.21.5 zwei
  Dokumentationskommentare übereinander — beim Ersetzen der Funktion war der
  alte stehengeblieben.

## 0.22.1 — 2026-08-06

Zwei Fehler aus 0.22.0, beide vom ersten Bildschirmfoto gefunden, das den
neuen Zähler zeigte. Auf der Stromkarte stand „Einspeisung 2.086 kWh ≈ 79,02 €
vergütet" — bei 8,2 ct hätten es 171 € sein müssen. Die Differenz war beide
Male derselbe Betrag: ein Grundpreisanteil von 89,90 €.

### Behoben
- **Ein Zweirichtungszähler zahlte den Grundpreis zweimal.** Die Rechnung über
  eine ganze Messstelle summierte die Grundpreise ihrer Zählwerke. Der
  Grundpreis gehört aber zum Anschluss, nicht zum Zählwerk — ein Gerät bekommt
  eine Rechnung. Gezählt wird jetzt je Tarifabschnitt: dieselbe Tarifkennung
  im selben Zeitraum ist derselbe Grundpreis. Zwei Zählwerke mit **eigenen**
  Tarifen behalten dagegen jeder seinen; eine zweite Prüfung hält das fest,
  damit die Korrektur nicht ins Gegenteil überschießt.
- **Die Einspeisevergütung auf der Karte nahm den Gesamtbetrag statt des
  Arbeitspreisanteils.** In `total` steckt auch der Grundpreis, und der wurde
  dadurch von der Gutschrift abgezogen.

### Bemerkenswert
- **Der Entwurf hatte hier recht und der Rechenkern unrecht.** Der Klick-Dummy
  rechnet den Grundpreis seit jeher einmal je Zähler. Bisher lief die Prüfung
  meist andersherum — das ist das erste Mal, dass die kürzere Fassung die
  gründlichere geschlagen hat.
- Beide neuen Prüfungen schlagen auf der alten Fassung fehl: 240 € statt 120 €
  Grundpreis, 500 € statt 380 € gesamt. Ein Test, der auch vorher grün gewesen
  wäre, hätte nichts bewiesen.

## 0.22.0 — 2026-08-06

**Photovoltaik.** Der Rechenkern konnte Zweirichtungszähler seit dem ersten
Tag, der Entwurf zeigte sie — nur die App kannte sie nicht. Wer eine PV-Anlage
hat, konnte seinen Zähler damit gar nicht abbilden, und in Deutschland ist das
längst keine Randgruppe mehr.

### Hinzugefügt
- **Ein Schalter „Einspeisung ins Netz"** im Zählereditor, sichtbar nur bei
  Strom. Dazu ein Feld für die Einspeisevergütung.
- **Der Erfassungsschirm fragt nacheinander nach beiden Zahlen** — erst Bezug,
  dann Einspeisung, mit „Weiter" statt „Sichern" dazwischen. Keine Auswahl
  davor: Wer vor dem Zähler steht, liest beide Zahlen in einem Zug ab; eine
  Auswahl hieße erst entscheiden, dann tippen, dann noch einmal öffnen.
- **Die Übersichtskarte zeigt die Einspeisung** mit Menge und Vergütung, und
  zwar **über** den Kosten: Der Betrag darunter ist bereits netto.
- Der Ausgangszustand enthält jetzt einen Stromzähler mit PV — sonst sähe
  weder ein Bildschirmfoto noch ein Test den Fall je.

### Behoben
- **Die Abschlagsvorschau rechnete bei PV systematisch falsch.** Sie nahm die
  Nettokosten der ganzen Messstelle — Bezug minus Vergütung — und skalierte
  sie mit dem Hochrechnungsfaktor des **Bezugs**. Das stimmt nur, wenn beide
  Zählwerke denselben Ausschnitt abdecken; Bezug und Einspeisung laufen aber
  gegenläufig durchs Jahr. Im August ist der Bezug fast durch, die Einspeisung
  noch lange nicht. Es ist die wiederkehrende Fehlerklasse aus CLAUDE.md, zum
  neunten Mal: eine Aussage über einen Zeitraum, den die Zahl nicht abdeckt.
  Jedes Zählwerk bekommt jetzt seine eigene Hochrechnung.

  Zwei Prüfungen halten das fest; die eine schlägt auf der alten Fassung mit
  483,98 € gegen erwartete 422,81 € fehl. Nachgerechnet von Hand — und die
  erste Handrechnung war falsch, nicht der Rechenkern.
- **Der Entwurf rechnete die Abschlagsvorschau brutto**, während die
  Kostenzeile derselben Karte netto war. Zwei Zahlen nebeneinander, die sich
  widersprachen. Beim Stromzähler springt das Guthaben dadurch von 90 € auf
  283 € — 193 € hochgerechnete Jahresvergütung, von denen bis zum 1. August
  134 € aufgelaufen sind. 69 % des Jahresertrags bis Ende Juli, für eine
  PV-Anlage die richtige Größenordnung.
- **Zwei Ablesungen desselben Geräts werden zusammen festgeschrieben.** Bisher
  sicherte der Speicher jeden Wert einzeln; ein Fehler beim zweiten Zählwerk
  hätte den ersten allein stehen lassen. Er sähe aus wie eine vollständige
  Ablesung, und der Rechenkern bildete daraus einen Verbrauch für einen
  Zeitraum, in dem die Gegenrichtung fehlt.

### Entschieden
- **Die Einspeisung lässt sich nicht mehr abschalten, sobald Werte dafür
  vorliegen.** Der Schalter ist dann gesperrt, mit Begründung. Ein Zählwerk zu
  entfernen, an dem Ablesungen hängen, hieße Daten zu verlieren, die der
  Nutzer selbst eingetragen hat.
- **Kein Wort über Zählwerke in der Oberfläche.** Der Nutzer sieht ein Gerät
  mit zwei Zahlen darauf, und genau so steht es da: „Für Zähler, die in beide
  Richtungen zählen." Beim Zweirichtungszähler heißt das erste Zählwerk
  „Bezug" — allein wäre das Wort nichtssagend, neben „Einspeisung" sagt es
  alles.

## 0.21.5 — 2026-08-06

### Behoben
- **Ein Oberflächentest hielt die falsche Formulierung fest.** Er prüfte auf
  den Wortlaut „Kosten seit Jahresbeginn" und ist deshalb an der Korrektur aus
  0.21.4 zerbrochen — zu Recht. Er prüft jetzt die Eigenschaft statt des
  Satzes: dass eine Kostenzeile da ist, dass ein Betrag dabeisteht, und dass
  beim überfälligen Zähler ein Enddatum genannt wird. Bewusst als vorhandene
  Aussage und nicht als fehlende: Am Ersten eines Monats wäre „seit
  Jahresbeginn" beim Stromzähler richtig, und eine Verneinung hinge am
  Kalender.
- **Die CI verschwieg, warum eine Prüfung gefallen ist.** `-quiet` nennt die
  Namen der gefallenen Tests, aber keine Begründung. Ein Lauf, der „testX ist
  gefallen" sagt und den Grund für sich behält, kostet zwanzig Minuten fürs
  Raten — genau das ist heute einmal passiert. Das Protokoll geht jetzt
  vollständig in eine Datei, und bei einem Fehlschlag stehen die Begründungen
  auf der Konsole. Die Datei liegt zusätzlich im Artefakt.

### Geändert
- Die Roadmap stand auf 0.9.0 und behauptete, `PulseUI` und der
  Erfassungsschirm seien offen. Sie führt jetzt den tatsächlichen Stand — und
  eine Tabelle, die nebeneinanderstellt, was der Rechenkern kann und was die
  App davon anbietet. Dieser Abstand ist der gefährlichste Zustand im Projekt:
  Er sieht in den Tests grün aus und ist trotzdem nicht da. Am größten ist er
  beim Zweirichtungszähler — `PulseCore` rechnet die Einspeisung seit dem
  ersten Tag, der Entwurf zeigt sie, die App kennt sie nicht.

## 0.21.4 — 2026-08-06

Die erste Runde, in der die zurückgeholten Screenshots wieder Fehler gefunden
haben — beide in derselben Stunde, in der sie wieder sichtbar wurden.

### Behoben
- **„Kosten seit Jahresbeginn" stimmte nicht.** Auf der Karte des Gaszählers
  stand am 6. August der Zeitraum „1. Januar bis 1. Mai" — richtig, denn seit
  dem 1. Mai gab es keine Ablesung. Zwei Zeilen tiefer standen 1.399,41 €
  „seit Jahresbeginn". Drei Monate, die der Betrag nicht enthält. Die Zahl war
  richtig, der Satz darüber nicht; es ist die wiederkehrende Fehlerklasse aus
  CLAUDE.md, diesmal in der Beschriftung statt in der Rechnung. Die Zeile
  nennt jetzt denselben Ausschnitt wie die Kopfzeile der Karte.
- **Die Bildschirmfotos hingen voneinander ab.** `-pulse-reset` wurde in
  `OverviewView` ausgewertet, und SwiftUI baut einen Tab erst, wenn er
  sichtbar wird. Ein Lauf, der direkt im Zähler-Schirm begann, erreichte diese
  Stelle nie und zeigte, was der vorherige Start hinterlassen hatte — nach
  `-pulse-empty` also „Noch kein Zähler", während die Übersicht drei Zähler
  führte. Der Verlauf-Schirm war nur durch die Reihenfolge zufällig richtig.
  Der Ausgangszustand entsteht jetzt in `LaunchFixture` beim Start der App.

### Entschieden
- **Ein fehlgeschlagener Ausgangszustand bricht ab, statt weiterzulaufen.**
  Stillschweigend leer weiterzumachen sähe auf dem Bild aus wie der Kaltstart
  — also wie ein gültiger Zustand. Genau daran wäre der Fehler wieder
  unsichtbar. Erreichbar ist die Stelle nur über einen Startschalter, den kein
  Nutzer setzt.

### Geändert
- Der Klick-Dummy zeigt jetzt ebenfalls Stand und Kosten auf der Karte. Beide
  Zeilen gab es bisher nur in der App — und es waren ausgerechnet die zwei,
  an denen der Beschriftungsfehler saß. Im Entwurf hätte ihn niemand sehen
  können, weil es sie dort nicht gab.
- Die Einspeisung steht im Entwurf **über** den Kosten, nicht darunter: Der
  Betrag ist bereits netto. Darunter zöge jeder Leser die Vergütung ein
  zweites Mal ab.
- Der Hinweis über der Übersicht sagt im Entwurf „Vorschau" statt „Prognose",
  wie in der App.

## 0.21.3 — 2026-08-06

Keine Produktänderung — eine Prüfung, die verlorengegangen war, ist wieder da.

### Hinzugefügt
- **Die Screenshots jedes Laufs liegen jetzt im Zweig `screenshots`.** Bisher
  gab es sie nur als Artefakt, und an ein Artefakt komme ich aus der
  Entwicklungsumgebung heraus nicht heran: Der Weg zur GitHub-API ist dort
  gesperrt, git dagegen läuft. Damit war die produktivste Prüfung dieses
  Projekts stillschweigend ausgefallen — sieben der bisher gefundenen
  Darstellungsfehler hat kein Test gefunden, sondern der Blick auf ein Bild.
- `scripts/publish-shots.sh` verkleinert die zehn Bilder auf 1000 Pixel Höhe
  und legt sie als JPEG ab. Aus über drei Megabyte werden rund dreihundert
  Kilobyte; für Anordnung, Kontrast und Zahlen reicht das bei weitem.

### Entschieden
- **Der Zweig trägt immer nur einen Stand.** Ein frisch angelegtes Repository
  wird mit `--force` geschoben, damit weder Historie noch Objektlager wachsen.
  Wer einen älteren Stand braucht, findet ihn im Artefakt des jeweiligen Laufs.

### Behoben
- Die README behauptete, Verlauf und Zähler seien Platzhalter. Das stimmt seit
  0.18.0 nicht mehr — beide sind vollwertige Bildschirme.

## 0.21.2 — 2026-08-06

### Behoben
- **Die Erinnerungen ließen sich immer noch nicht übersetzen — und meine
  Diagnose in 0.21.1 war falsch.** Nicht die Rückgabewerte waren das Problem,
  sondern das `@MainActor` am Typ `Reminders`. Es ordnet `center` dem
  Hauptakteur zu, und weil die Methoden von `UNUserNotificationCenter` nicht
  isoliert sind, wird **jeder** Aufruf zum Grenzübertritt — auch der, bei dem
  nur der Empfänger hinübergereicht wird (`sending 'self.center' risks causing
  data races`). Die Rückrufe aus 0.21.1 haben ein Symptom kuriert.

### Entschieden
- **Ein Typ, der nur eine threadsichere Systemschnittstelle umhüllt, bekommt
  keine Isolation.** `UNUserNotificationCenter` ist selbst threadsicher;
  `@MainActor` darüberzulegen macht die Sache nicht sicherer, sondern nur
  unübersetzbar. `Reminders` reicht jetzt ausschließlich `Sendable`-Werte
  heraus — Status als Aufzählung, Anzahl als Zahl —, und die Oberfläche wartet
  vom Hauptakteur aus darauf. Die Begründung steht im Kopf der Datei, damit
  der dritte Anlauf nicht nötig wird.

## 0.21.1 — 2026-08-06

### Behoben
- **Die Erinnerungen aus 0.21.0 ließen sich nicht übersetzen.**
  `UNNotificationSettings` und `[UNNotificationRequest]` sind nicht
  `Sendable`; unter Swift 6 dürfen sie die Isolationsgrenze nicht überqueren,
  und ein `await` vom Hauptakteur aus scheitert daran. Jetzt läuft beides über
  den Rückruf, und herüber kommt nur, was unbedenklich ist: der Status als
  Aufzählung und die Anzahl als Zahl.

Diese Fehlerklasse kann ich unter Linux nicht finden — `UserNotifications`
gibt es dort nicht, und `PulseCore` allein zu übersetzen sagt darüber nichts.
Sie fällt erst auf dem macOS-Läufer auf.

## 0.21.0 — 2026-08-06

**Erinnerungen.** Der Retention-Motor: Ohne sie kommt niemand nach drei
Monaten zurück, und dann laufen alle anderen Funktionen leer — der Verlauf
bleibt kurz, der Vorjahresvergleich entsteht nie, die Abschlagsvorschau rechnet
ins Blaue.

### Hinzugefügt
- `ReminderEngine` in `PulseCore` mit neun Prüfungen. Rechnet aus, wann ein
  Zähler wieder abgelesen werden sollte.
- Lokale Mitteilungen, abends um 18 Uhr im Rhythmus jedes Zählers. Ohne Konto,
  ohne Server, ohne Netz.
- Ein Schalter auf dem Zähler-Schirm statt in Einstellungen: Dort denkt der
  Nutzer ohnehin über Ableserhythmen nach, und die Systemfrage nach Erlaubnis
  wird nur **einmal** gestellt — sie soll in einem Moment kommen, in dem klar
  ist, wofür.
- Nach jeder Ablesung werden die Termine neu geplant. Eine stehengebliebene
  alte Mitteilung käme sonst, wenn längst nichts mehr fällig ist.

### Entschieden
- **Fälligkeit auf dem Schirm und Erinnerung rechnen jetzt über dieselbe
  Funktion.** Vorher waren es zwei getrennte Rechnungen für dieselbe Frage;
  die laufen früher oder später auseinander, und dann kommt eine Mitteilung,
  während auf dem Schirm nichts fällig ist. Ein Test prüft an sieben Tagen um
  die Grenze herum, dass beide dieselbe Antwort geben.
- **Ein überfälliger Zähler wird heute erinnert, nicht rückwirkend.** Eine
  Mitteilung für einen vergangenen Tag lässt sich nicht zustellen — der Zähler
  bliebe für immer stumm, und zwar genau der, der die Erinnerung am nötigsten
  hat.
- **Höchstens 32 Termine gleichzeitig.** iOS nimmt 64 lokale Mitteilungen an;
  wer sehr viele Zähler führt, bekäme sonst irgendwann keine mehr, und welche
  wegfallen, entschiede das System statt der App.
- **18 Uhr, nicht morgens.** Ein Zählerstand wird abgelesen, wenn jemand zu
  Hause ist und in den Keller gehen kann.

### Behoben
- `ReminderEngine.schedule` war als verkettete Ausdrucksfolge geschrieben, an
  der der Typprüfer über zwei Minuten rechnete und dann aufgab. Mit benannten
  Zwischenschritten übersetzt dasselbe in Sekunden.

## 0.20.0 — 2026-08-06

### Hinzugefügt
- **Menge / Kosten** in der Verlaufstabelle. Der Umschalter erscheint nur,
  wenn für den Zähler ein Tarif hinterlegt ist — ohne Preise gäbe es nichts
  umzuschalten.
- Nur in der Tabelle, nicht im Diagramm: Ein Balken, der mal kWh und mal Euro
  bedeutet, sieht in beiden Fällen gleich aus. In einer Tabelle steht die
  Einheit in der Kopfzeile, und der Oberflächentest prüft genau das —
  Euro-Beträge dürfen nicht unter „Verbrauch" stehen.
- Abschnitte ohne verwertbaren Tarif bleiben in der Kostenspalte leer statt
  null, und die Summe darunter sagt „unvollständig". Eine Null wäre die
  Aussage „hat nichts gekostet", die niemand gemacht hat.

### Behoben
- **Jeder Push löste zwei CI-Läufe aus**, solange eine Pull-Request offen war:
  einmal `push`, einmal `pull_request`. Beide lagen in verschiedenen
  Nebenläufigkeitsgruppen und bauten dieselbe App zweimal. Die Gruppe ist
  jetzt auf den Zweignamen normalisiert.

### Geändert
- Der Arbeitszweig ist nach dem Zusammenführen frisch von `main` aufgesetzt.

_Am Klick-Dummy ändert sich nichts: Menge und Kosten gibt es dort seit 0.9.
Diesmal hat die App aufgeholt, nicht der Entwurf._

## 0.19.1 — 2026-08-06

### Behoben
- **Der Abschlag auf der Karte war zu klein.** Bei 160 € im Monat stand dort
  „Abschlag 1.146,74 € im Jahr" — sieben Zwölftel. Ich hatte
  `runningBillingPeriod` verwendet, das den Zeitraum **am heutigen Tag
  abschneidet**, wo der ganze Abrechnungszeitraum gemeint war. Die Folge war
  nicht nur eine falsche Beschriftung: Hochgerechnete Jahreskosten wurden
  gegen sieben Monate Abschlag gestellt, und aus einem Guthaben wurde eine
  Nachzahlung. Es ist die wiederkehrende Fehlerklasse aus CLAUDE.md in neuem
  Gewand — eine Aussage über einen Zeitraum, den die Zahl nicht abdeckt.
  `MeteringPoint.currentBillingPeriod(on:)` liefert jetzt den ganzen Zeitraum,
  und der Unterschied zu `runningBillingPeriod` ist in beiden Dokumentationen
  benannt.
- **Ein volles Jahr ergab 12,03 Monate.** `lengthInMonths` zählte über
  `dayCount` und damit beide Grenztage. Ein Abrechnungszeitraum ist aber
  halboffen — der nächste Stichtag gehört zum Folgejahr, so wie
  `BillingCycle.period(containing:)` ihn auch liefert. Aus zwölf Abschlägen zu
  160 € wurden dadurch 1.925,26 € statt 1.920 €. Auf einer Karte, die Geld
  anzeigt, ist das der Unterschied zwischen „stimmt" und „stimmt fast".

### Geändert
- Die Testvorrichtung für Abrechnungsjahre lief bisher vom 1. Januar bis zum
  **31. Dezember** und damit über 364 Tage. Jetzt bis zum 1. Januar, wie jede
  Verbrauchsrechnung im Projekt einen Zeitraum versteht. Neun Erwartungswerte
  haben sich dadurch um einen Tag verschoben; alle neun sind nachgerechnet:
  365 Tage × 10 kWh = 3.650, davon 30 % = 1.095 €, gegen 1.200 € Abschlag
  ergibt 105 € Guthaben.
- Der Gas-Abschlag in den Beispieldaten steht auf 230 € statt 160 € — bei
  diesem Verbrauch war der alte Wert unrealistisch niedrig und erzeugte eine
  Nachzahlung, die nur aus der Vorrichtung stammte.

Zwei neue Prüfungen halten die Unterscheidung fest, damit sie nicht wiederkommt.

## 0.19.0 — 2026-08-06

Der Abschlag — und damit die Frage, für die Verbrauchszahlen überhaupt
interessieren: Kommt am Jahresende Geld zurück oder muss ich nachzahlen?

### Hinzugefügt
- **Abschlag und Abrechnungsjahr im Zähler-Editor.** Der Monat, in dem das
  Abrechnungsjahr des Versorgers beginnt, ist wählbar — bei vielen ist es
  nicht der Januar.
- **„≈ 168 € Nachzahlung" auf der Karte**, sobald ein Abschlag hinterlegt ist.
  Das „≈" steht dort, weil die Zahl den restlichen Zeitraum hochrechnet und
  nicht misst (Produktprinzip 7).
- Ein Oberflächentest, der die längste Kette der App abgeht: Ablesungen →
  Hochrechnung → Kosten je Tarifabschnitt → gegen die Abschläge. Er prüft
  zusätzlich, dass der Wasserzähler **ohne** Abschlag auch keine Vorschau
  zeigt — eine Null wäre dort eine Aussage, die niemand gemacht hat.
- Der Abschlag lässt sich auch im Klick-Dummy eintragen. Gegengerechnet: 60 €
  mehr im Monat ergeben 720 € mehr im Jahr, und aus 90 € Guthaben werden 810 €.

### Entschieden
- **Ohne Abschlag bekommt ein Zähler keinen Abrechnungsrhythmus.** Sonst
  entstünden Zeiträume, gegen die es nichts zu rechnen gibt. Bei den
  Beispieldaten läuft Wasser deshalb bewusst ohne — so stehen beide Fälle auf
  demselben Bildschirmfoto nebeneinander.

## 0.18.0 — 2026-08-05

Preise und Kosten. Der Rechenkern (`CostEngine`) stand seit 0.4 und war
getestet — es fehlte der Weg, ihm überhaupt einen Preis mitzuteilen.

### Hinzugefügt
- **Arbeitspreis und Grundpreis im Zähler-Editor.** Zwei Zahlen von der
  Jahresrechnung, freiwillig: Ohne sie funktioniert die App vollständig, nur
  ohne Beträge. Deshalb steht der Abschnitt unten und blockiert nichts.
- **Zustandszahl und Brennwert bei Gas.** Gas wird in m³ gemessen und in kWh
  abgerechnet; ohne diese beiden Zahlen lässt sich aus einem Zählerstand kein
  Betrag bilden. Der Rechenkern verweigert die Auskunft — die Oberfläche sagt
  jetzt, was fehlt, statt ein leeres Feld zu zeigen.
- **Kosten seit Jahresbeginn** auf jeder Übersichtskarte, sobald ein Preis
  hinterlegt ist.
- Die Beispieldaten haben Preise in der Größenordnung einer deutschen
  Jahresrechnung, damit die Kosten auf den Bildschirmfotos auch zu sehen sind.
- Zwei Oberflächentests: Steht mit hinterlegtem Tarif ein Betrag auf der
  Karte, und lässt sich beim neuen Zähler ein Preis eintragen?

### Behoben
- **Der Klick-Dummy konnte die Art eines Zählers nicht erkennen.** Sie stand
  nur implizit in der Kennung, nicht als Feld. Der neue Editor fiel deshalb
  bei jedem Zähler auf „Strom" zurück und zeigte beim Gaszähler weder
  Zustandszahl noch Brennwert. Jeder Beispielzähler trägt seine Art jetzt
  ausdrücklich.

## 0.17.0 — 2026-08-05

Der kalte Start — die App einmal so durchgegangen, wie ein neuer Nutzer sie
antrifft: ohne einen einzigen Zähler, ohne eine einzige Ablesung. Bis hierher
hat diesen Zustand weder ein Test noch ein Bildschirmfoto je gesehen, weil
jeder Lauf mit zwei Jahren Beispielhistorie begann.

Vier Fehler, alle im ersten Bildschirm, den jemand zu Gesicht bekommt.

### Behoben
- **Die Statuszeile meldete „Alles im Rahmen. Alle Zähler sind aktuell." für
  einen Zähler, der noch nie abgelesen wurde.** Die Bedingung fragte nach den
  Tagen seit der letzten Ablesung; ohne Ablesung gibt es die nicht, und der
  Fall fiel stillschweigend durch. Jetzt steht dort „… wurde noch nie
  abgelesen. Trag den ersten Stand ein, dann fängt der Verlauf an."
- **Auf der Karte stand aus demselben Grund „Noch kein Vergleichswert"**,
  obwohl „Noch nie abgelesen" gemeint war.
- **Der Verlauf zeigte „0" für einen Zähler ohne Historie** — eine Zahl, die
  aussieht wie eine Messung und keine ist. Jetzt steht dort, was fehlt: die
  erste Ablesung, oder die zweite.
- **Der leere Zustand bot „Beispieldaten anlegen" als einzige Möglichkeit an.**
  Entwicklersprache an genau der Stelle, an der ein neuer Nutzer zum ersten
  Mal etwas tut. Die Hauptsache heißt jetzt „Ersten Zähler anlegen" und führt
  direkt dorthin; die Beispieldaten bleiben als kleine Nebenzeile.

### Hinzugefügt
- Mit genau einer Ablesung sagt die Karte, was fehlt: „Der Verbrauch ergibt
  sich aus zwei Ablesungen." Für den Rechenkern sind null und eine Ablesung
  derselbe Fall — für den Nutzer nicht.
- Zwei Oberflächentests, die den ganzen Weg abgehen: leerer Start, Zähler
  anlegen, erste Ablesung eintippen, und die Karte muss den zweiten Schritt
  nennen. Das ist Produktprinzip 1 als ausführbare Prüfung.
- Bildschirmfotos vom leeren Zustand (`-pulse-empty`).
- Derselbe leere Zustand im Klick-Dummy, erreichbar durch Löschen aller
  Zähler. Vorher blieb die Übersicht dann einfach leer.

### Geändert
- Das Zeitlimit der CI steht auf 45 Minuten. Zehn Bildschirmfotos brauchen auf
  dem Läufer gut 16 Minuten, und mit dem Build wurden die 30 zu knapp.

## 0.16.1 — 2026-08-05

### Behoben
- **Ein deutsches Anführungszeichen zerriss eine Swift-Zeichenkette.** In
  `„Strom"` schließt das gerade Anführungszeichen das Literal — richtig ist
  das typografische `„Strom“`. Die App ließ sich nicht übersetzen; gefunden
  hat es der CI-Lauf nach zwei Minuten auf einem gemieteten macOS-Läufer.

### Hinzugefügt
- `scripts/check-strings.py`, als erster Schritt in der CI. Prüft in einer
  Sekunde, was sonst einen ganzen Lauf kostet. Die erste Fassung zählte nur
  Anführungszeichen je Zeile und fand den eigenen Anlassfall nicht — die
  Zeichen ergänzten sich zufällig zu einer geraden Zahl. Jetzt wird geprüft,
  was tatsächlich schiefgeht: ein `„` innerhalb einer Zeichenkette, das von
  einem geraden Anführungszeichen geschlossen wird.

Ohne Compiler für iOS-Code unter Linux ist die CI der einzige Ort, an dem
solche Fehler auffallen — und der teuerste. Diese Klasse fällt jetzt vorher.

## 0.16.0 — 2026-08-05

Der **Zähler**-Tab ist kein Platzhalter mehr. Damit ist die App zum ersten Mal
ohne Beispieldaten benutzbar — vorher kam man überhaupt nur über
„Beispieldaten anlegen" zu einem Zähler, und Produktprinzip 1 (60 Sekunden bis
zur ersten Ablesung) hing an einer Ansicht, die es nicht gab.

### Hinzugefügt
- Zähler anlegen, umbenennen und einordnen. Name und Art genügen; Einheit,
  Stellenzahl und Ableserhythmus sind aus der Art vorbelegt.
- Archivieren und Löschen als getrennte Wege. Archivieren nimmt den Zähler aus
  der Übersicht und behält alles; Löschen entfernt auch die Ablesungen und
  fragt vorher nach.
- Ein Oberflächentest, der einen Zähler anlegt und in der Liste wiederfindet.
- Bildschirmfotos vom Zähler-Tab (`-pulse-zaehler`).

### Behoben
- **Der Klick-Dummy stürzte ab, sobald ein Zähler ohne Ablesung existierte.**
  `lastReading` lief über eine leere Liste und gab `undefined` zurück, woran
  die nächste Zeile zerbrach. Aufgefallen ist das erst jetzt: Bis eben hatte
  jeder Zähler im Entwurf zwei Jahre Historie, und den Fall „noch nie
  abgelesen" gab es schlicht nicht — obwohl er für jeden neuen Nutzer der
  erste ist.

### Entschieden
- **Die Art eines Zählers lässt sich nicht mehr ändern, sobald Ablesungen
  vorliegen.** Sie bestimmt die Einheit, und ein nachträglicher Wechsel würde
  bestehende Werte stillschweigend umdeuten — aus 8.285 m³ Gas würden 8.285
  kWh Strom. Die Oberfläche sagt, warum es gesperrt ist, statt es nur zu
  verbieten.

## 0.15.1 — 2026-08-05

### Behoben
- **Das Verlaufsdiagramm zeigte zwölf Balken, wo es vier gibt.** Hinter jedem
  Monat stand eine hohe helle Spur. Auf dem ersten Bildschirmfoto des Verlaufs
  las sich das Jahr dadurch als zwölf Balken, von denen vier farbig waren —
  tatsächlich hat der Gaszähler seit Mai keine Ablesung. Statt der Spuren gibt
  es jetzt eine durchgehende Grundlinie; ein Abschnitt ohne Ablesung zeigt
  nichts. Der ausgewählte Abschnitt bekommt eine blasse Fläche, damit ein Tipp
  auf einen leeren Monat sichtbar bleibt.
- Die Legende erklärte „unvollständig" auch dann, wenn kein Abschnitt
  angebrochen war, und nannte in der Jahresansicht ein Vorjahr, das dort als
  eigener Balken steht.

Wieder ein Fund aus dem Bild, nicht aus einem Test: Die Zahlen waren richtig,
die Form log.

## 0.15.0 — 2026-08-05

Alle Zahlen und der Export — die Ansicht, nach der du früh gefragt hattest
(„gesamtzahl pro jahr, monat, quartal und exports").

### Hinzugefügt
- Umschalter **Diagramm / Alle Zahlen** im Verlauf. Die Tabelle listet jeden
  Abschnitt mit Verbrauch und Gesamtsumme; unvollständige Abschnitte tragen
  darunter den Ausschnitt, den sie wirklich abdecken.
- **Export als CSV**, Ablesungen und Auswertung getrennt, über das Teilen-Blatt
  des Systems. Semikolon und Dezimalkomma, damit Excel die Datei im
  deutschsprachigen Raum ohne Importdialog öffnet.
- `TableExport` in `PulseCore` mit sieben Prüfungen. Nachgestellte Nullen
  bleiben stehen (`8000,250`), weil ein exportierter Zählerstand ein Beleg ist
  und die Genauigkeit des Geräts zeigen soll.
- Bildschirmfotos vom Verlauf, in Hell und Dunkel (`-pulse-verlauf`).

### Behoben
- **Die Jahresansicht hätte einen einzelnen Balken gezeigt.** Ein Jahr hat
  genau einen Abschnitt — als Diagramm ist das keine Aussage. „Jahr" stellt
  jetzt drei Jahre nebeneinander.
- **Der Export des Klick-Dummys wich von dem der App ab**: andere Spalten,
  abgekürzte Monatsnamen und eine Kreuztabelle statt einer Zeile je Abschnitt.
  Jetzt liefern beide dieselbe Datei. Die Kreuztabelle liest sich schöner,
  kann aber je Zelle nicht sagen, ob ein Abschnitt vollständig ist — und genau
  daran hing in diesem Projekt bisher jeder Fehler.
- **„Zählwerk" stand in der Kopfzeile des Exports.** Eine exportierte Datei
  ist ein Dokument, und für Dokumente gilt dieselbe Wortliste wie für die
  Oberfläche (CLAUDE.md, Abschnitt „Sprache").

## 0.14.1 — 2026-08-05

### Behoben
- **Im Erfassungsschirm stand eine handbreite Leere zwischen Zählwerk und
  Ziffernblock.** Die Korrektur aus 0.13.1 hatte den Block nach unten
  geschoben, das Zählwerk aber oben kleben lassen — ein Fehler gegen einen
  anderen getauscht. Das Zählwerk schwebt jetzt zwischen zwei Abstandhaltern
  über dem Block, wie die Anzeige über den Tasten eines Rechners.

Nur die App. Der Klick-Dummy hatte den Fehler nie: Sein Bogen ist so hoch wie
sein Inhalt, während die App den Schirm ganz füllt und den Platz verteilen
muss.

## 0.14.0 — 2026-08-05

Der **Verlauf** ist kein Platzhalter mehr.

### Hinzugefügt
- Verlauf-Tab in der App: Zählerwahl, Balken je Monat / Quartal / Jahr mit dem
  Vorjahr als Marke im Balken, und die Liste aller Ablesungen hinter einer
  Zeile. Ein Tipp auf einen Abschnitt öffnet den Vergleich über drei Jahre.
- `PeriodEngine` in `PulseCore`: zerlegt eine Zeitreihe in Monate, Quartale
  und Jahre und vergleicht denselben Abschnitt über mehrere Jahre. 14 neue
  Prüfungen.
- Zwei Oberflächentests für den Verlauf.

### Behoben
- **Ein laufender Monat wurde gar nicht verglichen.** Der Klick-Dummy schrieb
  „wird nachgetragen, sobald der Monat abgeschlossen ist" — richtig gerechnet,
  aber genau der Monat, der den Nutzer am meisten interessiert, blieb leer.
  Jetzt wird das Vorjahr auf denselben Ausschnitt beschnitten: halber Februar
  gegen halben Februar, und darunter steht, welcher Ausschnitt gemeint ist.
- **Eine Zahl konnte aus einer Geraden über ein ganzes Jahr stammen und sah
  aus wie eine Messung.** Wer am 1. Februar 2025 und dann erst am 1. Februar
  2026 abliest, bekam für den Februar 2025 einen anteilig ausgeschnittenen
  Jahresschnitt — formal gedeckt, inhaltlich nichts. Ergebnisse führen jetzt
  den größten benutzten Ableseabstand mit, und ein Abschnitt gilt nur als
  vergleichbar, wenn er auf Ablesungen aus seiner Nähe beruht. Die Grenze
  liegt beim Doppelten der Zeitraumlänge — großzügig genug für jeden üblichen
  Ableserhythmus.

Beides fand derselbe Test, der eigentlich nur prüfen sollte, dass ein Jahr mit
halben Daten nicht wie ein sparsames Jahr aussieht.

## 0.13.1 — 2026-08-05

Drei Fehler, alle drei erst auf dem ersten Bildschirmfoto des
Erfassungsschirms zu sehen — er wurde in 0.13.0 überhaupt zum ersten Mal
automatisch fotografiert.

### Behoben
- **„Sichern" war im dunklen Erscheinungsbild kaum zu lesen.** Die gesperrte
  Schaltfläche legte die Akzentfarbe mit 32 % Deckkraft unter helle Schrift —
  im Dunkeln ergab das dunkelbraun auf braun. Gesperrt heißt jetzt gedämpfte
  Fläche mit gedämpfter Schrift, in beiden Erscheinungsbildern lesbar. Im
  Klick-Dummy steckte derselbe Fehler.
- **Ziffernblock und „Sichern" standen im oberen Drittel**, darunter ein
  Drittel leere Fläche. Genau verkehrt herum für einen Schirm, den man
  einhändig im Keller bedient: Was angetippt wird, gehört in Daumenreichweite.
  Beides sitzt jetzt am unteren Rand, auf kleinen Geräten greift weiter der
  Bildlauf.
- **Derselbe Zählerstand stand in zwei Schreibweisen in der App**: auf der
  Übersicht „8.285,1 m³", im Erfassungsschirm „8.285,100 m³". Die Übersicht
  schreibt ihn jetzt mit den Nachkommastellen des Zählwerks — so, wie er am
  Gerät abzulesen ist. Der Klick-Dummy machte das schon richtig.

## 0.13.0 — 2026-08-05

### Behoben
- **Die große Zahl auf der Übersicht sagte nicht, welchen Zeitraum sie
  abdeckt.** Beim Gaszähler stand „1.181 m³" — dieselbe Form wie „1.607 kWh"
  beim Strom, obwohl die eine Zahl bis Anfang Mai reicht und die andere bis
  August. Wer beide Karten untereinander sieht, vergleicht zwangsläufig, und
  der Vergleich war falsch. Gefunden wurde das nicht von einem Test, sondern
  beim Ansehen des Bildschirmfotos: Beide Zahlen waren für sich korrekt
  gerechnet. Es ist der siebte Fall derselben Fehlerklasse und der erste, der
  nicht im Rechenkern lag, sondern in der Anzeige.
- Ohne Daten für das laufende Jahr stand eine „0" da. Jetzt steht ein Strich —
  unbekannt ist nicht dasselbe wie nichts verbraucht.

### Hinzugefügt
- Über jeder großen Zahl steht der Zeitraum, den sie tatsächlich abdeckt:
  „Seit Jahresbeginn", sonst als Spanne wie „1. Januar bis 1. Mai".
  Ausgeschrieben statt als Vorbehalt, weil vier Tage Rückstand normal sind und
  drei Monate nicht — als Spanne ist der Unterschied ohne ein Wort zu sehen.
- Ein „≈" vor Werten, die nicht ausschließlich auf gemessenen Ständen beruhen
  (Produktprinzip 7). Kleiner und blasser als die Zahl gesetzt: Bei einem
  länger geführten Zähler ist es fast immer da, weil der Wert zum 1. Januar
  zwischen zwei Ablesungen liegt.
- `ConsumptionResult.coverage` in `PulseCore` — als Aufzählung, damit ein
  vollständiger `switch` die Oberfläche zwingt, den unvollständigen Fall zu
  beschriften. Ein `if isComplete` ließ sich vergessen, ein fehlender Fall
  übersetzt nicht. Sechs neue Prüfungen, darunter der Gasfall von oben.
- Bildschirmfotos zeigen jetzt auch den Erfassungsschirm, in Hell und Dunkel
  (`-pulse-capture`). Er ist der wichtigste Schirm der App und war auf keinem
  automatisch erzeugten Bild zu sehen.

### Geändert
- Die Bildschirmfotos starten die App mit frischen Beispieldaten. Vorher zeigten
  sie, was die Oberflächentests im Simulator hinterlassen hatten.

## 0.12.0 — 2026-08-05

### Hinzugefügt
- Der Erfassungsscreen. Zählwerk in Geräteoptik — weiße Vorkomma-, rote
  Nachkommastellen auf dunklem Grund —, eigener großer Ziffernblock statt
  Systemtastatur, Datum auf heute vorbelegt.
- Live-Plausibilisierung während der Eingabe: „Entspricht 312 kWh in 31 Tagen
  — normal für dich" oder bei einer Stelle zu viel „rund 11× dein üblicher
  Verbrauch. Stimmt die Zahl?". Ein Hinweis, keine Blockade — ein auffälliger
  Wert kann richtig sein, und die App weiß es nicht besser als der Mensch vor
  dem Zähler.
- „Vom letzten Stand übernehmen", damit sich die unveränderten führenden
  Ziffern nicht abtippen lassen müssen.

### Geändert
- Die Beispieldaten umfassen drei Zähler statt einem, davon einer bewusst
  überfällig. Nur so lassen sich Fällig-Zustand, Hinweiszeile und der
  Erfassungsfluss überhaupt prüfen.
- Zwei zusätzliche Oberflächentests: Wird ein überfälliger Zähler gemeldet, und
  räumt eine Ablesung den Hinweis wieder weg?
- Die Oberflächentests setzen den Bestand beim Start zurück. Ohne das hing
  jeder Test davon ab, was der vorherige hinterlassen hat — der Erfassungstest
  trug beim obersten Zähler einen Stand ein und räumte damit genau die
  Fälligkeit weg, die der nächste erwartete. Ein grüner Lauf hätte dann nichts
  über den einzelnen Fall ausgesagt.
- `deleteEverything` im Repository. Wird für den Rücksetzer gebraucht und
  gehört später ohnehin in die Einstellungen.

Warum dieser Screen vor allen anderen kommt: Der Nutzer steht im Keller, bei
schlechtem Licht, vielleicht mit einer Lampe in der Hand. Entsteht hier
Reibung, hört er nach drei Monaten auf — und alle anderen Funktionen werden
wertlos.

---

## 0.11.1 — 2026-08-05

### Behoben
- Die Simulator-Auswahl verglich Gerätenamen als Text. Dabei steht
  „iPhone SE" hinter „iPhone 16 Pro", weil S hinter 1 kommt — acht Läufe lang
  wurde die App auf dem kleinsten verfügbaren Bildschirm gebaut, getestet und
  fotografiert. Jetzt wird die Zahl im Namen ausgewertet.

Gefunden hat das kein Test, sondern der Blick auf den Screenshot: 750 × 1334
Pixel sind kein aktuelles Gerät. Genau dafür steht der Schritt in der
Prüfliste.

_Keine Änderung am Produkt. Tests unverändert._

---

## 0.11.0 — 2026-08-04

### Hinzugefügt
- `PulseUI`, das Design-System: Farben, Textstile und die Kernkomponenten aus
  `03-ux-konzept.md`. Die Palette steht als Code statt in einem Asset-Katalog —
  sie bleibt damit lesbar, versionierbar und in einer Zeile vergleichbar mit
  dem Klick-Dummy.
- Die Übersicht zeigt jetzt Zähler-Karten mit Verlaufslinie, Vorjahresvergleich
  und Statuszeile in ganzen Sätzen, statt einer Liste aus Textzeilen.

### Geändert
- Die Neutralen sind warm gebrochen statt kalt-grau. Die Zählerfarben sind die
  eigentliche Palette und machen die App ohne Text lesbar; ein kaltes Grau
  konkurriert mit ihnen.
- Sämtliche Textstile leiten sich von Systemstilen ab und wachsen deshalb mit
  Dynamic Type. Feste Punktgrößen wären bequemer und zerbrächen bei der
  größten Stufe — also genau dort, wo Barrierefreiheit anfängt.
- Die Beispieldaten umfassen gut zwei Jahre statt zweier Ablesungen. Mit zwei
  Werten sähe die Karte fertig aus und wäre doch leer: keine Verlaufslinie,
  kein Vorjahresvergleich.
- Der Oberflächentest prüft jetzt den Vorjahresvergleich statt nur den
  Jahresverbrauch. Er entsteht nur, wenn Speicher und Rechenkern über zwei
  Jahre Historie zusammenspielen.

_82 Tests in PulseCore, 10 in PulseData, beide Oberflächentests. Screenshots in
Hell und Dunkel liegen dem Lauf bei._

---

## 0.10.2 — 2026-08-04

Die erste Fassung, die auf einer Apple-Plattform tatsächlich gebaut, getestet
und gestartet wurde. Die CI auf einem macOS-Läufer fand innerhalb einer Stunde
fünf Fehler, die unter Linux allesamt unsichtbar waren.

### Behoben
- `Schema` lag als statische Konstante vor. `Schema` ist nicht `Sendable`,
  also unter Swift 6 global geteilter Zustand — `PulseData` ließ sich nicht
  übersetzen. Jetzt berechnet.
- Der Wiederherstellungstest legte einen zweiten Speicher im selben Prozess an
  und brachte ihn zu Fall. SwiftData verträgt das nicht, auch nicht mit
  unterschiedlichen Namen. Der leere Zustand entsteht jetzt durch Löschen —
  und belegt nebenbei, dass die Löschregel die Ablesungen mitnimmt.
- Die Oberflächentests waren nicht an den Hauptakteur gebunden. Die
  XCUITest-Schnittstellen sind es unter Swift 6, das Testziel ließ sich nicht
  bauen.
- Das Datum stand als `2026-08-04` auf dem Schirm — die Rohform des
  Kalendertags und damit technisches Vokabular. Jetzt „4. August 2026".

### Geändert
- Der Screenshot-Schritt übersetzte die App ein zweites Mal vollständig, für
  dasselbe Programm. Test- und Screenshot-Schritt teilen sich jetzt das
  Ableseverzeichnis; Hell und Dunkel entstehen durch Neustarten statt
  Neubauen. Spart auf einem gemieteten macOS-Läufer mehrere Minuten je Lauf.

_82 Tests in PulseCore, 10 in PulseData, beide Oberflächentests — alle grün auf
macOS. Die App startet im Simulator und zeigt einen vom Rechenkern ermittelten
Verbrauch._

---

## 0.10.1 — 2026-08-04

### Hinzugefügt
- CI auf einem macOS-Läufer. Sie übersetzt und testet, was auf einem
  Linux-Rechner nicht übersetzt werden kann: `PulseData`, das App-Target und
  die Skripte. Screenshots beider Erscheinungsbilder werden abgelegt.

### Behoben
- `PulseCore` gab keine Mindestversion der Plattform an. SwiftPM nahm auf
  Apple-Plattformen daraufhin eine sehr alte an, unter der `Identifiable` als
  nicht verfügbar gilt — das Paket ließ sich auf einem Mac gar nicht
  übersetzen. Unter Linux gibt es keine Verfügbarkeitsprüfung, deshalb fiel es
  dort nie auf. Der erste Fund der neuen CI, und ein gutes Argument für sie.

_82 Tests grün._

---

## 0.10.0 — 2026-08-04

### Hinzugefügt
- App-Gerüst: iOS-Target mit Tab-Navigation, das die Übersicht aus dem
  gespeicherten Bestand lädt und den Verbrauch über den Rechenkern ermittelt.
  Es belegt, dass App, Persistenz und Domäne zusammenspielen — gestaltet wird
  später mit `PulseUI`.
- Das Xcode-Projekt wird aus `project.yml` erzeugt statt eingecheckt. Eine
  `.xcodeproj` sortiert bei jeder Änderung Zeilen um und macht das
  Zusammenführen unnötig schwer; die Beschreibung ist lesbar und wiederholbar.
- Automatisierung in `scripts/`: `setup-mac.sh` richtet die Umgebung ein,
  `test.sh` prüft Pakete und App im Simulator, `run.sh` startet die App und
  legt einen Screenshot ab. Damit lässt sich ein Ergebnis auch ohne Blick auf
  den Bildschirm beurteilen.
- Zwei Oberflächentests: Startet die App, und erzeugt das Anlegen von
  Beispieldaten einen berechneten Wert? Ein Übersetzungsfehler fällt beim Bauen
  auf, ein Absturz beim Start nicht.
- Skill `xcode-workflow` mit dem Ablauf, den erwartbaren Fehlerbildern und dem
  Weg, CloudKit später einzuschalten.

### Geändert
- Die Prüfliste beginnt jetzt mit `git status`. Ein auf einen älteren Stand
  zurückgefallenes Arbeitsverzeichnis sah schon einmal wie verlorene Arbeit
  aus, obwohl auf dem Remote alles vollständig war.

_82 Tests in PulseCore, alle grün. App-Gerüst, `PulseData` und die Skripte sind
unter Linux nicht ausführbar und warten auf den ersten Lauf am Mac._

---

## 0.9.1 — 2026-08-04

### Geändert
- Die Roadmap nennt den erreichten Stand je Schritt, die nächsten drei
  Schritte und wo welche Arbeit geprüft werden kann. Damit findet sich eine
  Sitzung auf einem anderen Rechner ohne Gesprächsverlauf zurecht.

_Nur Dokumentation, keine Codeänderung. 82 Tests unverändert grün._

---

## 0.9.0 — 2026-08-04

### Hinzugefügt
- Release Notes und Versionierung als verbindlicher Teil jeder Änderung, samt
  Skill, die den Ablauf festhält. Ohne Änderungshistorie weiß in sechs Monaten
  niemand mehr, warum eine Zahl anders berechnet wird als vorher.
- Die Version steht jetzt in der Kopfzeile des Klick-Dummys. Damit lässt sich
  ein weitergegebener Entwurf einem Eintrag in dieser Datei zuordnen.

_82 Tests in PulseCore, alle grün._

---

## 0.8.0 — 2026-08-04

### Hinzugefügt
- `PulseData`: Persistenzschicht auf SwiftData mit CloudKit als Synchronisation.
  Datensätze spiegeln die Domänentypen, Beziehungen und Vorgabewerte halten
  sich an die Einschränkungen, die CloudKit dem Schema auferlegt.
- `ScaledDecimal`: Zählerstände und Preise werden als Ganzzahl mit
  mitgeführtem Dezimalfaktor gespeichert. CloudKit überträgt `Int64`
  verlustfrei, macht aus `Decimal` aber `Double` — aus 49.157,4 kWh wäre
  49157.399999999994 geworden, sichtbar in jedem Kostenbericht.
- `PulseSnapshot`: Sicherungs-, Export- und Wiederherstellungsformat mit einer
  Zusammenführung, die über die Kennungen idempotent ist. Dieselbe Sicherung
  zweimal einzuspielen erzeugt keine Dubletten — ohne diese Eigenschaft traut
  sich niemand, eine Sicherung einzuspielen.
- `ResourceKind` erhält eine stabile Speicher-Kennung. Eine unbekannte
  Zählerart aus einer neueren App-Version wird zu einem frei definierten
  Zähler statt zu einem Fehler: Der Nutzer verliert eine Vorbelegung, nie
  seine Ablesungen.

### Geändert
- Das Speichern eines geänderten Zählers gleicht die Zählwerke über ihre
  Kennung ab, statt sie zu ersetzen. Ein Ersetzen hätte über die Löschregel
  `.cascade` die gesamte Ablesehistorie mitgenommen — ein Umbenennen hätte
  die Historie gelöscht.
- Zähler werden archiviert statt gelöscht; endgültiges Löschen ist ein
  getrennter Weg.

_82 Tests in PulseCore, alle grün. `PulseData` ist unter Linux nicht baubar und
wartet auf eine Prüfung in Xcode._

---

## 0.7.0 — 2026-08-04

### Hinzugefügt
- `BillingCycle`: Abrechnungsrhythmus des Versorgers als eigener Typ. Er
  beginnt fast nie am 1. Januar — bei Strom oft im April, bei Gas im Oktober.
  Ein Bericht über das Kalenderjahr taugt deshalb nicht zum Prüfen der
  Jahresabrechnung.

### Behoben
- Ein Stichtag am 31. hätte im Februar kein Datum ergeben und damit Jahre ohne
  Zeitraumbeginn erzeugt. Er wird jetzt auf die Monatslänge begrenzt.
- Aufeinanderfolgende Abrechnungszeiträume teilen sich ihren Grenztag. Ohne das
  wäre der Verbrauch eines Tages zwischen die Zeiträume gefallen — derselbe
  Fehler, der zuvor schon an den Tarifgrenzen behoben wurde.

_62 Tests, alle grün._

---

## 0.6.0 — 2026-08-04

### Hinzugefügt
- Verbrauchsbericht als gestaltetes Dokument: Zusammenfassung, je Zähler
  Zählernummer, Anfangs- und Endstand, Monatstabelle gegen das Vorjahr und
  Kostenaufschlüsselung. Mit Druckformatierung.
- Auswahl von Umfang und Zeitraum vor dem Bericht — einzelner Zähler oder
  alle, laufendes oder abgeschlossenes Abrechnungsjahr, Kalenderjahr oder
  letzte zwölf Monate.

### Behoben
- Die Zusammenfassung stellte die Kosten aller vier Zähler den Abschlägen von
  zweien gegenüber und meldete 636,43 € Nachzahlung, wo 257,75 € Guthaben
  stehen. Nicht nur die Höhe war falsch, sondern das Vorzeichen. In den Saldo
  fließen jetzt nur Zähler mit hinterlegtem Abschlag, und der Bericht nennt sie.
- Bögen legten sich übereinander, statt einander zu ersetzen — der Export
  schob sich vor den Bericht, den er gerade geöffnet hatte.

_53 Tests, alle grün. Prototyp in Hell und Dunkel geprüft._

---

## 0.5.0 — 2026-08-04

### Hinzugefügt
- Monatsvergleich über drei Jahre: Ein Monat im Diagramm ist antippbar und
  öffnet darunter denselben Monat aller Jahre auf gemeinsamem Maßstab, mit
  Veränderung, Tagesmittel und Kosten.
- Umschalter „Summe / Ø je Tag" in der Datenansicht. Januar 290 kWh gegen
  Februar 266 kWh liest sich wie ein Rückgang; pro Tag sind es 9,35 gegen
  9,50 — also ein Anstieg. Die Rohzahlen sagten das Gegenteil der Wahrheit.

### Geändert
- Die Ablesungsliste im Verlauf liegt hinter einer Zeile statt im Hauptfluss.
  Sie zeigt dafür alle Einträge statt der letzten acht, und Diagramm samt
  Jahresvergleich passen ohne Scrollen auf einen Schirm.

_53 Tests, alle grün. Prototyp in Hell und Dunkel geprüft._

---

## 0.4.0 — 2026-08-04

### Hinzugefügt
- Datenansicht im Verlauf: Monat, Quartal oder Jahr gegen 2026, 2025 und 2024,
  wahlweise als Menge oder als Kosten.
- CSV-Export von Ablesungen und Auswertung, tatsächlich erzeugt und
  herunterladbar, dauerhaft kostenlos.
- Drittes Jahr Historie (2024), damit Vergleiche Tiefe haben.

### Geändert
- Bei „Alle Zähler" ist nur die Kostenansicht wählbar, die Mengenansicht ist
  gesperrt: kWh und m³ lassen sich nicht addieren, Euro schon. Die
  Einschränkung wird gezeigt statt still eine Variante zu wählen.
- Zwei Summenzeilen statt einer. Die rohen Spaltensummen tragen keine
  Veränderung mehr, weil 1.607 (Jan–Jul 2026) neben 3.020 (volles Jahr 2025)
  zum Fehlschluss einlädt. Nebeneinander lesbar ist nur die Zeile, die in
  allen Jahren denselben Ausschnitt beschreibt.

_53 Tests, alle grün. Prototyp in Hell und Dunkel geprüft._

---

## 0.3.0 — 2026-08-04

### Hinzugefügt
- Klick-Dummy: Übersicht, Erfassung mit Zählwerk-Optik und
  Live-Plausibilisierung, Verlauf und Zählerverwaltung. Rechnet mit echten
  Zeitreihen statt mit Platzhalterzahlen.

### Behoben
Drei Fehler, die der Prototyp aufdeckte — alle derselben Klasse: ein Zeitraum,
den die Daten abdecken, verglichen mit einem, den sie nicht abdecken.

- **Hochrechnung.** Die Tage zwischen letzter Ablesung und heute galten als
  gemessen und verbrauchsfrei. Wer länger nicht ablas, bekam eine zu niedrige
  Prognose — die App hätte Nachlässigkeit mit falscher Beruhigung belohnt.
- **Vorjahresvergleich.** Ein Gaszähler mit letzter Ablesung im Mai meldete
  +33 %, tatsächlich sind es −3 %. Verglichen wurde eine halbe Heizperiode
  gegen ein Vorjahr einschließlich Sommer.
- **Plausibilitätsprüfung.** Referenz war der Jahresdurchschnitt. Bei einem
  Gaszähler heißt das: jede korrekte Julimessung wird beanstandet, ein
  zehnfach zu hoher Wert geht durch. Genau verkehrt herum — das Feature, das
  Vertrauen schaffen soll, hätte es zerstört. Referenz ist jetzt derselbe
  Zeitraum des Vorjahres.

_53 Tests, alle grün._

---

## 0.2.0 — 2026-08-04

### Hinzugefügt
- `PulseCore`: Domänenmodell und Rechenkern, ausschließlich auf Foundation und
  damit ohne Xcode prüfbar.
- Trennung von Messstelle, Zählwerk und Gerät. Nur so lassen sich
  Zweirichtungszähler, Doppeltarifzähler und der Zählerwechsel abbilden, ohne
  die Historie zu zerreißen.
- Wertetypen `CalendarDay`, `Quantity` und `Money`: zeitzonenfreie
  Kalendertage, Einheit als Teil des Wertes, Geld als `Decimal`.
- Rechenkern mit Verlässlichkeitsangabe an jedem Ergebnis. Die Oberfläche kann
  eine interpolierte Zahl dadurch nicht wie eine gemessene darstellen.
- Kostenrechnung mit abschnittsweiser Tarifzerlegung, Gas-Umrechnung über
  Zustandszahl und Brennwert, Einspeisung als Gutschrift.

_50 Tests, alle grün._

---

## 0.1.0 — 2026-08-04

### Hinzugefügt
- Produktstrategie, Architektur als ADR, Datenmodell, UX-Konzept,
  Monetarisierung und Roadmap.
- Drei dokumentierte Einwände gegen das ursprüngliche Briefing: tägliche
  Nutzung als Erfolgskriterium, die Sogwirkung Richtung Smart Home, und die
  rechtliche Formulierung der Vermieter-Funktionen.
