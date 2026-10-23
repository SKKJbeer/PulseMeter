#!/usr/bin/env bash
# Die Tests von PulseCore, in zwei Läufen.
#
# **Warum zwei.** Das Ziffernnetz der Kamera rechnet 90 Millionen Multiplikationen je Bild, und die Tests
# lassen es an etwa 50 Bildern laufen. Im Debug-Bau (dem Vorgabewert von `swift test`) braucht das auf dem
# Mac-Läufer von GitHub Minuten: Der Lauf zu `41e318a` brauchte für PulseCore 38 statt 4 Minuten und
# riss das Zeitlimit von 60 Minuten des iPhone-Auftrags. Im Release-Bau sind es zehn Sekunden.
# Alles andere bleibt im Debug-Bau, wo die Prüfungen auf Überläufe und Grenzen scharf sind.
#
# `-Xswiftc -enable-testing` braucht der Release-Bau, damit `@testable import` geht.
#
# Aufruf aus dem Hauptverzeichnis: scripts/test-core.sh
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v swift >/dev/null 2>&1 && [ -x /opt/swift/usr/bin/swift ]; then
  PATH="/opt/swift/usr/bin:$PATH"; export PATH
fi
swift test --package-path Packages/PulseCore --skip DigitNetTests
swift test --package-path Packages/PulseCore -c release -Xswiftc -enable-testing --filter DigitNetTests
