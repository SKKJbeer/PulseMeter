#!/usr/bin/env bash
# Baut, was zu Cloudflare Pages hochgeladen wird: die Seiten und die Zählung.
#
#   scripts/website-paket.sh build/pages
#
# Ergebnis:
#   build/pages/inhalt/        die Seiten, genau wie aus `website-fertig.sh`
#   build/pages/functions/     die Zählung (`docs/website-server/`)
#   build/pages/wrangler.toml  der Ort, an den die Zählung schreibt
#
# **Warum die Funktion nicht in `docs/website/` liegt.** Alles dort wird als
# Datei ausgeliefert. Eine Funktion daneben stünde als Quelltext unter
# `/functions/_middleware.js` im Netz, und die Prüfung zählte sie als Seite.
# Wrangler sucht Funktionen im Ordner, in dem es läuft; deshalb dieser eigene
# Ordner, in dem es gestartet wird.
set -euo pipefail
cd "$(dirname "$0")/.."

ZIEL="${1:?Aufruf: scripts/website-paket.sh <zielordner>}"
rm -rf "$ZIEL"
mkdir -p "$ZIEL/functions"
scripts/website-fertig.sh "$ZIEL/inhalt"
cp docs/website-server/*.js "$ZIEL/functions/"

# **Die Funktion läuft nur für Seiten.** Bilder, Stylesheet und Symbole gehen
# an ihr vorbei: Sie würden ohnehin nicht gezählt, und jeder Aufruf einer
# Funktion zählt gegen die 100 000 am Tag, die kostenlos sind. Die Liste
# entsteht aus dem Ordner, damit eine neue Datei nicht vergessen wird.
python3 - "$ZIEL/inhalt" <<'ENDE_PY'
import json, pathlib, sys
ordner = pathlib.Path(sys.argv[1])
aus = sorted(f"/{p.name}/*" if p.is_dir() else f"/{p.name}"
             for p in ordner.iterdir()
             if not p.name.endswith(".html") and not p.name.startswith("_"))
if len(aus) > 99:
    sys.exit(f"_routes.json erlaubt 100 Regeln, hier wären es {len(aus) + 1}")
(ordner / "_routes.json").write_text(json.dumps(
    {"version": 1, "include": ["/*"], "exclude": aus}, indent=2) + "\n")
print(f"_routes.json: Funktion für Seiten, {len(aus)} Ausnahmen")
ENDE_PY

cat > "$ZIEL/wrangler.toml" <<'ENDE'
name = "zaehlora"
pages_build_output_dir = "inhalt"
compatibility_date = "2026-09-01"

# Die Zählung. Cloudflare legt den Datensatz beim ersten Schreiben an und
# bewahrt ihn drei Monate auf; länger nicht, und das steht so auch in der
# Datenschutzerklärung.
[[analytics_engine_datasets]]
binding = "ZAEHLUNG"
dataset = "zaehlora_aufrufe"
ENDE
echo "Paket in $ZIEL"
