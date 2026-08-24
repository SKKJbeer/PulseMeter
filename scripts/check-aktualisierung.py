#!/usr/bin/env python3
"""Prüft, dass jede Änderung am Bestand in allen Ansichten ankommt.

**Woher die Prüfung kommt.** Vom Gerät gemeldet: „stelle sicher dass die
Zahlen und Grafiken sich auch immer aktualisieren wenn neue Zähler eingaben
kamen. egal ob einer aus der historie gelöscht oder geändert wurde oder ein
ganz neuer zählerstand hinzu kommt."

Der Fehler war nicht eine vergessene Zeile, sondern die Bauweise: Jede der
drei Ansichten lud in ihrem eigenen `onAppear` und danach nur noch, wenn ein
Blatt, das *sie* aufgemacht hatte, sich schloss. Eine im Verlauf gelöschte
Ablesung erreichte die Übersicht nie. Seit 0.78.0 gibt es dafür ein Signal —
``Datenstand`` —, und diese Prüfung besteht darauf, dass es benutzt wird.

Drei Regeln, und sie hängen zusammen:

1. Jede Ansicht, die Zahlen zeigt, lädt auf das Signal hin neu.
2. Jedes Blatt, das etwas ändert, meldet sich über das Signal — oder reicht
   die Meldung an den weiter, der es aufgemacht hat.
3. Niemand lädt am Signal vorbei. Ein zweiter Weg wäre eine zweite
   Gelegenheit, dass eine Ansicht etwas anzeigt, was die andere nicht kennt.
"""

import pathlib
import re
import sys

APP = pathlib.Path("App")

# Die Ansichten, die Zahlen und Grafiken zeigen. Sie müssen auf das Signal
# hören — eine davon zu vergessen ist genau der gemeldete Fehler.
ANSICHTEN = ("OverviewView", "HistoryView", "MetersView")

# Blätter, die den Bestand ändern, und wie sie es melden.
BLAETTER = {
    "CaptureView": "onSaved",
    "MeterEditor": "onDone",
    "MeterChangeView": None,      # meldet über eine nachgestellte Schließung
    "ReadingsList": "onChanged",
    "ReadingEditor": "onDone",
}

# Womit eine Meldung weitergegeben werden darf: entweder das Signal selbst
# oder der Rückruf dessen, der das Blatt aufgemacht hat.
MELDET = re.compile(r"datenstand\.geaendert\(\)|\bon(Saved|Done|Changed)\(\)")

# Was in einer Meldung nichts zu suchen hat: der zweite Weg.
LAEDT_SELBST = re.compile(r"\b(re)?load\(\)")

probleme = []


def ohne_kommentare(text):
    """Kommentare durch Leerzeichen ersetzen, Länge und Zeilen unverändert.

    **Warum das sein muss.** Der erste Lauf dieser Prüfung meldete eine Stelle,
    die in Ordnung war: Im Kommentar daneben stand `load()` — als Erklärung,
    warum dort gerade *nicht* geladen wird. Eine Prüfung, die auf Fließtext
    anschlägt, wird binnen Tagen weggeklickt; dieselbe Erfahrung steht schon
    in 0.60.2. Die Positionen bleiben erhalten, damit die Zeilennummer in der
    Meldung auf die echte Zeile zeigt.
    """
    aus = list(text)
    i, n = 0, len(text)
    in_text = False
    while i < n:
        z = text[i]
        if in_text:
            if z == "\\":
                i += 2
                continue
            if z == '"':
                in_text = False
        elif z == '"':
            in_text = True
        elif z == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                aus[i] = " "
                i += 1
            continue
        elif z == "/" and i + 1 < n and text[i + 1] == "*":
            while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                if text[i] != "\n":
                    aus[i] = " "
                i += 1
            for k in range(i, min(i + 2, n)):
                aus[k] = " "
            i += 2
            continue
        i += 1
    return "".join(aus)


def spanne(text, start):
    """Der Aufruf ab ``start`` (dem `(` ) samt nachgestellter Schließung.

    Klammern werden gezählt, nicht gesucht: Ein `MeterEditor(...)` enthält
    selbst wieder Klammern, und ein `MeterChangeView(...) { ... }` hängt seine
    Schließung hinter die runde Klammer statt hinein.
    """
    i, tiefe = start, 0
    while i < len(text):
        if text[i] == "(":
            tiefe += 1
        elif text[i] == ")":
            tiefe -= 1
            if tiefe == 0:
                i += 1
                break
        i += 1
    else:
        return None

    j = i
    while j < len(text) and text[j] in " \t\r\n":
        j += 1
    if j < len(text) and text[j] == "{":
        tiefe = 0
        while j < len(text):
            if text[j] == "{":
                tiefe += 1
            elif text[j] == "}":
                tiefe -= 1
                if tiefe == 0:
                    j += 1
                    return text[start:j]
            j += 1
        return None
    return text[start:i]


for path in sorted(APP.rglob("*.swift")):
    text = ohne_kommentare(path.read_text(encoding="utf-8"))

    def zeile_von(pos, text=text):
        return text.count("\n", 0, pos) + 1

    for ansicht in ANSICHTEN:
        if not re.search(rf"^struct {ansicht}: View", text, re.M):
            continue
        if ".onChange(of: datenstand.version)" not in text:
            probleme.append(
                f"{path}: {ansicht} zeigt Zahlen, lädt aber nicht neu, wenn "
                "sich der Bestand ändert — .onChange(of: datenstand.version) fehlt"
            )

    for blatt in BLAETTER:
        # Nur Aufrufe, keine Deklaration und kein Wort im Fließtext.
        for treffer in re.finditer(rf"(?<![\w.]){blatt}\(", text):
            aufruf = spanne(text, treffer.end() - 1)
            if aufruf is None:
                continue
            if not MELDET.search(aufruf):
                probleme.append(
                    f"{path}:{zeile_von(treffer.start())}: {blatt} ändert den "
                    "Bestand, meldet es aber niemandem — datenstand.geaendert() fehlt"
                )
            elif LAEDT_SELBST.search(aufruf):
                probleme.append(
                    f"{path}:{zeile_von(treffer.start())}: {blatt} lädt am Signal "
                    "vorbei nach — dann sieht nur diese eine Ansicht die Änderung"
                )

if probleme:
    print("\n".join(probleme))
    print(f"\n{len(probleme)} Stelle(n), an denen eine Änderung nicht überall ankommt.")
    sys.exit(1)

print("Jede Änderung am Bestand erreicht alle drei Ansichten.")
