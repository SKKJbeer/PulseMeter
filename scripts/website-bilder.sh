#!/usr/bin/env bash
# Holt die Bilder der Website aus dem Zweig `screenshots`.
#
# **Warum es das gibt.** Bis 0.116.8 lagen in `docs/website/bilder` Aufnahmen
# vom 2. September, von Hand kopiert. Im Bericht darauf stand unten noch
# „PulseMeter", drei Wochen nach der Umbenennung, und auf der Übersicht der
# 28. August. Die CI legt bei jedem Lauf frische Aufnahmen in genau dieser
# Größe (460 × 1000) in den Zweig `screenshots`; sie wurden nur nie abgeholt.
#
# Aufruf: scripts/website-bilder.sh   (danach prüfen, committen)
set -euo pipefail
cd "$(dirname "$0")/.."

ZIEL=docs/website/bilder
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git fetch --quiet --depth 1 origin screenshots
git archive origin/screenshots | tar -x -C "$TMP"
stand=$(sed -n 's/.*aus `\([0-9a-f]\{7\}\)[0-9a-f]*`.*/\1/p' "$TMP/README.md" | head -1)

# Name auf der Website ← Name im Zweig. Die Website hat kürzere Namen, weil
# sie älter ist als die Aufnahmen; umbenannt wird hier, nicht dort.
paare="light:screenshot-light dark:screenshot-dark
capture-light:screenshot-capture-light capture-dark:screenshot-capture-dark
verlauf-light:screenshot-verlauf-light verlauf-dark:screenshot-verlauf-dark
bericht-light:screenshot-bericht-light bericht-dark:screenshot-bericht-dark
zaehler-light:screenshot-zaehler-light zaehler-dark:screenshot-zaehler-dark"

fehlt=0
for paar in $paare; do
  ziel=${paar%%:*}; quelle=${paar#*:}
  if [ -f "$TMP/$quelle.jpg" ]; then
    cp "$TMP/$quelle.jpg" "$ZIEL/$ziel.jpg"
  else
    echo "fehlt im Zweig: $quelle.jpg"; fehlt=1
  fi
done
echo "Bilder aus dem Stand ${stand:-unbekannt} übernommen."
exit $fehlt
