#!/usr/bin/env bash
# Legt die geprüfte Website in den Zweig `website` — als Wurzel, nicht als
# Unterordner.
#
# **Wofür das da ist.** Cloudflare Pages kann sich an einen Zweig hängen und
# alles auslesen, was darin liegt. Damit braucht es **kein** Token, kein
# Kontokennzeichen und keine zwei Geheimnisse im Repository — und genau die
# ließen sich am Telefon nicht eintragen: Die GitHub-App hat überhaupt keinen
# Einstellungsbereich, und der Verweis darauf lief ins Leere.
#
# **Und die Prüfung behält trotzdem das letzte Wort.** Der Einwand gegen
# Cloudflares Anbindung ans Repository war, dass dann auch eine Seite online
# geht, die `check-website.mjs` nicht bestanden hat. Der Zweig löst das: Er
# entsteht **nur** nach einer bestandenen Prüfung. Cloudflare sieht nie den
# Hauptzweig, sondern immer nur das, was durchgekommen ist.
#
# Der Zweig trägt immer nur einen Stand und wird überschrieben. Eine Historie
# der Website ist die Historie von `docs/website/` im Hauptzweig.
set -euo pipefail
cd "$(dirname "$0")/.."

QUELLE="docs/website"
BRANCH="${WEBSITE_BRANCH:-website}"

[ -d "$QUELLE" ] || { echo "$QUELLE gibt es nicht."; exit 1; }

if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  ZIEL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  STAND="${GITHUB_SHA:-unbekannt}"
  WOHER="CI"
else
  ZIEL=$(git remote get-url origin 2>/dev/null || true)
  [ -n "$ZIEL" ] || { echo "Kein origin und kein GITHUB_TOKEN."; exit 1; }
  STAND=$(git rev-parse HEAD)
  WOHER=$(uname -s); [ "$WOHER" = "Darwin" ] && WOHER="Mac"
  [ -z "$(git status --porcelain --untracked-files=no)" ] || STAND="$STAND (mit Änderungen)"
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -R "$QUELLE"/. "$WORK"/

# Was Cloudflare nicht ausliefern soll: die Anleitungen für den Gründer. Sie
# gehören ins Repository, nicht auf eine öffentliche Adresse.
rm -f "$WORK"/EINTRAGEN.md "$WORK"/CLOUDFLARE.md

# **Kein Verzeichnis auflisten.** Cloudflare Pages liefert `/bilder/` sonst als
# Liste aus, und damit stünde die Dateiablage offen im Netz.
cat > "$WORK/_headers" <<'ENDE'
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: SAMEORIGIN
ENDE

cd "$WORK"
git init -q -b "$BRANCH"
git add -A
git -c user.name="PulseMeter" -c user.email="noreply@pulsemeter.app" \
    commit -q -m "Website aus $STAND ($WOHER)"
git push -q --force "$ZIEL" "$BRANCH:$BRANCH"

echo "Website liegt im Zweig $BRANCH ($(find . -type f -not -path './.git/*' | wc -l | tr -d ' ') Dateien, $WOHER)."
