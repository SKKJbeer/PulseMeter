#!/usr/bin/env python3
"""Findet Namen, die kein Import und keine Zuweisung kennt.

**Warum das nötig wurde.** Bau 24 lag bereits in TestFlight, als der Schritt
danach abbrach:

    NameError: name 're' is not defined. Did you forget to import 're'?

`scripts/asc-testflight.py` benutzt `re` an sechs Stellen und importierte es
nicht. Kein bestehender Haken konnte das sehen: `ast.parse` prüft die
Grammatik, und die war fehlerfrei. Der Fehler entsteht erst beim Ausführen —
und zwar in genau der Verzweigung, die nur nach einem echten Bau läuft. So
etwas findet man nicht durch Nachdenken, sondern nur, indem man danach sucht.

Gesucht wird mit `pyflakes`: klein, reine Python-Bibliothek, keine
Einrichtung. **Fehlt sie, ist das ein Fehler und kein Überspringen.** Eine
Prüfung, die sich still abschaltet, meldet danach für immer „grün".
"""

import subprocess
import sys

# Nur die Skripte, die im Ernstfall laufen. Was nur beim Entwickeln aufgerufen
# wird, kostet hier Zeit ohne Gegenwert.
ORT = "scripts"


def main() -> int:
    try:
        from pyflakes.api import checkPath          # noqa: F401
    except ImportError:
        print("::error::pyflakes fehlt. Einmalig: pip3 install pyflakes")
        return 1

    lauf = subprocess.run([sys.executable, "-m", "pyflakes", ORT],
                          capture_output=True, text=True)
    zeilen = [z for z in lauf.stdout.splitlines() if z.strip()]

    # **Ein unbenutzter Import ist kein Fehler.** Er kostet nichts und steht
    # oft dort, weil er gleich gebraucht wird. Ein *unbekannter* Name dagegen
    # ist immer einer: Das Programm bricht ab, sobald die Zeile an die Reihe
    # kommt. Nur danach wird hier gesucht — eine Prüfung, die auch über
    # Aufräumarbeiten meckert, wird abgeschaltet.
    schlimm = [z for z in zeilen if "undefined name" in z]

    for zeile in zeilen:
        print(("  ✗ " if zeile in schlimm else "  · ") + zeile)

    if schlimm:
        print(f"\n{len(schlimm)} unbekannte(r) Name(n) — das bricht beim Ausführen ab.")
        return 1

    print(f"Keine unbekannten Namen in {ORT}/ "
          f"({len(zeilen)} Hinweis(e) zu ungenutzten Importen).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
