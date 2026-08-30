---
name: projekt-baukasten
description: Das gesammelte Vorgehen für ein Softwarevorhaben — wie ein Projekt aufgebaut, dokumentiert, konzipiert, geprüft und ohne Mac bis in TestFlight ausgeliefert wird, und welche Fallen bei Apple, App Store Connect, macOS-Läufern, Berechtigungen und In-App-Käufen dabei zuschlagen. **Zuerst verwenden, wenn eine Sitzung in einem leeren oder frisch angelegten Repository startet** — also überall dort, wo es noch keine CLAUDE.md und kein scripts/pruefen.sh gibt: dann wird das Gerüst aufgesetzt, bevor die erste Zeile Code entsteht. Außerdem verwenden, wenn ein neues Projekt beginnt oder eingerichtet wird, wenn eine Sitzung kalt startet und wissen muss, wie hier gearbeitet wird, wenn etwas über die Schnittstelle von Apple angelegt oder freigeschaltet werden soll, wenn ein Bau, ein Profil, eine Signatur oder ein Kauf nicht durchgeht, wenn ein Konzept oder eine Produktentscheidung entsteht, und wenn jemand fragt „wie machen wir das hier eigentlich" oder etwas aus einem anderen Projekt übernehmen will. Und es gilt: Jede neue, teuer bezahlte Erkenntnis wird hier nachgetragen.
---

# Der Baukasten

Alles, was dieses Projekt an Vorgehen gelernt hat, in einer Datei — damit es
in einer anderen Sitzung und in einem anderen Projekt nicht noch einmal
herausgefunden werden muss.

**Was hier steht, ist bezahlt.** Fast jede Zeile ist ein roter Lauf, ein
verbrannter gemieteter Mac oder ein halber Tag. Zahlen sind gemessen; wo
etwas nur vermutet ist, steht das dabei.

**Diese Datei wird fortgeführt.** Sobald eine Runde etwas kostet, das beim
nächsten Mal Zeit spart, kommt es hier hinein — im selben Commit, ohne dass
jemand danach fragt. Der Abschnitt ganz unten sagt, wie.

> **Langfassungen im PulseMeter-Repo:** `docs/08-baukasten.md` (wie geprüft
> wird) und `docs/12-auslieferung.md` (wie ausgeliefert wird). In einem
> anderen Projekt gibt es die nicht — was hier steht, genügt allein.

---

## 0. Wie diese Datei in ein neues Projekt kommt

### Der Fall, der am häufigsten vorkommt: ein leeres Repository, vom Telefon

Wird diese Skill in einer Sitzung geladen, deren Repository **kein**
`scripts/pruefen.sh` und **keine** `CLAUDE.md` hat, dann ist das Aufsetzen die
erste Aufgabe — vor der ersten Zeile Code, ohne dass jemand danach fragt. Es
gibt hier kein `scripts/neues-projekt.sh`; die folgenden Dateien werden direkt
angelegt, ihr Inhalt steht in den Abschnitten 1 bis 8.

| Datei | Was hineingehört |
|---|---|
| `CLAUDE.md` | die vier Regeln aus Abschnitt 1 und 8, die Sprachregeln, und **leer gelassen** die Produktprinzipien — die kann nur der Betreiber sagen |
| `scripts/pruefen.sh` | ein Befehl für alles, Umfänge `alles`/`schnell`, Schalter `--nur` und `--melden`, Schritte nach **Kosten** sortiert, Übersprungenes wird **benannt** |
| `.github/workflows/ci.yml` | zwei Aufträge, Nebenläufigkeit **je Auftrag** — der schnelle abbrechbar, der lange nicht —, Belege auch bei rotem Lauf |
| `.githooks/pre-push` | `scripts/pruefen.sh schnell` vor jedem Push, dazu `git config core.hooksPath .githooks` |
| `CHANGELOG.md` | neueste Version oben, Aufbau nach `release-discipline` |
| `docs/06-uebergabe.md` | der laufende Zustand, wird **überschrieben**, nicht fortgeschrieben |
| `.claude/skills/projekt-baukasten/SKILL.md` | **diese Datei, wörtlich** — nur so hat auch die nächste Sitzung in diesem Repository sie |

Die letzte Zeile ist die wichtigste und wird am leichtesten vergessen. Eine
Skill aus dem claude.ai-Konto gilt in einer Cloud-Sitzung; sie gilt **nicht**
für jemanden, der das Repository klont, und nicht für einen Prüflauf. Committet
gehört sie trotzdem.

Danach die drei Dinge nennen, die niemand raten kann: die Schritte in
`pruefen.sh`, die Produktprinzipien, und bei einem iOS-Vorhaben die Kennung
**vor** dem ersten Bau (Abschnitt 4).

### Wo eine Sitzung diese Datei überhaupt findet

| Ort | Pfad | Gilt in |
|---|---|---|
| claude.ai-Konto | in den Skill-Einstellungen hochgeladen | **jeder Cloud-Sitzung**, auch in einem frisch angelegten Repo |
| Persönlich | `~/.claude/skills/<name>/SKILL.md` | allen Projekten auf **einem Rechner** |
| Projekt | `<projekt>/.claude/skills/<name>/SKILL.md` | diesem Repository — lokal **und** in der Cloud |

**Eine Cloud-Sitzung liest `~/.claude/skills` nicht.** Wer Vorhaben vom Telefon
aus anfängt, hat deshalb genau einen Weg, der ohne Vorarbeit im Repository
funktioniert: die Skill **einmal** ins claude.ai-Konto laden. Danach ist sie in
jedem neuen Chat dabei, und der Abschnitt oben sorgt für den Rest.

### Auf einem Rechner mit Shell

Von Hand kopieren funktioniert genau einmal und dann nie wieder. Deshalb gibt
es `scripts/neues-projekt.sh`.

**Einmal auf dem Rechner, danach nie wieder:**

```bash
scripts/neues-projekt.sh --einrichten
```

Das setzt drei Dinge, und jedes deckt eine Lücke der beiden anderen:

1. **Verweis** auf `~/.claude/skills/projekt-baukasten` — die Skill gilt in
   jedem Projekt auf diesem Rechner.
2. **Ein Block in `~/.claude/CLAUDE.md`** — diese Datei wird in *jeder* Sitzung
   gelesen, auch in der ersten Minute eines leeren Ordners. Genau dann, wenn
   noch nichts dasteht, was eine Skill auslösen könnte. Darin die Anweisung:
   In einem Projekt ohne `scripts/pruefen.sh` oder ohne `CLAUDE.md` zuerst das
   Gerüst aufsetzen.
3. **Die Funktion `neu` in `~/.zshrc`** — damit „neues Projekt" nicht heißt, an
   ein Skript in einem anderen Repository zu denken. Der Befehl, mit dem ein
   Vorhaben anfängt, **ist** das Aufsetzen:

```bash
neu wasserwacht          # ~/Code/wasserwacht anlegen, Gerüst, hineinspringen, Claude
```

Alles drei ist wiederholbar: Die Blöcke stehen zwischen Marken und werden
**ersetzt**, nicht angehängt. Sonst trüge eine `.zshrc` nach vier Einrichtungen
vier Fassungen derselben Funktion.

**Einzelne Teile, wenn nicht alles gewollt ist:**

```bash
scripts/neues-projekt.sh --ueberall        # nur der Verweis, ohne Shell
scripts/neues-projekt.sh ~/Code/neu Name   # nur ein Projekt aufsetzen
scripts/neues-projekt.sh --trocken …       # nur zeigen, was geschähe
```

**Zwei Wege, weil es zwei Orte gibt.** Gemessen an der Dokumentation von
Claude Code:

| Ort | Pfad | Wo es gilt |
|---|---|---|
| Persönlich | `~/.claude/skills/<name>/SKILL.md` | alle Projekte auf diesem Rechner |
| Projekt | `<projekt>/.claude/skills/<name>/SKILL.md` | dieses Repository — **auch in der Cloud** |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | wo das Plugin eingeschaltet ist |

**Eine Cloud-Sitzung liest `~/.claude/skills` nicht.** Sie sieht nur, was im
geklonten Repository liegt. Der Verweis im Heimverzeichnis nützt also am Mac
und nirgends sonst — ein neues Repository braucht trotzdem seine eigene Kopie.
Wer es ohne Kopie über alle Rechner will, packt die Skill in ein Plugin und
deklariert es in `.claude/settings.json` des Repositories; solche Plugins
werden beim Sitzungsstart installiert.

`--ueberall` legt einen **Verweis** an, keine Kopie: Claude Code folgt an
dieser Stelle einem Symlink. Eine Kopie wäre am Tag der Erstellung richtig und
danach still veraltet — genau die Doppelung, gegen die diese Datei sonst
argumentiert.

Was das Aufsetzen mitbringt: die drei Skills, `melden.sh`, `publish-shots.sh`
und den Push-Haken unverändert, dazu ein Gerüst für `pruefen.sh`, einen
Arbeitsablauf mit getrennter Nebenläufigkeit je Auftrag, `CLAUDE.md`,
`CHANGELOG.md` und die Übergabe-Vorlage. Vorhandene Dateien werden **nie**
überschrieben, sondern benannt und übersprungen.

Von Hand bleibt danach: die Schritte in `pruefen.sh`, die Produktprinzipien in
`CLAUDE.md` — und bei einem iOS-Projekt die Abschnitte 4 und 5, **bevor** der
erste Bau läuft.

---

## 1. Wie ein Projekt aufgebaut wird

### Die vier Ideen

**1. Ein Befehl prüft alles.** Nicht vier Befehle in einer Reihenfolge, die
irgendwo beschrieben steht. Ein Skript, das an **beiden** Orten läuft, überall
dasselbe prüft und **benennt**, was es überspringt. Zwei Abläufe laufen
auseinander, und dann prüft der eine etwas anderes als der andere. Deshalb ist
es dasselbe Skript wie in der CI-Beschreibung.

**2. Der lokale Lauf ist der erste Durchgang, die CI die Gegenprobe.** Lokal
zwei Minuten, in der CI fünfzehn. Wer auf die CI wartet, wartet auf ein
Ergebnis, das er längst haben könnte.

**3. Zwei Zweige verbinden, was einander nicht sieht.** Eine Cloud-Sitzung
erreicht den Rechner des Nutzers nicht und umgekehrt. Verbunden sind sie über
git: `pruefungen` bekommt eine Zeile je lokalem Lauf (Zeitpunkt, Stand,
Ergebnis, Umfang, Dauer, Rechner), `screenshots` die Bilder des letzten Laufs.
Damit ist die CI für nichts mehr das Nadelöhr.

**4. Angefangenes wird zu Ende gebracht, ohne Nachfrage.** Wer einen Lauf
anstößt, plant die Nachschau selbst, bevor der Zug endet. Nie auf eine
Erinnerung warten, nie mit `sleep` blockieren.

### Die Teile

| Datei | Was sie tut | Übertragbar? |
|---|---|---|
| `scripts/pruefen.sh` | ein Befehl für alles, mit Umfängen (`schnell`, `app`, `bilder`) und Schaltern (`--nur`, `--melden`) | Gerüst allgemein, Schritte projektspezifisch |
| `scripts/mac-start.sh` | Stand holen → einrichten → prüfen → melden → Bilder zeigen | fast unverändert |
| `scripts/melden.sh` | schreibt eine Zeile je Lauf in den Zweig `pruefungen` | unverändert |
| `scripts/publish-shots.sh` | schiebt Bilder in den Zweig `screenshots`, aus CI **und** vom Rechner | fast unverändert |
| `.githooks/pre-push` | die schnellen Prüfungen vor jedem Push | unverändert |
| `.github/workflows/ci.yml` | schneller Auftrag auf Linux, langsamer auf macOS | Aufbau allgemein |
| `CLAUDE.md` | Arbeitsweise, Prüfschritte, Sprachregeln, die Regeln | teils allgemein |
| `.claude/skills/release-discipline` | Version, Release Notes und Tests als Pflicht je Änderung | unverändert |
| `.claude/settings.json` | die Befehle des Projekts ohne Rückfrage, `sudo` gesperrt | Liste anpassen |
| `docs/06-uebergabe.md` | der laufende Zustand für eine Sitzung, die kalt startet | Vorlage, wird **überschrieben**, nicht fortgeschrieben |

### Die Prüfungen — und was jede gekostet hat, bevor es sie gab

**Die Tabelle oben beschreibt das Gerüst. Diese hier beschreibt den Inhalt, und
der ist das eigentliche Erbe.** Jede dieser Prüfungen ist aus einem Schaden
entstanden, nicht aus einer Vorstellung von Gründlichkeit. Wer sie in ein neues
Vorhaben mitnimmt, kauft elf bezahlte Lehrgelder für eine Kopieroperation.

Jede Datei trägt ihren Anlass im eigenen Kopf — vor dem Übernehmen einmal
lesen; dort steht, ob sie für das neue Vorhaben überhaupt zutrifft.

| Prüfung | Was sie fängt | Was es ohne sie gekostet hat | Übertragbar? |
|---|---|---|---|
| `check-strings.py` | ein `„` in einem Swift-Literal, das die Zeichenkette zerreißt; ungültiges Python, YAML und Shell in Arbeitsabläufen; Store-Felder über ihrer Zeichengrenze | ein macOS-Lauf von fünfzehn Minuten für ein einzelnes Zeichen; zweimal ein TestFlight-Lauf an kaputter Shell; eine Beschreibung mit 4152 von 4000 Zeichen, die Apple erst am Ende einer Einreichung abgelehnt hätte | **unverändert**, sobald Swift und ein Store im Spiel sind |
| `check-namen.py` | Namen, die kein Import und keine Zuweisung kennt (pyflakes) | Bau 24 lag schon in TestFlight, als ein fehlendes `import re` den Schritt danach umbrachte — die Testhinweise fielen aus, die Nummer war verbraucht | **unverändert**, überall wo Python-Skripte laufen |
| `check-sicherheit.sh` | Netzverkehr, Protokollausgabe, Analyse-Bausteine, fremde Pakete, öffentliche Cloud-Datenbank, ungenutzte Berechtigungen, widersprüchliche Privacy-Manifeste | nichts — sie war früh da. Genau das ist der Punkt: Ein Datenschutzversprechen hält so lange, wie niemand an einem Dienstagnachmittag eine bequeme Zeile einbaut | **Liste anpassen**, Aufbau unverändert |
| `check-versprechen.py` | Beträge und Anzahlen auf der Website gegen die eine Quelle im Quelltext; Markup gegen sichtbaren Text | zwei Wochen lang bot eine öffentliche Seite ein Feature gratis an, das 0,99 € kostet — während die Preisseite daneben stimmte | **Muster übertragbar**, Pfade projektspezifisch |
| `check-trefferflaechen.py` | Knöpfe ohne `contentShape`, die nur dort reagieren, wo sie zeichnen | ein Fehlerbericht vom Gerät: zwei Drittel einer Zeile reagierten nicht, und wer dort tippt, tippt ein zweites und drittes Mal | **unverändert** bei SwiftUI |
| `check-aktualisierung.py` | eine Ansicht, die eine Änderung an den Daten nicht mitbekommt | ein gelöschter Eintrag blieb auf einem anderen Schirm stehen — vom Gerät gemeldet, nicht von einer Prüfung | **unverändert** bei SwiftUI mit geteiltem Bestand |
| `check-prototype.mjs` | Hauptflüsse, JS-Fehler, horizontaler Überlauf, Hell **und** Dunkel im Klick-Dummy | der Entwurf ist der produktivste Fehlerfinder des Projekts und wurde geprüft, wenn jemand daran dachte | **Muster übertragbar**, wenn es einen Klick-Dummy gibt |
| `check-nichtfunktional.mjs` | Trefferflächen, Kontrast nach AA, Zeiten, und die Produktprinzipien als **gezählte** Bedingung | „drei Berührungen" und „fünf Sekunden" standen als Zusage im Strategiepapier und wurden nie gemessen | **Aufbau übertragbar**, Prinzipien austauschen |
| `check-website.mjs` | Aufbau, Verweise ins Leere, Überlauf von 320 bis 1280 Pixel, fremde Anfragen — und den **Ton**: Gedankenstriche je 250 Wörter, verbotene Werbewörter | eine Regel, die niemand zählt, wird nicht befolgt: 25 Gedankenstriche auf 1150 Wörter, obwohl die Regel seit Wochen dastand | **unverändert**, wenn eine Website dazugehört |
| `check-buendel.mjs` | dasselbe für die zu einer Datei gepackte Fassung | ein Bündel zeigte im Dunkeln drei leere Rahmen, weil nur `src` ersetzt wurde und nicht `srcset` | nur mit Bündel |
| `check-entwuerfe.mjs` | Vorschlagsseiten, die beim Antippen nichts tun | ein Entwurf sieht auf einem Bild fertig aus, auch wenn nichts dahinterliegt | nur mit Entwurfsseiten |

**Die Reihenfolge in `pruefen.sh` ist nach Kosten sortiert, nicht nach
Wichtigkeit.** Die ersten sechs zusammen brauchen unter fünf Sekunden. Was in
einer Sekunde brechen kann, soll auch in einer Sekunde brechen — und nicht nach
sechzehn Minuten auf einem gemieteten Mac.

`scripts/neues-projekt.sh <ordner>` bringt die vier ohne Projektbezug
(`check-strings.py`, `check-namen.py`, `check-sicherheit.sh`,
`check-trefferflaechen.py`) direkt mit und trägt sie in das erzeugte
`pruefen.sh` ein. Die übrigen sind Vorlagen: hinsehen, anpassen, übernehmen.

### In zehn Schritten übertragen

1. `scripts/`, `.githooks/`, `.claude/` und `.github/workflows/ci.yml` kopieren.
2. In `pruefen.sh` die Schritte austauschen. **Nach Kosten sortieren, nicht
   nach Wichtigkeit** — was in einer Sekunde brechen kann, soll auch in einer
   Sekunde brechen.
3. Die Bedingung finden, die „hier fehlt das schwere Werkzeug" bedeutet (hier:
   `xcodebuild`). Übersprungenes wird **benannt**, nie verschwiegen.
4. `mac-start.sh` auf den Zielzweig einstellen.
5. `melden.sh` und `publish-shots.sh` unverändert übernehmen — beide brauchen
   nur `origin`.
6. Im Arbeitsablauf beide Aufträge trennen: einer schnell und abbrechbar, einer
   langsam und **nicht** abbrechbar.
7. Bilder — oder was das Gegenstück ist — **auch bei rotem Lauf** erzeugen.
8. `CLAUDE.md` schreiben: wo was liegt, wie geprüft wird, welche Wörter
   verboten sind, und die Regel, dass Angefangenes zu Ende gebracht wird.
9. `release-discipline` übernehmen.
10. `06-uebergabe.md` anlegen und bei jeder Übergabe überschreiben.

---

## 2. Wie dokumentiert wird

**Nummerierte Dokumente, ein Thema je Datei, Entscheidungen als ADR.**
Strategie, Architektur, Datenmodell, UX, Monetarisierung, Roadmap,
Sichtbarkeit, Sicherheit, Auslieferung. Ein Dokument beantwortet eine Frage;
wer die Frage hat, findet die Datei am Namen.

**Was ein gutes Dokument von einem schlechten trennt:**

- **Zahlen sind gemessen oder gekennzeichnet.** „Fünf Läufe, vier Befunde",
  „80 bis 130 Sekunden", „27 Stellen". Eine Annahme steht als Annahme da
  („Wette", „geschätzt", „nicht gemessen").
- **Der Fehlschlag steht drin, nicht nur die Lösung.** Der Abschnitt „was uns
  das gekostet hat" ist der wertvollste. Er verhindert, dass jemand denselben
  Weg noch einmal geht, weil er plausibel aussieht.
- **Auch die falsche Vermutung steht drin.** Zweimal war meine Diagnose falsch
  und das Protokoll richtig. Das gehört ins Dokument, sonst wirkt der Weg
  gerade, und der nächste hält seine erste Vermutung wieder für die Antwort.
- **Kommentare im Code begründen *warum*, nicht *was*.** Ein Kommentar, der
  den Code nacherzählt, veraltet still.

**Keine Annahmen in Texten, die jemand anderes liest.** Was über den Betreiber,
sein Gewerbe, seine Anschrift oder seine Zahlen behauptet wird, muss von ihm
bestätigt sein. Sonst: weglassen. Geht es nicht ohne, dann als Platzhalter in
eckigen Klammern mit einem `PLATZHALTER`-Kommentar daneben — sichtbar, zählbar,
prüfbar. Das gilt besonders für Rechtstexte; ein Impressum ist keine Textsorte,
in der sich etwas plausibel ergänzen lässt.

---

## 3. Wie Konzepte entstehen

**Der Prototyp rechnet echt.** Der Klick-Dummy enthält eine verkürzte Fassung
des Rechenkerns und arbeitet mit echten Zeitreihen über Jahre, nicht mit
Platzhalterzahlen. Das ist der Grund, warum er sich lohnt: **Bisher hat jede
Runde am Prototyp einen echten Fehler im Rechenkern aufgedeckt, den kein
ausgedachter Unit-Test gefunden hätte.**

**Weicht der Prototyp von der App ab, ist das ein Fehler, kein Zustand.** Eine
falsche Beschriftung überlebte fünf Versionen, weil der Prototyp die Karte an
dieser Stelle gar nicht zeigte — es gab dort nichts, was hätte auffallen
können.

**Vorschläge statt Vorschlag.** Wenn eine Ansicht nicht trägt: drei Optionen
mit Mehrwert, kurz begründet, der Nutzer wählt eine. Nicht eine bauen und
hoffen.

**Produktprinzipien sind Prüfsteine, keine Präambel.** Jede Änderung wird
gegen sie gehalten. Bei uns: 60 Sekunden bis zur ersten Nutzung ohne Konto,
3 Berührungen bis zur Folgeaktion, 5 Sekunden Blickzeit, keine Sackgasse,
Datenfreiheit, kein technisches Vokabular, **nie stillschweigend rechnen**.

**Selbstsprechend statt erklärt.** Wenn ein Text erklären muss, was daneben
steht, stimmt die Beschriftung nicht. Erst die Beschriftung richtig machen,
dann den Erklärsatz streichen. Anlass: Über einer Zahl stand „August", die
Zahl meinte drei Tage, und ein Satz darunter erklärte das. Die Zahl war
richtig, die Überschrift falsch — und der Erklärsatz hat den Fehler nicht
behoben, sondern verdeckt.

**Kein Schema ersetzt, dass jemand das Produkt benutzt.** Sieben
Darstellungsfehler hat kein Test gefunden, sondern der Blick auf ein Bild —
und der Fehler, der den Kernfluss zur Sackgasse machte, fiel auf, weil jemand
die App in die Hand genommen hat.

---

## 4. Ausliefern ohne Mac

### Die eine Erkenntnis, die alles trägt

**Ein iOS-Projekt braucht keinen Mac, sondern einen macOS-Läufer.** Wer eine CI
mit `runs-on: macos-*` hat, hat den Mac schon. Es fehlen zwei Dinge, und beide
gehen ohne Bildschirm:

- **Signieren** mit einem Schlüssel statt eines Anmeldefensters
  (`-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID`).
- **Hochladen** mit `xcrun altool --upload-app --apiKey … --apiIssuer …`.

Meine erste Antwort war „nein, iOS-Apps brauchen Xcode". Das stimmt — und war
trotzdem falsch, weil das Projekt längst einen hatte. **Wenn eine Antwort auf
eine Voraussetzung verweist, prüfe zuerst, ob sie nicht schon erfüllt ist.**

### Die Reihenfolge, die funktioniert

| # | Was | Wo | Dauer |
|---|---|---|---|
| 1 | API-Schlüssel in App Store Connect, Rolle **App Manager** | Browser | 5 min |
| 2 | Vier Geheimnisse im Repository: Key-ID, Issuer-ID, `.p8`-Inhalt, Team-ID | Browser | 5 min |
| 3 | Verteilzertifikat **einmalig** über die Schnittstelle anlegen und als Geheimnis ablegen | Ablauf | 2 min |
| 4 | **App-Eintrag** in App Store Connect anlegen | Browser | 10 min |
| 5 | Bauen, signieren, hochladen | Ablauf | 3 min |
| 6 | Exportbestimmungen, Testergruppe, Tester, Bau zuweisen | Browser | 5 min |

Schritt 4 kommt vor Schritt 5, und das ist nicht offensichtlich: Die **App-ID**
entsteht beim ersten Bau von selbst, der **App-Eintrag** nicht — aber vor dem
ersten Bau steht die Kennung nicht in Apples Auswahlliste. Also einmal bauen
lassen und den Eintrag anlegen, während der Lauf läuft.

### Die Befunde, in der Reihenfolge, in der sie zuschlagen

**Die Bundle-ID gehört nicht auf eine fremde Domain.**
`com.<produkt>.app` ist eine Wette gegen alle anderen Apple-Entwickler und geht
oft verloren. Nimm `de.<nachname>.<produkt>`. **Und entscheide es vor allem
anderen:** Die Kennung steckt in der Projektdatei, in beiden
Berechtigungsdateien, in der App-Gruppe, im iCloud-Container, in jeder
Kauf-Kennung, in Tests und Skripten — bei uns an 27 Stellen. Solange in App
Store Connect keine App und kein Kauf existiert, ist das Suchen und Ersetzen.
Danach kostet es jeden Käufer seinen Kauf.

**`xcodebuild archive` will ein Development-Profil.** Mit
`CODE_SIGN_STYLE=Automatic` besorgt sich `archive` ein Entwicklungsprofil, und
das verlangt mindestens ein registriertes Gerät. Ein Konto ohne Kabel hat
keins — **dieser Weg kann nie durchgehen.** Ausweg: App-Store-Profile über
`POST /v1/profiles` (`profileType: IOS_APP_STORE`), Inhalt nach
`~/Library/MobileDevice/Provisioning Profiles/<uuid>.mobileprovision`, bauen mit
`CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY="Apple Distribution"` und
`PROVISIONING_PROFILE_SPECIFIER` **je Ziel**.
(Meine erste Erklärung — die fehlende Angabe `-configuration Release` — war
falsch und hat einen Lauf gekostet. Die Profilart hängt nicht an der
Konfiguration.)

**Bauvorgaben auf der Kommandozeile gelten für *alle* Ziele.**
`CODE_SIGN_ENTITLEMENTS=…` hinter `xcodebuild` trifft App **und** Erweiterung.
Also je Ziel in der Projektdatei über Variablen, leer als Vorgabe:

```yaml
settings:
  base:
    PULSE_PROFILE_APP: ""      # leer = automatisch, für Simulator und CI
    PULSE_PROFILE_WIDGET: ""
targets:
  App:    { settings: { base: { PROVISIONING_PROFILE_SPECIFIER: $(PULSE_PROFILE_APP) } } }
  Widget: { settings: { base: { PROVISIONING_PROFILE_SPECIFIER: $(PULSE_PROFILE_WIDGET) } } }
```

Dasselbe Muster trägt `aps-environment`: `development` in Debug, `production`
in Release — fest eingetragen ist einer der beiden Wege immer falsch.

**Der Läufer hat mehrere Xcodes, und das voreingestellte ist zu alt.**
`SDK version issue … must be built with the iOS 26 SDK or later`, während der
Läufer auf 16.4 stand und 26.3 danebenlag. **Nie das voreingestellte Xcode
nehmen.** Höchste vorhandene Fassung suchen, `xcode-select` setzen — und wenn
keine reicht, **auflisten, was da ist**, statt über das Läuferbild zu raten.

**Hochgeladen ist nicht testbar.** Vier getrennte Dinge, jedes hält den Bau
unsichtbar: Exportbestimmungen beantworten (sonst „Missing Compliance"),
Gruppe für interne Tests anlegen, **sich selbst als Tester eintragen**
(Kontoinhaber zu sein genügt nicht), Bau der Gruppe zuweisen.

**Die Testhinweise hängen nicht am Paket.** `altool` lädt nur hoch. „Was ist
neu" hängt am Bau in App Store Connect und geht nur über die Schnittstelle —
erreichbar erst, wenn Apple den Bau verarbeitet hat. Zehn Bauten lang stand bei
den Testern nichts, und niemandem ist es aufgefallen. Also: auf `VALID` warten,
Lokalisierung `de-DE` anlegen oder ändern, melden, wann der Bau bereitsteht.
Dauert die Verarbeitung zu lange, grün enden mit Hinweis — ein roter Lauf für
etwas, das niemand beheben kann, ist eine Meldung ohne Handlung.

### Die Kleinigkeiten, die je einen Lauf kosten

| Falle | Was zu tun ist |
|---|---|
| **Buildnummer doppelt** | App Store Connect nimmt jede Nummer **einmal**. `CURRENT_PROJECT_VERSION=${{ github.run_number }}` — sie zählt auch bei rotem Lauf weiter |
| **Drei Zertifikate, dann Schluss** | Zertifikat **einmal** anlegen und als Geheimnis ablegen. Ein frischer Läufer legt sonst jedes Mal ein neues an |
| **PKCS#12 lässt sich nicht einlesen** | `openssl pkcs12 -export -legacy`. OpenSSL 3 erzeugt sonst ein Format, das der Schlüsselbund mit „MAC verification failed" ablehnt — das sieht nach falschem Kennwort aus und ist keins |
| **`codesign` wartet auf ein Kennwort** | `security set-key-partition-list -S apple-tool:,apple:,codesign:` nach dem Import, sonst läuft der Auftrag in die Zeitgrenze |
| **Falsches Profil am falschen Ziel** | Apples `filter[identifier]` filtert als **Präfix**: `de.x.app` liefert auch `de.x.app.widget`. Genau vergleichen, nicht das erste Ergebnis nehmen |
| **Zugangsdaten fehlen** | Die Prüfung darauf als **ersten** Schritt, sonst scheitert der Lauf nach zwanzig Minuten an einer Meldung, die das fehlende Geheimnis nicht nennt |
| **Geheimnisse abtippen** | Nicht abtippen. Öffentlichen Schlüssel des Repositories holen, Wert in eine Sealed Box legen, `PUT /actions/secrets/<name>`. Dafür braucht es ein **fein granuliertes** Token mit „Secrets: Read and write" — ein klassisches mit `repo` genügt nicht |
| **`cancel-in-progress` über dem ganzen Ablauf** | Nebenläufigkeit **je Auftrag**: der schnelle darf abgebrochen werden, der lange nicht. Drei Läufe an einem Tag endeten sonst kurz vor dem Ziel |
| **Vorgabetext, der nichts sagt** | Ein `default:` wie „Neuer Stand zum Ausprobieren." lässt den Schritt grün melden und liefert den Testern nichts. Vorgabe **leer** lassen und aus dem Änderungsprotokoll ableiten — das steht ohnehin da |

### Ein Schritt, der nur mit Apple spricht, darf nicht an einem Bau hängen

Zweimal dieselbe Rechnung: erst die Berechtigungen, dann die Testhinweise. Beide
liefen zunächst nur im TestFlight-Lauf mit. Das genügt, solange es einmal
richtig ist — und ist falsch, sobald man nachbessern muss. Jeder Versuch kostet
dann einen gemieteten Mac, zwanzig Minuten und eine **verbrauchte Buildnummer**,
für eine Zeile Text.

> Was nur HTTP macht, bekommt zusätzlich einen eigenen `workflow_dispatch` auf
> Linux. **Dasselbe Skript an zwei Orten, nicht zwei Skripte:** im Bau als
> Selbstheilung, daneben zum Nachbessern in Sekunden.

Erkennungsmerkmal für „das gehört auch nach Linux": Der Schritt braucht weder
Xcode noch Simulator noch das Paket — nur den Schlüssel.

---

## 5. App Store Connect über die Schnittstelle

Alles unten ist **gemessen**, nicht aus einer Anleitung übernommen.

### Was geht und was nicht

| Vorgang | Antwort |
|---|---|
| `POST /v1/bundleIdCapabilities` — `APP_GROUPS`, `ICLOUD` (Einstellung `XCODE_6`), `PUSH_NOTIFICATIONS` | 200 — geht, an App **und** Erweiterung |
| `POST /v1/appGroups` | **404** — gibt es nicht, im Portal anlegen |
| `POST /v1/cloudContainers` | **404** — gibt es nicht, im Portal anlegen |
| `POST /v2/inAppPurchases` samt Beschriftung, Preis, Verfügbarkeit, Prüfbild | geht vollständig |
| Verträge (bezahlte Apps, Bank, Steuer) | keine Schnittstelle, nur Browser |

Es bleiben also genau **zwei Klicks im Portal**: die App-Gruppe und der
iCloud-Behälter. Angelegt werden sie dort, **zugeordnet** an der App-ID — und
die Häkchen dafür setzt der Lauf.

### Eine Fortschrittsliste von Hand ist am nächsten Tag falsch

Im Projektdokument stand „was vor dem Einreichen noch fehlt", gepflegt von
Hand. Beim Nachsehen war der Punkt StoreKit offen — obwohl die fünf Käufe seit
Tagen bereit waren und sich in TestFlight kaufen ließen. Nach der Liste hätte
man Arbeit gemacht, die längst getan war.

> Für alles, was eine Schnittstelle beantworten kann, wird **gefragt statt
> erinnert**: ein Lauf, der liest und nichts schreibt, in Sekunden, so oft man
> will. Von Hand bleibt nur, was keine Schnittstelle kennt — Entscheidungen,
> Angaben über Menschen, Messungen am Gerät.

Nützlich ist dabei die Dreiteilung der Ausgabe: **steht** / **mache ich** /
**kann nur der Auftraggeber**. Der dritte Block ist die Liste, die er wirklich
braucht; die ersten beiden gehen ihn nichts an.

### Der Berechtigungsteil gehört nicht in den TestFlight-Lauf

Er spricht nur HTTP: kein Xcode, kein Simulator, kein Mac. Als Schritt im
TestFlight-Lauf kostet **jeder Versuch** einen gemieteten Mac und eine
verbrauchte Buildnummer. Als eigener `workflow_dispatch`-Ablauf auf Ubuntu
läuft er in Sekunden, so oft man will.

Im TestFlight-Lauf bleibt derselbe Schritt trotzdem stehen — dort ist er die
Selbstheilung vor dem Signieren. **Zwei Orte, dasselbe Skript.**

> `workflow_dispatch` verlangt die Datei auf dem Standardzweig, kann aber jeden
> `ref` fahren. So lässt sich ein Zweigstand ausprobieren, ohne ihn zu
> verschmelzen.

### In-App-Käufe anlegen

Vier Schritte je Kauf: anlegen, Beschriftung, Preis, Verfügbarkeit. Dazu das
Prüfbild. Was dabei zuschlägt:

- **`MISSING_METADATA` heißt: StoreKit liefert den Kauf nicht aus** — auch
  nicht in der Sandbox, auch nicht in TestFlight. Die Kaufseite zeigt dann ihre
  Merkmale ohne Knopf. Erst ab `READY_TO_SUBMIT` kommt das Produkt in der App
  an.
- **Das Prüfbild ist Pflicht** für `READY_TO_SUBMIT`, nicht Beiwerk. Genau
  daran hing „ich kann im TestFlight nichts kaufen".
- **Hochladen ist dreiteilig:** reservieren, Bytes per `PUT` an die von Apple
  genannte Adresse, dann mit md5-Prüfsumme bestätigen.
- **Die Maße müssen einer echten Gerätauflösung entsprechen**, nicht bloß ein
  Minimum überschreiten. 640×1000 ist größer als das dokumentierte Minimum und
  wird trotzdem mit `IMAGE_INCORRECT_DIMENSIONS` abgelehnt; 1242×2208 wurde
  angenommen. Welche gilt, steht nirgends verbindlich — also der Reihe nach
  durchprobieren und die siegreiche Größe für die übrigen Käufe merken.
- **Bild lieber ergänzen als vergrößern.** Hochskalieren macht die Schrift
  matschig; ein breiterer Rand in der Eckfarbe des Bildes lässt es in Ruhe.
- **Beziehungsnamen sind nicht durchgängig abgekürzt.** `iapPriceSchedule`
  funktioniert, `iapAvailability` gibt es nicht — sie heißt
  `inAppPurchaseAvailability`. Mit dem falschen Namen sah das Skript 404, hielt
  die Verfügbarkeit für ungesetzt, legte sie bei **jedem** Lauf neu an und
  meldete jedes Mal Erfolg.
- **Store-Text ist eine andere Textsorte als App-Text.** 30 Zeichen für den
  Anzeigenamen, 45 für die Beschreibung. Der Anzeigename ist zugleich Suchfeld —
  beim Kürzen bleiben die Wörter stehen, nach denen jemand sucht.
- **Die Produkt-Kennung ist das einzig Unveränderliche.** Ein umbenannter Kauf
  ist für jeden Käufer ein verlorener Kauf. Deshalb kommt sie im Skript aus
  derselben Regel wie in der App, nie aus einer abgetippten Liste.
- **Ein neu angelegter Kauf ist ein Entwurf**, kein Verkaufsangebot: in der
  Sandbox sichtbar und dort kostenlos, verkauft wird er erst mit der
  Einreichung der App.
- **Die App selbst muss in Ländern verfügbar sein.** Der Kauf hat eine
  Verfügbarkeit *und die App auch*, und die des Kaufs beschreibt nur, wo er
  gälte, wenn es die App dort gäbe. Fehlt sie an der App, antwortet
  `GET /v1/apps/<id>/appAvailabilityV2` mit **404** — „There is no resource of
  type 'appAvailabilities'". Setzen über `POST /v2/appAvailabilities`; die
  Länder gehen als `included` mit und ihre Kennung muss wörtlich `${AFG}`
  lauten, mit geschweiften Klammern. Das veröffentlicht nichts: Die App bleibt
  auf `PREPARE_FOR_SUBMISSION`.
- **Vertrag für bezahlte Apps.** Steht auch nur eine Zeile unter „Geschäftlich"
  — Kontaktangaben, Bankverbindung, Steuerangaben — nicht auf „Aktiv", gibt
  StoreKit in der Sandbox eine **leere** Produktliste zurück, ohne Fehler und
  ohne Hinweis. Das ist die häufigste Ursache für „im TestFlight kommt nichts",
  wenn an den Käufen nachweislich alles steht. Eine Schnittstelle dafür gibt es
  nicht — nur der Browser, unter **appstoreconnect.apple.com/business**.

### Was in TestFlight mit Käufen wirklich geht

Nachgeschlagen, nachdem ich es drei Tage lang **behauptet** hatte:

| Frage | Antwort |
|---|---|
| Kann man in einem TestFlight-Bau kaufen? | **Ja.** TestFlight-Bauten laufen gegen die Sandbox |
| Kostet es den Tester etwas? | **Nein**, in der Sandbox ist jeder Kauf kostenlos |
| Muss der Kauf genehmigt sein? | **Nein**, `READY_TO_SUBMIT` genügt |
| Muss die App genehmigt sein? | **Nein** |
| Braucht es einen Sandbox-Zugang? | **Nein**, in TestFlight nicht |

Bleibt die Produktliste trotzdem leer, sind es erfahrungsgemäß zwei Dinge:
die **Verfügbarkeit der App** und der **Vertrag für bezahlte Apps**. Beide
liegen außerhalb des Kaufs, und genau deshalb sucht man sie zuletzt.

### Die Reihenfolge, in der ein Kauf einzurichten ist

Von unten nach oben zu suchen hat drei Tage gekostet. **Von oben nach unten
einzurichten kostet zwanzig Minuten**, und in dieser Reihenfolge fällt jeder
Fehler dort auf, wo er entsteht:

| # | Was | Wo | Woran man merkt, dass es fehlt |
|---|---|---|---|
| 1 | **Verträge**: bezahlte Apps, Bank, Steuer — alle drei auf „Aktiv" | Browser, `appstoreconnect.apple.com/business` | keine Schnittstelle; nur im Browser sichtbar |
| 2 | **Preisplan der App** | `GET /v1/apps/<id>/appPriceSchedule` | Antwort 404 |
| 3 | **Verfügbarkeit der App** in Ländern | `GET /v1/apps/<id>/appAvailabilityV2` | **404 — „There is no resource of type 'appAvailabilities'"** |
| 4 | **Kauf** anlegen, beschriften, bepreisen, verfügbar machen | `/v2/inAppPurchases` und Beziehungen | Zustand `MISSING_METADATA` |
| 5 | **Prüfbild** je Kauf | `/v1/inAppPurchaseAppStoreReviewScreenshots` | Zustand bleibt `MISSING_METADATA` |
| 6 | Nachlesen: **Zustand**, nicht Existenz | `state` je Kauf | `READY_TO_SUBMIT` = wird ausgeliefert |

**Punkt 3 war bei uns der Blocker**, und er ist der unauffälligste: Die fünf
Käufe standen vollständig auf `READY_TO_SUBMIT`, mit Preis, Beschriftung und
angenommenem Prüfbild — und die App gab es in **keinem** Land. Ein Kauf in
einer App, die in keinem Laden existiert, hat keinen Laden, in dem er
angeboten werden könnte. Die Verfügbarkeit des *Kaufs* half nicht: Sie
beschreibt, wo er gälte, wenn es die App dort gäbe.

**Nach dem Setzen nicht sofort nachmessen.** Zwischen „Verfügbarkeit gesetzt"
und „Preise stehen auf dem Telefon" lagen bei uns **mehrere Stunden**. Ein
Nachmessen nach zehn Minuten hätte „geht immer noch nicht" ergeben und die
richtige Änderung fälschlich verworfen. Wer etwas an der Storefront ändert,
misst am nächsten Tag nach — oder wartet mindestens ein paar Stunden, bevor er
weitersucht.

### Jedes Store-Feld hat eine Zeichengrenze, und Apple prüft sie zuletzt

Name 30, Untertitel 30, Werbetext 170, Schlagworte 100, Beschreibung 4000. Wer
darüber liegt, erfährt es **am Ende einer Einreichung** — nicht beim Schreiben,
nicht beim Übertragen, sondern nachdem alles andere schon stand.

Zwei Fallen darin, beide erlebt:

- **Die Schlagworte wurden stillschweigend abgeschnitten.** Die Liste kam auf
  101 Zeichen, und App Store Connect hat sie beim Einfügen am Ende gekürzt.
  Kein Fehler, keine Warnung, ein Wort weniger.
- **Eine von Hand gepflegte Zahl im Dokument war beim nächsten Satz falsch.**
  Unter der Beschreibung stand „3844 Zeichen". Nach einer Korrektur waren es
  4152, und die Zahl stand unverändert da.

> **Schreib die Grenze in die Überschrift des Feldes und lass sie von dort
> lesen.** „Beschreibung (max. 4000 Zeichen)" ist dann nicht Zierde, sondern
> die Prüfvorschrift: Ein Ausdruck zieht die Zahl heraus und misst den Block
> darunter. Kein zweiter Ort, keine gepflegte Zahl, keine Abweichung möglich.

Das ist derselbe Handgriff wie bei den Preisen: Wo sich der zweite Ort nicht
abschaffen lässt, wird er gemessen statt gepflegt.

### Die Währung kommt vom Gerät, nicht vom Entwickler

Im TestFlight standen `$2,99` und `$9,99` statt Euro. Das ist **kein
Konfigurationsfehler**: Angezeigt wird der Laden der Apple-ID, die auf dem
Gerät angemeldet ist, nicht das Land des Entwicklerkontos. Dasselbe im
CI-Simulator, der in der US-Region läuft.

- Prüfen unter **Einstellungen → App Store → Apple-Account**; im TestFlight
  zusätzlich der Sandbox-Zugang unter **Einstellungen → Entwickler → Sandbox
  Apple Account**.
- Die hinterlegten Beträge sind davon unberührt: Ein Preispunkt gilt in allen
  Ländern, Apple rechnet ihn je Laden um.
- **Deshalb nie einen Betrag fest in die App schreiben.** Was der Store nennt,
  ist die einzige richtige Zahl; ein eigener Vorschlagswert gehört sichtbar
  gekennzeichnet („ca.") und verschwindet, sobald der Store antwortet.

---

## 6. Die zwei Fehlerklassen, die immer wiederkommen

### „Vorhanden" ist nicht „wirkt"

Dreimal an einem einzigen Tag, jedes Mal in anderer Verkleidung:

1. Das Nachlesen der Berechtigungen gab bei einer **Fehlantwort** eine leere
   Menge zurück — und leer heißt für den Aufrufer „nichts eingeschaltet".
   „Konnte ich nicht lesen" und „ist nicht da" sahen gleich aus.
2. Bei den Käufen habe ich die **Existenz** geprüft, nicht den Zustand. Alle
   fünf standen in der Liste und keiner wurde ausgeliefert.
3. Das Prüfbild **existiert**, sobald es reserviert ist. Ob die Bytes ankamen
   und die Maße gelten, sagt `assetDeliveryState` — ein Bild in `FAILED` ist
   vorhanden und zählt trotzdem nicht.

Und ein viertes Mal, diesmal in der Diagnose selbst: Drei Abfragen kamen mit
`400 — nicht lesbar` zurück und sahen aus wie eine Auskunft von Apple. Es war
ein Fehler in meiner Abfrage — ein `limit` an einem Einzelstück statt an einer
Liste. Ausgerechnet die zwei Felder, wegen derer die Aufstellung geschrieben
worden war.

Und ein fünftes Mal, im eigenen Programm — die teuerste Zeile der ganzen Suche:

```swift
if let geladen = try? await Product.products(for: kennungen) { … }
```

Dieses `try?` legt „der Store hat einen Fehler geworfen" und „der Store kennt
keine unserer Kennungen" unter einen Wert. Beides endet in einer leeren Liste,
und die Oberfläche sagte dazu einen Satz, den niemand geprüft hatte. Drei Tage
lang wurde überall gesucht, nur nicht an der Stelle, die die Antwort hatte.

> **Jedes Nachlesen muss zwei Fragen stellen: Ist es da, und wirkt es?** Und
> zwei Sachverhalte gehören nie unter einen Wert. Auch nicht „ich konnte nicht
> fragen" und „die Gegenseite sagt nein": Ein Fehler auf der eigenen Seite darf
> nie wie eine Antwort der Gegenseite aussehen.

### Ein Zeitplan bei GitHub ist keine Zusage

Ein Ablauf mit `schedule: cron: "23 * * * *"` lag ab 12:12 UTC auf dem
Hauptzweig. Bis 18:26 hätte er sechsmal feuern müssen. Gefeuert hat er
**einmal**, um 16:47 — nicht zur Minute, nicht zur Stunde, und danach wieder
nicht. GitHub reiht geplante Läufe bei Last ein und lässt sie aus; in einem
Depot, in dem wenig los ist, sind Verzögerungen von Stunden normal und
ausgelassene Fenster ebenfalls.

Der Fehler daraus war nicht der Ablauf, sondern **meine Aussage darüber**. Um
16:13 standen null Läufe da, und ich habe dem Gründer gemeldet, der Ablauf
feuere nicht. Eine halbe Stunde später hatte er gefeuert. Aus „bisher nicht"
war „tut es nicht" geworden — dieselbe Verwechslung wie überall sonst in dieser
Liste, nur mit der Uhr statt mit einer Schnittstelle.

> **Ein ausgebliebener Lauf ist kein Befund, sondern ein fehlender.** Für eine
> Aussage über einen Zeitplan braucht es mehrere Fenster, und selbst dann heißt
> das Ergebnis „unzuverlässig", nicht „kaputt".

Die Folge fürs Bauen: Ein Zeitplan taugt für Dinge, die auch drei Stunden
später noch richtig sind. Alles, was zu einem **Zeitpunkt** geschehen muss,
bekommt zusätzlich `workflow_dispatch` und einen Satz in der Anleitung, dass am
Tag X von Hand ausgelöst und **nachgesehen** wird.

### „Vorhanden" ist auch nicht „richtig"

Die Stufe nach „vorhanden ist nicht wirkt", und sie kostet mehr, weil nichts
rot wird. Ein Einrichtungslauf las nach, **ob** ein Preisplan existiert, und
meldete „Preis stand schon". Als die Preise geändert wurden, lief er grün durch
und änderte nichts: Bei Apple standen die alten Beträge, in der App die neuen.
Aufgefallen wäre es einem Käufer, der einen anderen Preis sieht als
angeschrieben.

> Ein Nachlesen, das nur die **Existenz** prüft, macht jede spätere Änderung
> unsichtbar. Verglichen wird der **Wert** — und wenn er abweicht, wird er
> gesetzt und das im Protokoll benannt: „war X, soll Y sein, wird geändert."

Erkennungsmerkmal: Steht im Code `if vorhanden: return`, gehört daneben die
Frage, was passiert, wenn sich der Sollwert ändert.

### Eine vollständige Liste beweist nur, dass alle Punkte darauf abgehakt sind

Die dritte Stufe, und die stillste: Der Lauf meldete „15 steht, 0 offen". Was
fehlte, war der Hinweistext an die Prüfung — er stand im Dokument, wurde nie
übertragen und **stand auch auf keiner Liste**. Keine rote Zeile, kein Einwand,
niemand hat ihn vermisst. Eine Prüfliste sagt nichts über das, was nicht auf
ihr steht.

Zwei Dinge helfen, und beide kosten Minuten:

1. **Von der Gegenseite her zählen.** Nicht die eigene Liste durchgehen,
   sondern das fremde Formular: Welche Felder gibt es dort, und welche davon
   berührt der Lauf? Was er nicht anfasst, gehört auf die Liste oder ausdrücklich
   in ein „braucht einen Menschen".
2. **Jeder Text im Dokument braucht einen Abnehmer.** Steht ein Block da, den
   kein Aufruf liest, ist er Deko. Ein Test, der jede Überschrift mit einem
   Codeblock einmal abfragt, findet das in Sekunden.

Der Nachschlag: Der Leser fand die Überschrift gar nicht — er suchte nur nach
`###`, dieser eine Block stand unter `##` mit einer Nummer davor. Und er gab
dann keinen Fehler zurück, sondern **einen leeren Text**. Ein Sucher, der bei
Misserfolg etwas Harmloses liefert statt zu lärmen, verschiebt den Fehler
dorthin, wo ihn niemand mehr mit ihm in Verbindung bringt.

### Ein Punkt auf der Liste, der drei Dinge zusammenfasst, lügt über zwei davon

„Kontakt für die Prüfung — Name, Telefon, E-Mail" stand als **ein** offener
Punkt. Zwei der drei Angaben waren längst bekannt und standen im Impressum; nur
die Telefonnummer fehlte. Die Zeile war formal richtig und in der Wirkung
falsch: Wer sie las, hielt den ganzen Block für ungeklärt und fragte nach
allem, statt nach dem einen.

> Ein Punkt, der mehrere Felder bündelt, ist erst dann erledigt, wenn das
> letzte davon steht — und meldet bis dahin die anderen als offen mit. Ein Feld,
> ein Punkt.

Das gilt besonders für die Grenze zwischen „hole ich selbst" und „braucht einen
Menschen": Sie verläuft fast nie an einer Gruppe, sondern mitten hindurch.

**Und die Gegenprobe, eine Stunde später kassiert:** Die Aufteilung ist nur
richtig, wenn die Gegenseite die Felder auch einzeln annimmt. Apple nahm Name
und E-Mail ohne Telefonnummer **gar nicht** — „You must provide a value for the
attribute 'contactPhone'". Drei getrennte Zeilen hätten zwei davon als erledigt
gemeldet, während bei Apple nichts stand.

> Die Aufteilung folgt der **Annahme drüben**, nicht der Zählung hier. Wo ein
> Formular nur ganz annimmt, ist ein Punkt richtig — und er nennt, welches
> einzelne Feld ihn aufhält.

### Zwei Felder mit fast demselben Namen, und eines davon ist öffentlich

Apple fragt zweimal nach Kontaktangaben, und die Antworten gehen an
entgegengesetzte Orte:

| Feld | Wer sieht es |
|---|---|
| App Review Information (`appStoreReviewDetail`) | nur der Prüfer bei Apple |
| Händlerangaben nach dem Digitale-Dienste-Gesetz | **öffentlich** auf der Produktseite in der EU |

Beide wollen Name, Telefon und E-Mail. Wer sie für dasselbe hält, gibt eine
private Nummer in ein Feld, das sie veröffentlicht — und merkt es erst, wenn
sie im Laden steht.

> Bei jeder Angabe über eine Person **vor** dem Eintragen fragen, wo sie
> herauskommt. Bei einer Plattform ist „an wen geht das" eine andere Frage als
> „wo trage ich das ein", und die Antwort steht selten neben dem Feld.

Der zweite Punkt hat noch eine Eigenschaft, die ihn gefährlich macht: **Die
Schnittstelle kennt ihn nicht.** Der Prüflauf, der sonst alles nachsieht, wird
ihn nie melden — weder grün noch rot. Was kein Skript sehen kann, gehört
ausdrücklich in die Liste für Menschen, mit dem Satz dazu, warum es dort steht.

### Eine Prüfung, die anschlägt, hat meistens recht — auch gegen den Auftrag

Aus einer kostenlosen Funktion eine kostenpflichtige zu machen, ließ drei
Prüfungen fallen. Der erste Reflex ist, sie anzupassen, weil ja die Änderung
gewollt war. Bei einer davon war das richtig, bei zweien nicht:

| Was fiel | Was stimmte nicht |
|---|---|
| Preis muss über 0,99 € liegen | Die **Prüfung**. Der Preis war eine Entscheidung, die Grenze eine Vermutung |
| Bündel zählt mehr Zeilen auf als erlaubt | Die **Prüfung**, aber nur fürs Bündel — es nennt, was es ersetzt, und das ist keine Wahl |
| Titel enthält das Wort „Ablesung" | Der **Titel**. Die Prüfung wachte darüber, dass Ablesungen nie verkauft werden, und der Titel las sich genau so |

> Vor jeder Anpassung einer gefallenen Prüfung: **Was verteidigt sie?** Steht
> dahinter ein Prinzip, wird der Code geändert. Steht dahinter eine Zahl aus
> einer alten Lage, wird die Prüfung geändert — mit einem Kommentar, der die
> neue Lage nennt.

Was dabei außerdem auffiel: Eine Zusage und eine Sperre über derselben Sache
sind der Fehler, den niemand bemerkt, weil **beide Stellen für sich stimmen**.
Die Liste „dauerhaft kostenlos" und die Liste der Käufe standen einen Commit
lang beide richtig da und widersprachen einander. Dagegen hilft nur eine
Prüfung, die beide Listen gegeneinander hält.

### Zwei Formulare bei Apple, an die kein Schlüssel kommt

Die Schnittstelle deckt fast alles ab — Texte, Bilder, Preise, Käufe,
Altersfreigabe, Kontakt, Bau, Einreichung. **Zwei Dinge nicht**, und beide sind
harte Sperren vor der ersten Einreichung:

| Was | Wo | Über die Schnittstelle |
|---|---|---|
| Datenschutz-Fragebogen („Welche Daten erfasst die App?") | App Store → App-Datenschutz | acht Pfade probiert, acht „does not exist" |
| Händlerstatus nach dem Digitale-Dienste-Gesetz | Business → Agreements → Compliance | drei Pfade probiert, drei „does not exist" |

**Der Fragebogen ist nicht die Datenschutz-URL.** Die URL steht am App-Eintrag,
lässt sich setzen und war bei uns seit Tagen gesetzt — sie hat mit dem
Fragebogen nichts zu tun außer dem Namen. Wer „Datenschutz: steht" auf seiner
Liste hat, hat womöglich nur die Hälfte.

**Und die beiden sind nicht gleich teuer.** Diese Zeile stand hier als „sie
kosten fünf Minuten und blockieren sonst am Ende einen Tag". Das gilt für den
Fragebogen. Für den Händlerstatus ist es falsch, und zwar gemessen:

| | Ausfüllen | Bis es gilt |
|---|---|---|
| Datenschutz-Fragebogen | fünf Minuten | sofort |
| Händlerstatus (DSA) | fünf Minuten | **Apple prüft. Bei uns über drei Tage** |

Am 27. August eingetragen, am 30. August immer noch „In Prüfung" — während
Bau, Store-Texte, Bilder, Käufe und Länder seit zwei Tagen vollständig
dastanden. Der Starttermin des Gründers ist daran verstrichen, und es gab
nichts zu beheben: Die Verzögerung liegt vollständig bei Apple.

> **Der Händlerstatus wird als Erstes eingetragen, nicht als Letztes — und
> zwar Wochen vor dem geplanten Start.** Er ist der einzige Punkt der ganzen
> Auslieferung, den man nicht durch Arbeit beschleunigen kann. Alles andere
> lässt sich an dem Tag noch bauen, an dem es auffällt; dieser eine nicht.

Der Fragebogen bleibt der Fünf-Minuten-Fall — aber auch er **zuerst**, bevor
irgendetwas automatisiert wird.

Woran man in der Oberfläche erkennt, ob er es ist: Unter *Agreements →
Compliance* steht je Verordnung eine Zeile mit Status. Steht dort bei „Gesetz
über digitale Dienste" **In Prüfung** statt **Aktiviert**, ist das die Sperre —
und es ist die einzige Stelle, an der sie sichtbar wird.

Und die Meldung, an der es hängt, nennt keines von beidem:

    appStoreVersions with id '…' is not in valid state.
    This resource cannot be reviewed, please check associated errors to see why.

Die „associated errors" stehen **nur in der Oberfläche**, als rote Punkte neben
den Feldern. Über die Schnittstelle sind sie nicht abrufbar. Wer nur die
Schnittstelle hat, rät — und genau das hat hier drei Versuche gekostet.

### Nie nach einem Feld sortieren, das bei den Gesuchten leer ist

Ein Einreichungsskript fragte Apple nach vorhandenen Einreichungen — mit
`sort=-submittedDate`. Eine Einreichung, die noch **nicht abgeschickt** ist, hat
kein Absendedatum; genau die also, nach denen gesucht wurde. Apple lieferte sie
nicht aus, das Skript hielt die Bahn für frei, legte eine zweite an, und der
Fehlschlag kam mit einer Meldung über die **Fassung**:

    appStoreVersions with id '…' is not in valid state.

**Der Grund war ein anderer, und das gehört dazu:** Ich hielt die doppelte
Einreichung für die Ursache, räumte auf, und derselbe Fehler kam an einer
nachweislich leeren wieder. Die Sortierung war trotzdem ein echter Fehler — nur
eben nicht *der* Fehler. Eine gefundene Ursache, die den Befund erklärt, ist
noch nicht die Ursache; erst der Gegentest zeigt es.

> Ein `sort` ist ein stiller Filter. Vor jedem Sortierfeld die Frage: Ist es
> bei dem Datensatz gefüllt, den ich finden **will** — oder gerade bei dem
> nicht?

Dieselbe Runde brachte noch zwei Verwandte davon zutage:

- **Ein Zustandsname, der etwas anderes heißt, als er klingt.**
  `READY_FOR_REVIEW` bedeutet „angelegt und bereit zum Abschicken", nicht „bei
  der Prüfung". Er stand in der Liste der Zustände, bei denen das Skript nichts
  tut — und hätte damit jede zweite Einreichung verhindert.
- **Ein Fehlschlag, der eine Leiche hinterlässt.** Die angelegte Einreichung
  blieb leer stehen und sah für jeden späteren Lauf aus wie eine laufende. Wer
  in einem fremden System etwas anlegt und danach scheitert, räumt es weg —
  sonst wird die Sperre gegen ein Versehen selbst zur Sperre.

### Ein unbekannter Name ist nicht immer ein Fehler — manchmal nur ein Rückfall

`var(--bg)` stand im Stil eines Knopfes, und die Datei kannte nur `--ground`,
`--raised` und `--surface`. Der Browser meldet das **nicht**: Ein `var()` auf
einen unbekannten Namen fällt auf den geerbten Wert zurück. Im dunklen
Erscheinungsbild war das fast dasselbe Weiß wie der Hintergrund — auf dem
Telefon des Gründers stand ein leerer grauer Kasten, und keine der 393
Prüfungen sah etwas. Der Text war da, nur unsichtbar.

> Wo eine Sprache einen unbekannten Namen **still** auflöst statt abzubrechen,
> gehört eine Prüfung daneben, die die Namen gegeneinander hält. Zehn Zeilen:
> alle Definitionen sammeln, alle Verwendungen sammeln, die Differenz melden.

Dieselbe Form auch anderswo: Umgebungsvariablen, die leer statt undefiniert
sind; Wörterbuchzugriffe mit Vorgabewert; Vorlagen, die einen fehlenden
Platzhalter als leere Zeichenkette einsetzen.

### Der Einwand der Gegenseite nennt oft das Feld — dann wird gelesen, nicht geraten

Zwei Ablehnungen beim ersten Eintragen der Store-Daten:

```
Unexpected json type provided for attribute 'messagingAndChat'.
Expected a BOOLEAN but got STRING

Attribute 'whatsNew' cannot be edited at this time
```

Beides ließe sich mit abgetippten Listen erschlagen: welche Felder
Wahrheitswerte sind, und dass die **erste** Fassung keine Versionshinweise
annimmt. Solche Listen veralten still — die Gegenseite ändert Feldnamen, und
niemand merkt es, bis ein Lauf rot wird.

> Nennt der Fehler das Feld, **beantwortet der Aufruf ihn**: falscher Typ →
> umdrehen, nicht änderbar → weglassen und den Rest trotzdem eintragen. Das
> überlebt jede Umbenennung, die eine Liste nicht überlebt hätte.

Erkennungsmerkmal: Wo im Code eine Aufzählung von Feldnamen der Gegenseite
steht, gehört die Frage daneben, woher man wüsste, dass sie noch stimmt.

### Wer nur dort sucht, wo der Fehler auftritt, findet ihn nicht

Der Kauf war vollständig, fünfmal. Die Ursache saß eine Ebene höher, an der
App, nach der niemand gefragt hatte. Dieselbe Form wie beim Prüfbild und beim
Profil, das der Bau nicht bekam:

> Bei jedem Fehlschlag mitfragen, **worin** das Fehlgeschlagene steckt — und ob
> das seinerseits vollständig ist.

Dieselbe Regel greift beim Signieren: Erst wenn die App-ID **noch einmal
abgefragt** wurde und alles steht, darf der Bau die Berechtigungsdateien
anziehen. Ein Bau, der auf einer Vermutung signiert, scheitert zwanzig Minuten
später an einer Meldung, die den Grund nicht nennt.

### Eine richtige Meldung mit einer falschen Ursache dahinter

Der Einreichungslauf meldete fünfmal „Bild liegt nicht im Zweig". Die Meldung
war wahr — an der Stelle, an der er nachsah, lag nichts. Nur lag es woanders:
`tar -x --strip-components=1` schneidet die erste Pfadebene ab, und genau die
war der Ordner, um den es ging. Das Archiv führte `store/…`, gestrippt landete
alles direkt daneben, und `store/` blieb leer.

> Eine Meldung sagt, **wo** vergeblich gesucht wurde, nie **warum** dort nichts
> liegt. Bevor die Quelle verdächtigt wird, einmal auflisten, was am Zielort
> tatsächlich angekommen ist.

Zwei Minuten, die den Fehler sofort zeigen:

```bash
git archive origin/<zweig> <ordner> | tar -x -C /tmp/probe && find /tmp/probe
```

Und die Verallgemeinerung, die mehr trägt als der eine Schalter: **Jeder
Schritt, der Dateien von einem Ort zum anderen bringt, zählt danach und meldet
die Zahl.** Null ist dann eine Warnung an Ort und Stelle statt fünf Fehlzeilen
zwei Schritte später, die auf den falschen Verdächtigen zeigen.

### Zwei Zeitausschnitte, die einander nicht decken

Bisher entstand **jeder** gefundene Rechenfehler dadurch, dass ein Zeitraum,
den die Daten abdecken, gegen einen verglichen wurde, den sie nicht abdecken —
in fünf Verkleidungen: Hochrechnung, Vorjahresvergleich, Plausibilitätsprüfung,
Tabellensummen, Abschlagssaldo.

> Beide Seiten müssen denselben Zeitausschnitt beschreiben — und bei saisonalen
> Daten denselben Ausschnitt des Jahres.

Der Zwilling davon in der Oberfläche: **zwei verschiedene Register unter einer
Beschriftung.** Ein Oberflächentest fiel, weil der neueste Wert die Einspeisung
war und die Karte zu Recht unverändert blieb.

### Zwei Zustände für eine Sache geraten aus dem Takt

Ein Blatt in SwiftUI stand über einem Schalter „ist es offen?" und daneben lag
in einer zweiten Merkstelle, **was** darauf stehen soll. Der Tipp schrieb beide
im selben Atemzug. Das Blatt ging mit dem Inhalt von vorher auf — sichtbar der
falsche Kauf. Ein Lauf auf einem gemieteten Mac, fünfundzwanzig Minuten.

> Ein Zustand kann nicht mit sich selbst aus dem Takt geraten, zwei können es
> immer. Das Blatt hängt am Gegenstand (`sheet(item:)`), nicht an einem Schalter
> daneben.

Es stand sogar eine Begründung dabei, warum es zwei sein müssten: Der Typ liege
im Rechenkern, und ihm eine Kennung anzuhängen hieße, eine Anforderung der
Oberfläche in die Domäne zu tragen. Sie trug nicht — `Identifiable` steht in der
Standardbibliothek, nicht in SwiftUI. **Eine Begründung, die im Code steht, ist
deshalb noch nicht geprüft.**

### Dieselbe Sache an zwei Orten läuft auseinander — jedes Mal

Drei Fälle an einem Nachmittag, alle mit derselben Form:

| Was doppelt stand | Was passierte |
|---|---|
| Welche Dateien ausgeliefert werden | Ein Weg entfernte die privaten Anleitungen, der andere hätte sie **ins Netz gestellt** |
| Die Version des Prüfbrowsers | Drei Orte, zwei Versionen, und einer installierte nur den Browser ohne das Paket — Lauf rot mit einer Meldung, die nach einem Fehler in der Prüfung aussah |
| Ein Schalter „Blatt offen" plus die Merkstelle, **was** darauf steht | Das Blatt ging mit dem Inhalt von vorher auf |
| Der Preis eines Kaufs: im Quelltext und auf zwei Seiten der Website | Ein Kauf wurde von 1,99 € auf 0,99 € gesenkt. Die Preisseite zog mit, die Hilfeseite nicht — und bot ihn **zwei Wochen lang öffentlich als kostenlos an** |

> Wo etwas zweimal steht, steht es früher oder später verschieden. Der Ausweg
> ist immer derselbe: **ein Ort**, an dem es steht, und alle rufen ihn auf.

Erkennungsmerkmal beim Schreiben: Wenn zwei Stellen denselben Satz enthalten —
eine Versionsnummer, eine Dateiliste, einen Pfad —, ist das keine Wiederholung,
sondern eine Verabredung ohne Vertrag.

**Und wenn sich der zweite Ort nicht abschaffen lässt?** Ein Preis muss auf
einer Verkaufsseite stehen; man kann dort nicht auf den Quelltext verweisen.
Dann tritt eine Prüfung an die Stelle des einen Ortes: Sie liest die Quelle und
hält den Text dagegen. Das ist kein Ersatz, sondern die zweitbeste Bauart — und
sie ist billig. Zwanzig Zeilen, die die Beträge aus einer Datei ziehen und im
sichtbaren Text der Seiten suchen, hätten diesen Fall am Tag seiner Entstehung
gemeldet.

### Die Verkaufsseite ist eine Behauptung über den Code, und niemand prüft sie

Vor dem Launch wurde die Website Satz für Satz gegen den Quelltext gehalten.
Von rund dreißig Zusagen waren **drei falsch und vier zu absolut** — bei einem
Projekt, dessen Prüfsuite an dem Tag 228 Unit-Tests, 407 Website-Prüfungen und
neun Sicherheitsprüfungen grün meldete.

| Auf der Seite | Im Quelltext |
|---|---|
| „Ein Feld auf dem Sperrbildschirm" | `supportedFamilies([.systemSmall, .systemMedium])` — nur Homescreen |
| „Oktober bis April gegen Oktober bis April" | Es gibt Monat, Quartal, Jahr. Sonst nichts |
| „Zeitraum frei wählbar" | Sechs Vorgaben in einer Liste |
| „Die App fragt nirgendwo an" | StoreKit, CloudKit und die stille Mitteilung reden mit Apple |
| „Du entfernst die App, und die Daten sind weg" | Die Kopie in der privaten Cloud bleibt |

Keine dieser Zusagen war gelogen; jede war einmal geplant, teilweise gebaut
oder großzügig formuliert. Genau deshalb fällt so etwas nicht auf: Es gibt
keinen Ort, an dem eine Werbeaussage und ihre Umsetzung nebeneinanderstehen.
Der Code kennt die Website nicht, und die Website kennt den Code nicht.

> **Was die Prüfsuite prüft, ist die Innenseite.** Sie sagt, dass die App tut,
> was der Code sagt. Ob der Code tut, was die Verkaufsseite verspricht, sagt
> sie nicht — und das ist die Seite, an der ein Nutzer enttäuscht wird und ein
> App-Store-Prüfer ablehnt.

Der Handgriff, der es findet, ist billig und einmalig: **jede Zusage der
Verkaufsseite einzeln aufschreiben und den Beleg im Quelltext danebenlegen —
Datei und Zeile, nicht „ist implementiert".** Wo kein Beleg steht, ist die
Zusage entweder zu streichen oder zu bauen. Eine Stunde vor dem Launch, und
danach vor jeder Änderung am Umfang.

Zwei Regeln, die dabei den Unterschied machen:

- **Ein Modell zu finden genügt nicht.** Eine `ForecastEngine` im Repo beweist
  nicht, dass irgendeine Ansicht sie aufruft, und ein Aufruf beweist nicht,
  dass das Ergebnis auf einem Schirm landet. Der Beleg reicht von der Zusage
  bis zur sichtbaren Zeile.
- **Die kostenlose Fassung ist auch ein Versprechen.** In diesem Projekt gab
  ein ungeschützter Knopf „Beispieldaten anlegen" drei von fünf Käufen
  dauerhaft frei, weil die Sperre danach fragte, *ob Tarife vorhanden sind*,
  statt *ob gekauft wurde*. Wer eine Grenze prüft, prüft sie am Kauf und nie
  an einem Nebenprodukt davon.

### Eine Gegenprobe wird zurückgenommen, nicht zurückgesetzt

Eine neue Prüfung ist erst dann eine, wenn sie mit dem alten Verhalten **rot**
wird. Also wird das alte Verhalten kurz wiederhergestellt, der Lauf angesehen
und der Eingriff rückgängig gemacht. Der letzte Schritt ist die Falle.

Ich habe dafür `git checkout <datei>` benutzt. Die Datei enthielt neben den
zwei Zeilen der Gegenprobe **drei echte, noch nicht committete Korrekturen**,
und die waren damit weg. Gemerkt habe ich es nur, weil die Umgebung mir den
neuen Dateiinhalt vorlegte.

> **`git checkout <datei>` nimmt nicht die letzte Änderung zurück, sondern
> alle.** Für eine Gegenprobe gilt deshalb: entweder vorher committen und
> danach den einen Eingriff mit derselben Ersetzung rückwärts aufheben, oder
> die Gegenprobe an einer **Kopie** durchführen und die Quelle nie anfassen.

Der billigste Weg ist die gezielte Umkehrung: Wer mit `sed 's/A/B/'` verändert,
stellt mit `sed 's/B/A/'` wieder her. Das trifft genau eine Stelle, und wenn es
danebengeht, sagt es der Vergleich.

### Ein zweiter Versuch, der über den ersten hinweggeht, meldet das Falsche

Die Prüfhilfe tippte einen Knopf, wartete auf einen Anker und tippte bei
Ausbleiben ein zweites Mal — gedacht gegen verlorene Tipps. Der erste Tipp war
aber angekommen und hatte ein Blatt geöffnet, nur das falsche. Der zweite lief
gegen dieses Blatt, und gemeldet wurde `not hittable`: eine Aussage über die
Zeile, die mit der Ursache nichts mehr zu tun hatte. Die Suche ging danach eine
Stunde lang in die falsche Richtung.

> Wer beim zweiten Versuch nicht mehr an den Knopf herankommt, **hat ihn beim
> ersten getroffen.** Dann ist die Frage nicht, ob die Zeile antippbar ist,
> sondern was aufgegangen ist. Ein Wiederholungsversuch prüft vorher, ob die
> Voraussetzung des ersten überhaupt noch gilt.

Erkennbar war es an der Uhr, bevor es an der Meldung erkennbar war: Der Test
lief 24 Sekunden, und die Wartezeit auf den Anker beträgt 10. Wer nicht
hinkommt, wartet nicht.

---

## 7. Wie ermittelt wird, wenn etwas nicht geht

**Die Voraussetzung wird zuerst geprüft, nicht zuletzt.** Drei Tage lang stand
in jedem Lauf „In einem TestFlight-Bau lassen sie sich kostenlos ausprobieren."
Nachgeschlagen hatte ich das nie. Es stimmte — aber es war eine **Annahme**, und
sie war die Grundlage aller anderen Schritte. Hätte sie nicht gestimmt, wäre die
ganze Suche in die falsche Richtung gelaufen, und niemand hätte es gemerkt.

> **Was die Suche trägt, wird belegt, bevor gesucht wird.** Und solange es nicht
> belegt ist, steht es als Annahme da — nicht als Satz im Protokoll, den beim
> zehnten Lesen niemand mehr hinterfragt. Der Gründer hat es benannt: „rate
> niemals."

**Der Fehlschlag ist die Auskunft.** Der Reflex, aus einer Meldung eine
Erklärung zu bauen und danach zu handeln, hat mehr gekostet als das Lesen.

**Ein schneller Fehlschlag ist billig.** Die Läufe scheiterten nach 80 bis 130
Sekunden. Bei dieser Länge lohnt es, zu probieren statt zu grübeln — und genau
deshalb gehört die Zugangsprüfung nach vorn.

**Beim zweiten Danebengreifen wird instrumentiert, nicht weitergeraten.** Nach
zwei falschen Vermutungen zu `MISSING_METADATA` habe ich eine Diagnose
geschrieben, die **alles** ausgibt, was Apple über einen Kauf führt: jedes
Attribut und zu jeder Beziehung, ob sie existiert und mit welcher Antwort. Der
genaue Fehlercode stand danach in **einem** Lauf da. Dasselbe hat bei einem
roten Oberflächentest der halbe Zugänglichkeitsbaum geleistet.

**Zwei rote Läufe mit derselben Meldung sind kein Fortschritt.** Beim zweiten
Mal derselben Diagnose liegt die Ursache nicht im Code — dann melden statt
basteln. Bei uns fehlte der App-Eintrag, und den kann kein Skript anlegen.

**Eine plausible Erklärung ist keine gemessene.** Ein Test fiel zweimal mit
„Knopf fehlt". Die erste Erklärung war „zu kurz gewartet", alle Wartezeiten
wurden verdoppelt. Beim zweiten Mal sagten die Zeitstempel, die schon im
**ersten** Protokoll standen, etwas anderes: Der Start dauerte vierzehn
Sekunden, der Tipp fiel in dieses Fenster und ging verloren. Der Knopf war nie
langsam, er war auf einem anderen Schirm.

> **Eine Bedienhandlung, deren Wirkung nicht nachgeprüft wird, ist eine
> Annahme.** Wo ein Test etwas antippt, gehört die Gegenprobe daneben — an
> einem Merkmal, das der Tipp selbst nicht schon erfüllt.

**Eine Prüfung, die grundlos anschlägt, ist schlechter als keine.** Die Suche
nach einem deutschen Anführungszeichen mit geradem Schlusszeichen fand 24
Stellen, von denen keine einzige schadete — in einem Kommentar ist das Zeichen
harmlos. Die richtige Prüfung testet nicht das Zeichen, sondern die **Folge**:
Python übersetzen, YAML laden, jeden `run:`-Block durch `bash -n`. Wer den
Kommentar nicht ausblendet, baut eine Prüfung, die ignoriert wird.

**Was sich nicht setzen lässt, bringt den Lauf nicht zu Fall.** Es wandert in
eine Liste zum Anklicken, mit Adresse dazu, und der Bau fährt mit dem Rückfall
weiter. Voraussetzung: Der Code muss den Ausfall aushalten — bei uns in drei
Stufen, und die **mittlere** ist die wichtige. Ohne sie fiele der Simulator auf
einen flüchtigen Speicher zurück und jede Oberflächenprüfung wäre rot, ohne
dass irgendwo der Grund stünde.

**Ein Skript, das etwas erzeugt, wird ausgeführt, nicht gelesen.** Zweimal
hintereinander bewiesen, beide Male in Sekunden durch einen Durchlauf in einen
Wegwerfordner:

- Das Gerüst setzte das Ausführbit in der Kopierphase — da gab es die erzeugte
  Datei noch gar nicht. Das neue Projekt scheiterte beim allerersten Aufruf mit
  „Permission denied".
- **Erzeugter Code hat zwei Lagen Anführung, und die zweite sieht man nicht.**
  Ein Backtick im Kommentar eines Here-Dokuments, das in einer
  Kommandoersetzung steht, wird trotz Rückstrich noch einmal ausgewertet und
  reißt alles bis zum nächsten Backtick mit hinein. Der Fehler zeigt auf eine
  Zeile weit unterhalb der Ursache. Im erzeugten Text also keine Backticks —
  und was erzeugt wurde, danach selbst durch `bash -n` schicken.

**Ein Arbeitsverzeichnis auf einem veralteten Zweig sieht vollständig aus.**
Eine Sitzung hat zwei Versionen alten Code vollständig geprüft, grün gemeldet
und für den aktuellen Stand gehalten. Deshalb: **zuerst holen**, dann Zweig und
Version nennen, dann loslaufen.

---

## 8. Wann etwas fertig ist

**Fertig heißt: beim Nutzer.** Nicht gepusht, nicht zusammengeführt — bei uns:
ein Bau verarbeitet in TestFlight, belegt mit `Bau N: VALID` aus dem Protokoll,
nicht mit einer Vermutung.

Nach jedem Push und jedem angestoßenen Lauf:

1. **Nachschau planen**, bevor der Zug endet. Nie auf eine Erinnerung warten,
   nie mit `sleep` blockieren.
2. **Grün** → zusammenführen, Auslieferung anstoßen, Zeile im
   Auslieferungsprotokoll nachtragen, zusammengeführte Arbeitszweige löschen,
   Ergebnis melden.
3. **Rot** → Begründung aus dem Protokoll holen, einordnen (Prüf- oder
   Produktfehler), **beheben** und von vorn. Melden, was los war, statt auf
   eine Freigabe zu warten.
4. **Noch offen** → nächste Nachschau planen und **nichts** melden. Eine
   Zwischenmeldung ohne Ergebnis ist eine Störung.

**Nicht jede Version geht den ganzen Weg.** Was nur Dokumente, Prüfskripte oder
den Prototyp anfasst, endet im Hauptzweig. Alles, was am Bau etwas ändert, geht
bis aufs Gerät. Mehrere Versionen dürfen in **einem** Bau zusammenkommen; jeder
Bau kostet einen gemieteten Mac und eine Nummer, die verbraucht ist.

**Nebenläufigkeit je Auftrag, und dann darf man pushen.** Aus „`cancel-in-progress`
hat drei Läufe gekostet" war die Regel „nie pushen, solange ein Lauf läuft"
geworden. Behoben war das längst — mit zwei Gruppen: der schnelle Auftrag darf
abgebrochen werden, der teure steht auf `cancel-in-progress: false` und reiht
sich an. Die Regel blieb trotzdem stehen und kostete danach nur noch Wartezeit.

> Eine Regel, die aus einem Schaden entstand, gilt nicht weiter, weil der
> Schaden einmal echt war. Sie gilt, solange die **Ursache** steht. Wer sie
> aufschreibt, schreibt die Ursache dazu — sonst überlebt sie ihre Behebung.

---

## 9. Diese Datei fortführen

Am Ende einer Runde, in der etwas Neues teuer war, gehört der Befund hierher —
**im selben Commit wie die Änderung**, nicht in einem Folgeticket.

Was hier hineingehört:

- Ein Befund, der einen Lauf, einen Bau oder mehr als eine Stunde gekostet hat.
- Eine Vermutung, die falsch war, samt dem, was stattdessen zutraf.
- Eine gemessene Antwort von einer fremden Schnittstelle — auch ein 404.
- Eine Regel, die aus einem Fehler entstanden ist, der sich wiederholen kann.

Was nicht hineingehört: was in einer Anleitung steht und beim ersten Versuch
funktioniert hat.

**Beim Eintragen gelten dieselben Regeln wie für alle Dokumente hier:** die
Zahl gemessen oder gekennzeichnet, die falsche Vermutung mit aufgeschrieben,
und der Satz sagt, was zu tun ist — nicht nur, was war.

**Und wenn eine Zeile hier widerlegt wird, wird sie geändert, nicht ergänzt.**
Zwei Stände derselben Auskunft nebeneinander sind schlimmer als keine.
