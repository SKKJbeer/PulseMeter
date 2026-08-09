#!/usr/bin/env bash
# Richtet die Arbeitsumgebung auf einem Mac ein und erzeugt das Xcode-Projekt.
# Mehrfach ausführbar — jeder Schritt prüft erst, ob er nötig ist.
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf "\n\033[1m%s\033[0m\n" "$1"; }
fail() { printf "\n\033[31m%s\033[0m\n" "$1"; exit 1; }

say "1/6  Xcode prüfen"
command -v xcodebuild >/dev/null || fail "xcodebuild fehlt. Xcode aus dem App Store installieren, einmal öffnen und die Lizenz bestätigen."
if ! xcode-select -p | grep -q "Xcode.app"; then
  fail "Die Kommandozeile zeigt auf die Developer Tools statt auf Xcode.
Behebung:  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi
xcodebuild -version | head -1

say "2/6  Swift prüfen"
swift --version 2>&1 | head -1

say "3/6  XcodeGen bereitstellen"
if ! command -v xcodegen >/dev/null; then
  command -v brew >/dev/null || fail "Weder xcodegen noch Homebrew gefunden.
Homebrew installieren:  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo "XcodeGen wird installiert…"
  brew install xcodegen
fi
xcodegen --version

say "4/6  Xcode-Projekt erzeugen"
xcodegen generate
echo "PulseMeter.xcodeproj erzeugt (nicht im Repository — aus project.yml jederzeit neu erzeugbar)."

say "5/6  Haken vor dem Push"
# Der Haken liegt im Repository, nicht in .git/hooks — dadurch ist er
# eingecheckt und gilt für jede Arbeitskopie. `core.hooksPath` ist eine
# lokale Einstellung und wird deshalb hier gesetzt.
git config core.hooksPath .githooks
echo "Vor jedem Push laufen die schnellen Prüfungen (überspringen: git push --no-verify)."

say "6/6  Tests der Pakete"
( cd Packages/PulseCore && swift test )
( cd Packages/PulseData && swift build )

say "Fertig."
cat <<'EOF'
Weiter mit:
  scripts/pruefen.sh          alles, was auch die CI prüft — nur schneller
  scripts/pruefen.sh schnell  ohne App-Build, für zwischendurch
  scripts/test.sh          Pakete und App-Tests im Simulator
  scripts/run.sh           App im Simulator starten, Screenshot ablegen
  open PulseMeter.xcodeproj   falls du selbst hineinsehen willst
EOF
