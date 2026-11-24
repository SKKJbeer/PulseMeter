#!/usr/bin/env python3
"""Hält App, Laden und Website bei derselben Geschichte.

Vom Gründer am 23. November: „stelle sicher dass das auch synchronisiert
läuft die updates und änderungen app, app notes updates und webseite“.

**Wo was steht.** Zu jeder Fassung gibt es genau zwei Quellen:

  docs/fassungen/<fassung>.json   `app`   die Kurzform in der App (ab 1.9)
                                  `weg`   der Eintrag auf entwicklung.html
                                  `start` der Eintrag auf der Startseite
                                  `plan`  welche Zeilen aus „Als Nächstes“,
                                          „Danach“ oder „Später“ sie erfüllt
  docs/09-appstore.md             „Für <fassung>:“  die Versionshinweise im Laden

Die App bringt `docs/fassungen/` als Ordner mit (`project.yml`), die Website
bekommt ihre Einträge daraus über `scripts/website-fassung.py`, und
`asc-einreichung.py` trägt den Block aus 09-appstore.md ein. Abgeschrieben
wird nichts — außer im Klick-Dummy, der ohne Netz laufen muss; dort wird die
Abschrift hier verglichen.

Geprüft wird:
  1. Jede Datei ist lesbar; ab 1.9 hat jede einen Block `app` mit Überschrift
     und ein bis drei Punkten, kurz genug für ein halbes Blatt, und dieselbe
     Überschrift wie der Eintrag auf der Website.
  2. Ab 1.5 gibt es zu jeder Fassung beides: Datei und Versionshinweise. Die
     neueste ist auf beiden Seiten dieselbe.
  3. Die Versionshinweise sind nicht leer, passen in Apples Feld und enthalten
     keine Zeichen, die Apple ablehnt.
  4. Keine Floskel und kein verbotenes Fachwort in der Kurzform der App.
  5. Was eine Fassung erfüllt (`plan`), steht nicht mehr unter „Als Nächstes“,
     „Danach“ oder „Später“, sobald die Fassung auf der Website steht.
  6. Der Klick-Dummy zeigt dieselbe Kurzform wie die neueste Datei.

Aufruf: python3 scripts/check-neuigkeiten.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
FASSUNGEN = WURZEL / "docs" / "fassungen"
STORE = WURZEL / "docs" / "09-appstore.md"
WEG = WURZEL / "docs" / "website" / "entwicklung.html"
ENTWURF = WURZEL / "docs" / "prototype" / "index.html"
FLOSKELN = WURZEL / "scripts" / "floskeln.txt"

AB_APP = (1, 9)        # seit dieser Fassung zeigt die App, was neu ist
AB_DATEI = (1, 5)      # seit dieser Fassung gibt es docs/fassungen/
MAX_TITEL = 48
MAX_PUNKT = 170
MAX_PUNKTE = 3         # wie ReleaseNotes.maxPoints in PulseCore
MAX_STORE = 4000
# Apple lehnt sie in „Neue Funktionen“ und den Testhinweisen ab (Bau 37).
APPLE_NEIN = "×›─✓"
# CLAUDE.md, „Sprache“: Wörter, die in der Oberfläche nichts verloren haben.
FACHWORT = ["messstelle", "zählwerk", "register", "obis", "entität", "datensatz",
            "synchronisation"]


def nummer(fassung: str) -> tuple:
    return tuple(int(t) for t in fassung.split("."))


def floskeln() -> list[str]:
    return [z.strip() for z in FLOSKELN.read_text(encoding="utf-8").splitlines()
            if z.strip() and not z.startswith("#")]


def store_bloecke() -> dict[str, str]:
    text = STORE.read_text(encoding="utf-8")
    kopf = re.search(r"^### Neue Funktionen \(Versionshinweise\)\s*$", text, re.M)
    if not kopf:
        return {}
    rest = text[kopf.end():]
    ende = re.search(r"^## ", rest, re.M)
    rest = rest[:ende.start()] if ende else rest
    bloecke = {}
    for m in re.finditer(r"^Für ([\d.]+):\s*\n+```\n(.*?)```", rest, re.M | re.S):
        bloecke[m.group(1)] = m.group(2).strip()
    return bloecke


def plan_auf_seite(html: str) -> list[str]:
    return re.findall(r'data-plan="([a-z0-9-]+)"', html)


def im_laden_auf_seite(html: str) -> list[str]:
    return re.findall(r'class="stand stand-laden">Fassung ([\d.]+)<', html)


def entwurf_neuigkeiten(html: str) -> dict | None:
    m = re.search(r"const NEUIGKEITEN = (\{.*?\});\s*$", html, re.M | re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except ValueError:
        return None


def pruefen() -> list[str]:
    fehler: list[str] = []
    dateien = {p.stem: p for p in FASSUNGEN.glob("*.json")}
    daten: dict[str, dict] = {}
    for fassung, pfad in sorted(dateien.items(), key=lambda kv: nummer(kv[0])):
        try:
            d = json.loads(pfad.read_text(encoding="utf-8"))
        except ValueError as e:
            fehler.append(f"docs/fassungen/{fassung}.json ist kein JSON: {e}")
            continue
        daten[fassung] = d
        if d.get("fassung") != fassung:
            fehler.append(f"docs/fassungen/{fassung}.json: „fassung“ ist {d.get('fassung')!r}")
        app = d.get("app")
        if nummer(fassung) >= AB_APP and app is None:
            fehler.append(f"docs/fassungen/{fassung}.json: Block „app“ fehlt. Ohne ihn zeigt die "
                          "App nach dem Update nichts, oder die Neuigkeiten der vorigen Fassung.")
        if app is not None:
            titel = str(app.get("titel", "")).strip()
            punkte = [str(p).strip() for p in app.get("punkte", []) if str(p).strip()]
            if not titel:
                fehler.append(f"{fassung}: app.titel fehlt")
            elif len(titel) > MAX_TITEL:
                fehler.append(f"{fassung}: app.titel hat {len(titel)} Zeichen, höchstens {MAX_TITEL}")
            if not 1 <= len(punkte) <= MAX_PUNKTE:
                fehler.append(f"{fassung}: app.punkte hat {len(punkte)} Einträge, erlaubt 1 bis {MAX_PUNKTE}")
            for p in punkte:
                if len(p) > MAX_PUNKT:
                    fehler.append(f"{fassung}: ein Punkt hat {len(p)} Zeichen, höchstens {MAX_PUNKT}: „{p[:40]}…“")
            weg_titel = (d.get("weg") or {}).get("titel", "")
            if titel and titel != weg_titel:
                fehler.append(f"{fassung}: Überschrift in der App („{titel}“) und auf der Website "
                              f"(„{weg_titel}“) weichen voneinander ab")
            klein = " ".join([titel] + punkte).lower()
            for wort in FACHWORT + floskeln():
                if re.search(r"\b" + re.escape(wort), klein):
                    fehler.append(f"{fassung}: „{wort}“ in der Kurzform der App")
        plan = d.get("plan", [])
        if not isinstance(plan, list) or not all(isinstance(p, str) for p in plan):
            fehler.append(f"{fassung}: „plan“ muss eine Liste von Kennungen sein")

    store = store_bloecke()
    if not store:
        fehler.append("docs/09-appstore.md: keine Versionshinweise gefunden")
    for fassung, text in store.items():
        if not text:
            fehler.append(f"Versionshinweise für {fassung} sind leer")
        if len(text) > MAX_STORE:
            fehler.append(f"Versionshinweise für {fassung}: {len(text)} Zeichen, Apple nimmt {MAX_STORE}")
        for z in APPLE_NEIN:
            if z in text:
                fehler.append(f"Versionshinweise für {fassung} enthalten „{z}“, das Apple ablehnt")

    ab = lambda menge: {f for f in menge if nummer(f) >= AB_DATEI}
    for f in sorted(ab(store) - set(daten), key=nummer):
        fehler.append(f"Für {f} gibt es Versionshinweise, aber keine docs/fassungen/{f}.json "
                      "(App und Website wüssten nichts davon)")
    for f in sorted(ab(daten) - set(store), key=nummer):
        fehler.append(f"docs/fassungen/{f}.json gibt es, aber keine Versionshinweise "
                      f"„Für {f}:“ in docs/09-appstore.md")
    if daten and store:
        a, b = max(daten, key=nummer), max(store, key=nummer)
        if a != b:
            fehler.append(f"Neueste Fassung: {a} in docs/fassungen, {b} in docs/09-appstore.md")

    weg = WEG.read_text(encoding="utf-8")
    offen = plan_auf_seite(weg)
    for kennung in sorted({k for k in offen if offen.count(k) > 1}):
        fehler.append(f"entwicklung.html: data-plan=\"{kennung}\" steht mehrfach da")
    for fassung in im_laden_auf_seite(weg):
        for kennung in daten.get(fassung, {}).get("plan", []):
            if kennung in offen:
                fehler.append(f"entwicklung.html: „{kennung}“ steht noch als kommend da, obwohl "
                              f"Fassung {fassung} es mitgebracht hat und im Laden steht")

    neueste_app = max((f for f, d in daten.items() if d.get("app")), key=nummer, default=None)
    if neueste_app:
        entwurf = entwurf_neuigkeiten(ENTWURF.read_text(encoding="utf-8"))
        soll = dict(daten[neueste_app]["app"], fassung=neueste_app)
        if entwurf is None:
            fehler.append("docs/prototype/index.html: „const NEUIGKEITEN = {…};“ fehlt")
        elif entwurf != soll:
            fehler.append(f"Klick-Dummy zeigt andere Neuigkeiten als docs/fassungen/{neueste_app}.json")
    return fehler


def main() -> int:
    fehler = pruefen()
    for f in fehler:
        print(f"::error::{f}")
    if fehler:
        print(f"{len(fehler)} Abweichung(en) zwischen App, Laden und Website.")
        return 1
    print("App, Versionshinweise im Laden und Website erzählen dieselbe Geschichte.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
