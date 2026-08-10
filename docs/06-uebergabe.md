# 06 – Übergabe an eine Sitzung, die diesen Verlauf nicht kennt

Stand: 2026-08-10, Version 0.34.0

---

## Wozu dieses Dokument

Eine neue Sitzung startet kalt. Sie kennt keinen Chatverlauf — weder den auf
dem Mac noch den in der Cloud. Was sie kennt, ist das Repository.

Der **dauerhafte** Teil steht deshalb längst dort und ist ausführlich:

| Was | Wo |
|---|---|
| Warum es dieses Produkt gibt, für wen, wogegen es sich entscheidet | `docs/00-produktstrategie.md` |
| Jede technische Entscheidung mit Begründung | `docs/01-architektur.md` |
| Domänenmodell, Rechenkern, Randfälle | `docs/02-datenmodell.md` |
| **Jede Änderung mit Begründung, neueste oben** | `CHANGELOG.md` |
| Arbeitsweise, Sprachregeln, Prüfschritte, die vier Regeln | `CLAUDE.md` |
| Was für 1.0 fehlt und was gestrichen ist | `docs/07-v1-plan.md` |
| Das Aufbauschema zum Übertragen | `docs/08-baukasten.md` |

Dazu die Kommentare im Code: Sie begründen durchgehend das **Warum**, nicht das
Was.

Was **nicht** im Repository steht, ist der laufende Zustand. Genau dafür ist
diese Datei. Sie wird bei jeder Übergabe überschrieben, nicht fortgeschrieben.

---

## Wo die Arbeit steht

**`main` ist der aktuelle Stand.** Am 10. August sind 21 Commits von 0.31.0 bis
0.33.5 zusammengeführt worden; die Arbeitszweige sind erledigt. Der letzte
vollständige macOS-Lauf war **grün**: 154 Prüfungen in `PulseCore`, 21
Oberflächenprüfungen, 44 im Klick-Dummy, 18 Screenshots.

Alles aus dem v1-Umfang steht bis auf Paywall und StoreKit — die brauchen das
Apple Developer Program.

### Die nächsten Schritte

Sie stehen begründet und sortiert in **`docs/07-v1-plan.md`**. Kurz:

1. **Apple Developer Program kaufen** (99 €). Blockiert Paywall, TestFlight und
   App Store und lässt sich nicht vorarbeiten. Liegt beim Gründer.
2. **Die App zwei Wochen mit echten Zählerständen benutzen.** Der Punkt, der
   bisher am meisten gefunden hat.
3. Danach Paywall und StoreKit, Barrierefreiheit zu Ende, 800 ms auf einem
   Gerät messen, App-Store-Material.

**Gestrichen für 1.0:** Foto-Belege und Siri-Kurzbefehl, beide nach 1.1. Sie
dürfen deshalb auch nicht in der Pro-Beschreibung im Store auftauchen.

### Kleinigkeit, die offen blieb

Die Arbeitszweige `claude/pulsemeter-kickoff-dns3am` und
`claude/setup-pruefung-4qyr2u` sind zusammengeführt, ließen sich aber aus der
Cloud-Sitzung **nicht löschen** — der git-Vermittler dort blockiert das Löschen
von Referenzen. Auf einem Mac genügt:

```bash
git push origin --delete claude/pulsemeter-kickoff-dns3am
git push origin --delete claude/setup-pruefung-4qyr2u
```

---

## Was der 9./10. August gekostet und gebracht hat

Ein Tag an einer einzigen roten Oberflächenprüfung und einem leeren Bericht.
Beide Male ging es schnell, sobald gemessen statt vermutet wurde — und langsam,
solange vermutet wurde. Die Zahlen:

| | Vermutungen | Messungen |
|---|---|---|
| Doppeltarif-Schalter | 3, alle falsch | 1, klärte alles |
| Leerer PDF-Bericht | 4, alle falsch | 1, klärte alles |

**Die Regel daraus** steht in `docs/08-baukasten.md` und gilt für jedes
Projekt: Nach dem **zweiten** Fehlversuch nicht weiterraten, sondern die
Prüfung oder die Ansicht ihren eigenen Zustand berichten lassen. Eine Vermutung
kostet hier eine Viertelstunde Läuferzeit und bringt im Zweifel nichts.

### Was dabei am Produkt gefunden wurde

- **Der PDF-Bericht war seit 0.32.0 unsichtbar.** Nicht falsch gerechnet — die
  Vorschau schnitt ihren eigenen Inhalt weg (`scaleEffect` ändert die
  Layoutgröße nicht, der Rahmen darunter zentrierte die unveränderte Box). Alle
  Prüfungen dazu waren grün, weil sie `exists` fragten statt `isHittable`.
  Gefunden hat es ein **Bildschirmfoto**, nachdem 0.32.8 dafür gesorgt hatte,
  dass auch ein roter Lauf Bilder liefert.
- **Der Knopf „Stand eintragen" hieß in jeder Karte gleich.** Sichtbar
  eindeutig, für VoiceOver nicht: vier Zähler, vier identische Knöpfe. Er trägt
  jetzt den Zählernamen in der Beschriftung.

---

## Worauf besonders zu achten ist

**Die wiederkehrende Fehlerklasse.** Jeder bisher gefundene Rechenfehler
entstand daraus, dass ein Zeitraum, den die Daten abdecken, gegen einen
verglichen wurde, den sie nicht abdecken. Elf Fälle. Steht in `CLAUDE.md` und
ist keine Floskel.

**`exists` ist keine Aussage über Sichtbarkeit.** Die teuerste Lehre dieses
Tages. Wo eine Prüfung belegen soll, dass ein Nutzer etwas *sieht*, gehört
`isHittable` dazu.

**Screenshots finden, was Tests nicht finden.** Inzwischen acht
Darstellungsfehler, darunter der unsichtbare Bericht.

**Der Klick-Dummy ist der produktivste Fehlerfinder.** Er rechnet echt. Weicht
er von `PulseCore` ab, ist das ein Fehler, kein Zustand.

**Beim Nutzer liegen:** Apple Developer Program und die Messung auf einem
echten Gerät.

---

## Wie die beiden Orte zusammenarbeiten

Eine Sitzung am Mac und eine in der Cloud sehen einander **nicht**. Verbunden
sind sie über das Repository und zwei Zweige:

- **`pruefungen`** — eine Zeile je lokalem Lauf. **Noch leer:** Auf dem Mac ist
  bisher kein Lauf gemeldet worden.
- **`screenshots`** — die Bilder des letzten Laufs, aus der CI **oder** von
  einem Mac (`scripts/pruefen.sh --melden`, und damit jedes
  `scripts/mac-start.sh`). Die Kopfzeile nennt Herkunft und warnt, wenn der
  Lauf gefallen war.

Sinnvolle Aufteilung: Die Cloud-Sitzung nimmt `PulseCore`, den Entwurf und das
Werkzeug; die Sitzung am Mac baut, prüft und fotografiert die App. Beide halten
sich an `CLAUDE.md`, besonders an Regel 4.
