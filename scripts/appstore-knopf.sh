#!/usr/bin/env bash
# Schaltet das App-Store-Abzeichen auf der Website scharf — oder wieder ab.
#
# **Warum ein Skript und nicht die Hand.** Am Starttag ist die Liste lang, und
# ein Abzeichen „Laden im App Store", das auf eine Fehlseite führt, ist das
# Versprechen, das dieses Projekt sich verbietet (docs/09-appstore.md). Also
# steht es bis dahin als „Bald im App Store" da, und ein Befehl macht daraus
# den Verweis. Dieselbe Lehre wie bei `domain-setzen.sh`: Eine halb
# umgestellte Website ist schlimmer als eine, die ehrlich wartet.
#
#   scripts/appstore-knopf.sh              # zeigt, was gerade dasteht
#   scripts/appstore-knopf.sh an           # macht den Verweis daraus
#   scripts/appstore-knopf.sh aus          # zurück in den Wartezustand
#
# Die App-Kennung steht fest, seit der Eintrag in App Store Connect existiert.
set -euo pipefail

cd "$(dirname "$0")/.."
SEITE="docs/website/index.html"
APP_ID="6802262743"
ZIEL="https://apps.apple.com/de/app/id${APP_ID}"

APFEL='<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
              <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
            </svg>'

zustand() {
  if grep -q "apfel-wartet" "$SEITE"; then echo "aus"; else echo "an"; fi
}

case "${1:-}" in
  "")
    echo "App-Store-Abzeichen: $(zustand)"
    [ "$(zustand)" = "aus" ] && echo "Es steht „Bald im App Store\" da und führt nirgendwohin."
    [ "$(zustand)" = "an" ] && echo "Es führt auf $ZIEL"
    exit 0
    ;;
  an)
    NEU="<a class=\"apfel\" href=\"${ZIEL}\">
            ${APFEL}
            <span class=\"apfel-text\">
              <small>Laden im</small>
              <b>App Store</b>
            </span>
          </a>"
    ;;
  aus)
    NEU="<span class=\"apfel apfel-wartet\" aria-label=\"Bald im App Store\">
            ${APFEL}
            <span class=\"apfel-text\">
              <small>Bald</small>
              <b>im App Store</b>
            </span>
          </span>"
    ;;
  *)
    echo "Unbekannt: $1 — erlaubt sind „an\" und „aus\"." >&2
    exit 1
    ;;
esac

# Ersetzt wird der ganze markierte Block, nicht ein Wort darin: Ein `sed` auf
# „apfel-wartet" hätte die Klasse getauscht und das `<span>` stehen lassen —
# ein Abzeichen, das aussieht wie ein Knopf und keiner ist.
python3 - "$SEITE" "$NEU" <<'PY'
import re, sys, pathlib
pfad, neu = sys.argv[1], sys.argv[2]
p = pathlib.Path(pfad)
t = p.read_text()
muster = re.compile(r"(<!-- APPSTORE-KNOPF.*?-->\n)(.*?)(\n\s*<!-- /APPSTORE-KNOPF -->)",
                    re.S)
if not muster.search(t):
    sys.exit("Der markierte Block APPSTORE-KNOPF steht nicht in der Seite.")
t = muster.sub(lambda m: m.group(1) + "          " + neu + m.group(3), t, count=1)
p.write_text(t)
PY

echo "App-Store-Abzeichen: $(zustand)"
