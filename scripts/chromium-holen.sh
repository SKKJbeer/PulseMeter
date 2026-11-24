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
# **Als ES-Modul aus diesem Ordner, nicht als `require`.** `require.resolve`
# fand am 11. Oktober ein global installiertes Playwright und meldete „liegt
# schon da", während `import "playwright"` in den Prüfskripten scheiterte: Ein
# ES-Modul sucht nur im `node_modules` des Projekts.
if node --input-type=module -e "await import('playwright')" 2>/dev/null; then
  echo "Playwright liegt schon da."
else
  npm install --no-save "playwright@${VERSION}"
fi

# Welche Browser: ohne Angabe Chromium, `scripts/chromium-holen.sh chromium webkit`
# holt beide in einem Gang (CI, Website in WebKit).
# (`set --` statt leerem Feld: Die Bash 3.2 eines Macs bricht mit `set -u` an
# einem leeren Feld ab.)
if [ $# -eq 0 ]; then set -- chromium; fi
BROWSER=("$@")

# Der Browser selbst — es sei denn, er liegt schon da. In der Cloud-Sitzung
# zeigt `PULSE_CHROMIUM` auf ein vorbereitetes Chromium, und der Nachladeversuch
# wäre dort ohnehin geblockt.
if [ -n "${PULSE_CHROMIUM:-}" ]; then
  echo "Chromium steht unter $PULSE_CHROMIUM — nichts zu holen."
  exit 0
fi

# **Systempakete getrennt vom Browser, und mit Warten auf die Paketsperre, seit
# 0.180.1.** Vorher stand hier `timeout 180 npx playwright install --with-deps`
# in zwei Anläufen. Am 24. November (Lauf 45323965381) kam der Spiegel nach drei
# Minuten nicht durch; `timeout` beendete `npx`, aber nicht das `apt-get`, das
# Playwright mit `sudo` gestartet hatte. Das lief weiter und hielt die Sperre
# `/var/lib/dpkg/lock-frontend`. Der zweite Anlauf und danach der WebKit-Schritt
# scheiterten sofort an „Could not get lock", der Lauf wurde rot, und an der
# Prüfung selbst war nichts falsch.
#
# Jetzt wartet apt bis zu zehn Minuten auf die Sperre, statt aufzugeben, und
# ein zweiter Anlauf trifft ein noch laufendes apt nicht mehr ins Leere. Nur auf
# einem Linux-Läufer mit `sudo` ohne Passwort; lokal ändert das Skript nichts am
# System.
if [ "$(uname)" = "Linux" ] && [ -n "${CI:-}" ] && sudo -n true 2>/dev/null; then
  echo 'DPkg::Lock::Timeout "600";' | sudo tee /etc/apt/apt.conf.d/90-pulse-sperre >/dev/null
  pakete_da=""
  for versuch in 1 2 3; do
    if timeout 480 npx playwright install-deps "${BROWSER[@]}"; then pakete_da=1; break; fi
    echo "::warning::Systempakete für ${BROWSER[*]}, Anlauf $versuch ohne Erfolg."
    sleep 15
  done
  # Das Ubuntu-Bild von GitHub hat fast alles schon. Fehlt trotzdem etwas,
  # sagt es die Prüfung selbst beim Start des Browsers — deutlicher als apt.
  [ -n "$pakete_da" ] || echo "::warning::Systempakete nicht vollständig; weiter mit dem, was da ist."
fi

for versuch in 1 2 3; do
  if timeout 300 npx playwright install "${BROWSER[@]}"; then exit 0; fi
  echo "::warning::Browser ${BROWSER[*]} holen, Anlauf $versuch ohne Erfolg."
  sleep 15
done
echo "::error::Browser ${BROWSER[*]} ließen sich nicht holen."
exit 1
