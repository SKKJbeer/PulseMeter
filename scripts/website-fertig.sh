#!/usr/bin/env bash
# Legt die auslieferbare Website in einen Ordner — genau das, was ins Netz geht.
#
# **Warum das nicht `docs/website/` selbst ist.** Dort liegen zwei Dateien, die
# niemanden außer dem Gründer etwas angehen: `EINTRAGEN.md` mit seiner
# Anschrift und den offenen Stellen, und `CLOUDFLARE.md` mit der Einrichtung.
# Der Zweigweg hat sie entfernt, der Upload über wrangler hätte sie
# mitgeschickt — zwei Wege, die dasselbe tun sollen und es nicht taten.
# Genau die Fehlerklasse, die dieses Projekt schon zweimal bezahlt hat.
#
# Also: **ein** Ort, an dem entschieden wird, was ausgeliefert wird.
#
#   scripts/website-fertig.sh build/website
set -euo pipefail
cd "$(dirname "$0")/.."

ZIEL="${1:?Aufruf: scripts/website-fertig.sh <zielordner>}"
QUELLE="docs/website"

rm -rf "$ZIEL"
mkdir -p "$ZIEL"
cp -R "$QUELLE"/. "$ZIEL"/

# Was im Repository bleibt und nicht ins Netz geht.
rm -f "$ZIEL"/EINTRAGEN.md "$ZIEL"/CLOUDFLARE.md

# **Kein Verzeichnis auflisten.** Ohne diese Datei liefert Pages `/bilder/` als
# Liste aus, und die Dateiablage stünde offen im Netz.
cat > "$ZIEL/_headers" <<'ENDE'
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: SAMEORIGIN
ENDE

# Fällt jemandem eine weitere Datei ein, die nicht ins Netz gehört, gehört sie
# hierher — und die Prüfung darunter merkt es, wenn sie es doch tut.
if find "$ZIEL" -name "*.md" | grep -q .; then
  echo "Im Auslieferordner liegt noch eine Markdown-Datei:" >&2
  find "$ZIEL" -name "*.md" >&2
  exit 1
fi

echo "$(find "$ZIEL" -type f | wc -l | tr -d ' ') Dateien in $ZIEL"
