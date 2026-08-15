#!/usr/bin/env bash
# Trägt die Adresse der Website an allen Stellen ein, an denen sie steht.
#
# **Warum es dieses Skript gibt.** Der Anfang ist eine kostenlose Adresse, und
# das ist eine vernünftige Entscheidung — aber nur, solange sie umkehrbar
# bleibt. Die Adresse steht in vier `canonical`-Zeilen, und eine halb
# umgestellte Website ist schlimmer als eine mit der falschen Adresse: Google
# hält `canonical` für die Wahrheit und wirft die Seiten weg, die auf eine
# fremde Adresse zeigen.
#
# Ein Befehl, alle Stellen, danach die Prüfung. Der Wechsel von
# `pulsemeter.pages.dev` auf eine eigene Domain kostet damit eine Minute.
#
# Aufruf:
#   scripts/domain-setzen.sh pulsemeter.de
#   scripts/domain-setzen.sh              zeigt nur, was gerade eingetragen ist
set -euo pipefail
cd "$(dirname "$0")/.."

ORDNER="docs/website"
DATEIEN=("$ORDNER"/*.html)

jetzt() {
  grep -ho 'rel="canonical" href="https://[^/"]*' "${DATEIEN[@]}" \
    | sed 's|.*https://||' | sort -u
}

if [ $# -eq 0 ]; then
  printf "Eingetragen ist gerade:\n"
  jetzt | sed 's/^/  /'
  printf "\nÄndern:  scripts/domain-setzen.sh <adresse>\n"
  exit 0
fi

NEU="${1#https://}"; NEU="${NEU#http://}"; NEU="${NEU%/}"
ALT=$(jetzt | head -1)

if [ -z "$ALT" ]; then
  echo "Keine canonical-Zeile gefunden — steht die Website noch in $ORDNER?" >&2
  exit 1
fi
if [ "$(jetzt | wc -l)" -gt 1 ]; then
  echo "Die Seiten zeigen auf verschiedene Adressen. Das ist der Zustand, den" >&2
  echo "dieses Skript verhindern soll — bitte einmal von Hand ansehen:" >&2
  jetzt | sed 's/^/  /' >&2
  exit 1
fi

for datei in "${DATEIEN[@]}"; do
  # Nur innerhalb der canonical-Zeilen ersetzen. Ein stumpfes Suchen und
  # Ersetzen über die ganze Datei träfe auch Fließtext, in dem die Adresse
  # aus gutem Grund anders lauten kann.
  sed -i.bak "s|\(rel=\"canonical\" href=\"https://\)$ALT|\1$NEU|" "$datei"
  rm -f "$datei.bak"
done

printf "Von %s auf %s umgestellt.\n\n" "$ALT" "$NEU"
printf "Noch zu tun:\n"
printf "  · node scripts/check-website.mjs\n"
printf "  · Die Adresse bei Cloudflare Pages eintragen\n"
printf "  · In App Store Connect die Datenschutz- und die Support-URL ändern\n"
