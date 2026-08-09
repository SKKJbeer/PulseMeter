#!/usr/bin/env bash
# Legt das Ergebnis eines lokalen Prüflaufs in den Zweig `pruefungen`.
#
# **Wozu.** Eine Sitzung, die in einem Linux-Container läuft, sieht den Mac des
# Gründers nicht. Sie weiß deshalb nicht, ob ein Stand schon geprüft wurde —
# und wartet vorsichtshalber auf die CI, zwölf bis fünfzehn Minuten, obwohl das
# Ergebnis längst vorliegt.
#
# Ein Zweig ist der einzige Weg, der von hier aus in beide Richtungen
# funktioniert: An die GitHub-API komme ich aus dieser Umgebung nicht heran, an
# git schon. Dasselbe Verfahren wie bei den Screenshots.
#
# Der Zweig ist eine **Liste**, keine Momentaufnahme: Er wächst um eine Zeile je
# Lauf, damit sich nachlesen lässt, welcher Stand wo geprüft wurde. Die Datei
# bleibt klein — eine Zeile hat unter zweihundert Zeichen.
#
# Aufruf (macht `scripts/pruefen.sh --melden` selbst):
#   scripts/melden.sh <ergebnis> <dauer-in-sekunden> <umfang> [notiz]
#
# `PRUEF_TROCKEN=1` zeigt nur, was gemeldet würde, und schiebt nichts.
set -euo pipefail
cd "$(dirname "$0")/.."

ERGEBNIS="${1:-unbekannt}"
DAUER="${2:-0}"
UMFANG="${3:-alles}"
NOTIZ="${4:-}"
BRANCH="${PRUEF_BRANCH:-pruefungen}"

REMOTE=$(git remote get-url origin 2>/dev/null || true)
[ -n "$REMOTE" ] || { echo "Kein origin — nichts zu melden."; exit 0; }

SHA=$(git rev-parse HEAD)
ZWEIG=$(git rev-parse --abbrev-ref HEAD)
WER=$(git config user.name || echo unbekannt)
# Sauber oder nicht: Ein Lauf auf einem Arbeitsverzeichnis mit nicht
# eingecheckten Änderungen sagt über den Commit nichts aus. Das gehört dazu,
# sonst liest sich später ein grüner Haken als Aussage über einen Stand, den
# so nie jemand geprüft hat.
SAUBER=$([ -z "$(git status --porcelain)" ] && echo "sauber" || echo "mit Änderungen")
WANN=$(date -u '+%Y-%m-%d %H:%M UTC')
WO=$(uname -s)
[ "$WO" = "Darwin" ] && WO="Mac"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Den vorhandenen Stand holen, wenn es ihn gibt — sonst fängt die Liste an.
if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
  git clone -q --depth 1 --branch "$BRANCH" "$REMOTE" "$WORK" 2>/dev/null || true
fi
if [ ! -d "$WORK/.git" ]; then
  rm -rf "$WORK"; mkdir -p "$WORK"
  git init -q -b "$BRANCH" "$WORK"
  {
    echo "# Lokale Prüfläufe"
    echo
    echo "Eine Zeile je Lauf von \`scripts/pruefen.sh --melden\`. Der Zweck steht"
    echo "in \`scripts/melden.sh\`: Eine Sitzung ohne Zugriff auf den Mac soll"
    echo "sehen können, ob ein Stand dort schon geprüft wurde — statt auf die CI"
    echo "zu warten, deren Ergebnis längst vorliegt."
    echo
    echo "| Wann | Stand | Zweig | Ergebnis | Umfang | Dauer | Wo | Wer | Anmerkung |"
    echo "|---|---|---|---|---|---|---|---|---|"
  } > "$WORK/README.md"
fi

printf '| %s | `%s` | %s | %s | %s | %ss | %s | %s | %s |\n' \
  "$WANN" "${SHA:0:8}" "$ZWEIG" "$ERGEBNIS" "$UMFANG" "$DAUER" "$WO" "$WER" \
  "${NOTIZ:-$SAUBER}" >> "$WORK/README.md"

cd "$WORK"
git add -A
git -c user.name="PulseMeter" -c user.email="noreply@pulsemeter.app" \
    commit -q -m "Prüflauf ${SHA:0:8}: $ERGEBNIS ($UMFANG, $WO)"
# Fehlschlag darf nichts blockieren: Ohne Netz ist ein nicht gemeldeter Lauf
# ärgerlich, ein abgebrochener Push wäre schlimmer.
if [ "${PRUEF_TROCKEN:-0}" = "1" ]; then
  echo "Trockenlauf — es wird nichts geschoben. Die Zeile lautete:"
  tail -1 README.md
  exit 0
fi

git push -q "$REMOTE" "$BRANCH" 2>/dev/null \
  || { echo "Melden fehlgeschlagen (kein Netz?) — der Lauf selbst zählt trotzdem."; exit 0; }

echo "Gemeldet: ${SHA:0:8} $ERGEBNIS ($UMFANG) → Zweig $BRANCH"
