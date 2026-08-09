#!/usr/bin/env bash
# Ein Aufruf, und dieser Mac kann alles: aktuellen Stand holen, Xcode-Projekt
# erzeugen, alles prüfen, Bilder zeigen.
#
# **Warum es das gibt.** Die Einzelschritte lagen bisher an vier Stellen —
# `START-HIER.md` fürs Anfangen, `setup-mac.sh` für Xcode, `pruefen.sh` fürs
# Prüfen, `run.sh` für die Bilder. Jeder Schritt für sich war beschrieben, die
# Reihenfolge nirgends. Wer nach zwei Wochen zurückkommt, rät.
#
# Und ein Fehler, der ohne diesen Ablauf nicht auffällt: Eine Arbeitskopie, die
# auf `main` steht, während die Arbeit auf einem Zweig liegt, sieht vollständig
# aus und ist zwei Versionen alt. Genau das ist passiert — eine Sitzung prüfte
# 0.30.1 und hielt es für den aktuellen Stand.
#
# Aufruf:
#   scripts/mac-start.sh              Stand von `main` holen und alles prüfen
#   scripts/mac-start.sh <zweig>      von einem anderen Zweig holen
#   scripts/mac-start.sh --ohne-holen  nichts holen, nur einrichten und prüfen
set -uo pipefail
cd "$(dirname "$0")/.."

ZWEIG="main"
HOLEN=1
for arg in "$@"; do
  case "$arg" in
    --ohne-holen) HOLEN=0 ;;
    -h|--hilfe|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unbekannter Schalter: $arg" >&2; exit 2 ;;
    *) ZWEIG="$arg" ;;
  esac
done

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
say()  { printf "\n%s▸ %s%s\n" "$BOLD" "$1" "$RESET"; }
note() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }
fail() { printf "\n%s%s%s\n" "$RED" "$1" "$RESET"; exit 1; }

# ------------------------------------------------------------- 1. Den Stand

if [ "$HOLEN" = "1" ]; then
  say "Aktuellen Stand holen"

  # Nicht eingecheckte Arbeit wird nie überschrieben. Ein Skript, das
  # „aufräumt", ist genau einmal nett und danach der Grund, warum niemand es
  # mehr startet.
  #
  # Geprüft werden nur **eingecheckte** Dateien. Eine unbeteiligte neue Datei
  # überlebt einen Zweigwechsel unbeschadet, und wer wegen einer Notiz im
  # Ordner nicht mehr starten kann, startet bald gar nicht mehr. Gäbe es die
  # Datei auf dem Zielzweig ebenfalls, verweigert git den Wechsel von selbst —
  # mit einer Meldung, die genau sie benennt.
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    printf "  %sIm Arbeitsverzeichnis liegen Änderungen:%s\n" "$RED" "$RESET"
    git status --short --untracked-files=no | sed 's/^/    /'
    fail "Erst sichern (git commit) oder wegwerfen (git checkout .), dann noch einmal starten.
Nur einrichten und prüfen, ohne zu holen:  scripts/mac-start.sh --ohne-holen"
  fi

  git fetch --quiet origin "$ZWEIG" || fail "Konnte $ZWEIG nicht holen — hängt das Netz?"

  VORHER=$(git rev-parse HEAD)
  git checkout --quiet -B "$ZWEIG" "origin/$ZWEIG" || fail "Konnte nicht auf $ZWEIG wechseln."
  NACHHER=$(git rev-parse HEAD)

  if [ "$VORHER" = "$NACHHER" ]; then
    note "Schon auf dem neuesten Stand."
  else
    note "$(git log --oneline "$VORHER".."$NACHHER" | wc -l | tr -d ' ') neue Commits."
  fi
  printf "  %s auf %s\n" "$(git log -1 --format='%h %s')" "$ZWEIG"
fi

VERSION=$(grep -m1 '^## 0\.' CHANGELOG.md | sed 's/^## //;s/ .*//')
printf "\n%sPulseMeter %s%s\n" "$BOLD" "${VERSION:-unbekannt}" "$RESET"

# --------------------------------------------------------- 2. Xcode und Rest

if ! command -v xcodebuild >/dev/null 2>&1; then
  say "Xcode fehlt"
  cat <<'EOF'
  Ohne Xcode laufen der Rechenkern und der Klick-Dummy, aber nicht die App.

  1. Xcode aus dem App Store installieren
  2. Einmal öffnen und die Lizenz bestätigen
  3. Dieses Skript noch einmal starten

  Nur das, was ohne Xcode geht:  scripts/pruefen.sh schnell
EOF
  exit 1
fi

say "Einrichten"
scripts/setup-mac.sh || fail "Die Einrichtung ist gefallen — die Meldung darüber sagt, woran."

# ------------------------------------------------------------- 3. Alles prüfen

say "Alles prüfen"
note "Rechenkern, Speicher, App, Oberflächentests, Bilder, Klick-Dummy."
# `--melden` schreibt das Ergebnis in den Zweig `pruefungen` und die Bilder in
# den Zweig `screenshots`. Damit sieht eine Sitzung, die diesen Mac nicht
# erreicht, beides sofort — und niemand muss auf die CI warten, deren Ergebnis
# dann schon vorliegt.
scripts/pruefen.sh --melden
ERGEBNIS=$?

# ------------------------------------------------------------- 4. Die Bilder

if [ "$ERGEBNIS" = "0" ] && [ -d build ] && ls build/*.png >/dev/null 2>&1; then
  say "Bilder"
  note "$(ls build/*.png | wc -l | tr -d ' ') Screenshots in build/ — hell und dunkel."
  open build 2>/dev/null || true
fi

# ---------------------------------------------------------------- 5. Weiter

if [ "$ERGEBNIS" != "0" ]; then
  printf "\n%sEs ist etwas gefallen — siehe oben.%s\n" "$RED" "$RESET"
  exit "$ERGEBNIS"
fi

printf "\n%sDieser Mac kann jetzt alles.%s\n" "$GREEN" "$RESET"
if command -v claude >/dev/null 2>&1; then
  cat <<'EOF'

Weiter mit Claude Code — im Projektordner einfach:
  claude
EOF
else
  cat <<'EOF'

Claude Code ist auf diesem Rechner noch nicht installiert. Entweder die
Desktop-App von https://claude.com/claude-code, oder:
  npm install -g @anthropic-ai/claude-code && claude
EOF
fi
cat <<'EOF'

Danach genügt:
  scripts/pruefen.sh schnell   zwischendurch, in Sekunden
  scripts/run.sh               App im Simulator, neue Bilder
EOF
