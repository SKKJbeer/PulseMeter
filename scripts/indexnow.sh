#!/usr/bin/env bash
# Meldet die Adressen aus der Sitemap bei IndexNow.
#
# **Was IndexNow ist.** Ein offenes Verfahren, mit dem eine Website sagt „hier
# hat sich etwas geändert", statt zu warten, bis ein Suchdienst von selbst
# vorbeikommt. Bing, Yandex, Seznam und Naver nehmen es an, und Bing liefert
# die Ergebnisse für DuckDuckGo, Ecosia und die Websuche von ChatGPT mit.
# **Google nimmt es nicht an.** Dort ist der offizielle Weg die Search Console,
# siehe `docs/10-sichtbarkeit.md`.
#
# **Der Schlüssel ist öffentlich, und das ist so gedacht.** Er liegt als
# `<schlüssel>.txt` im Wurzelverzeichnis der Website; wer die Datei ablegen
# kann, beweist damit, dass ihm die Website gehört. Ein Geheimnis wäre er nur,
# wenn ihn jemand anders auf seiner eigenen Website ablegen könnte.
#
# Aufruf: scripts/indexnow.sh   (im Ablauf website.yml nach dem Veröffentlichen)
set -euo pipefail
cd "$(dirname "$0")/.."

WEBSITE="https://zaehlora.pages.dev"
HOST="${WEBSITE#https://}"
schluessel=$(ls docs/website | grep -E '^[0-9a-f]{32}\.txt$' | head -1 | sed 's/\.txt$//')
[ -n "$schluessel" ] || { echo "Kein IndexNow-Schlüssel in docs/website"; exit 1; }

# Erst nachsehen, ob der Schlüssel schon online steht. Cloudflare braucht nach
# dem Hochladen einen Moment; eine Meldung, deren Schlüssel noch nicht
# abrufbar ist, lehnt IndexNow mit 403 ab.
for versuch in 1 2 3 4 5 6; do
  if [ "$(curl -fsS "$WEBSITE/$schluessel.txt" 2>/dev/null || true)" = "$schluessel" ]; then
    break
  fi
  [ "$versuch" = 6 ] && { echo "::warning::Der IndexNow-Schlüssel ist noch nicht online; nichts gemeldet."; exit 0; }
  sleep 20
done

# Die Sitemap der ausgelieferten Seite, nicht die im Repository: Nur dort
# stehen die Adressen ohne `.html`, so wie Cloudflare sie ausliefert.
adressen=$(curl -fsS "$WEBSITE/sitemap.xml" | grep -oE '<loc>[^<]+</loc>' | sed -E 's#</?loc>##g')
json=$(python3 - "$HOST" "$schluessel" "$WEBSITE" <<PY
import json, sys
host, key, site = sys.argv[1:4]
urls = """$adressen""".split()
print(json.dumps({"host": host, "key": key, "keyLocation": f"{site}/{key}.txt", "urlList": urls}))
PY
)
stand=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "https://api.indexnow.org/indexnow" \
          -H "Content-Type: application/json; charset=utf-8" -d "$json")
anzahl=$(printf "%s\n" $adressen | wc -l | tr -d ' ')
case "$stand" in
  200|202) echo "::notice::IndexNow: $anzahl Adressen gemeldet (Antwort $stand)." ;;
  *)       echo "::warning::IndexNow antwortete mit $stand. Die Website ist trotzdem online." ;;
esac
