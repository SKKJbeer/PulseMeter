#!/usr/bin/env python3
"""Hält `docs/15-testkonzept.md` ehrlich.

**Warum es das gibt.** Das Testkonzept zeigt auf Tests und Skripte. Wird ein
Test umbenannt oder gelöscht, zeigt es ins Leere und behauptet eine Abdeckung,
die es nicht mehr gibt — schlimmer als gar kein Konzept. Umgekehrt soll eine
neue Prüfung nicht neben dem Konzept entstehen, sondern darin stehen.

Geprüft wird:
  1. Jeder Testname in Backticks (`testIrgendwas`, auch `Klasse.testX`) ist
     als `func testIrgendwas` in einem Test definiert.
  2. Jeder Pfad in Backticks unter scripts/, .github/workflows/, cloudkit/
     oder docs/ existiert.
  3. Jedes Prüfskript `scripts/check-*` steht im Konzept.
  4. Jede Testklasse unter AppUITests/ steht im Konzept.

Aufruf: python3 scripts/check-testkonzept.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
KONZEPT = WURZEL / "docs" / "15-testkonzept.md"
TESTORTE = ["AppUITests", "Packages/PulseCore/Tests", "Packages/PulseData/Tests"]


def definierte_tests() -> set[str]:
    namen: set[str] = set()
    for ort in TESTORTE:
        for datei in (WURZEL / ort).rglob("*.swift"):
            namen.update(re.findall(r"func (test\w+)", datei.read_text(encoding="utf-8")))
    return namen


def main() -> int:
    text = KONZEPT.read_text(encoding="utf-8")
    code = re.findall(r"`([^`\n]+)`", text)
    fehler: list[str] = []

    tests = definierte_tests()
    genannt = {m.group(1) for c in code for m in [re.fullmatch(r"(?:\w+\.)?(test[A-Z]\w*)", c)] if m}
    for name in sorted(genannt - tests):
        fehler.append(f"`{name}` steht im Konzept, aber kein Test heißt so")

    pfade = {c for c in code if re.match(r"(scripts|\.github/workflows|cloudkit|docs)/", c) and "*" not in c}
    for pfad in sorted(pfade):
        if not (WURZEL / pfad.split(" ")[0]).exists():
            fehler.append(f"`{pfad}` steht im Konzept, aber die Datei fehlt")

    for skript in sorted((WURZEL / "scripts").glob("check-*")):
        if f"scripts/{skript.name}" not in pfade:
            fehler.append(f"scripts/{skript.name} prüft etwas, steht aber nicht im Testkonzept")

    for klasse in sorted((WURZEL / "AppUITests").glob("*.swift")):
        if f"`{klasse.stem}`" not in text:
            fehler.append(f"Die Oberflächentests `{klasse.stem}` stehen nicht im Testkonzept")

    for f in fehler:
        print("  FEHL " + f)
    if fehler:
        return 1
    print(f"  ok   {len(genannt)} Tests und {len(pfade)} Dateien im Testkonzept gibt es alle")
    return 0


if __name__ == "__main__":
    sys.exit(main())
