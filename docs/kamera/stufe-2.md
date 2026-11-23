# Kamera, Stufe 2: zwei Zahlen an einem Zähler

Stand 8. November 2026. Konzept vor dem ersten Code. **Umgesetzt in 0.144.0:** die Regel über den Bereich (`RegisterChoice`). Offen: die Kennzahl lesen. Es baut auf Stufe 1 auf
(`README.md` in diesem Ordner, im Laden seit 1.6).

## Die Lage

Ein Zähler mit zwei Zahlen hat in Zählora zwei Zählwerke. Der Ziffernblock
fragt sie nacheinander ab („Bezug, Schritt 1 von 2“), und seit 1.6 hat jeder
Schritt seinen eigenen Kameraknopf. Das geht gut, solange im Rahmen nur die
Zahl steht, die gerade gefragt ist.

Bei der häufigsten Bauart in Deutschland ist das nicht so. Die moderne
Messeinrichtung (eHZ, EasyMeter, ISKRA, EMH, Logarex) hat **ein** Display und
**wechselt** darauf alle paar Sekunden zwischen den Zählwerken:

    1.8.0   012345,6 kWh      Bezug
    2.8.0   000987,4 kWh      Einspeisung

Links neben dem Wert steht die Kennzahl, kleiner als die Ziffern. Wer im
Schritt „Bezug“ die Kamera hält, während die Anzeige gerade 2.8.0 zeigt,
bekommt heute die Einspeisung als Bezug vorgeschlagen. Dafür reichen sechs
Bilder in etwa einer Sekunde, und die Anzeige steht meist fünf bis zehn
Sekunden still. Die Einigung „vier von sechs“ schützt also nicht.

Bisher fängt das nur der Bereich ab (vom letzten Stand bis zum Vierfachen des
üblichen Verbrauchs). Bei einer Solaranlage liegen Bezug und Einspeisung aber
oft in derselben Größenordnung, und bei der ersten Ablesung gibt es gar keinen
Bereich. **Das ist ein falscher Vorschlag, der plausibel aussieht: genau die
Art, die Produktprinzip 7 verbietet.**

## Wie es gekommen ist

Die Regel über den Bereich (unten Punkt 1) ist seit 0.144.0 drin und seit 1.7 im Laden: Eine Zahl,
die auch zu einem anderen Zählwerk passen kann, wird nicht vorgeschlagen. Offen blieben die Kennzahl
und „ein Kamerabesuch für beide Zahlen“. Beides war für 1.9 geplant (Entscheidung vom 22.11.).

## Messung der Kennzahl (22.11.2026)

Ein eigenes Kennzahl-Netz, gleiche Bauart wie das Ziffernnetz, vom Ziffernnetz aus weitertrainiert
auf gezeichnete Kennzahl-Ausschnitte (`scripts/kamera-netz/kennzahl_synth.py`, `kennzahl_gen.py`).
Gemessen wie in der App (`kennzahl.py`, Teil B): Rahmen auf der Zahl, Kennzahl-Fenster links und links
darüber, 30 Versuche je Foto, je sechs Bilder, gilt nur bei drei gleichen ohne Widerspruch. Auf vier
der 20 Fotos steht eine Kennzahl (Logarex, Landis, Kamstrup, Kaifa).

| Netz | richtig | **falsch** | Fotos, auf denen etwas falsch kam |
|---|---|---|---|
| Ziffernnetz (ohne Kennzahl-Training) | 0–25 % je Foto | 0 | – |
| Kennzahl-Netz Runde 1 (1 Epoche) | 26 von 120 | **2** | Meterus: „E.T2“ als 282 |
| Kennzahl-Netz Runde 2 (5 Epochen, 14-Segment-Wörter als Störer, Fenster bis zur Zeile darüber) | 17 von 120 | **4** | Landis, Kaifa |
| Runde 1 und 2 müssen sich einig sein | 1 von 120 | 0 | – |

Das Ziel war null falsche Kennzahlen bei brauchbarer Trefferquote. Keine Fassung erreicht beides:
Entweder liest das Netz zu selten, oder es liest manchmal falsch. Eine falsche Kennzahl bei der
ersten Ablesung, wo es noch keinen Bereich gibt, ordnet die Zahl dem falschen Zählwerk zu. Das ist
der schlimmste Fall, den diese Stufe verhindern soll.

**Deshalb liest die App die Kennzahl vorerst nicht.** Die Regeln dafür (`ObisCode`, die Zuordnung
mit Kennzahl, `LabeledConsensus`) bleiben im Rechenkern, geprüft und gleich im Klick-Dummy, damit ein
besseres Netz nur noch angeschlossen werden muss. Was fehlt, sind echte Fotos mit Kennzahl: vier
sind zu wenig, um ein Netz zu trainieren, das man nicht auf eben diesen Fotos misst.

## Was 1.9 macht

1. **Die Bereiche entscheiden.** Für einen Zähler mit mehreren Zählwerken liest die Kamera die Zahl
   im Rahmen und prüft sie zuerst gegen den Bereich des gefragten Zählwerks, dann gegen die der
   anderen (`KameraSitzung.auswerten`). Danach sagt `RegisterAssignment.decide`:
   - Die Zahl passt zum gefragten Zählwerk und zu keinem anderen: **Vorschlag** wie bisher.
   - Sie passt nicht zum gefragten, aber zu **genau einem** anderen: Sie wird für dieses
     **gemerkt**. Der Sucher sagt „„Einspeisung“ gelesen. Warte, bis „Bezug“ kommt.“ Kommt danach
     der Bezug, wird er vorgeschlagen, und auf der Karte steht „Auch gelesen: „Einspeisung“
     7.171,90 kWh“.
   - Sie passt zum gefragten **und** zu einem anderen: kein Vorschlag (die Regel aus 1.7).
   - Sie passt zu keinem, oder zu mehreren anderen: nichts vorschlagen, nichts merken.
2. **Ein Kamerabesuch für beide Zahlen.** Kommt das gemerkte Zählwerk im nächsten Schritt dran und
   ist dort noch nichts eingetippt, steht die Zahl schon im Ziffernblock, mit „Von der Kamera
   gelesen“, und wird erst mit „Sichern“ gesichert. Auch nach dem Vorschlag läuft die Kamera weiter
   und merkt die andere Zahl, wenn sie noch kommt.
3. **Ab der zweiten Ablesung.** Bei der ersten gibt es keine Bereiche, dann schlägt die Kamera an
   einem Zähler mit zwei Zahlen nichts vor (wie in 1.7). Ein anderes Zählwerk ohne Bereich bekommt
   nie eine gemerkte Zahl: Wer nichts weiß, merkt nichts.
4. **Der Rahmen bleibt, wie er ist.** Kein zweiter Rahmen, kein neuer Knopf. Neu sind nur der
   Satz im Sucher und die Zeile „Auch gelesen“.

Nicht in 1.9: die Kennzahl (siehe Messung) und zwei Rollenzählwerke übereinander.

## Wer was darf

- `PulseCore`: `RegisterAssignment.decide` nimmt die Zahl, die Bereiche aller Zählwerke und das
  gefragte und sagt *vorschlagen*, *für ein anderes merken*, *nicht eindeutig* oder *passt nicht*.
  Der eigene Bereich zählt immer, auch mit Kennzahl.
- `KameraSitzung` liest das Bild **einmal** und prüft die Lesung gegen den eigenen, dann gegen die
  anderen Bereiche. Sie entscheidet nichts.
- `KameraView` hält die Einigung (vier von sechs), fragt `decide` und reicht gemerkte Zahlen beim
  Schließen an `CaptureView` zurück.
- `CaptureView` legt eine gemerkte Zahl beim nächsten Schritt in den Ziffernblock. Gesichert wird
  wie immer erst mit „Sichern“.

## Prüfung

- `PulseCoreTests`: `RegisterAssignmentTests` (alle Fälle, jeder neue Test einmal rot gesehen),
  dazu die gemeinsamen Fälle in `docs/kamera/vektoren.json` (`zuweisung`, `kennzahl`,
  `kennzahl_einigung`), die `scripts/check-kamera-js.mjs` gegen den Klick-Dummy laufen lässt.
- Oberflächentest `testOneCameraVisitReadsBothNumbersOfAnAlternatingDisplay` mit
  `-pulse-kamera-test -pulse-kamera-wechsel`: Das gezeichnete Display zeigt erst die Einspeisung,
  dann den Bezug, beides durch dieselbe Auswertung wie ein Kamerabild. Erwartet: Bezug
  vorgeschlagen, „Auch gelesen“ auf der Karte, im zweiten Schritt die Einspeisung im Ziffernblock,
  nichts von selbst gesichert.
- Klick-Dummy: Beim Stromzähler gibt es unter den Beispielbildern „Display wechselt“. Das echte
  Ziffernnetz liest das gezeichnete Display; `scripts/check-prototype.mjs` prüft den ganzen Weg.
- Die Kennzahl-Messung wiederholen: `TEIL=b python scripts/kamera-netz/kennzahl.py <netz.pt> 30`.
