#!/usr/bin/env bash
# Zum Doppelklicken im Finder: die App aufs eigene iPhone bringen.
#
# Dasselbe Muster wie `Am-Mac-starten.command` und aus demselben Grund:
# `.command` ist die einzige Endung, die der Finder von sich aus im Terminal
# öffnet. Wer bis hierher gekommen ist, soll nichts mehr abtippen müssen.
#
# Der aktuelle Stand wird vorher geholt. Ohne das installiert dieser
# Doppelklick irgendwann eine Fassung, die zwei Wochen alt ist — und niemand
# sieht es der App an.
cd "$(dirname "$0")" || exit 1

printf "\033[1mPulseMeter aufs iPhone\033[0m\n\n"

if [ -t 0 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  git fetch origin main --quiet 2>/dev/null || true
  # Nur vorspulen. Liegt hier eigene, nicht gesicherte Arbeit, bleibt sie
  # unangetastet — ein Doppelklick darf nichts wegwerfen.
  git merge --ff-only origin/main --quiet 2>/dev/null \
    || printf "\033[2mStand nicht geholt — hier liegt eigene Arbeit. Es wird gebaut, was da ist.\033[0m\n\n"
fi

./scripts/aufs-handy.sh "$@"
ERGEBNIS=$?

printf "\n"
if [ "$ERGEBNIS" = "0" ]; then
  printf "\033[2mFertig. Dieses Fenster darf zu.\033[0m\n"
else
  printf "\033[2mMit Fehler beendet (%s). Die Meldung steht oben und nennt den nächsten Schritt.\033[0m\n" "$ERGEBNIS"
fi
printf "\033[2mTaste drücken zum Schließen …\033[0m"
read -r -n 1 -s
printf "\n"
exit "$ERGEBNIS"
