# 08 – Der Baukasten: dieses Vorgehen auf ein anderes Projekt übertragen

Stand: 2026-08-09

Das Aufbauschema dieses Projekts ist nicht an Zählerstände gebunden. Es
funktioniert für jedes Vorhaben, an dem **zwei Orte** arbeiten — ein Rechner
mit allem drauf und eine Sitzung in der Cloud, die einander nicht sehen.

Dieses Dokument sagt, woraus es besteht, was daran allgemein ist und was
ausgetauscht werden muss.

> **Das Gegenstück ist [`12-auslieferung.md`](12-auslieferung.md).** Hier steht,
> wie geprüft wird; dort, wie ausgeliefert wird — ohne Mac, über einen
> macOS-Läufer. Beide sind unabhängig voneinander übertragbar.

> **Die Kurzfassung von beidem in einer Datei:**
> [`.claude/skills/projekt-baukasten/SKILL.md`](../.claude/skills/projekt-baukasten/SKILL.md).
> Sie ist in sich geschlossen, gilt auch ohne dieses Repo und wird bei jeder
> teuren Erkenntnis fortgeschrieben. Wer etwas in ein neues Projekt mitnehmen
> will, nimmt sie.

---

## Die vier Ideen dahinter

**1. Ein Befehl prüft alles.** Nicht vier Befehle in einer Reihenfolge, die
irgendwo beschrieben steht. Ein Skript, das an beiden Orten läuft, überall
dasselbe prüft und **benennt**, was es überspringt. Zwei Abläufe würden
auseinanderlaufen, und dann prüft der eine etwas anderes als der andere.

**2. Der lokale Lauf ist der erste Durchgang, die CI die Gegenprobe.** Lokal
bleibt das Ableseverzeichnis liegen, in der CI wird von null gebaut — daher
zwei Minuten gegen fünfzehn. Wer auf die CI wartet, wartet auf ein Ergebnis,
das er längst haben könnte.

**3. Zwei Zweige verbinden, was einander nicht sieht.** Eine Cloud-Sitzung
erreicht den Rechner des Nutzers nicht und umgekehrt. Verbunden sind sie über
git: eine Zeile je Lauf, und die Bilder des letzten Laufs.

**4. Angefangenes wird zu Ende gebracht.** Wer einen Lauf anstößt, plant die
Nachschau selbst. Eine Aufgabe ist erledigt, wenn sie zusammengeführt ist —
nicht, wenn sie gepusht ist.

---

## Die Teile

| Datei | Was sie tut | Übertragbar? |
|---|---|---|
| `scripts/pruefen.sh` | Ein Befehl für alles, mit Umfängen (`schnell`, `app`, `bilder`) und Schaltern (`--nur`, `--melden`) | **Gerüst allgemein**, die Schritte darin sind projektspezifisch |
| `scripts/mac-start.sh` | Stand holen → einrichten → prüfen → Bilder zeigen | fast unverändert |
| `Am-Mac-starten.command` | dasselbe zum Doppelklicken im Finder | unverändert |
| `scripts/melden.sh` | schreibt eine Zeile je Lauf in den Zweig `pruefungen` | **unverändert** |
| `scripts/publish-shots.sh` | schiebt Bilder in den Zweig `screenshots`, aus CI **und** vom Rechner | fast unverändert |
| `.githooks/pre-push` | die schnellen Prüfungen vor jedem Push | unverändert |
| `.github/workflows/ci.yml` | schneller Auftrag auf Linux, langsamer auf macOS | Aufbau allgemein, Schritte projektspezifisch |
| `CLAUDE.md` | Arbeitsweise, Prüfschritte, Sprachregeln, die vier Regeln | Regeln 3 und 4 allgemein, 1 und 2 projektspezifisch |
| `.claude/skills/release-discipline` | Version, Release Notes und Tests als Pflicht je Änderung | **unverändert** |
| `.claude/settings.json` | die Befehle des Projekts ohne Rückfrage, `sudo` gesperrt | Liste anpassen |
| `docs/06-uebergabe.md` | der laufende Zustand für eine Sitzung, die kalt startet | Vorlage |

---

## Die Fehler, die dieses Schema gekostet hat

Sie stehen hier, weil sie sich in jedem Projekt wiederholen. Jeder einzelne hat
hier einen halben Tag gekostet.

**Ein Arbeitsverzeichnis auf einem veralteten Zweig sieht vollständig aus.**
Eine Sitzung hat zwei Versionen alten Code vollständig geprüft, grün gemeldet
und für den aktuellen Stand gehalten. Deshalb holt `mac-start.sh` **zuerst**
und nennt Zweig und Version, bevor es losläuft.

**Ein roter Lauf, der keine Bilder macht, ist blind.** Die Screenshots hingen
an `if: success()`. Eine einzige rote Prüfung unterdrückte damit alle Bilder —
also genau dann, wenn man sie am dringendsten braucht.

**Ein Fehlschlag, der nur „fehlt" sagt, erzwingt Raten.** Zwei plausible
Diagnosen, zwei Läufe zu je dreizehn Minuten, beide falsch. Erst als die
Prüfung bei einem Fehlschlag den halben Zugänglichkeitsbaum ausgab, war die
Ursache in einem Lauf abzulesen. **Instrumentieren schlägt vermuten**, sobald
man zum zweiten Mal danebengelegen hat.

**Ein Filter, der nur die erste Zeile einer Begründung zeigt**, macht genau
diese Ausgabe wieder unbrauchbar.

**`cancel-in-progress` über dem ganzen Ablauf** bricht den langen Auftrag ab,
sobald der nächste Push kommt. Drei Läufe an einem Tag endeten so, jeder kurz
vor dem Ende. Die Nebenläufigkeit gehört **je Auftrag**: Der schnelle darf
abgebrochen werden, der lange nicht.

**Ein Prüfschritt, der die Testquellen auslässt**, findet Tippfehler dort erst
nach dem vollständigen Build — nach der teuersten Minute des Laufs.

**Eine plausible Erklärung ist keine gemessene.** Eine Oberflächenprüfung fiel
zweimal mit „Knopf fehlt". Beim ersten Mal war die Erklärung „zu kurz
gewartet", und alle Wartezeiten wurden verdoppelt. Beim zweiten Mal fiel sie
wieder — und die Zeitstempel, die schon im **ersten** Protokoll gestanden
hatten, sagten etwas anderes: Der Start dauerte vierzehn Sekunden, und der
Tipp auf den Tab fiel in dieses Fenster und ging verloren. Der Knopf war nie
langsam, er war auf einem anderen Schirm — und dagegen hilft keine Wartezeit
der Welt.

Die Lehre ist nicht „länger warten" und auch nicht „öfter tippen", sondern:
**Eine Bedienhandlung, deren Wirkung nicht nachgeprüft wird, ist eine
Annahme.** Wo ein Test etwas antippt, gehört die Gegenprobe daneben, dass es
gewirkt hat — und zwar an einem Merkmal, das der Tipp selbst nicht schon
erfüllt.

---

## In zehn Schritten übertragen

Die Schritte 1, 5, 6, 8, 9 und 10 macht seit 0.84.0 ein Aufruf, und seit
0.85.0 richtet `--einrichten` den Rechner einmal so ein, dass `neu <name>`
genügt:

```bash
scripts/neues-projekt.sh --einrichten    # einmal je Rechner
neu wasserwacht                          # ab dann fängt jedes Vorhaben so an
```

Von Hand bleiben 2, 3, 4 und 7 — die vier, die wissen müssen, was das Projekt
eigentlich tut. Die Liste steht trotzdem vollständig hier, weil sie erklärt,
**warum** das Skript tut, was es tut.

1. `scripts/`, `.githooks/`, `.claude/` und `.github/workflows/ci.yml` kopieren.
2. In `pruefen.sh` die Schritte austauschen: Was ist die schnelle Prüfung, was
   die teure? **Nach Kosten sortieren, nicht nach Wichtigkeit** — was in einer
   Sekunde brechen kann, soll auch in einer Sekunde brechen.
3. Die Bedingung finden, die „hier fehlt das schwere Werkzeug" bedeutet (hier:
   `xcodebuild`). Übersprungenes wird **benannt**, nie verschwiegen.
4. `mac-start.sh` auf den Zielzweig einstellen und den Namen anpassen.
5. `melden.sh` und `publish-shots.sh` unverändert übernehmen. Beide brauchen
   nur `origin`.
6. Im Arbeitsablauf beide Aufträge trennen: einer schnell und abbrechbar, einer
   langsam und nicht abbrechbar.
7. Bilder — oder was in deinem Projekt das Gegenstück ist — **auch bei rotem
   Lauf** erzeugen.
8. `CLAUDE.md` schreiben: wo was liegt, wie geprüft wird, welche Wörter
   verboten sind, und die Regel, dass Angefangenes zu Ende gebracht wird.
9. `release-discipline` übernehmen. Version, Release Notes und Tests je
   Änderung, ohne dass jemand danach fragt.
10. `06-uebergabe.md` anlegen und bei jeder Übergabe **überschreiben**. Es ist
    eine Momentaufnahme, keine Historie.

---

## Was dieses Schema nicht leistet

Es ersetzt nicht, dass jemand das Produkt **benutzt**. Sieben der hier
gefundenen Darstellungsfehler hat kein Test gefunden, sondern der Blick auf ein
Bild — und der Fehler, der den Kernfluss zur Sackgasse machte, fiel auf, weil
jemand die App in die Hand genommen hat.

Der Baukasten sorgt dafür, dass man **sieht**, was man gebaut hat. Hinsehen
muss man selbst.
