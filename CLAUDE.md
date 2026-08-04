# Arbeitsweise in diesem Projekt

## Regel 1 — Jede Änderung kommt sofort in den Klick-Dummy

Sobald sich etwas am Produkt ändert — neue Ansicht, geänderter Ablauf, andere
Berechnung, angepasstes Design — wird `docs/prototype/index.html` im selben
Zug aktualisiert und als Artifact neu veröffentlicht.

**Keine Produktänderung wird nur beschrieben.** Wenn sie nicht anklickbar ist,
ist sie nicht fertig.

- Veröffentlichen immer über **denselben Artifact-Pfad**, damit die URL stabil
  bleibt: `/tmp/.../scratchpad/pulsemeter-klickdummy.html`. Der Versionswähler
  im Artifact hält die Historie.
- Aus einer neuen Sitzung heraus die URL unten als `url` mitgeben — sonst
  entsteht ein zweiter Link und die Historie reißt ab.
- `label` je Veröffentlichung kurz und beschreibend setzen („datenansicht",
  „erfassung-v2").
- Danach dieselbe Datei nach `docs/prototype/index.html` kopieren und
  mitcommitten — der Container wird irgendwann abgeräumt, das Repo nicht.

## Regel 1a — Der Link steht in jeder Antwort

Die URL des Klick-Dummys gehört **an den Anfang jeder Antwort**, in der sich
etwas am Produkt geändert hat. Nicht als Verweis auf das Seitenpanel, nicht
am Ende, sondern als anklickbare Zeile ganz oben:

```
🔗 Klick-Dummy: https://claude.ai/code/artifact/720b5f91-ac9d-4371-a2ed-2d9da645b28c
```

Diese URL bleibt über alle Sitzungen dieselbe.

**Zusätzlich** wird `docs/prototype/index.html` per SendUserFile mitgeliefert.
Grund: Artifacts sind privat und an den claude.ai-Account gebunden — auf einem
zweiten Gerät oder im Inkognito-Fenster verlangt der Link eine Anmeldung. Die
Datei ist in sich geschlossen und läuft ohne Login und ohne Netz.

GitHub Pages wäre die dritte Möglichkeit, scheidet aber vorerst aus: Das Repo
ist privat, und Pages setzt dafür GitHub Pro voraus.

## Regel 2 — Der Prototyp rechnet echt

Der Klick-Dummy enthält eine verkürzte Fassung von `PulseCore` in JavaScript.
Er zeigt keine Platzhalterzahlen, sondern rechnet mit echten Zeitreihen über
drei Jahre. Das ist Absicht: Bisher hat jede Runde am Prototyp einen echten
Fehler im Rechenkern aufgedeckt, den kein ausgedachter Unit-Test gefunden hätte.

Ändert sich Logik in `PulseCore`, wird sie im Prototyp nachgezogen — und
umgekehrt. Weichen beide voneinander ab, ist das ein Fehler, kein Zustand.

## Regel 3 — Nichts gilt als fertig ohne Prüfung

| Was | Wie |
|---|---|
| `PulseCore` | `cd Packages/PulseCore && swift test` — muss vollständig grün sein |
| Prototyp | Headless in Chromium laden, Hauptflüsse klicken, auf JS-Fehler und horizontalen Überlauf prüfen, in Hell **und** Dunkel |
| Zahlen im Prototyp | Vor dem Veröffentlichen einmal ausrechnen lassen und auf Plausibilität ansehen |

Swift-Toolchain unter Linux: `/opt/swift/usr/bin` (Swift 6.0.3).
Chromium für Playwright: `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`.

## Sprache

- **Oberfläche und Dokumente:** Deutsch, in der Sprache des Nutzers.
  Verbotene Wörter in der UI: Messstelle, Zählwerk, Register, OBIS, Entität,
  Datensatz, Synchronisation.
- **Code, Bezeichner, Commit-Nachrichten:** Englisch.
- **Kommentare im Code:** Deutsch, und sie begründen *warum*, nicht *was*.

## Wo was liegt

```
docs/00-produktstrategie.md   Problem, Markt, Zielgruppen, Prinzipien, Risiken
docs/01-architektur.md        Technische Entscheidungen als ADR
docs/02-datenmodell.md        Domänenmodell, Rechenkern, Randfälle
docs/03-ux-konzept.md         Navigation, Kernscreens, Design-System
docs/04-monetarisierung.md    Free / Pro / Vermieter
docs/05-roadmap.md            v1-Umfang, Ausschlüsse, Reihenfolge
docs/prototype/index.html     Klick-Dummy, in sich geschlossen
Packages/PulseCore/           Domäne und Rechenkern, nur Foundation
```

## Produktprinzipien, gegen die jede Änderung geprüft wird

1. **60 Sekunden** von Installation bis zur ersten Ablesung, ohne Konto.
2. **3 Berührungen** von App-Start bis zur gesicherten Folge-Ablesung.
3. **5 Sekunden** Blickzeit für „Ist alles im Rahmen?" — ohne Scrollen.
4. **Keine Sackgasse** — jede angezeigte Zahl ist antippbar und erklärt sich.
5. **Datenfreiheit** — Export bleibt dauerhaft kostenlos.
6. **Kein technisches Vokabular** — die Struktur lebt im Datenmodell, nicht in
   der Oberfläche.
7. **Nie stillschweigend rechnen** — geschätzte, interpolierte und
   hochgerechnete Werte sind immer als solche gekennzeichnet.

## Wiederkehrende Fehlerklasse

Bisher entstanden alle gefundenen Rechenfehler dadurch, dass ein Zeitraum, den
die Daten abdecken, gegen einen verglichen wurde, den sie nicht abdecken.
Bei jedem neuen Vergleich, jeder Hochrechnung und jeder Prüfung gilt deshalb:

> Beide Seiten müssen denselben Zeitausschnitt beschreiben — und bei
> saisonalen Zählern denselben Ausschnitt des Jahres.
