#!/usr/bin/env bash
# Zum Doppelklicken im Finder.
#
# Der Umweg über eine eigene Datei hat einen Grund: `.command` ist die einzige
# Endung, die der Finder von sich aus im Terminal öffnet. Ein Skript in
# `scripts/` tut das nicht — es müsste abgetippt werden, und genau das soll
# hier niemand müssen.
#
# Das Fenster bleibt am Ende offen. Ohne das schließt der Finder es sofort,
# und das Ergebnis ist weg, bevor es jemand gelesen hat.
cd "$(dirname "$0")" || exit 1
./scripts/mac-start.sh "$@"
ERGEBNIS=$?

printf "\n"
if [ "$ERGEBNIS" = "0" ]; then
  printf "\033[2mFertig. Dieses Fenster darf zu.\033[0m\n"
else
  printf "\033[2mMit Fehler beendet (%s). Die Meldung steht oben.\033[0m\n" "$ERGEBNIS"
fi
printf "\033[2mTaste drücken zum Schließen …\033[0m"
read -r -n 1 -s
printf "\n"
exit "$ERGEBNIS"
