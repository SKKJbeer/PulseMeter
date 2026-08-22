---
name: selbstsprechend
description: Regeln für jeden Text, den ein Nutzer in PulseMeter sieht — Überschriften, Beschriftungen, Zahlen, Erklärzeilen, Legenden, Knöpfe, Hinweise, Fehlermeldungen. Diese Skill greift, sobald ein sichtbarer Text geschrieben, umformuliert oder gekürzt wird, und ebenso, wenn eine Zahl, ein Balken oder ein Symbol beschriftet wird. Auch verwenden, wenn ein Erklärsatz nötig scheint, wenn eine Karte eine Überschrift bekommt, wenn ein Wert mehrdeutig wirkt, oder wenn der Nutzer sagt, etwas sei „zu viel Text", „nicht eindeutig" oder klinge „nach KI".
---

# Selbstsprechend

Der Gründer, am 22. August, vor einer Karte mit vier Erklärsätzen:

> „es soll eigentlich alles immer selbstsprechend sein"

Das ist keine Stilfrage. Eine Zahl, die einen Satz zur Erklärung braucht, ist
falsch beschriftet — und der Satz repariert das nicht, er verdeckt es nur.

---

## Die eine Regel

**Wenn ein Text erklären muss, was daneben steht, stimmt die Beschriftung
nicht.** Erst die Beschriftung richtig machen, dann den Text streichen.

Der Fall, an dem es sich gezeigt hat: Über einer Zahl stand `August`, die Zahl
war `≈ 11 kWh`, und darunter ein Satz — „Verglichen wird 1. August bis
3. August — in jedem Jahr derselbe Ausschnitt." Der Gründer las 11 kWh als
Augustverbrauch und hielt sie für falsch. Sie war richtig. Falsch war die
Überschrift.

Die Lösung war nicht ein besserer Satz, sondern **`1.–3. August`** als
Überschrift. Danach war der Satz überflüssig.

| Statt | Lieber |
|---|---|
| Zahl mit Erklärsatz darunter | Beschriftung, die die Zahl eindeutig macht |
| „Verglichen wird 1. bis 3. August" | Überschrift `1.–3. August` |
| „≈ heißt: zwischen zwei Ablesungen gerechnet, nicht gemessen." | „≈ gerechnet, nicht gemessen." |
| „Gleicher Monat, andere Jahre" | „Damals im August" |

---

## Überschriften

**Kurz, konkret, und nicht die Konstruktion, die eine Maschine bauen würde.**
„Gleicher Monat, andere Jahre" beschreibt korrekt, was passiert, und klingt
dabei wie ein Datenbankfeld. „Damals im August" sagt dasselbe und klingt nach
einem Menschen.

- **Benennen, nicht beschreiben.** Die Überschrift ist ein Name, keine
  Zusammenfassung.
- **Der Ausschnitt gehört hinein**, wenn die Zahlen darunter einen Ausschnitt
  meinen. Wer „August" liest und drei Tage bekommt, ist getäuscht — auch wenn
  es weiter unten steht.
- **Kein Doppelpunkt-Anhängsel**, kein erklärender Nachsatz nach Gedankenstrich.
- **Nichts, was die Zeile darunter schon sagt.** Stehen die Jahre als Zeilen da,
  muss die Überschrift nicht „andere Jahre" sagen.

---

## Wie viel Text

Die Reihenfolge, in der ein Nutzer etwas erfasst: **Zahl, Beschriftung, Form.**
Fließtext kommt zuletzt und wird meistens gar nicht gelesen.

1. **Ein Satz.** Zwei nur, wenn der zweite etwas sagt, was der erste nicht kann.
2. **Streichen, was das Bild schon zeigt.** Ein Balken, der zu zwei Dritteln
   voll ist, braucht kein „zwei Drittel".
3. **Streichen, was die Überschrift schon sagt.**
4. **Was bleibt, so kurz wie möglich.** „≈ gerechnet, nicht gemessen." statt
   eines Nebensatzes über Ablesungen.

Was **nicht** gestrichen wird: die Kennzeichnung geschätzter Zahlen
(Produktprinzip 7) und die Grundlage einer Hochrechnung. Beides ist keine
Erklärung, sondern Teil der Aussage.

---

## Woran man den maschinellen Klang erkennt

Ergänzend zu `CLAUDE.md`, Abschnitt „Tonfall":

- Eine Überschrift, die eine Bedingung beschreibt („Gleicher X, anderes Y").
- Ein Satz, der sich selbst begründet, obwohl niemand gefragt hat.
- Drei gleich gebaute Sätze hintereinander.
- Ein Erklärsatz für ein Zeichen, das man auch weglassen könnte.

---

## Prüfen

Vor dem Veröffentlichen einer Ansicht, die Zahlen zeigt, drei Fragen:

1. **Deckt jede Zahl das ab, was ihre Beschriftung verspricht?** Wenn nicht:
   Beschriftung ändern, nicht erklären.
2. **Welchen Satz kann ich streichen, ohne dass etwas unklar wird?** Den
   streichen. Dann noch einmal fragen.
3. **Würde ich das so sagen?** Wenn nicht, umschreiben, bis ja.
