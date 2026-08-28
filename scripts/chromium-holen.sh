#!/usr/bin/env bash
# Holt Playwright und Chromium — an **einer** Stelle, mit **einer** Version.
#
# **Warum das ein Skript ist.** Die Version stand an drei Orten: in `ci.yml`,
# in `pruefen.sh` und im Ablauf für die Website. Zwei sagten 1.62.1, einer
# 1.47.0 — und der dritte installierte obendrein nur den Browser und nicht das
# Paket. Der Lauf fiel mit `Cannot find package 'playwright'`, und das sah nach
# einem Fehler in der Prüfung aus, war aber ein Fehler im Aufruf.
#
# Dieselbe Fehlerklasse wie beim Auslieferordner, zwei Stunden vorher: zwei
# Wege, die dasselbe tun sollen, tun es nicht. Der Ausweg ist immer derselbe —
# ein Ort, an dem es steht.
#
# `--no-save`: Das Paket gehört nicht in die Abhängigkeiten des Projekts. Es
# ist Werkzeug der Prüfung, nicht Bestandteil dessen, was ausgeliefert wird.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="1.62.1"

# Auf einem Rechner, der es schon hat, kostet das zwei Sekunden statt zwanzig.
if node -e "require.resolve('playwright')" 2>/dev/null; then
  echo "Playwright liegt schon da."
else
  npm install --no-save "playwright@${VERSION}"
fi

# Der Browser selbst — es sei denn, er liegt schon da. In der Cloud-Sitzung
# zeigt `PULSE_CHROMIUM` auf ein vorbereitetes Chromium, und der Nachladeversuch
# wäre dort ohnehin geblockt.
if [ -n "${PULSE_CHROMIUM:-}" ]; then
  echo "Chromium steht unter $PULSE_CHROMIUM — nichts zu holen."
else
  npx playwright install --with-deps chromium
fi
