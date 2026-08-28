#!/usr/bin/env bash
# Sorgt dafür, dass es das Pages-Projekt gibt — und legt es an, wenn nicht.
#
# **Warum das nicht der Gründer klickt.** Er hat es versucht, und der erste
# Versuch endete in Cloudflares eigenem Bau mit `Could not detect a directory
# to deploy`. Danach hieß es „Project not found": Das Projekt war entweder nie
# entstanden oder anders benannt. Ein Schritt, den ein Token erledigen kann,
# gehört nicht auf eine Klickliste — vom Gründer so verlangt: „ich will, dass
# du alles für mich automatisierst."
#
# Das Token braucht dafür nichts Zusätzliches: `Cloudflare Pages: Edit` darf
# Projekte anlegen.
#
# Aus der Umgebung: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
set -euo pipefail

PROJEKT="${1:-pulsemeter}"
ZWEIG="${2:-main}"
# Dieselbe Fassung, die `wrangler-action` benutzt. Stünde hier eine andere,
# wäre das die vierte Stelle mit einer Version, die auseinanderlaufen kann.
WRANGLER="wrangler@3.90.0"

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN fehlt}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID fehlt}"

# `project list` schreibt eine Tabelle; gesucht wird der Name als ganzes Wort,
# damit `pulsemeter-alt` nicht als Treffer durchgeht.
if npx --yes "$WRANGLER" pages project list 2>/dev/null \
     | grep -qE "(^|[^a-z0-9-])${PROJEKT}([^a-z0-9-]|$)"; then
  echo "Pages-Projekt „$PROJEKT\" steht."
  exit 0
fi

echo "Pages-Projekt „$PROJEKT\" gibt es nicht — wird angelegt."
npx --yes "$WRANGLER" pages project create "$PROJEKT" --production-branch="$ZWEIG"
echo "Angelegt. Die Adresse ist https://${PROJEKT}.pages.dev"
