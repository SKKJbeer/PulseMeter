#!/usr/bin/env python3
"""Findet Namen, die eine Änderung entfernt hat und die trotzdem noch benutzt werden.

**Warum es das gibt.** In 0.112.3 hat eine Umarbeitung die Variable `zweiter`
gelöscht und eine Verwendung vierzig Zeilen weiter unten stehen lassen. Der
Bau ist daran gescheitert — nach neunzig Sekunden auf einem gemieteten Mac,
weil vorher noch das Xcode-Projekt entsteht und die Pakete übersetzt werden.

Gefunden hat es keine der Prüfungen, die ohne Xcode laufen, und das ist kein
Versehen: `swiftc -parse` liest die **Form** und löst keine Namen auf. Eine
gelöschte Variable ist syntaktisch einwandfrei; erst der Typprüfer merkt, dass
sie fehlt. Den gibt es unter Linux für iOS-Quellen nicht.

Diese Prüfung ist deshalb absichtlich klein und arbeitet am **Unterschied**,
nicht an der Datei: Sie nimmt die Namen, die der Vergleich mit dem letzten
Commit entfernt hat, und sieht nach, ob sie im neuen Stand noch vorkommen,
ohne dort noch erklärt zu sein. Das ist genau der Fall von oben und erzeugt
keine Fehlalarme bei Namen, die anderswo weiterleben.

Ohne git-Vergleich (etwa in einem frischen Klon ohne Historie) tut sie nichts
und sagt das auch — eine Prüfung, die stillschweigend nichts prüft, ist
schlimmer als keine.
"""
import re
import subprocess
import sys

# `let x`, `var x`, `guard let x`, `if let x` — der Name direkt dahinter.
DEKLARATION = re.compile(r"\b(?:let|var)\s+([a-z_][A-Za-z0-9_]*)\b")


def lauf(*befehl: str) -> str:
    fertig = subprocess.run(befehl, capture_output=True, text=True)
    return fertig.stdout if fertig.returncode == 0 else ""


def namen(text: str) -> set[str]:
    return set(DEKLARATION.findall(text))


def entkleiden(text: str) -> str:
    """Nimmt Kommentare und Fließtext heraus, lässt Code und Zeilen stehen.

    **Ohne das war die Prüfung sofort wertlos.** Der erste Lauf meldete
    „zweiter" — und traf viermal das Wort in einem Kommentar („zweiter
    Versuch"). Eine Prüfung, die bei jedem deutschen Nebensatz anschlägt, wird
    nach drei Tagen abgeschaltet, und dann fängt sie auch den echten Fall nicht
    mehr.

    Was in einer Zeichenkette in `\\(…)` steht, bleibt: Das ist eine echte
    Verwendung. Alles andere darin ist Prosa für den Nutzer.

    Zeilenumbrüche bleiben erhalten, damit die Fundstelle die Zeile nennt, die
    auch im Editor steht.
    """
    aus: list[str] = []
    i, n = 0, len(text)
    tiefe = 0  # Schachtelung von /* */
    while i < n:
        z = text[i]
        if tiefe:
            if text.startswith("*/", i):
                tiefe -= 1; aus.append("  "); i += 2; continue
            if text.startswith("/*", i):
                tiefe += 1; aus.append("  "); i += 2; continue
            aus.append("\n" if z == "\n" else " "); i += 1; continue
        if text.startswith("/*", i):
            tiefe = 1; aus.append("  "); i += 2; continue
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                aus.append(" "); i += 1
            continue
        if z == '"':
            # Dreifache Anführungszeichen kommen in diesem Projekt nicht vor;
            # käme eines dazu, fiele es hier als unbeendete Zeichenkette auf.
            aus.append(" "); i += 1
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n and text[i + 1] == "(":
                    # Interpolation: Inhalt behalten, bis die Klammer zugeht.
                    aus.append("  "); i += 2
                    klammern = 1
                    while i < n and klammern:
                        if text[i] == "(": klammern += 1
                        elif text[i] == ")": klammern -= 1
                        aus.append(text[i] if klammern else " ")
                        i += 1
                    continue
                if text[i] == "\\" and i + 1 < n:
                    aus.append("  "); i += 2; continue
                aus.append("\n" if text[i] == "\n" else " "); i += 1
            if i < n: aus.append(" "); i += 1
            continue
        aus.append(z); i += 1
    return "".join(aus)


def verwendet(text: str, name: str) -> bool:
    """Kommt der Name irgendwo als eigenständiges Wort vor?

    Ein Zugriff auf ein Feld (`.name`) zählt nicht: Das ist ein anderer Name,
    der zufällig gleich heißt. Ohne diese Einschränkung schlägt die Prüfung
    bei jedem `row.value` an, dessen lokale Fassung gerade weggefallen ist.
    """
    return re.search(rf"(?<![.\w]){re.escape(name)}\b", text) is not None


def main() -> int:
    # Vergleichsstand wählbar, damit sich die Prüfung selbst prüfen lässt —
    # und damit ein Haken vor dem Push gegen den Zweigpunkt vergleichen kann
    # statt nur gegen den letzten Commit.
    basis = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    geaendert = lauf("git", "diff", "--name-only", basis, "--", "*.swift").split()
    if not geaendert:
        print("Keine geänderten Swift-Dateien — nichts zu prüfen.")
        return 0

    treffer: list[str] = []
    for datei in geaendert:
        vorher = lauf("git", "show", f"{basis}:{datei}")
        if not vorher:
            continue  # Neue Datei: Es kann nichts weggefallen sein.
        try:
            nachher = open(datei, encoding="utf-8").read()
        except OSError:
            continue  # Gelöscht — dann ist auch nichts mehr zu benutzen.

        # Beide Seiten ohne Kommentare und ohne Fließtext: Erklärt und
        # benutzt wird im Code, nicht in der Begründung daneben.
        vorher, nachher = entkleiden(vorher), entkleiden(nachher)
        for name in namen(vorher) - namen(nachher):
            if verwendet(nachher, name):
                zeilen = [i for i, z in enumerate(nachher.splitlines(), 1)
                          if verwendet(z, name)]
                stellen = ", ".join(f"Zeile {z}" for z in zeilen[:5])
                treffer.append(f"{datei}: „{name}“ wird nicht mehr erklärt, "
                               f"steht aber noch da ({stellen})")

    if treffer:
        print("Verwaiste Namen — der Bau würde daran scheitern:")
        for zeile in treffer:
            print(f"  · {zeile}")
        return 1

    print(f"Keine verwaisten Namen in {len(geaendert)} geänderten Swift-Datei(en).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
