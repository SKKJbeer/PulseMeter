#!/usr/bin/env python3
"""Hält die Website bei dem, was im App Store steht.

Vom Gründer am 19. Oktober: „dass wenn neue versionen deployed und live gehen
auch die webseite immer das aktuelle darstellt. aktuell laufen die
auseinander." Gemessen: 1.5 stand seit dem 14. Oktober, 22:44 UTC im Laden;
`entwicklung.html` und die Startseite nannten fünf Tage lang 1.4.1 als neueste
Fassung und den Import als „Als Nächstes". Niemand hatte vergessen, es war
schlicht kein Schritt, der von selbst losging: Die Nachschau nach dem
Einreichen war für drei Stunden später geplant und kam erst an, als die
Sitzung wieder aufwachte.

**Wie es jetzt läuft:** Der Text für die Website entsteht **vor** dem
Einreichen, neben den Versionshinweisen, als `docs/fassungen/<fassung>.json`.
Sobald Apple die Fassung freigibt, trägt `website-fassung.yml` sie mit dem
Datum aus dem Laden auf `entwicklung.html` und der Startseite ein, zählt hoch
und stößt die Veröffentlichung an. Fehlt die Datei, wird der Lauf rot, und
`einreichen.yml` lässt gar nicht erst einreichen.

Aufruf:
  website-fassung.py                  zeigt Laden, Repository und Netz nebeneinander
  website-fassung.py --nachziehen     trägt die Fassung aus dem Laden ein
  website-fassung.py --vorbereitet 1.6   gibt es den Text für diese Fassung?
  website-fassung.py --netz           steht sie auch auf der veröffentlichten Seite?
  website-fassung.py --selbsttest     erzeugt vorhandene Einträge neu und vergleicht

**Über curl, nicht über urllib.** Derselbe Grund wie bei `store-rang.py`: Der
Proxy der Cloud-Sitzung antwortet auf Pythons eigenen Abruf mit 403.

**Das Datum ist das UTC-Datum der Freigabe**, so wie bei 1.0 („4.9.") und in
`12-auslieferung.md`. Ein Eintrag um 22:44 UTC steht damit auf dem 14., auch
wenn es in Deutschland schon der 15. war.
"""
import html
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

APP = 6802262743
WURZEL = Path(__file__).resolve().parent.parent
WEB = WURZEL / "docs" / "website"
FASSUNGEN = WURZEL / "docs" / "fassungen"
WEG = WEB / "entwicklung.html"
START = WEB / "index.html"

MONATE = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
          "August", "September", "Oktober", "November", "Dezember"]

HAKEN = ('<span class="weg-punkt"><svg viewBox="0 0 12 12" aria-hidden="true" '
         'focusable="false" fill="none" stroke="currentColor" stroke-width="2" '
         'stroke-linecap="round" stroke-linejoin="round"><path d="m2.5 6.2 2.3 2.3 '
         '4.7-5"/></svg></span>')


def nummer(fassung: str) -> tuple:
    return tuple(int(teil) for teil in fassung.split("."))


def curl(adresse: str) -> str | None:
    lauf = subprocess.run(["curl", "-sS", "--max-time", "25", adresse],
                          capture_output=True, text=True)
    return lauf.stdout if lauf.returncode == 0 and lauf.stdout else None


def laden() -> tuple[str, str]:
    """Fassung und UTC-Datum, wie sie ein Käufer sieht."""
    antwort = curl(f"https://itunes.apple.com/lookup?id={APP}&country=de")
    try:
        eintrag = json.loads(antwort or "")["results"][0]
        return eintrag["version"], eintrag["currentVersionReleaseDate"][:10]
    except (ValueError, KeyError, IndexError):
        sys.exit("::error::Der Laden antwortet nicht lesbar (itunes.apple.com/lookup).")


def im_weg() -> list[str]:
    roh = WEG.read_text(encoding="utf-8")
    return re.findall(r'class="stand stand-laden">Fassung ([\d.]+)<', roh)


def auf_start() -> list[str]:
    roh = START.read_text(encoding="utf-8")
    return re.findall(r'<span class="fassung">Fassung ([\d.]+)</span>', roh)


def text_zu(fassung: str) -> dict | None:
    datei = FASSUNGEN / f"{fassung}.json"
    if not datei.exists():
        return None
    daten = json.loads(datei.read_text(encoding="utf-8"))
    pruefen(daten, fassung)
    return daten


def pruefen(daten: dict, fassung: str) -> None:
    fehler = []
    if daten.get("fassung") != fassung:
        fehler.append(f"„fassung“ ist nicht {fassung}")
    weg = daten.get("weg") or {}
    for feld in ("titel", "text"):
        if not str(weg.get(feld, "")).strip():
            fehler.append(f"weg.{feld} fehlt")
    start = daten.get("start")
    if start is not None:
        if not str(start.get("titel", "")).strip():
            fehler.append("start.titel fehlt")
        if not start.get("absaetze"):
            fehler.append("start.absaetze fehlt")
    if fehler:
        sys.exit(f"::error::docs/fassungen/{fassung}.json: " + ", ".join(fehler))


def eintrag_weg(daten: dict, datum: str) -> str:
    jahr, monat, tag = (int(t) for t in datum.split("-"))
    return (
        '        <li class="weg-laden">\n'
        f'          {HAKEN}\n'
        '          <div class="weg-karte">\n'
        f'            <div class="weg-kopf"><span class="stand stand-laden">Fassung {daten["fassung"]}</span>'
        f'<time datetime="{datum}">{tag:02d}.{monat:02d}.{jahr}</time></div>\n'
        f'            <h3>{html.escape(daten["weg"]["titel"], quote=False)}</h3>\n'
        f'            <p>{html.escape(daten["weg"]["text"], quote=False)}</p>\n'
        '          </div>\n'
        '        </li>\n'
    )


def umbrechen(text: str, breite: int = 68) -> str:
    zeilen, zeile = [], ""
    for wort in text.split():
        if zeile and len(zeile) + 1 + len(wort) > breite:
            zeilen.append(zeile)
            zeile = wort
        else:
            zeile = f"{zeile} {wort}".strip()
    zeilen.append(zeile)
    return "\n".join("            " + z for z in zeilen)


def eintrag_start(daten: dict, datum: str) -> str:
    jahr, monat, tag = (int(t) for t in datum.split("-"))
    absaetze = "".join(
        f'          <p>\n{umbrechen(html.escape(a, quote=False))}\n          </p>\n'
        for a in daten["start"]["absaetze"])
    return (
        '        <li>\n'
        '          <div class="neuerung-kopf">\n'
        f'            <time datetime="{datum}">{tag}. {MONATE[monat - 1]} {jahr}</time>\n'
        f'            <span class="fassung">Fassung {daten["fassung"]}</span>\n'
        '          </div>\n'
        f'          <h3>{html.escape(daten["start"]["titel"], quote=False)}</h3>\n'
        f'{absaetze}'
        '        </li>\n'
    )


def einsetzen(fassung: str, datum: str) -> list[str]:
    """Trägt fehlende Einträge ein und gibt zurück, was geändert wurde."""
    daten = text_zu(fassung)
    if daten is None:
        sys.exit(f"::error::Fassung {fassung} steht im Laden, aber docs/fassungen/{fassung}.json "
                 "fehlt. Der Text für die Website gehört vor das Einreichen, neben die "
                 "Versionshinweise in docs/09-appstore.md. Vorlage: docs/fassungen/1.5.json")
    geaendert = []

    weg = WEG.read_text(encoding="utf-8")
    if fassung not in im_weg():
        marke = '        <li class="weg-laden">'
        i = weg.index(marke)
        weg = weg[:i] + eintrag_weg(daten, datum) + weg[i:]
        weg = re.sub(r'(data-zahl="fassungen">)(\d+)(<)',
                     lambda m: f"{m.group(1)}{int(m.group(2)) + 1}{m.group(3)}", weg, count=1)
        WEG.write_text(weg, encoding="utf-8")
        geaendert.append("entwicklung.html")

    if daten.get("start") is not None and fassung not in auf_start():
        start = START.read_text(encoding="utf-8")
        marke = '      <ol class="neuerungen">\n'
        i = start.index(marke) + len(marke)
        start = start[:i] + eintrag_start(daten, datum) + start[i:]
        START.write_text(start, encoding="utf-8")
        geaendert.append("index.html")
    return geaendert


def stand() -> int:
    version, datum = laden()
    weg, start = im_weg(), auf_start()
    neueste = max(weg, key=nummer)
    print(f"Laden:            {version}  (freigegeben {datum})")
    print(f"entwicklung.html: {neueste}  ({len(weg)} Fassungen)")
    print(f"Startseite:       {max(start, key=nummer)}")
    daten = text_zu(version)
    print(f"Text vorhanden:   {'ja' if daten else 'nein, docs/fassungen/' + version + '.json fehlt'}")

    if nummer(neueste) > nummer(version):
        print(f"::warning::entwicklung.html nennt {neueste}, im Laden steht aber {version}. "
              "Öffentlich steht mit Nummer und Datum nur, was im Laden ist.")
    fehlt = []
    if version not in weg:
        fehlt.append("entwicklung.html")
    if daten and daten.get("start") is not None and version not in start:
        fehlt.append("Startseite")
    if fehlt:
        print(f"::error::Fassung {version} ist im Laden und fehlt auf: {', '.join(fehlt)}. "
              "`scripts/website-fassung.py --nachziehen` trägt sie ein.")
        return 1
    print("Die Website nennt die Fassung, die im Laden steht.")
    return 0


def nachziehen() -> int:
    version, datum = laden()
    geaendert = einsetzen(version, datum)
    ausgabe = os.environ.get("GITHUB_OUTPUT")
    if ausgabe:
        with open(ausgabe, "a", encoding="utf-8") as datei:
            datei.write(f"geaendert={'ja' if geaendert else 'nein'}\nfassung={version}\n")
    if geaendert:
        print(f"::notice::Fassung {version} ({datum}) eingetragen in {', '.join(geaendert)}.")
    else:
        print(f"Nichts zu tun: Fassung {version} steht schon auf der Website.")
    return 0


def vorbereitet(fassung: str) -> int:
    if text_zu(fassung) is None:
        print(f"::error::docs/fassungen/{fassung}.json fehlt. Ohne den Text bliebe die Website "
              f"nach der Freigabe bei der alten Fassung. Vorlage: docs/fassungen/1.5.json")
        return 1
    print(f"Der Website-Text für {fassung} liegt bereit.")
    return 0


def netz() -> int:
    version, _ = laden()
    kopf = START.read_text(encoding="utf-8")
    adresse = re.search(r'rel="canonical" href="https://([^"/]+)', kopf)
    if not adresse:
        sys.exit("::error::Kein canonical in index.html.")
    ziel = f"https://{adresse.group(1)}/entwicklung"
    # Der Veröffentlichungslauf braucht knapp zwei Minuten; beim ersten Blick
    # kann die alte Seite noch dastehen.
    for versuch in range(1, 13):
        seite = curl(ziel) or ""
        if f"Fassung {version}<" in seite:
            print(f"::notice::{ziel} nennt Fassung {version}.")
            return 0
        print(f"Versuch {versuch}: {ziel} nennt Fassung {version} noch nicht.")
        time.sleep(30)
    print(f"::error::Fassung {version} ist im Laden, aber {ziel} nennt sie nach sechs Minuten nicht.")
    return 1


def selbsttest() -> int:
    """Erzeugt jeden vorhandenen Eintrag neu und vergleicht ihn mit der Seite.

    Der Erzeuger darf nicht still vom Handwerk abweichen: Wer an `entwicklung.html`
    das Markup ändert, ohne den Erzeuger anzufassen, bekäme sonst bei der
    nächsten Fassung einen Eintrag, der anders aussieht als alle davor.
    """
    weg, start = WEG.read_text(encoding="utf-8"), START.read_text(encoding="utf-8")
    dateien = sorted(FASSUNGEN.glob("*.json"), key=lambda p: nummer(p.stem))
    if not dateien:
        print("::error::docs/fassungen/ ist leer.")
        return 1
    fehler = 0
    for datei in dateien:
        fassung = datei.stem
        daten = text_zu(fassung)
        if fassung not in im_weg():
            print(f"  {fassung}: noch nicht im Laden, Text liegt bereit")
            continue
        datum = re.search(
            rf'Fassung {re.escape(fassung)}</span><time datetime="(\d{{4}}-\d\d-\d\d)"', weg)
        if not datum:
            print(f"::error::{fassung}: kein Datum in entwicklung.html")
            fehler += 1
            continue
        if eintrag_weg(daten, datum.group(1)) not in weg:
            print(f"::error::{fassung}: der Eintrag in entwicklung.html weicht vom Erzeuger ab")
            fehler += 1
        if daten.get("start") is not None and eintrag_start(daten, datum.group(1)) not in start:
            print(f"::error::{fassung}: der Eintrag auf der Startseite weicht vom Erzeuger ab")
            fehler += 1
    print("Selbsttest: " + ("alle Einträge stimmen mit dem Erzeuger überein." if not fehler
                            else f"{fehler} Abweichung(en)."))
    return 1 if fehler else 0


def main() -> int:
    if "--selbsttest" in sys.argv:
        return selbsttest()
    if "--nachziehen" in sys.argv:
        return nachziehen()
    if "--netz" in sys.argv:
        return netz()
    if "--vorbereitet" in sys.argv:
        i = sys.argv.index("--vorbereitet")
        if i + 1 >= len(sys.argv):
            sys.exit("Aufruf: website-fassung.py --vorbereitet 1.6")
        return vorbereitet(sys.argv[i + 1])
    return stand()


if __name__ == "__main__":
    sys.exit(main())
