#!/usr/bin/env bash
# Legt die Screenshots eines Laufs in den Zweig `screenshots` — aus der CI
# **und** von einem Mac aus.
#
# **Warum nicht einfach das Artefakt?** Weil ich als Entwickler in dieser
# Umgebung nicht an die GitHub-API komme — der Download eines Artefakts
# scheitert an der Zugangssperre, git dagegen läuft. Und ohne die Bilder fehlt
# die produktivste Prüfung, die dieses Projekt hat: Sieben der bisher
# gefundenen Darstellungsfehler hat kein Test gefunden, sondern der Blick auf
# einen Screenshot.
#
# **Warum auch lokal.** Bis 0.32.3 lief das nur in der CI, und damit war die CI
# der einzige Weg, wie eine Sitzung ohne Zugriff auf den Mac die Bilder je zu
# sehen bekam — fünfzehn Minuten für etwas, das lokal nach zwei Minuten fertig
# in `build/` liegt. Auf einem Mac gibt es kein `GITHUB_TOKEN`, dafür aber die
# eingerichteten git-Zugangsdaten für `origin`. Die genügen.
#
# Der Zweig trägt immer nur **einen** Stand: Ein frisch angelegtes Repository
# wird mit `--force` geschoben. Damit wächst weder die Historie noch das
# Objektlager — der jeweils letzte Lauf zählt, ältere Stände sind über die
# Artefakte weiter erreichbar.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-build}"
BRANCH="${SHOTS_BRANCH:-screenshots}"

shopt -s nullglob
shots=("$SRC"/*.png)
if [ ${#shots[@]} -eq 0 ]; then
  echo "Keine Screenshots in $SRC — nichts zu veröffentlichen."
  exit 0
fi

# In der CI liegt ein Token bereit; auf einem Mac nicht. Dort wird über
# `origin` geschoben, mit den Zugangsdaten, die für jedes andere `git push`
# dieses Projekts ohnehin schon eingerichtet sind.
if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  ZIEL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  STAND="${GITHUB_SHA:-unbekannt}"
  WOHER="CI"
else
  ZIEL=$(git remote get-url origin 2>/dev/null || true)
  [ -n "$ZIEL" ] || { echo "Kein origin und kein GITHUB_TOKEN — nichts zu veröffentlichen."; exit 0; }
  STAND=$(git rev-parse HEAD)
  WOHER=$(uname -s); [ "$WOHER" = "Darwin" ] && WOHER="Mac"
  # Ein Lauf auf einem Arbeitsverzeichnis mit nicht eingecheckten Änderungen
  # zeigt Bilder, die zu keinem Commit gehören. Das gehört dazu, sonst liest
  # sich der Zweig später als Aussage über einen Stand, den es nie gab.
  [ -z "$(git status --porcelain --untracked-files=no)" ] || STAND="$STAND (mit Änderungen)"
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Verkleinert und als JPEG: Zehn Bildschirmfotos eines iPhone-Simulators sind
# als PNG zusammen über drei Megabyte. In dieser Größe brauche ich sie nicht —
# ich sehe mir Anordnung, Kontrast und Zahlen an, und dafür reichen 1000 Pixel
# Höhe bei weitem. Das Ganze schrumpft damit auf ein Zehntel.
for png in "${shots[@]}"; do
  name=$(basename "$png" .png)
  sips -Z 1000 -s format jpeg -s formatOptions 72 "$png" --out "$WORK/$name.jpg" >/dev/null
done

{
  echo "# Screenshots"
  echo
  echo "Erzeugt am $(date -u '+%Y-%m-%d %H:%M UTC') aus \`$STAND\` — $WOHER."
  echo
  echo "Dieser Zweig wird bei jedem Lauf **überschrieben**. Er ist keine"
  echo "Historie, sondern der jeweils aktuelle Blick auf die Oberfläche."
  echo
  for jpg in "$WORK"/*.jpg; do
    echo "- \`$(basename "$jpg")\`"
  done
} > "$WORK/README.md"

cd "$WORK"
git init -q -b "$BRANCH"
git add -A
git -c user.name="PulseMeter" -c user.email="noreply@pulsemeter.app" \
    commit -q -m "Screenshots aus $STAND ($WOHER)"
git push -q --force "$ZIEL" "$BRANCH"

echo "Screenshots liegen im Zweig $BRANCH (${#shots[@]} Bilder, $WOHER)."
