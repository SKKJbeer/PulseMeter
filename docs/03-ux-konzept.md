# 03 – UX-Konzept

Status: Entwurf zur Entscheidung
Letzte Änderung: 2026-08-04

---

## 1. Navigationsentscheidung

**Problem.** Tab Bar, Sidebar oder eine einzige Ebene?

**Optionen.**

| Option | Vorteile | Nachteile |
|---|---|---|
| **3 Tabs** (Übersicht · Verlauf · Zähler) + zentrale Erfassungsaktion | Vertraut, flach, jeder Tab hat eine Aufgabe, skaliert zu iPad-Sidebar | Erfordert Disziplin, damit Tabs nicht zu Sammelbecken werden |
| Einzelner Screen mit Scrolling | Maximal einfach | Bricht ab 3–4 Zählern; Verlauf und Verwaltung finden keinen Ort |
| Tab Bar mit 5 Tabs | Alles erreichbar | Widerspricht „ein Screen, eine Aufgabe"; wirkt sofort technisch |

**Empfehlung: drei Tabs.**

```
┌──────────────┬──────────────┬──────────────┐
│  Übersicht   │   Verlauf    │    Zähler    │
└──────────────┴──────────────┴──────────────┘
        "Wie stehe ich da?"
                       "Wie war es?"
                                      "Was messe ich?"
```

Einstellungen liegen **nicht** in einem Tab, sondern hinter dem Profil-/Zahnrad-Symbol in der Übersicht. Begründung: Einstellungen sind kein gleichwertiges Ziel; ein eigener Tab signalisiert „hier musst du etwas konfigurieren" — genau der Eindruck, den wir vermeiden wollen.

**Erfassen** ist kein Tab, sondern die primäre Aktion: eine prominente Schaltfläche in der Übersicht sowie direkt auf jeder Zähler-Karte. Grund: Der Nutzer will nicht „zum Erfassen-Bereich navigieren", er will *diesen* Zähler eintragen.

---

## 2. Übersicht – der wichtigste Screen

**Aufgabe:** In unter fünf Sekunden Blickzeit beantworten: *Ist alles im Rahmen?*

Aufbau von oben nach unten:

1. **Statuszeile** — eine Zeile, ganze Sätze, keine Kennzahlen:
   „Alles im Rahmen." / „Strom liegt 12 % über dem Vorjahr." / „Seit 68 Tagen keine Ablesung."
2. **Fällige Ablesungen** — nur wenn welche anstehen. Ein Tipp führt direkt in die Erfassung.
3. **Zähler-Karten** — pro Zähler eine Karte:
   - Name + Symbol in der Farbe des Zählers
   - aktueller Verbrauch im laufenden Zeitraum, groß und in Alltagssprache
   - Sparkline der letzten 12 Monate
   - eine Einordnung: „−7 % ggü. Vorjahr" oder „Prognose: 3.180 kWh"
   - bei hinterlegtem Abschlag: „Voraussichtlich 84 € Guthaben"
4. Kein Chart-Wald, keine Tabelle, keine Zahlenreihe.

**Was hier bewusst fehlt:** Wochenwerte, Balkendiagramme, Prozentringe, Vergleich mit „durchschnittlichen Haushalten". Letzteres ist besonders verlockend und besonders schädlich — die Referenzwerte sind fragwürdig, und niemandem hilft die Information, dass er „über dem Durchschnitt" liegt, ohne zu wissen, warum.

---

## 3. Erfassung – der Screen, an dem sich alles entscheidet

**Problem.** Der Nutzer steht am Zähler. Schlechtes Licht, kalt, vielleicht eine Taschenlampe in der anderen Hand. Wenn hier Reibung entsteht, hört er nach drei Monaten auf — und alle anderen Features werden wertlos.

**Ablauf (Ziel: 3 Berührungen).**

1. Übersicht → Tipp auf die Zähler-Karte oder auf „Eintragen"
2. Eingabemaske erscheint **sofort mit aktiver Tastatur**, Datum ist auf heute vorbelegt
3. Zahl eintippen → „Sichern"

**Gestaltung der Eingabe.**
- Ziffernfelder im Look eines echten Zählwerks: weiße Vorkommastellen, rote Nachkommastelle, wie am Gerät. Der Nutzer vergleicht optisch statt zu übersetzen — das reduziert Tippfehler messbar.
- Eigener großer Ziffernblock, nicht die Systemtastatur. Große Ziele, mit Handschuhen bedienbar.
- **Live-Plausibilisierung während der Eingabe:** unterhalb des Feldes erscheint sofort „entspricht 312 kWh in 31 Tagen · normal für dich". Bei Unplausibilität (Faktor 10 daneben, Rückwärtssprung) ein ruhiger Hinweis, **keine** Fehlermeldung und keine Blockade.
- Foto ist optional und einen Tipp entfernt — nie ein Pflichtschritt.
- Datum ändern ist möglich, aber sekundär platziert.

**Rundgang (seit 0.119.0, Fassung 1.4).** Sind nach dem geöffneten Zähler
noch andere fällig, bleibt das Blatt nach dem Sichern offen und zeigt den
nächsten, in der Reihenfolge der Übersicht. Der Knopf sagt das vorher:
„Sichern, weiter mit Gas". Oben steht danach „Strom gesichert", der Ausweg
heißt „Fertig", und „Überspringen" geht am Zähler vorbei, der gerade nicht
erreichbar ist. Ist sonst nichts fällig, ändert sich nichts: drei Berührungen,
dann ist das Blatt zu. Die Regel steht in `PulseCore.ReadingRound`.

**Warum Live-Plausibilisierung das wichtigste Einzelfeature ist:** Der häufigste Datenfehler in solchen Apps ist der Tippfehler, und er wird erst Monate später bemerkt — dann, wenn ein Chart absurd aussieht und der Nutzer der App nicht mehr traut. Die Prüfung im Moment der Eingabe ist der billigste Ort, das zu verhindern.

---

## 4. Verlauf

Ein Zähler, ein Zeitraum, ein Chart. Nicht alle Zähler übereinander.

- Umschalter Monat / Jahr / Gesamt
- Balken für Verbrauch je Periode, Vorjahr als dezente Geisterlinie dahinter
- Interpolierte Werte visuell unterscheidbar (schraffiert statt gefüllt)
- Antippen eines Balkens zeigt die zugrunde liegenden Ablesungen — die Kette von der Aussage zur Rohdaten-Quelle ist immer nachvollziehbar (Prinzip 4)
- Die Liste der Ablesungen ist eine Detailansicht, nicht die Hauptoberfläche
- **In dieser Liste lässt sich jede Ablesung berichtigen und löschen.** Eine
  falsche Ziffer verschiebt beide angrenzenden Zeiträume; ohne einen Weg
  zurück steht sie für immer im Verlauf (Prinzip 4). Geändert wird auf
  demselben Schirm, auf dem erfasst wird — dieselbe Zählwerk-Optik, derselbe
  Ziffernblock. Gelöscht wird nur nach Rückfrage, und die Rückfrage nennt die
  Folge: Der Verbrauch davor und danach wird neu gerechnet
- **Die Zeile unter der großen Zahl nennt, woher sie kommt** (seit 0.133.1).
  Kaum jemand liest am Ersten ab, also ist ein Monatsrand meistens zeitanteilig
  aus der Ablesung davor oder danach gerechnet. Der laufende Abschnitt sagt
  „aus 2 von 31 Tagen". Ein abgeschlossener nennt den Grund mit Datum:

  | Fall | Zeile |
  |---|---|
  | Erst im Monat angefangen | „erst ab 10. September abgelesen" |
  | Ein Rand zwischen zwei Ablesungen | „Monatsende anteilig aus der Ablesung am 12. Oktober" |
  | Beide Ränder | „Monatsanfang und -ende anteilig aus den Ablesungen am 3. Februar und 2. April" |
  | Nach dem Monat noch keine Ablesung | „nur bis 28. Mai abgelesen, der Rest kommt mit der nächsten Ablesung" |

  Beim Quartal und beim Jahr dieselben Sätze mit „Quartalsende" und
  „Jahresende". Die Zahl trägt das ≈ wie bisher. Bis 0.133.0 stand dort für
  alle vier Fälle „aus 21 von 30 Tagen", und das las sich wie ein offener
  Monat.

---

## 5. Onboarding

Ziel: erste Ablesung in unter 60 Sekunden, ohne Konto.

1. Ein Satz zum Zweck, kein Feature-Karussell
2. „Was möchtest du erfassen?" — große Kacheln: Strom · Wasser · Gas · Heizung · Solar · Eigenes
3. Optional: Zählernummer und Foto (überspringbar, deutlich sichtbar)
4. Erste Ablesung eintragen
5. „Wann sollen wir dich erinnern?" — Monatlich vorbelegt, ein Tipp zum Bestätigen

Kein Konto. Keine Berechtigungsanfrage vor dem ersten Erfolgserlebnis. Die Nachfrage für Benachrichtigungen kommt **nach** Schritt 4, wenn der Nutzen offensichtlich ist — das ist der Unterschied zwischen 30 % und 70 % Opt-in-Rate.

---

## 5a. Einlesen aus einer Tabelle (seit 0.133.0)

Für alle, die schon eine Liste führen, in Excel, Numbers, auf Papier
abgetippt oder in einer anderen App. Vom Gründer verlangt: „dynamisch und so
benutzerfreundlich wie möglich".

**Ein Blatt, kein Assistent.** Oben kommt die Tabelle hinein: Zellen
markieren, kopieren, „Einfügen" tippen. Oder eine Datei wählen. Darunter
steht sofort, was daraus wird:

1. **Was erkannt ist**, in einer Zeile: „3 Zähler · 15 Stände · 03.01.2025 bis 03.05.2025".
2. **Wohin**, je Zähler: „Neuer Zähler" (mit Art), ein vorhandener Zähler derselben Einheit, oder „Nicht einlesen".
3. **Der Knopf** nennt die Zahl: „15 Stände einlesen".
4. **Hinweise** mit Zeilennummer, nur wenn es welche gibt.
5. **„Spalten anders zuordnen"**, eingeklappt: Für den Fall, dass die Erkennung danebenliegt.

Danach „15 Stände eingelesen · 3 Zähler neu angelegt" und **„Rückgängig machen"**.

**Was die App selbst erkennt** (`TableImport` im Rechenkern, dieselben Regeln
im Klick-Dummy): Trennzeichen (Tabulator aus der Zwischenablage, Semikolon aus
deutschem Excel, Komma), Zeichensatz (Windows-1252 aus Excel unter Windows),
Kopfzeile oder keine, deutsche und englische Zahlen, Daten wie `03.04.2025`,
`3.4.25`, `2025-04-03`, `3. April 2025`, mit Uhrzeit oder ohne, lange Tabellen
(eine Spalte nennt den Zähler) und breite (eine Spalte je Zähler), HT/NT und
Einspeisung als Zählwerke eines Zählers, die Einheit aus Kopf oder Zelle.

**Was sie bewusst nicht tut:**

- **Verbräuche einlesen.** Eine Spalte „Verbrauch" oder „Kosten" bleibt draußen, mit Begründung. Zählora rechnet den Verbrauch aus den Ständen.
- **Einen Monat ohne Tag als Datum nehmen.** „April 2025" sagt nicht, wann abgelesen wurde.
- **Rückwärts laufende Stände übernehmen.** Die Zeile bleibt draußen und wird genannt; ein Zählerwechsel gehört in die App.
- **Nach Namen allein zuordnen.** Eine Reihe kommt nur dann automatisch in einen vorhandenen Zähler, wenn sie zwischen dessen Stände passt. Sonst wird es ein neuer Zähler.
- **Über die Zählergrenze hinaus anlegen.** Ohne Kauf bleiben weitere Zähler draußen, und der Weg zur Freischaltung steht daneben.

**Kostenlos.** Wie der Export (Produktprinzip 5): Wer zu Zählora wechselt,
soll seine Geschichte mitnehmen können, ohne erst zu bezahlen.

---

## 6. Design-System

**Farbe.** Eine ruhige neutrale Grundfläche. Farbe ist ausschließlich funktional: jede Zählerart hat eine Signalfarbe (Strom bernstein, Wasser blau, Gas orange, Wärme rot, Solar grün). Diese Farbe erscheint auf Karten, in Charts und Symbolen konsistent und macht die App ohne Text lesbar. Keine Verläufe als Dekoration, keine Markenfarbe, die mit den Datenfarben konkurriert.

**Typografie.** SF Pro durchgehend, Dynamic Type ohne Ausnahme. Zahlen in `monospacedDigit`, damit sie beim Aktualisieren nicht springen. Große Werte in gerundeten Ziffern, damit sie nach Anzeige und nicht nach Tabelle aussehen.

**Dark Mode.** Kein invertiertes Light-Theme. Eigene Flächenhierarchie, gedämpfte Signalfarben mit geprüften Kontrastwerten (mindestens WCAG AA, 4.5:1 für Text).

**Bewegung.** Animation nur, wenn sie eine Zustandsänderung erklärt: Wert wird gesichert, Karte aktualisiert sich, Chart wächst beim ersten Erscheinen. Alles unter 300 ms. `Reduce Motion` wird respektiert — das ist keine Option, sondern Voraussetzung.

**Haptik.** Genau ein Feedback: erfolgreiches Sichern einer Ablesung. Mehr wirkt billig.

**Barrierefreiheit.** VoiceOver-Labels sind ganze Sätze, keine Fragmente („Strom, 312 Kilowattstunden diesen Monat, 7 Prozent unter Vorjahr"). Alle Charts haben eine Audio-Graph-Repräsentation. Touch-Ziele mindestens 44 pt. Layouts werden bei größter Dynamic-Type-Stufe getestet, nicht nur bei Standard.

---

## 7. Erweiterungen der Plattform (hoher Eindruck, geringer Aufwand)

| Erweiterung | Nutzen | Aufwand |
|---|---|---|
| **Home-Screen-Widget** | Aktueller Stand + „fällig" ohne App-Start; hält uns präsent trotz seltener Nutzung | gering |
| **Lock-Screen-Widget** | dito | gering |
| **Shortcuts / Siri** („Zählerstand eintragen") | Erfassung ohne Navigation; wirkt hochwertig | gering |
| **Control Center Control** | Ein Tipp zur Erfassung | gering |
| **Interaktive Benachrichtigung** | Ablesung direkt aus der Erinnerung eintragen | mittel |
| **Kamera-Erkennung (OCR)** | Starkes Marketing-Argument | hoch, fehleranfällig — bewusst nach v1 |

Die ersten vier sind der beste Aufwand-Wirkungs-Hebel im ganzen Projekt: Sie adressieren exakt das Retention-Problem aus `00`, Abschnitt 4.1, und sie sind genau die Art von Detail, die in App-Store-Rezensionen erwähnt wird.
