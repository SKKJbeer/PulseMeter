#!/usr/bin/env python3
"""Hält das CloudKit-Schema der App und das der Produktion zusammen.

**Warum es das gibt.** Der Abgleich zwischen den Geräten lief von 1.0 bis
1.6 nie, und keine Prüfung hat es gemerkt (Käufermeldung 14. Oktober, behoben
in 0.141.0 bis 0.142.0). In der Produktionsumgebung von CloudKit stand kein
einziger Datensatztyp. CloudKit lehnt dann jedes Hochladen ab, SwiftData sichert
lokal weiter und meldet nichts. Für den Nutzer sieht das aus wie „die App
vergisst meine Zähler auf dem iPad“.

Dieselbe Falle steht bei jedem neuen Feld wieder offen. Die Produktion kennt
nur, was jemand in der CloudKit-Konsole übertragen hat; eine App mit einem Feld,
das dort fehlt, kann den ganzen Datensatz nicht mehr hochladen. Und was einmal
in der Produktion steht, lässt sich nicht mehr löschen oder umtypen.

Drei Dateien, zwei Regeln:

  cloudkit/schema.ckdb      was das Modell der App braucht (CloudKitSchemaTests
                            hält es gleich mit `PulseStore.modelTypes`)
  cloudkit/produktion.ckdb  was in der Produktion steht, zuletzt nachgesehen
                            von `.github/workflows/cloudkit-wache.yml`

  1. Nur anfügen. Jeder Typ und jedes Feld der Produktion steht weiter im
     Schema, mit demselben Datentyp. Sonst hat jemand umbenannt, und die Daten
     unter dem alten Namen sind für die neue App verloren. Immer ein Fehler.
  2. Vor der Auslieferung ist alles in der Produktion. Mit `--auslieferung`
     ist ein Feld, das nur im Schema steht, ein Fehler: Ein Bau für TestFlight
     oder den Laden spricht mit der Produktion. Ohne den Schalter ist es ein
     Hinweis, denn in einem Zweig darf das Modell wachsen.

Aufruf:
  python3 scripts/check-cloudkit-schema.py                 Regel 1, Hinweis zu 2
  python3 scripts/check-cloudkit-schema.py --auslieferung  Regel 1 und 2
  python3 scripts/check-cloudkit-schema.py --gegen /tmp/production.ckdb
        vergleicht zusätzlich die Ablage mit einer frischen Ausfuhr aus der
        Produktion (die Wache macht das jede Woche)
  python3 scripts/check-cloudkit-schema.py --selbsttest
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
SCHEMA = WURZEL / "cloudkit" / "schema.ckdb"
PRODUKTION = WURZEL / "cloudkit" / "produktion.ckdb"

TYP_ZEILE = re.compile(r"^\s*RECORD TYPE\s+(\S+)\s*\(\s*$")
FELD_ZEILE = re.compile(r'^\s*("?[A-Za-z_][\w]*"?)\s+([A-Z0-9_]+(?:<[A-Z0-9_]+>)?)')


def lesen(text: str) -> dict[str, dict[str, str]]:
    """Typ → {Feld → Datentyp}. Systemfelder (`___…`) und Rechte zählen nicht:
    Sie legt Apple an, und an ihnen kann die App nichts falsch machen."""
    typen: dict[str, dict[str, str]] = {}
    aktuell: dict[str, str] | None = None
    for zeile in text.splitlines():
        if m := TYP_ZEILE.match(zeile):
            aktuell = typen.setdefault(m.group(1), {})
            continue
        if aktuell is None:
            continue
        if zeile.strip().startswith(")"):
            aktuell = None
            continue
        if zeile.strip().startswith("GRANT"):
            continue
        if m := FELD_ZEILE.match(zeile):
            name = m.group(1).strip('"')
            if name.startswith("___"):
                continue
            aktuell[name] = m.group(2)
    return typen


def vergleichen(produktion: dict, schema: dict) -> tuple[list[str], list[str]]:
    """(Brüche, Fehlendes). Brüche verletzen Regel 1, Fehlendes Regel 2."""
    brueche, fehlt = [], []
    for typ, felder in sorted(produktion.items()):
        if typ not in schema:
            brueche.append(f"Typ {typ} steht in der Produktion, aber nicht mehr im Schema "
                           f"(umbenannt oder entfernt? Die Daten darin sähe die neue App nicht mehr)")
            continue
        for feld, art in sorted(felder.items()):
            neu = schema[typ].get(feld)
            if neu is None:
                brueche.append(f"{typ}.{feld} steht in der Produktion, aber nicht mehr im Schema")
            elif neu != art:
                brueche.append(f"{typ}.{feld} ist in der Produktion {art}, im Schema {neu} — "
                               f"CloudKit kann den Datentyp eines Feldes nicht ändern")
    for typ, felder in sorted(schema.items()):
        if typ not in produktion:
            fehlt.append(f"Typ {typ}")
            continue
        for feld in sorted(felder):
            if feld not in produktion[typ]:
                fehlt.append(f"{typ}.{feld}")
    return brueche, fehlt


def gleich(a: dict, b: dict) -> list[str]:
    """Unterschiede zwischen Ablage und frischer Ausfuhr, in beide Richtungen."""
    ab, ba = vergleichen(a, b), vergleichen(b, a)
    umgetypt = [x for x in ab[0] if "Datentyp" in x]
    return umgetypt + [f"nur in der Ausfuhr: {x}" for x in ab[1]] + \
        [f"nur in der Ablage: {x}" for x in ba[1]]


def selbsttest() -> int:
    """Jede Regel einmal rot, einmal grün. Eine Prüfung, die nie anschlägt, ist keine."""
    grund = """DEFINE SCHEMA
    RECORD TYPE CD_ReadingRecord (
        CD_day INT64 QUERYABLE SORTABLE,
        CD_id STRING QUERYABLE SEARCHABLE SORTABLE,
        "___createTime" TIMESTAMP,
        GRANT READ TO "_world"
    );
    RECORD TYPE Users (
        "___createTime" TIMESTAMP,
        roles LIST<INT64>,
        GRANT READ TO "_world"
    );
"""
    zusatz = grund.replace("CD_id STRING", "CD_note STRING QUERYABLE,\n        CD_id STRING")
    umbenannt = grund.replace("CD_day INT64", "CD_tag INT64")
    umgetypt = grund.replace("CD_day INT64", "CD_day STRING")
    ohne_typ = grund.split("    RECORD TYPE Users")[0]
    oktober = "DEFINE SCHEMA\n    RECORD TYPE Users (\n        roles LIST<INT64>\n    );\n"

    faelle = [
        ("Lesen findet Felder und lässt Systemfelder aus",
         lesen(grund) == {"CD_ReadingRecord": {"CD_day": "INT64", "CD_id": "STRING"},
                          "Users": {"roles": "LIST<INT64>"}}),
        ("Gleiches Schema: nichts", vergleichen(lesen(grund), lesen(grund)) == ([], [])),
        ("Neues Feld: kein Bruch, aber fehlt in der Produktion",
         vergleichen(lesen(grund), lesen(zusatz)) == ([], ["CD_ReadingRecord.CD_note"])),
        ("Umbenanntes Feld ist ein Bruch",
         len(vergleichen(lesen(grund), lesen(umbenannt))[0]) == 1),
        ("Geänderter Datentyp ist ein Bruch",
         "Datentyp" in " ".join(vergleichen(lesen(grund), lesen(umgetypt))[0])),
        ("Entfernter Typ ist ein Bruch",
         len(vergleichen(lesen(grund), lesen(ohne_typ))[0]) == 1),
        # Der Fall vom 14. Oktober: In der Produktion steht nur `Users`.
        ("Oktober: leere Produktion meldet jeden Zählora-Typ",
         vergleichen(lesen(oktober), lesen(grund))[1] == ["Typ CD_ReadingRecord"]),
        ("Ablage gegen Ausfuhr: Abweichung in beide Richtungen",
         len(gleich(lesen(grund), lesen(zusatz))) == 1
         and len(gleich(lesen(zusatz), lesen(grund))) == 1),
    ]
    schlecht = [name for name, ok in faelle if not ok]
    for name, ok in faelle:
        print(("  ok   " if ok else "  FEHL ") + name)
    return 1 if schlecht else 0


def main(argumente: list[str]) -> int:
    if "--selbsttest" in argumente:
        return selbsttest()
    auslieferung = "--auslieferung" in argumente

    for datei in (SCHEMA, PRODUKTION):
        if not datei.exists():
            print(f"FEHL {datei.relative_to(WURZEL)} fehlt")
            return 1
    schema = lesen(SCHEMA.read_text(encoding="utf-8"))
    produktion = lesen(PRODUKTION.read_text(encoding="utf-8"))
    if not schema or not produktion:
        print("FEHL Eine der Dateien enthält keinen einzigen Datensatztyp — "
              "eine leere Datei würde jede Prüfung bestehen.")
        return 1

    fehler: list[str] = []

    if "--gegen" in argumente:
        pfad = Path(argumente[argumente.index("--gegen") + 1])
        frisch = lesen(pfad.read_text(encoding="utf-8"))
        if not frisch:
            fehler.append(f"Die Ausfuhr {pfad} enthält keinen Datensatztyp")
        else:
            for unterschied in gleich(produktion, frisch):
                fehler.append("cloudkit/produktion.ckdb stimmt nicht mehr mit der Produktion: "
                              + unterschied)
            # Gemessen wird an der echten Produktion, nicht an der Ablage.
            produktion = frisch

    brueche, fehlt = vergleichen(produktion, schema)
    fehler += brueche
    if fehlt:
        text = ("Noch nicht in der Produktion von CloudKit: " + ", ".join(fehlt) +
                ". Weg: cloudkit-schema.yml (Modus hochladen), in der CloudKit-Konsole "
                "„Deploy Schema Changes“, danach cloudkit-wache.yml laufen lassen, "
                "die cloudkit/produktion.ckdb nachzieht.")
        if auslieferung:
            fehler.append(text + " Ein Bau für TestFlight oder den Laden würde diese "
                          "Datensätze nie abgleichen.")
        else:
            print("  Hinweis: " + text)

    for f in fehler:
        print("  FEHL " + f)
    if not fehler:
        print(f"  ok   {len(schema)} Typen, {sum(map(len, schema.values()))} Felder; "
              f"die Produktion kennt alle" if not fehlt else
              "  ok   nichts umbenannt oder umgetypt")
    return 1 if fehler else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
