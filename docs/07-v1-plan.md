# 07 – Der Weg zum ersten Go-Live

Stand: 2026-08-09
Ziel: **1.0 im App Store**, mit dem kleinsten Umfang, der das Produktversprechen einlöst.

---

## Leitsatz

Nicht alles muss zum ersten Release fertig sein. Fertig muss sein, was ein
Nutzer am ersten Tag braucht — und alles, was Apple verlangt.

Der Rest ist 1.1, und 1.1 kommt schneller, wenn 1.0 draußen ist. Die größte
Gefahr bleibt Risiko R7 aus `00-produktstrategie.md`: eine Version 1, die nie
fertig wird.

---

## 1. Der Engpass ist kein Feature

**Apple Developer Program, 99 € im Jahr.** Ohne das gibt es kein TestFlight,
keinen App Store, keine Paywall und keine App-Gruppe fürs Widget. Es blockiert
allein, es lässt sich nicht vorarbeiten, und die Verifizierung dauert
gelegentlich Tage.

Das ist Schritt eins. Alles andere läuft parallel.

---

## 2. Was bereits steht

Erfassung, Übersicht, Verlauf, Zählerverwaltung, Tarife, Kosten, Prognose,
Abschlagsvergleich, Zweirichtungszähler, Doppeltarif, Zählerwechsel,
CSV-Export, Erinnerungen, Widget, PDF-Bericht. Rechenkern mit 154 Prüfungen,
`PulseData` auf macOS geprüft, Design-System in Hell und Dunkel.

Das ist mehr Umfang, als die meisten 1.0 haben.

---

## 3. Was für 1.0 noch hinein muss

| Was | Zustand | Wer |
|---|---|---|
| Paywall, StoreKit 2, Kaufwiederherstellung | offen | Mac, nach dem Programm |
| **App-Store-Material** — Icon, Bilder je Gerätegröße, Texte, Datenschutzerklärung mit URL, Support-URL | **nicht angefangen** | gemeinsam |
| App-Privacy-Angaben | offen | Nutzer |
| Barrierefreiheit zu Ende | halb | Mac |
| 800 ms Kaltstart auf einem **Gerät** | nie gemessen | Nutzer |
| **Zwei Wochen echte Eigennutzung** | offen | Nutzer |

### Warum die Eigennutzung ganz oben mitsteht

Sieben der bisher gefundenen Darstellungsfehler hat kein Test gefunden, sondern
der Blick auf einen Screenshot. Und der eine Fehler, der den Erfassungsfluss zur
Sackgasse machte, fiel auf, weil jemand die App **benutzt** hat.

Zwei Wochen mit den eigenen Zählerständen finden mehr als jede weitere Runde
Tests. Das Zeitfenster für die Reparaturen danach gehört fest eingeplant — es
füllt sich zuverlässig.

### Was am meisten unterschätzt wird

Das App-Store-Material. Icon, sechs bis acht Bilder je Gerätegröße, Kurz- und
Langbeschreibung, Schlagworte, eine erreichbare Datenschutzerklärung und eine
Support-Adresse. Das ist kein Nachmittag, und es blockiert am Ende die
Einreichung, wenn man zu spät anfängt.

---

## 4. Was gestrichen wird

| Gestrichen | Nach | Warum das trägt |
|---|---|---|
| **Foto-Belege** | 1.1 | Größtes Restrisiko im ganzen Umfang: Bilder in CloudKit, Speicherplatz, Export, Löschen, Zählerwechsel. Viel Arbeit für ein Pro-Merkmal, das niemand vermisst, der die App noch nicht hat |
| **Siri-Kurzbefehl** | 1.1 | Wer die App nicht kennt, richtet keinen Kurzbefehl ein |
| **Widget** | 1.0, aber ohne Gnade | Ist gebaut. Zickt die App-Gruppe, fliegt es raus, statt den Start zu verschieben |
| Vermieter, iPad, Import | 1.1 | War nie in 1.0 |

Foto-Belege sind der einzige Streichposten, bei dem es weh tut: Sie stehen in
`04-monetarisierung.md` in der Pro-Liste. Pro trägt aber auch ohne sie —
unbegrenzte Zähler, Kosten und Tarife, Abschlagsvergleich, Jahresprognose und
der PDF-Bericht sind fünf Gründe, und keiner davon ist ein Versprechen auf
später.

**In der Pro-Beschreibung im Store dürfen sie deshalb nicht auftauchen.** Ein
verkauftes Merkmal, das es nicht gibt, ist eine Rückerstattung und eine
schlechte Bewertung.

---

## 5. Reihenfolge

1. **Apple Developer Program kaufen.** Blockiert alles Weitere.
2. **Die App benutzen** — ab sofort, parallel, mit echten Zählerständen.
3. **Paywall und StoreKit**, sobald das Programm da ist.
4. **Reparieren, was Punkt 2 gefunden hat.** Dieses Fenster nicht wegplanen.
5. **Barrierefreiheit zu Ende, 800 ms auf dem Gerät messen.**
6. **App-Store-Material.** Früher anfangen, als es sich anfühlt.
7. **TestFlight** an fünf bis zehn Leute, zwei Wochen.
8. **Einreichen.** Die erste Ablehnung ist normal und eingeplant.

---

## 6. Was ohne den Nutzer geht — und was nicht

| Ort | Kann |
|---|---|
| Cloud-Sitzung (Linux) | Rechenkern, Klick-Dummy, Dokumente, Werkzeug, CI |
| Sitzung am Mac | Paywall, Barrierefreiheit, App-Build, Bilder fürs Material |
| **Nur der Nutzer** | Developer Program, Messung auf dem Gerät, zwei Wochen Eigennutzung, und die Entscheidung, was gut genug ist |

---

## 7. Zeitrahmen, ehrlich

**Vier bis sechs Wochen bis zur Einreichung**, wenn das Programm diese Woche
gekauft und die App tatsächlich benutzt wird. Der Code ist nicht das Problem —
Material, Eigennutzung und Review sind es.

Ein Vorbehalt gehört dazu: Der PDF-Bericht ist bis heute **nie als PDF gesehen
worden**, und die App lief noch nie auf einem echten Gerät. Beides kann diesen
Plan ändern. Genau deshalb steht die Eigennutzung so weit vorn.
