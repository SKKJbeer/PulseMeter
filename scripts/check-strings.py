#!/usr/bin/env python3
"""Findet deutsche Anführungszeichen, die eine Swift-Zeichenkette zerreißen.

Der Anlass: In `Text("… „Strom", …")` schließt das gerade Anführungszeichen
nach `„Strom` die Swift-Zeichenkette. Richtig wäre das typografische `“`.
Unter Linux gibt es keinen Swift-Compiler für iOS-Code, also fällt so etwas
erst auf einem gemieteten macOS-Läufer auf — fünfzehn Minuten und ein ganzer
Lauf für ein einzelnes Zeichen. Diese Prüfung kostet eine Sekunde.

Geprüft werden zwei Dinge:

1. Ein `„` innerhalb einer Zeichenkette muss mit `“` geschlossen werden. Endet
   die Zeichenkette vorher, ist das Literal an der falschen Stelle zu Ende.
   Genau dieser Fall ist passiert, und er ist die eigentliche Prüfung.

2. Eine Zeichenkette, die auf ihrer Zeile nicht endet. Das ist nur ein
   zusätzliches Netz — es fängt den Fall aus 1. nicht zuverlässig, weil sich
   die Zeichen zufällig zu einer geraden Zahl ergänzen können.
"""
import pathlib
import sys

GERMAN_OPEN = "„"
GERMAN_CLOSE = "“"

problems: list[str] = []


def check(line: str) -> str | None:
    """Gibt die Beanstandung zurück, oder `None`, wenn die Zeile in Ordnung ist."""
    in_string = False
    german_open = False
    index = 0

    while index < len(line):
        char = line[index]

        if char == "\\":
            index += 2
            continue

        if char == '"':
            if in_string and german_open:
                return "„ wird von einem geraden Anführungszeichen geschlossen — „…“ verwenden"
            in_string = not in_string
            german_open = False
        elif not in_string and char == "/" and index + 1 < len(line) and line[index + 1] == "/":
            return None  # Kommentar außerhalb einer Zeichenkette
        elif in_string and char == GERMAN_OPEN:
            german_open = True
        elif in_string and char == GERMAN_CLOSE:
            german_open = False

        index += 1

    return "Zeichenkette endet nicht auf ihrer Zeile" if in_string else None


for path in sorted(pathlib.Path(".").rglob("*.swift")):
    if ".build" in path.parts or "DerivedData" in path.parts:
        continue

    in_multiline = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.count('"""') % 2 == 1:
            in_multiline = not in_multiline
            continue
        if in_multiline:
            continue

        if problem := check(line):
            problems.append(f"{path}:{number}: {problem}\n    {line.strip()}")

if problems:
    print("\n".join(problems))
    print(f"\n{len(problems)} Fund(e).")
    sys.exit(1)

print("Zeichenketten in Swift-Quellen sind in Ordnung.")
