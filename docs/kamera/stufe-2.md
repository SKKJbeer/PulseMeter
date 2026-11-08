# Kamera, Stufe 2: zwei Zahlen an einem Zähler (für 1.7)

Stand 8. November 2026. Konzept vor dem ersten Code. **Umgesetzt in 0.142.0:** die Regel über den Bereich (`RegisterChoice`). Offen: die Kennzahl lesen. Es baut auf Stufe 1 auf
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

## Was 1.7 macht

1. **Die Kennzahl lesen.** Neben dem Rahmen, links davon und auf derselben
   Höhe, wird ein zweiter Ausschnitt genommen und mit demselben Ziffernnetz
   gelesen. Als Kennzahl gilt nur `d.d.d` (auch ohne Punkte als `ddd`, weil
   manche Displays die Punkte nicht zeigen) und nur, wenn sie zu einer
   bekannten Kennzahl passt: `1.8.0`, `1.8.1`, `1.8.2`, `2.8.0`, `2.8.1`,
   `2.8.2`.
2. **Zuordnen statt raten.** Für einen Zähler mit mehreren Zählwerken, die
   eine Kennzahl haben (Voreinstellung bei „Strom mit Solar“ und „Strom mit
   zwei Tarifen“):
   - Kennzahl gelesen und sie gehört zum gefragten Zählwerk: Vorschlag wie
     bisher.
   - Kennzahl gelesen und sie gehört zu einem **anderen** Zählwerk desselben
     Zählers: Die Zahl wird für dieses Zählwerk gemerkt und **kein** Vorschlag
     gemacht. Der Sucher sagt „Das ist Einspeisung (2.8.0). Warte, bis 1.8.0
     kommt.“ Kommt danach 1.8.0, wird vorgeschlagen. Im nächsten Schritt steht
     die gemerkte Einspeisung schon als Vorschlag im Ziffernblock, mit Herkunft
     „Kamera“ und zum Bestätigen, nicht gesichert. **So reicht ein
     Kamerabesuch für beide Zahlen.**
   - Keine Kennzahl gelesen: vorgeschlagen wird nur, wenn der Bereich die
     Zahl eindeutig macht, sie also in den Bereich des gefragten Zählwerks
     passt und **nicht** in den eines anderen. Sonst kein Vorschlag, Hinweis
     „Halte die Kamera so, dass die Kennzahl links mit im Bild ist.“ Ein
     Abwarten, ob die Anzeige wechselt, hilft nicht: Der Vorschlag steht nach
     einer Sekunde, der Wechsel kommt nach fünf bis zehn.
   - Zähler mit einem Zählwerk und Zählwerke ohne Kennzahl (Rollenzählwerke):
     wie bisher.
3. **Der Rahmen bleibt, wie er ist.** Kein zweiter Rahmen, kein neuer Knopf.
   Der Kennzahl-Ausschnitt ist für den Nutzer unsichtbar; nur die Hinweise
   sind neu.

Nicht in 1.7: zwei Rollenzählwerke übereinander (Ferraris-Zähler mit Hoch-
und Niedertarif). Die gibt es kaum noch neu, und dort fängt der Bereich den
Irrtum meist ab, weil beide Zahlen weit auseinander liegen. Bleibt auf der
Liste unter „Später“.

## Wer was darf

- `PulseCore` bekommt die reine Regel: `RegisterAssignment` (Name offen) nimmt
  die gelesene Kennzahl, die Kennzahlen der Zählwerke des Zählers und das
  gefragte Zählwerk und sagt *vorschlagen*, *für ein anderes merken* oder
  *nicht vorschlagen*. Testbar unter Linux, wie `MeterTextReader`.
- `KameraSitzung` nimmt den zweiten Ausschnitt und liest ihn. Sie entscheidet
  nichts.
- `KameraView` hält die Einigung je Kennzahl getrennt (vier von sechs **je
  Zählwerk**) und reicht gemerkte Zahlen an `CaptureView` zurück.
- `CaptureView` legt eine gemerkte Zahl beim nächsten Schritt als Vorschlag in
  den Ziffernblock. Gesichert wird wie immer erst mit „Sichern“.

## Messen, bevor gebaut wird

Ohne Zahlen wird nichts davon eingebaut. Zuerst `scripts/kamera-netz/`:

1. **Echte Fotos mit Kennzahl** von Wikimedia Commons (deutsche, österreichische,
   niederländische Zähler: eHZ, EasyMeter, ISKRA MT175/MT681, EMH, Logarex),
   blind geholt wie die dritte Sammlung. Ziel: mindestens zehn Fotos, auf denen
   eine Kennzahl lesbar ist.
2. **Liest das Netz die Kennzahl?** Je Foto viele Ausschnitte links vom Rahmen.
   Gezählt wird: richtig, falsch, nichts. Maßstab wie in Stufe 1: **eine falsch
   gelesene Kennzahl, die zu einem anderen Zählwerk passt, ist der schlimmste
   Fall.** Ziel 0 in allen Versuchen.
3. Reicht das Netz nicht, wird es mit Kennzahlen im Generator nachtrainiert
   (`synth.py` zeichnet sie heute schon, aber als Nebenzeichen, die zu
   übergehen sind) und auf Stufe 1 **neu gemessen**: Die Zahlen für 1.6 dürfen
   nicht schlechter werden.
4. Der Wechsel-Fall wird nachgestellt: abwechselnd Bilder von zwei Zahlen in
   den Ausschnitten, die Einigung darf keinen Vorschlag für das falsche
   Zählwerk machen.

## Prüfung in der App

- `PulseCoreTests`: alle Fälle der Zuordnung, dazu „Kennzahl `180` ohne
  Punkte“ und „Kennzahl `1.8.0` an einem Zähler ohne Kennzahlen“ (dann wird
  sie übergangen).
- Oberflächentest mit `-pulse-kamera-test`: ein gezeichnetes Display, das
  zwischen 1.8.0 und 2.8.0 wechselt. Erwartet: Bezug richtig vorgeschlagen,
  Einspeisung im zweiten Schritt schon vorgeschlagen.
- Klick-Dummy: der Wechsel zum Durchklicken (Regel 1).

## Offen

- Wie oft Kennzahlen auf Fotos überhaupt lesbar mit im Bild sind, zeigt erst
  die Messung. Fällt sie schlecht aus, bleibt von 1.7 die Regel über den
  Bereich, und das Lesen der Kennzahl wandert nach hinten. Auch das wäre schon
  ein Gewinn: Es verhindert den plausiblen falschen Vorschlag. **Die Regel
  über den Bereich kommt deshalb zuerst**, sie braucht kein neues Netz.
