#!/usr/bin/env python3
"""Die Version steht an vier Stellen in Dateien, und alle vier sagen dasselbe.

**Warum es das gibt.** `.claude/skills/release-discipline/SKILL.md` verlangt
es seit 0.69.2, aber nur als Satz. Am 11. November stand die Kopfzeile des
Klick-Dummys auf v0.138.0, während `project.yml` bei 0.144.0 war: sechs
Versionen lang, gesehen hat es ein Review, keine Prüfung. Und die eine Stelle,
die beim Nutzer ankommt, ist `MARKETING_VERSION` — wer sie vergisst, liefert
einen neuen Stand unter der alten Nummer nach TestFlight.

Geprüft wird:
  1. CHANGELOG.md       die oberste Überschrift „## x.y.z — Datum“
  2. project.yml        jedes MARKETING_VERSION (App und Widget)
  3. README.md          „Version **x.y.z**.“
  4. Klick-Dummy        „Klickbarer Entwurf · vx.y.z“

Aufruf: python3 scripts/check-versionen.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
VERSION = r"(\d+\.\d+\.\d+)"

STELLEN = [
    ("CHANGELOG.md", re.compile(r"^## " + VERSION, re.M), "erste"),
    ("project.yml", re.compile(r'MARKETING_VERSION:\s*"?' + VERSION), "alle"),
    ("README.md", re.compile(r"Version \*\*" + VERSION + r"\*\*"), "erste"),
    ("docs/prototype/index.html", re.compile(r"Klickbarer Entwurf · v" + VERSION), "erste"),
]


def main() -> int:
    gefunden: list[tuple[str, str]] = []
    fehler: list[str] = []
    for datei, muster, wie in STELLEN:
        text = (WURZEL / datei).read_text(encoding="utf-8")
        treffer = muster.findall(text)
        if not treffer:
            fehler.append(f"{datei}: keine Version gefunden (Muster {muster.pattern})")
            continue
        for v in (treffer if wie == "alle" else treffer[:1]):
            gefunden.append((datei, v))

    versionen = {v for _, v in gefunden}
    if len(versionen) > 1:
        fuehrend = next(v for d, v in gefunden if d == "CHANGELOG.md") if gefunden else "?"
        for datei, v in gefunden:
            if v != fuehrend:
                fehler.append(f"{datei} sagt {v}, CHANGELOG.md sagt {fuehrend}")

    for f in fehler:
        print("  FEHL " + f)
    if fehler:
        return 1
    print(f"  ok   Version {versionen.pop()} an {len(gefunden)} Stellen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
