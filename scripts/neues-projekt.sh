#!/usr/bin/env bash
# Setzt ein neues Projekt mit diesem Vorgehen auf — oder macht den Baukasten
# auf diesem Rechner für **jedes** Projekt verfügbar.
#
# **Warum es das gibt.** Das Gelernte in einer Datei zu haben nützt nichts,
# solange man sie von Hand kopieren muss. Wer ein neues Vorhaben anfängt, denkt
# nicht an eine Skill-Datei in einem anderen Repository — er fängt an, und drei
# Tage später zahlt er dieselben Fehler noch einmal.
#
# **Zwei Orte, zwei Wege — und das ist kein Versehen.** Gemessen an der
# Dokumentation von Claude Code:
#
#   ~/.claude/skills/<name>/SKILL.md    gilt in allen Projekten auf diesem Rechner
#   <projekt>/.claude/skills/<name>/    gilt in diesem Projekt — auch in der Cloud
#
# Eine Cloud-Sitzung liest `~/.claude/skills` **nicht**. Sie sieht nur, was im
# geklonten Repository liegt. Deshalb genügt der Verweis im Heimverzeichnis für
# den Mac, und ein neues Repository braucht trotzdem seine eigene Kopie.
#
# Aufruf:
#   scripts/neues-projekt.sh --einrichten         einmal auf diesem Rechner:
#                                                 Verweis, Regel für jede Sitzung
#                                                 und der Befehl `neu` in der Shell
#   scripts/neues-projekt.sh --ueberall           nur der Verweis, ohne Shell
#   scripts/neues-projekt.sh <ordner> [name]      neues Projekt aufsetzen
#
# Nach `--einrichten` fängt ein Vorhaben so an, und das ist alles:
#   neu wasserwacht
#
# Schalter:
#   --trocken     nur zeigen, was geschähe
#   --ohne-git    im Zielordner kein `git init` ausführen
set -uo pipefail

# **Der Ordner entsteht dort, wo der Aufrufer steht — nicht im Quell-Repo.**
#
# Hier stand nur `cd "$(dirname "$0")/.."`, und damit lösten sich relative
# Zielangaben gegen das Quellprojekt auf. Wer im Heimatverzeichnis
# `neues-projekt.sh zweitapp` tippte, bekam die zweite App **innerhalb** der
# ersten — mit eigenem `git init`, also einem Depot im Depot. Aufgefallen beim
# Ausprobieren der Übertragung, nicht in einem Lauf: Das Skript meldete für
# jede Datei einen grünen Haken, und der Ordner lag nur woanders.
#
# Also wird das Verzeichnis des Aufrufers festgehalten, **bevor** irgendetwas
# wechselt, und ein relatives Ziel dagegen aufgelöst.
VONWO="$PWD"
cd "$(dirname "$0")/.."
QUELLE="$PWD"

BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
weg()  { printf "  %s·%s %s\n" "$DIM" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
titel(){ printf "\n%s▸ %s%s\n" "$BOLD" "$1" "$RESET"; }

ZIEL=""
NAME=""
UEBERALL=0
EINRICHTEN=0
TROCKEN=0
GIT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --einrichten) EINRICHTEN=1 ;;
    --ueberall) UEBERALL=1 ;;
    --trocken)  TROCKEN=1 ;;
    --ohne-git) GIT=0 ;;
    -h|--hilfe|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unbekannter Schalter: $1" >&2; exit 2 ;;
    *)  if [ -z "$ZIEL" ]; then ZIEL="$1"; else NAME="$1"; fi ;;
  esac
  shift
done

tu() {  # führt aus — oder sagt bei --trocken nur, was geschähe
  if [ "$TROCKEN" = 1 ]; then printf "  %s→ %s%s\n" "$DIM" "$*" "$RESET"; return 0; fi
  "$@"
}

# ------------------------------------------------- Auf diesem Rechner überall

# Schreibt einen Block zwischen zwei Marken in eine Datei — legt sie an, wenn
# es sie nicht gibt, und **ersetzt** den Block, wenn er schon dasteht. Anhängen
# statt ersetzen wäre der Weg, auf dem eine Datei nach vier Einrichtungen vier
# Fassungen derselben Regel trägt.
block() {
  local datei="$1" marke="$2" inhalt="$3"
  local anfang="$marke:anfang" ende="$marke:ende"
  if [ "$TROCKEN" = 1 ]; then
    printf "  %s→ Block %s in %s%s\n" "$DIM" "$marke" "$datei" "$RESET"; return 0
  fi
  mkdir -p "$(dirname "$datei")"
  [ -f "$datei" ] || : > "$datei"
  if grep -q "$anfang" "$datei" 2>/dev/null; then
    # Alten Block herausschneiden, ohne den Rest der Datei anzufassen.
    awk -v a="$anfang" -v e="$ende" '
      index($0,a) {drin=1} !drin {print} index($0,e) {drin=0}
    ' "$datei" > "$datei.neu" && mv "$datei.neu" "$datei"
  fi
  printf '%s\n' "$inhalt" >> "$datei"
  ok "$datei"
}

verweis() {
  local heim="$HOME/.claude/skills" link="$HOME/.claude/skills/projekt-baukasten"
  # Ein **Verweis**, keine Kopie. Eine Kopie wäre am Tag der Erstellung richtig
  # und danach still veraltet — genau die Doppelung, gegen die der Baukasten
  # selbst argumentiert. Claude Code folgt einem Symlink an dieser Stelle.
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    warn "$link gibt es schon und es ist kein Verweis — nichts angefasst."
    return 1
  fi
  tu mkdir -p "$heim"
  tu ln -sfn "$QUELLE/.claude/skills/projekt-baukasten" "$link"
  ok "$link → $QUELLE/.claude/skills/projekt-baukasten"
}

if [ "$UEBERALL" = 1 ] && [ "$EINRICHTEN" = 0 ]; then
  titel "Baukasten für jedes Projekt auf diesem Rechner"
  verweis || exit 1
  weg "Gilt in jedem Projekt auf diesem Rechner, sofort, ohne Neustart."
  weg "Gilt **nicht** in einer Cloud-Sitzung — die liest nur das geklonte Repo."
  weg "Für ein neues Repository: scripts/neues-projekt.sh <ordner>"
  exit 0
fi

# ------------------------------------------------- Einmal, danach nie wieder

if [ "$EINRICHTEN" = 1 ]; then
  titel "Einrichtung — läuft einmal, danach ist nichts mehr zu tun"

  verweis || exit 1

  # **Warum zusätzlich `~/.claude/CLAUDE.md`.** Eine Skill wird geladen, wenn
  # sie passt. Diese Datei wird in **jeder** Sitzung gelesen, auch in der
  # allerersten Minute eines leeren Ordners — also genau dann, wenn noch nichts
  # dasteht, was eine Skill auslösen könnte.
  block "$HOME/.claude/CLAUDE.md" "<!-- baukasten" "$(cat <<HEIM
<!-- baukasten:anfang -->
## Vorgehen in jedem Projekt

Das gesammelte Vorgehen steht in der Skill \`projekt-baukasten\`: Aufbau,
Dokumentation, Konzeptarbeit, Prüfen, Ausliefern über einen macOS-Läufer, die
Schnittstelle von Apple, die wiederkehrenden Fehlerklassen.

**Beim Start in einem Projekt ohne \`scripts/pruefen.sh\` oder ohne
\`CLAUDE.md\`:** das Gerüst aufsetzen, bevor die erste Zeile Code entsteht —
\`$QUELLE/scripts/neues-projekt.sh <ordner> <name>\`. Danach die drei Dinge
nachtragen, die das Skript nicht wissen kann: die Schritte in \`pruefen.sh\`,
die Produktprinzipien in \`CLAUDE.md\`, und bei einem iOS-Projekt die Kennung
**vor** dem ersten Bau.

**Und was einen Lauf, einen Bau oder mehr als eine Stunde gekostet hat**, wird
im Baukasten nachgetragen — im selben Commit wie die Änderung, ohne dass jemand
danach fragt. Auch die Vermutung, die falsch war.
<!-- baukasten:ende -->
HEIM
)"

  # **Warum zusätzlich eine Funktion in der Shell.** Damit „neues Projekt"
  # nicht heißt: an ein Skript in einem anderen Repository denken. Der Befehl,
  # mit dem ein Vorhaben anfängt, **ist** das Aufsetzen.
  for profil in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$profil" ] || [ "$profil" = "$HOME/.zshrc" ] || continue
    block "$profil" "# baukasten" "$(cat <<PROFIL
# baukasten:anfang
# Neues Vorhaben aufsetzen:  neu <name> [ordner]
neu() {
  [ -n "\${1:-}" ] || { echo "neu <name> [ordner]" >&2; return 2; }
  local ziel="\${2:-\$HOME/Code/\$1}"
  "$QUELLE/scripts/neues-projekt.sh" "\$ziel" "\$1" || return 1
  cd "\$ziel" || return 1
  # Ohne das oder-true gäbe die Funktion einen Fehlschlag zurück, nur weil auf
  # diesem Rechner kein claude liegt — das Projekt steht dann trotzdem.
  { command -v claude >/dev/null && claude; } || true
}
# baukasten:ende
PROFIL
)"
  done

  cat <<ENDE

  Fertig. Ab jetzt gilt der Baukasten in jedem Projekt auf diesem Rechner.

  Ein neues Vorhaben fängt so an — ein Wort, sonst nichts:

      neu wasserwacht

  Das legt ~/Code/wasserwacht an, setzt das Gerüst auf, springt hinein und
  startet Claude. Ein anderer Ort: neu wasserwacht ~/woanders/hin

  Einmal noch nötig: ein neues Terminalfenster, damit die Shell die Funktion
  kennt. Oder jetzt sofort:  source ~/.zshrc

  Was das **nicht** kann: Eine Cloud-Sitzung liest ~/.claude nicht. Sie sieht
  nur das geklonte Repository — dort liegt der Baukasten dann aber schon, weil
  das Aufsetzen ihn hineinschreibt. Einmal committen und pushen genügt.
ENDE
  exit 0
fi

if [ -z "$ZIEL" ]; then
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

[ -n "$NAME" ] || NAME="$(basename "$ZIEL")"
KLEIN="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"

# Ein relatives Ziel gehört dorthin, wo der Aufrufer steht. Ein absolutes
# bleibt, wie es ist.
case "$ZIEL" in
  /*) ;;
  *)  ZIEL="$VONWO/$ZIEL" ;;
esac

# Und niemals in das Quellprojekt hinein: Ein Depot im Depot ist die Art
# Fehler, die man erst drei Commits später bemerkt.
case "$ZIEL/" in
  "$QUELLE"/*)
    printf "%s✗ %s liegt innerhalb von %s.%s\n" "$YELLOW" "$ZIEL" "$QUELLE" "$RESET"
    printf "  Ein neues Vorhaben gehört daneben, nicht hinein — sonst entsteht\n"
    printf "  ein Depot im Depot. Bitte einen Ordner ausserhalb wählen.\n"
    exit 2 ;;
esac

# ------------------------------------------------------------ Neues Projekt

titel "Neues Projekt: $NAME in $ZIEL"
tu mkdir -p "$ZIEL"/{scripts,docs,.githooks,.github/workflows,.claude/skills}

# Legt eine Datei nur an, wenn es sie nicht schon gibt. Ein Skript, das eine
# vorhandene Datei überschreibt, ist einmal bequem und danach gefährlich.
schreibe() {
  local pfad="$ZIEL/$1"
  if [ -e "$pfad" ]; then weg "$1 gibt es schon — übersprungen"; return 0; fi
  if [ "$TROCKEN" = 1 ]; then printf "  %s→ anlegen: %s%s\n" "$DIM" "$1" "$RESET"; cat > /dev/null; return 0; fi
  mkdir -p "$(dirname "$pfad")"
  cat > "$pfad"
  ok "$1"
}

kopiere() {
  local von="$1" nach="${2:-$1}"
  local pfad="$ZIEL/$nach"
  if [ -e "$pfad" ]; then weg "$nach gibt es schon — übersprungen"; return 0; fi
  if [ "$TROCKEN" = 1 ]; then printf "  %s→ kopieren: %s%s\n" "$DIM" "$nach" "$RESET"; return 0; fi
  mkdir -p "$(dirname "$pfad")"
  cp -R "$QUELLE/$von" "$pfad"
  ok "$nach"
}

titel "Das Gelernte"
kopiere ".claude/skills/projekt-baukasten"  ".claude/skills/projekt-baukasten"
kopiere ".claude/skills/release-discipline" ".claude/skills/release-discipline"
kopiere ".claude/skills/selbstsprechend"    ".claude/skills/selbstsprechend"

titel "Die Teile, die unverändert übertragbar sind"
kopiere "scripts/melden.sh"        "scripts/melden.sh"
kopiere "scripts/publish-shots.sh" "scripts/publish-shots.sh"
kopiere ".githooks/pre-push"       ".githooks/pre-push"

# **Die Prüfungen ohne Projektbezug — der eigentliche Wert dieser Übertragung.**
#
# Bis heute kopierte dieses Skript das Gerüst und keine einzige Prüfung; in das
# erzeugte `pruefen.sh` schrieb es `check-strings.py` als **auskommentiertes
# Beispiel**. Ein neues Vorhaben fing damit bei null an und bezahlte dieselben
# Lehrgelder ein zweites Mal.
#
# Diese vier hängen an nichts, was diesem Projekt gehört. Was jede von ihnen
# einmal gekostet hat, steht in der Tabelle im Baukasten und im Kopf jeder
# Datei — vor dem Gebrauch einmal lesen.
titel "Die Prüfungen, die sofort tragen"
kopiere "scripts/check-strings.py"        "scripts/check-strings.py"
kopiere "scripts/check-namen.py"          "scripts/check-namen.py"
kopiere "scripts/check-sicherheit.sh"     "scripts/check-sicherheit.sh"
kopiere "scripts/check-trefferflaechen.py" "scripts/check-trefferflaechen.py"

# **`check-versprechen.py` kommt als Vorlage mit, nicht als fertige Prüfung.**
# Sie liest eine bestimmte Swift-Datei und bestimmte HTML-Seiten; in einem
# anderen Vorhaben heißen beide anders. Der Wert liegt im Muster: Ein Preis
# steht immer an zwei Orten, und wenn sich der zweite nicht abschaffen lässt,
# tritt eine Prüfung an die Stelle der einen Quelle.
kopiere "scripts/check-versprechen.py" "scripts/vorlagen/check-versprechen.py"

# Die beiden Skripte tragen an je einer Stelle den Namen dieses Projekts — als
# Autor der Commits in den Nebenzweigen. Der wandert mit.
if [ "$TROCKEN" = 0 ]; then
  for datei in "$ZIEL/scripts/melden.sh" "$ZIEL/scripts/publish-shots.sh"; do
    [ -f "$datei" ] || continue
    sed -i.bak "s/PulseMeter/$NAME/g; s/pulsemeter\.app/$KLEIN.example/g; s/PULSE_/PRUEF_/g" "$datei"
    rm -f "$datei.bak"
  done
fi

titel "Das Gerüst, das gefüllt werden will"

schreibe "scripts/pruefen.sh" <<PRUEFEN
#!/usr/bin/env bash
# Ein Befehl prüft alles.
#
# **Die Reihenfolge ist nach Kosten sortiert, nicht nach Wichtigkeit.** Was in
# einer Sekunde brechen kann, soll auch in einer Sekunde brechen.
#
# **Was hier fehlt, wird benannt.** Ein Lauf, der stillschweigend die Hälfte
# überspringt, meldet Grün und sagt nichts — das ist schlimmer als Rot.
#
# Aufruf:
#   scripts/pruefen.sh              alles, wie die CI
#   scripts/pruefen.sh schnell      nur, was in Sekunden geht
#
# Schalter:
#   --nur <Name>    nur eine Prüfung (Teilname genügt)
#   --melden        Ergebnis in den Zweig \`pruefungen\` schreiben
set -uo pipefail
cd "\$(dirname "\$0")/.."

SCOPE="alles"; ONLY=""; REPORT=0
while [ \$# -gt 0 ]; do
  case "\$1" in
    alles|schnell) SCOPE="\$1" ;;
    --nur) shift; ONLY="\${1:-}" ;;
    --melden) REPORT=1 ;;
    -h|--hilfe|--help) sed -n '2,18p' "\$0" | sed 's/^# \\{0,1\\}//'; exit 0 ;;
    *) echo "Unbekannter Schalter: \$1" >&2; exit 2 ;;
  esac
  shift
done

BOLD=\$'\\033[1m'; DIM=\$'\\033[2m'; RED=\$'\\033[31m'; GREEN=\$'\\033[32m'; RESET=\$'\\033[0m'
START=\$(date +%s); FAILED=()

step() { printf "\\n%s▸ %s%s\\n" "\$BOLD" "\$1" "\$RESET"; }
ok()   { printf "  %s✓%s %s %s(%ss)%s\\n" "\$GREEN" "\$RESET" "\$1" "\$DIM" "\$2" "\$RESET"; }
bad()  { printf "  %s✗%s %s %s(%ss)%s\\n" "\$RED" "\$RESET" "\$1" "\$DIM" "\$2" "\$RESET"; FAILED+=("\$1"); }
note() { printf "  %s%s%s\\n" "\$DIM" "\$1" "\$RESET"; }

# Führt einen Schritt aus, misst ihn und merkt sich einen Fehlschlag, ohne
# abzubrechen: Wer drei Dinge kaputt gemacht hat, will alle drei sehen.
run() {
  local name="\$1"; shift
  [ -z "\$ONLY" ] || case "\$name" in *"\$ONLY"*) ;; *) return 0 ;; esac
  local began; began=\$(date +%s)
  if "\$@" > /tmp/pruefen-schritt.log 2>&1; then
    ok "\$name" "\$(( \$(date +%s) - began ))"; return 0
  fi
  bad "\$name" "\$(( \$(date +%s) - began ))"
  tail -25 /tmp/pruefen-schritt.log | sed 's/^/    /'
  return 1
}

step "Sofortprüfungen"
# Diese vier kamen mit und laufen sofort. Zusammen unter fünf Sekunden.
# Was jede einmal gekostet hat, steht in ihrem eigenen Kopf.
run "Zeichenketten" python3 scripts/check-strings.py || true
run "Unbekannte Namen" python3 scripts/check-namen.py || true
run "Angriffsfläche" scripts/check-sicherheit.sh || true
run "Trefferflächen" python3 scripts/check-trefferflaechen.py || true
# HIER EINTRAGEN: was sonst noch in Sekunden bricht — Syntax, Einheitstests.

if [ "\$SCOPE" = "alles" ]; then
  step "Das Teure"
  # HIER EINTRAGEN: Build, Oberflächentests, Bilder.
  # Fehlt das schwere Werkzeug, wird das **benannt**, nicht verschwiegen:
  # if ! command -v xcodebuild >/dev/null; then
  #   note "App-Build übersprungen — hier gibt es kein Xcode."
  # fi
  :
fi

DAUER=\$(( \$(date +%s) - START ))
if [ \${#FAILED[@]} -eq 0 ]; then
  printf "\\n%sAlles durchgelaufen — %ss.%s\\n" "\$GREEN" "\$DAUER" "\$RESET"
  [ "\$REPORT" = 0 ] || scripts/melden.sh gruen "\$DAUER" "\$SCOPE"
  exit 0
fi
printf "\\n%sFehlgeschlagen: %s — %ss.%s\\n" "\$RED" "\${FAILED[*]}" "\$DAUER" "\$RESET"
[ "\$REPORT" = 0 ] || scripts/melden.sh rot "\$DAUER" "\$SCOPE" "\${FAILED[*]}"
exit 1
PRUEFEN

schreibe ".github/workflows/ci.yml" <<'CI'
name: CI

# **Nebenläufigkeit je Auftrag, nicht über dem Ablauf.** Steht
# `cancel-in-progress` oben, bricht der nächste Push den langen Auftrag ab —
# und zwar nach der teuersten Minute, ohne je ein Ergebnis geliefert zu haben.
# Der schnelle darf abgebrochen werden, der lange nicht.

on:
  push:
  pull_request:

jobs:
  schnell:
    runs-on: ubuntu-latest
    concurrency:
      group: schnell-${{ github.ref }}
      cancel-in-progress: true
    steps:
      - uses: actions/checkout@v4
      - name: Prüfen
        run: scripts/pruefen.sh schnell

  vollstaendig:
    runs-on: ubuntu-latest      # für iOS: macos-15 — und nie das voreingestellte Xcode nehmen
    concurrency:
      group: vollstaendig-${{ github.ref }}
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4
      - name: Prüfen
        run: scripts/pruefen.sh

      # **Auch bei rotem Lauf.** Bilder oder Protokolle hinter `if: success()`
      # zu verstecken heißt: Sie fehlen genau dann, wenn man sie braucht.
      - name: Belege sichern
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: belege
          path: build/
          if-no-files-found: ignore
CI

schreibe "CLAUDE.md" <<CLAUDEMD
# Arbeitsweise in diesem Projekt

## Regel 1 — Nichts gilt als fertig ohne Prüfung

\`\`\`bash
scripts/pruefen.sh            # alles
scripts/pruefen.sh schnell    # in Sekunden
\`\`\`

Vor jeder Runde \`git status\` — das Arbeitsverzeichnis muss auf dem
committeten Stand sein. Ein zurückgefallener Container sah schon einmal wie
verlorene Arbeit aus.

Erst wenn das grün ist, wird gepusht. Die CI ist die Gegenprobe auf einem
frischen Rechner, nicht der erste Durchgang.

## Regel 2 — Version, Release Notes und Tests je Änderung

Ohne dass jemand danach fragt. Der Ablauf steht in
\`.claude/skills/release-discipline/SKILL.md\`.

## Regel 3 — Angefangenes wird zu Ende gebracht, ohne Nachfrage

Wer einen Lauf anstößt, plant die Nachschau selbst, bevor der Zug endet. Nie
auf eine Erinnerung warten, nie mit \`sleep\` blockieren. Fertig heißt: beim
Nutzer — nicht gepusht, nicht zusammengeführt.

## Regel 4 — Teuer Gelerntes kommt in den Baukasten

\`.claude/skills/projekt-baukasten/SKILL.md\` trägt das gesammelte Vorgehen:
Aufbau, Dokumentation, Konzeptarbeit, Auslieferung, die wiederkehrenden
Fehlerklassen. **Was einen Lauf, einen Bau oder mehr als eine Stunde gekostet
hat, wird dort nachgetragen — im selben Commit wie die Änderung.** Auch die
Vermutung, die falsch war. Wird eine Zeile widerlegt, wird sie geändert, nicht
ergänzt.

## Sprache

- **Oberfläche und Dokumente:** Deutsch.
- **Code, Bezeichner, Commit-Nachrichten:** Englisch.
- **Kommentare im Code:** Deutsch, und sie begründen *warum*, nicht *was*.

Der Tonfall für alles, was der Nutzer liest, steht im Baukasten. Kurz gesagt:
behaupten und weitergehen, konkrete Orte und Zahlen statt Adjektive, und keine
Annahme über den Betreiber, die er nicht bestätigt hat.

## Produktprinzipien, gegen die jede Änderung geprüft wird

HIER EINTRAGEN: fünf bis sieben Sätze, gegen die sich jede Änderung halten
lassen muss. Sie sind Prüfsteine, keine Präambel.
CLAUDEMD

schreibe "CHANGELOG.md" <<'CHANGELOG'
# Änderungen

Alle nennenswerten Änderungen, neueste Version oben.
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/);
bis zur ersten Veröffentlichung bleibt die Hauptversion `0`.

Der Ablauf, nach dem diese Datei gepflegt wird, steht in
`.claude/skills/release-discipline/SKILL.md`.

---

## 0.1.0 — unveröffentlicht

### Hinzugefügt
- Erster Aufbau, übernommen aus dem Baukasten.
CHANGELOG

schreibe "docs/06-uebergabe.md" <<'UEBERGABE'
# Übergabe: der laufende Zustand

**Diese Datei wird überschrieben, nicht fortgeschrieben.** Sie ist eine
Momentaufnahme für eine Sitzung, die kalt startet. Die Historie steht im
CHANGELOG.

Stand: HIER EINTRAGEN

## Woran gerade gearbeitet wird

## Was als Nächstes ansteht

## Was offen ist und auf jemanden wartet

## Was schiefgehen kann, und woran man es merkt
UEBERGABE

titel "Fertig"

# **Nach allem Schreiben, nicht davor.** Der erste Anlauf setzte das Ausführbit
# in der Kopierphase — da gab es `pruefen.sh` noch gar nicht, und das erzeugte
# Projekt scheiterte beim ersten Aufruf mit „Permission denied".
if [ "$TROCKEN" = 0 ]; then
  chmod +x "$ZIEL"/scripts/*.sh "$ZIEL/.githooks/pre-push" 2>/dev/null || true
fi

if [ "$GIT" = 1 ] && [ "$TROCKEN" = 0 ] && [ ! -d "$ZIEL/.git" ]; then
  (cd "$ZIEL" && git init -q && git config core.hooksPath .githooks) && ok "git init, Haken auf .githooks"
elif [ "$TROCKEN" = 0 ] && [ -d "$ZIEL/.git" ]; then
  (cd "$ZIEL" && git config core.hooksPath .githooks) && ok "Haken auf .githooks gesetzt"
fi

cat <<ENDE

  Was jetzt noch von Hand kommt — und nur das:

    1. In scripts/check-sicherheit.sh die Liste QUELLEN auf die Ordner dieses
       Projekts setzen. **Der erste Prüflauf ist genau deswegen rot** — die
       Prüfung sagt lieber „ich sehe nichts" als grün über ungelesenen Code.
    2. In scripts/pruefen.sh die weiteren Schritte eintragen. Nach Kosten
       sortiert: was in einer Sekunde brechen kann, zuerst.
    3. In CLAUDE.md die Produktprinzipien schreiben.
    4. Bei einem iOS-Projekt: Abschnitt 4 und 5 des Baukastens durchgehen,
       **bevor** der erste Bau läuft. Die Bundle-ID zuerst.

  Vier Prüfungen liegen schon in scripts/ und laufen sofort. Was jede von
  ihnen einmal gekostet hat, steht in ihrem eigenen Kopf und in der Tabelle
  „Die Prüfungen" im Baukasten. In scripts/vorlagen/ liegt eine fünfte als
  Muster: Sie hält Preise auf einer Website gegen den Quelltext.

  Der Baukasten liegt in $ZIEL/.claude/skills/projekt-baukasten/SKILL.md
  und gilt dort auch in einer Cloud-Sitzung, sobald er committet ist.
ENDE
