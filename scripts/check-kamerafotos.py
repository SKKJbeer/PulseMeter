#!/usr/bin/env python3
"""Prüft die Fotosammlung für die Kamera (`docs/kamera/`).

Die Fotos sind fremde Werke. Das Repository ist öffentlich, und eine
Creative-Commons-Lizenz gilt nur mit Namensnennung und Quelle; ein Foto ohne
beides ist ein Urheberrechtsverstoß, den niemand bemerkt, bis jemand schreibt.
Deshalb bricht dieser Lauf ab, wenn bei einem Foto etwas fehlt, und auch, wenn
ein Foto im Ordner liegt, das niemand in `fotos.json` eingetragen hat.
"""
import json
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent / "docs" / "kamera"
ERLAUBT = re.compile(r"^(CC0|Public domain|CC BY [234]\.\d|CC BY-SA [234]\.\d)$")
MAX_BYTES = 400_000


def main() -> int:
    fehler: list[str] = []
    # Zwei Sammlungen: die ersten 15 Fotos und die zweite, die nie zum Training diente (LCD).
    fotos = []
    eingetragen = set()
    vorhanden = set()
    for datei, ordner in (("fotos.json", "fotos"), ("fotos-lcd.json", "fotos-lcd")):
        sammlung = json.loads((WURZEL / datei).read_text(encoding="utf-8"))["fotos"]
        fotos += sammlung
        eingetragen |= {f["datei"] for f in sammlung}
        vorhanden |= {f"{ordner}/{p.name}" for p in (WURZEL / ordner).glob("*") if p.is_file()}
        for fehlt in sorted({f["datei"] for f in sammlung} - {f"{ordner}/{p.name}" for p in (WURZEL / ordner).glob("*")}):
            fehler.append(f"{fehlt}: in {datei}, aber nicht im Ordner")
    readme = (WURZEL / "README.md").read_text(encoding="utf-8")
    for fremd in sorted(vorhanden - eingetragen):
        fehler.append(f"{fremd}: im Ordner, aber in keiner Sammlung eingetragen (Urheber und Lizenz fehlen)")

    for f in fotos:
        name = f["datei"]
        if not ERLAUBT.match(f.get("lizenz", "")):
            fehler.append(f"{name}: Lizenz „{f.get('lizenz')}“ ist keine freie")
        if not f.get("urheber"):
            fehler.append(f"{name}: kein Urheber")
        if not f.get("quelle", "").startswith("https://commons.wikimedia.org/"):
            fehler.append(f"{name}: keine Quelle auf Wikimedia Commons")
        if name not in readme:
            fehler.append(f"{name}: steht nicht in README.md (Namensnennung)")
        if (WURZEL / name).exists() and (WURZEL / name).stat().st_size > MAX_BYTES:
            fehler.append(f"{name}: über {MAX_BYTES // 1000} KB — das Repository wächst mit jedem Foto")
        if f.get("stand") is not None:
            try:
                Decimal(f["stand"])
            except InvalidOperation:
                fehler.append(f"{name}: Stand „{f['stand']}“ ist keine Zahl")
        a = f.get("ausschnitt")
        if a is not None and not (len(a) == 4 and all(isinstance(x, (int, float)) and 0 <= x <= 1 for x in a)
                                  and a[0] < a[2] and a[1] < a[3]):
            fehler.append(f"{name}: ausschnitt muss [links, oben, rechts, unten] als Bruchteile sein")
        if a is not None and f.get("stand") is None:
            fehler.append(f"{name}: ein Rahmen nur bei Fotos mit ablesbarem Stand")
        for feld in ("vorkommastellen", "nachkommastellen"):
            if not isinstance(f.get(feld), int):
                fehler.append(f"{name}: {feld} fehlt")

    if fehler:
        print("Kamerafotos:")
        for z in fehler:
            print("  ✗", z)
        return 1
    ohne = sum(1 for f in fotos if f["stand"] is None)
    print(f"Kamerafotos: {len(fotos)} Fotos, alle mit Urheber, Quelle und freier Lizenz "
          f"({ohne} ohne ablesbaren Stand).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
