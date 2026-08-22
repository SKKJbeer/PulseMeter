#!/usr/bin/env python3
"""Findet Knöpfe, die größer aussehen als sie sind.

Der Anlass steht in CHANGELOG 0.72.2: Auf dem Gerät des Gründers ging ein
Zähler „erst beim 3. Mal tippen" auf. Der Knopf war die ganze Zeile breit, aber
`.buttonStyle(.plain)` reicht nur so weit wie das, was der Knopf zeichnet. Der
Abstand zwischen Name und Pfeil zeichnet nichts — und das sind bei „Strom" zwei
Drittel der Zeile, die auf keinen Tipp reagieren.

Sichtbar ist der Fehler nicht: Der Knopf sieht richtig aus, VoiceOver liest ihn
richtig vor, und die Trefferflächenmessung in `check-nichtfunktional.mjs` misst
den Klick-Dummy, nicht die App. Bemerkt hat es ein Mensch mit einem Daumen.

Die Regel, die daraus folgt:

> Ein Knopf mit `.buttonStyle(.plain)`, dessen Inhalt mehr Fläche beansprucht
> als er füllt — ein `Spacer`, ein `frame(maxWidth: .infinity)` —, braucht
> entweder eine eigene Fläche (`.background`) oder `.contentShape(Rectangle())`.

Beides zugleich schadet nicht. Keins von beidem heißt: Der Nutzer tippt ins
Leere und hält die App für langsam.
"""
import pathlib
import re
import sys

ORTE = ["App", "Packages/PulseUI/Sources", "Widget"]

# Der Inhalt beansprucht Fläche, die er nicht zeichnet.
DEHNT_SICH = (re.compile(r"\bSpacer\b"),
              re.compile(r"frame\(\s*maxWidth:\s*\.infinity"))
# Womit die Fläche antippbar wird.
TRAEGT = (re.compile(r"\.contentShape\("), re.compile(r"\.background\("))

BEGINNT = re.compile(r"\bButton\s*[({]")

problems: list[str] = []


def aeussere_kette(block: list[str]) -> str:
    """Nur die Modifikatoren am Inhalt selbst, nicht die an seinen Teilen.

    Diese Unterscheidung ist der ganze Punkt. Die gemeldete Zeile hatte ein
    `.background` — am 30 Punkt großen Symbol links, nicht an der Zeile. Wer
    danach irgendwo im Knopf sucht, hält genau den Fall für geheilt, der den
    Fehlerbericht ausgelöst hat.

    Zwei Ebenen tief, weil beide Schreibweisen im Haus vorkommen: Modifikatoren
    am Inhalt selbst und Modifikatoren, die unter einem mehrzeiligen Aufruf
    noch einmal eingerückt sind. Tiefer liegt nichts Äußeres mehr — das Symbol
    aus dem Anlassfall sitzt drei Ebenen tief.
    """
    tiefe = len(block[0]) - len(block[0].lstrip())
    return "\n".join(z for z in block[1:]
                     if z.strip() and len(z) - len(z.lstrip()) <= tiefe + 8)


def label_block(lines: list[str], ende: int) -> list[str] | None:
    """Die Zeilen des Knopfes, von `Button` bis vor `.buttonStyle(.plain)`.

    Gesucht wird rückwärts nach der ersten `Button`-Zeile, die höchstens so
    weit eingerückt ist wie der Stil darunter — bei tieferer Einrückung wäre es
    ein anderer, innen liegender Knopf.
    """
    tiefe = len(lines[ende]) - len(lines[ende].lstrip())
    for start in range(ende - 1, max(-1, ende - 80), -1):
        zeile = lines[start]
        if not BEGINNT.search(zeile):
            continue
        if len(zeile) - len(zeile.lstrip()) <= tiefe:
            return lines[start:ende]
    return None


for ort in ORTE:
    wurzel = pathlib.Path(ort)
    if not wurzel.exists():
        continue
    for path in sorted(wurzel.rglob("*.swift")):
        lines = path.read_text(encoding="utf-8").split("\n")
        for index, line in enumerate(lines):
            if ".buttonStyle(.plain)" not in line:
                continue
            block = label_block(lines, index)
            if block is None:
                continue
            if not any(muster.search("\n".join(block)) for muster in DEHNT_SICH):
                continue
            aussen = aeussere_kette(block)
            if any(muster.search(aussen) for muster in TRAEGT):
                continue
            problems.append(
                f"{path}:{index - len(block) + 1}: Knopf spannt sich über die "
                "Zeile, ist aber nur dort antippbar, wo er zeichnet — "
                ".contentShape(Rectangle()) fehlt"
            )

if problems:
    print("\n".join(problems))
    print(f"\n{len(problems)} Knopf/Knöpfe reagieren nicht auf ihrer ganzen Fläche.")
    sys.exit(1)

print("Alle Knöpfe sind auf ihrer ganzen Fläche antippbar.")
