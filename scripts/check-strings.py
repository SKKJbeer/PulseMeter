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

# **Was in Python, Shell und YAML wirklich bricht.**
#
# Ein erster Versuch suchte hier nach demselben Muster wie oben — „ gefolgt von
# einem geraden " — und fand 24 Stellen, von denen keine einzige schadete: In
# einem Kommentar ist das Zeichen harmlos. Eine Pruefung, die so oft grundlos
# anschlaegt, liest nach drei Tagen niemand mehr, und dann ist sie schlechter
# als keine.
#
# Geprueft wird deshalb nicht das Zeichen, sondern die **Folge**: Uebersetzt das
# Python noch? Laedt das YAML noch? Und — der Fall, der zwanzig Minuten
# Laeuferzeit kostet — ist jeder `run:`-Block noch gueltige Shell? Genau daran
# ist der TestFlight-Ablauf zweimal vorbeigelaufen.
import py_compile
import re
import subprocess
import tempfile

with tempfile.TemporaryDirectory() as ablage:
    # In einen Ordner, der danach verschwindet — nicht neben die Quelle. Sonst
    # entsteht bei jedem Lauf ein `__pycache__`, und in 0.60.1 sind drei davon
    # versehentlich in den Commit gewandert.
    for datei in sorted(pathlib.Path("scripts").glob("*.py")):
        ziel = pathlib.Path(ablage) / (datei.stem + ".pyc")
        try:
            py_compile.compile(str(datei), cfile=str(ziel), doraise=True)
        except py_compile.PyCompileError as fehler:
            problems.append(f"{datei}: uebersetzt nicht\n"
                            f"    {fehler.msg.strip().splitlines()[-1]}")

try:
    import yaml
except ImportError:
    yaml = None

for datei in sorted(pathlib.Path(".github/workflows").glob("*.yml")):
    if yaml is None:
        break
    try:
        beschreibung = yaml.safe_load(datei.read_text(encoding="utf-8"))
    except yaml.YAMLError as fehler:
        problems.append(f"{datei}: kein gueltiges YAML\n    {str(fehler).splitlines()[0]}")
        continue
    for auftrag in (beschreibung.get("jobs") or {}).values():
        for nummer, schritt in enumerate(auftrag.get("steps") or [], 1):
            skript = schritt.get("run")
            if not skript:
                continue
            fertig = subprocess.run(["bash", "-n"], input=skript, text=True,
                                    capture_output=True)
            if fertig.returncode != 0:
                name = schritt.get("name", f"Schritt {nummer}")
                problems.append(f"{datei}: {name} ist keine gueltige Shell\n"
                                f"    {fertig.stderr.strip().splitlines()[0]}")

# **Der alte Name darf in keinem Text stehen, den jemand liest.**
#
# Umbenannt am 28. August: aus „PulseMeter" wurde „Zählora". Die Bundle-ID, die
# Kauf-Kennungen und die Swift-Module heißen weiter so — das sieht kein Nutzer,
# und eine Kauf-Kennung zu ändern hieße, jedem Käufer seinen Kauf zu nehmen.
#
# Geprüft wird deshalb nicht die Datei, sondern die **Zeichenkette**: alles
# zwischen Anführungszeichen in Swift, und der sichtbare Text der Website und
# des Entwurfs. Ohne diese Prüfung steht der alte Name in drei Wochen wieder
# irgendwo — so ist es mit dem Keller gegangen.
ALTER_NAME = "PulseMeter"
for pfad in sorted(pathlib.Path("App").glob("*.swift")) + \
            sorted(pathlib.Path("Widget").glob("*.swift")) + \
            sorted(pathlib.Path("Packages/PulseUI/Sources/PulseUI").glob("*.swift")):
    for nummer, zeile in enumerate(pfad.read_text(encoding="utf-8").splitlines(), 1):
        nackt = zeile.strip()
        if nackt.startswith(("//", "///", "*")):
            continue
        for stueck in re.findall(r'"([^"]*)"', zeile):
            # **Kennungen sind kein Text.** `de.karjoth.…` ist die Bundle-ID,
            # `PulseMeterWidget` die Kennung des Widgets bei WidgetKit. Wer sie
            # umbenennt, nimmt jedem platzierten Widget den Bezug — und keiner
            # von beiden steht je auf einem Schirm.
            if stueck.startswith("de.karjoth") or stueck == "PulseMeterWidget":
                continue
            if ALTER_NAME in stueck:
                problems.append(f"{pfad}:{nummer}: {ALTER_NAME} steht in einer "
                                f"sichtbaren Zeichenkette — die App heisst Zaehlora\n"
                                f"    {nackt[:90]}")

for pfad in [pathlib.Path("docs/prototype/index.html"),
             *sorted(pathlib.Path("docs/website").glob("*.html"))]:
    if not pfad.exists():
        continue
    roh = pfad.read_text(encoding="utf-8")
    sichtbar = re.sub(r"<!--.*?-->|<script.*?</script>|<style.*?</style>", " ",
                      roh, flags=re.S)
    sichtbar = re.sub(r"<[^>]+>", " ", sichtbar)
    if ALTER_NAME in sichtbar:
        problems.append(f"{pfad}: {ALTER_NAME} steht im sichtbaren Text — "
                        "die App heisst Zaehlora")

# **Jeder Store-Text braucht einen Abnehmer, und jeder Abnehmer einen Text.**
# `store_text("…")` gab bei einer unbekannten Überschrift einen leeren String
# zurück statt zu lärmen. Genau eine Überschrift stand unter `##` statt `###`,
# der Aufruf lief still ins Leere, und der Hinweistext an die Prüfung kam bei
# Apple nie an — ohne dass irgendwo etwas rot wurde.
einreichung = pathlib.Path("scripts/asc-einreichung.py")
appstore = pathlib.Path("docs/09-appstore.md")
if einreichung.exists() and appstore.exists():
    inhalt = appstore.read_text(encoding="utf-8")
    for ueberschrift in re.findall(r'store_text\("([^"]+)"\)',
                                   einreichung.read_text(encoding="utf-8")):
        kopf = re.compile(r"^#{2,4} (?:\d+\. )?" + re.escape(ueberschrift) + r"\s*$",
                          re.M)
        treffer = kopf.search(inhalt)
        if treffer is None:
            problems.append(f"{appstore}: keine Ueberschrift {ueberschrift!r} — "
                            f"store_text() liefert dafuer stillschweigend "
                            f"einen leeren Text")
        elif not re.search(r"```\n(.*?)```", inhalt[treffer.end():], re.S):
            problems.append(f"{appstore}: unter {ueberschrift!r} steht kein "
                            f"Codeblock — es gibt nichts einzutragen")

if problems:
    print("\n".join(problems))
    print(f"\n{len(problems)} Fund(e).")
    sys.exit(1)

print("Zeichenketten, Python, YAML und die Shell in den Abläufen sind in Ordnung.")
