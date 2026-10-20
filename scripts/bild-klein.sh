#!/usr/bin/env bash
# Verkleinert Bilder zum **Ansehen**: höchstens 1000 Pixel hoch, JPEG.
#
# Warum: Ein Bild im Kontext kostet nach seiner Fläche, ein Store-Bild von
# 1320 × 2868 etwa das Vierfache eines Bildes von 460 × 1000 — und es wird bei
# jeder weiteren Antwort der Sitzung mitgelesen. Zum Beurteilen von Anordnung,
# Kontrast und Zahlen reichen 1000 Pixel (`publish-shots.sh` verkleinert die
# Bilder für den Zweig `screenshots` aus demselben Grund).
#
# Aufruf:  scripts/bild-klein.sh bild.png [weiteres.jpg …]
# Ausgabe: je Bild eine Datei `<name>-klein.jpg` daneben, der Pfad auf stdout.
# **Zum Ansehen, nie zum Einreichen:** Der Store bekommt die Bilder in voller
# Größe (`store-shots.mjs`).
set -euo pipefail
[ $# -gt 0 ] || { echo "Aufruf: $0 bild [bild …]" >&2; exit 2; }
for bild in "$@"; do
  ziel="${bild%.*}-klein.jpg"
  if command -v convert >/dev/null 2>&1; then
    convert "$bild" -resize 'x1000>' -quality 72 "$ziel"
  elif command -v sips >/dev/null 2>&1; then
    sips -Z 1000 -s format jpeg -s formatOptions 72 "$bild" --out "$ziel" >/dev/null
  else
    echo "Weder ImageMagick (convert) noch sips gefunden." >&2; exit 1
  fi
  echo "$ziel"
done
