#!/usr/bin/env bash
# Legt die Screenshots eines CI-Laufs in den Zweig `screenshots`.
#
# **Warum nicht einfach das Artefakt?** Weil ich als Entwickler in dieser
# Umgebung nicht an die GitHub-API komme — der Download eines Artefakts
# scheitert an der Zugangssperre, git dagegen läuft. Und ohne die Bilder fehlt
# die produktivste Prüfung, die dieses Projekt hat: Sieben der bisher
# gefundenen Darstellungsfehler hat kein Test gefunden, sondern der Blick auf
# einen Screenshot.
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

: "${GITHUB_TOKEN:?GITHUB_TOKEN fehlt}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY fehlt}"

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
  echo "Erzeugt am $(date -u '+%Y-%m-%d %H:%M UTC') aus \`${GITHUB_SHA:-unbekannt}\`."
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
git -c user.name="PulseMeter CI" -c user.email="noreply@github.com" \
    commit -q -m "Screenshots aus ${GITHUB_SHA:-unbekannt}"
git push -q --force \
    "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
    "$BRANCH"

echo "Screenshots liegen im Zweig $BRANCH (${#shots[@]} Bilder)."
