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

> Wo etwas zweimal steht, steht es früher oder später verschieden. Der Ausweg
> ist immer derselbe: **ein Ort**, an dem es steht, und alle rufen ihn auf.

Erkennungsmerkmal beim Schreiben: Wenn zwei Stellen denselben Satz enthalten —
eine Versionsnummer, eine Dateiliste, einen Pfad —, ist das keine Wiederholung,
sondern eine Verabredung ohne Vertrag.

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
