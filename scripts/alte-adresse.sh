#!/usr/bin/env bash
# Leitet die alte Adresse dauerhaft auf die neue um.
#
# **Warum das nötig wurde, und warum Abschalten falsch wäre.**
# `pulsemeter.pages.dev` blieb nach dem Umzug stehen und lieferte weiter eine
# vollständige Kopie der Website — mit einem `canonical`, das auf **sich
# selbst** zeigt. Damit sieht eine Suchmaschine zwei Seiten mit gleichem
# Inhalt, von denen jede sich zum Original erklärt. Sie entscheidet dann
# selbst, welche sie behält, und das ist eine Wette.
#
# Gefunden hat es der Gründer mit einer Frage, nicht eine Prüfung: „ist die
# alte wieder heruntergenommen?" Ich hatte es angenommen.
#
# **Löschen wäre die schlechtere Lösung.** Jeder Verweis, der irgendwo auf die
# alte Adresse zeigt, liefe dann ins Leere; mit einer 301 landet er auf der
# passenden neuen Seite, und das Gewicht der alten Adresse geht mit.
#
#   scripts/alte-adresse.sh            # baut den Umleitungsordner
#   scripts/alte-adresse.sh --pruefen  # sieht nach, was die alte Adresse tut
set -euo pipefail

cd "$(dirname "$0")/.."
ALT="pulsemeter"
NEU="https://zaehlora.pages.dev"
ORDNER="build/umleitung"

if [ "${1:-}" = "--pruefen" ]; then
  echo "Alte Adresse: https://${ALT}.pages.dev"
  code=$(curl -sS -o /dev/null -w "%{http_code}" "https://${ALT}.pages.dev/")
  ziel=$(curl -sS -o /dev/null -w "%{redirect_url}" "https://${ALT}.pages.dev/")
  echo "  Antwort: $code"
  echo "  Leitet nach: ${ziel:-nirgendwohin}"
  # 301 mit Ziel auf der neuen Adresse ist der Sollzustand. Alles andere heißt:
  # Die alte Seite steht noch als eigene Seite da.
  case "$code" in
    301|308) echo "  ✓ Sie leitet weiter." ;;
    *)       echo "  ✗ Sie liefert noch eine eigene Seite." ; exit 1 ;;
  esac
  exit 0
fi

rm -rf "$ORDNER"
mkdir -p "$ORDNER"

# `:splat` überträgt den ganzen Pfad. Wer auf `/datenschutz` verweist, landet
# auf `/datenschutz` — nicht auf der Startseite. Eine Umleitung, die alles auf
# die Startseite wirft, verliert genau die Verweise, für die sie gedacht ist.
cat > "$ORDNER/_redirects" <<REDIRECTS
/*  ${NEU}/:splat  301
REDIRECTS

# Eine Seite muss trotzdem daliegen: Cloudflare Pages nimmt keinen Ordner an,
# der nur eine Steuerdatei enthält. Sie wird nie ausgeliefert — die Umleitung
# greift vorher —, aber sie darf trotzdem nichts Falsches behaupten.
cat > "$ORDNER/index.html" <<SEITE
<!doctype html>
<html lang="de">
<meta charset="utf-8">
<title>Zählora</title>
<link rel="canonical" href="${NEU}/">
<meta http-equiv="refresh" content="0; url=${NEU}/">
<p>Zählora steht jetzt unter <a href="${NEU}/">${NEU}</a>.</p>
SEITE

echo "Umleitungsordner steht in $ORDNER — ${ALT}.pages.dev → ${NEU}"
