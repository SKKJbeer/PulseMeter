# Arbeitsweise: Hintergrund und Begründungen

Das stand bis 0.134.1 in `CLAUDE.md`. Dort steht jetzt nur noch, was jede
Sitzung wissen muss; hier steht, **warum**. Die Datei wird nicht bei jedem
Start gelesen, sondern wenn jemand wissen will, woher eine Regel kommt.

Warum die Trennung: `CLAUDE.md` wird bei jedem Sitzungsstart und bei jeder
Verdichtung vollständig in den Kontext gelegt und von da an bei jeder Antwort
mitgelesen (`scripts/token-bericht.py`). Vorgeschichte gehört nicht dorthin.

---

## Kopfblock: Name, Domain und was den alten Namen behalten hat

> **Die App heißt „Zählora".** Umbenannt am 28. August, vorher „PulseMeter".
> Im App Store steht sie seit 1.4.1 (7. Oktober) als **„Zählora – Zählerstand
> ablesen"** (29 von 30 Zeichen), auf dem Homescreen als **„Zählora"**. Davor
> hieß sie dort „Zählora – Zähler & Verbrauch". Begründung in
> `docs/09-appstore.md`.
>
> **Die Website steht auf `zaehlora.de`.** Seit dem 3. Oktober, gekauft bei
> netcup, DNS bei Cloudflare. `zaehlora.pages.dev` (seit dem Umzug vom alten
> Namen am 29. August) und `www.zaehlora.de` leiten mit 301 dorthin weiter,
> `pulsemeter.pages.dev` ebenso. Das Cloudflare-Projekt heißt weiter
> `zaehlora`.
>
> **Was den alten Namen behalten hat, und mit Absicht:** die Bundle-ID
> `de.karjoth.pulsemeter`, die fünf Kauf-Kennungen, die Swift-Module
> `PulseCore`, `PulseData`, `PulseUI`, das Xcode-Ziel und das Repository. Das
> sieht kein Nutzer, und eine Kauf-Kennung zu ändern heißt, jedem Käufer seinen
> Kauf zu nehmen. Wer das trotzdem umziehen will, braucht einen neuen
> App-Eintrag bei Apple — und muss es tun, **bevor** jemand kauft. Vom Gründer
> am 29. August bestätigt: „ids müssen wir nicht anpassen, die sind ja schon
> und ist unnötig aufwand."
>
> **Die Adresse steht an drei Orten** — in `canonical` der Seiten, als
> `WEBSITE` in `asc-einreichung.py` und als `W=` der Prüfung in `website.yml`.
> `check-strings.py` hält sie zusammen; jede für sich wäre sonst stimmig und
> das Ganze falsch.

---

## Regel 1a: Warum GitHub Pages nicht umgestellt ist

> **Hier stand „GitHub Pages scheidet aus — das Repo ist privat". Das war
> falsch.** Am 31. August nachgemessen: `"private": false`, `"visibility":
> "public"`. Wann es öffentlich wurde, ist nicht rekonstruierbar; die Zeile
> stand seit Wochen ungeprüft da und ist einmal aus einer Annahme entstanden.
>
> **Damit ist der ganze Umweg oben verhandelbar.** Regel 1 verlangt bei jeder
> Veröffentlichung ein neues Artifact unter neuem Dateinamen, weil ein erneutes
> Veröffentlichen auf denselben Pfad beim Gründer eine Anmeldemaske auslöst.
> Über GitHub Pages ginge stattdessen eine **feste** Adresse
> (`skkjbeer.github.io/PulseMeter/prototype/`) — ohne Anmeldung, mit
> Versionshistorie über die Commits, und ohne dass bei jeder Runde ein Link
> weiterzugeben wäre.
>
> Umgestellt ist es nicht: Das ist eine Entscheidung des Gründers, keine
> Nebenwirkung einer Korrektur. Bis er sie trifft, gilt Regel 1 unverändert.

---

## Regel 1c: Baukasten in andere Vorhaben bringen

In ein anderes Vorhaben kommt sie über `scripts/neues-projekt.sh --einrichten`.
Das läuft **einmal** auf einem Rechner und setzt drei Dinge: den Verweis unter
`~/.claude/skills`, eine Regel in `~/.claude/CLAUDE.md` — die wird in jeder
Sitzung gelesen, auch im leeren Ordner — und die Funktion `neu` in der Shell.
Danach fängt ein Vorhaben mit `neu <name>` an, und das Gerüst steht.

Eine Cloud-Sitzung liest `~/.claude` **nicht**. Sie sieht nur das geklonte
Repository — dort liegt der Baukasten dann aber schon, weil das Aufsetzen ihn
hineinschreibt.

---

## Pushen während eines laufenden Prüflaufs

### Pushen während eines laufenden Prüflaufs ist erlaubt

**Diese Regel stand hier umgekehrt und war überholt.** Sie lautete „nie pushen,
solange ein Prüflauf läuft", weil `cancel-in-progress` an einem einzigen Tag
drei Läufe gekostet hatte — jeden abgebrochen kurz vor dem App-Build, also nach
der teuersten Minute und ohne je ein Ergebnis. Behoben wurde das damals mit
**zwei Gruppen** in `ci.yml`, und die Regel blieb trotzdem stehen. Sie hat
danach nur noch Wartezeit gekostet.

| Auftrag | Gruppe | Bei neuem Push |
|---|---|---|
| `prototype` (Ubuntu, Minuten) | `entwurf-<zweig>` | wird abgebrochen — soll er, er läuft gleich wieder |
| `iphone` (macOS, teuer) | `iphone-<zweig>` | `cancel-in-progress: false` — **reiht sich an**, beide laufen durch |
| `ipad` (macOS, teuer) | `ipad-<zweig>` | dasselbe, eigene Gruppe — sonst bricht der eine den anderen ab |
| `bilder` (macOS, kurz) | — | wartet auf beide, legt beide Bildersätze in den Zweig `screenshots` |

Der teure Auftrag ist also geschützt. Wer wartet, wartet umsonst.

```bash
git fetch origin screenshots && git show origin/screenshots:README.md | head -3
```

**Nicht als Ersatz lesen, sondern als Vorsprung.** Ein Lauf „mit Änderungen"
sagt über den committeten Stand nichts, und `schnell` sagt nichts über die App
im Simulator. Beides steht in der Zeile.

Swift-Toolchain unter Linux: `/opt/swift/usr/bin` (Swift 6.0.3).
Chromium für Playwright: `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`.

