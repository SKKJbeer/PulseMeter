#!/usr/bin/env python3
"""Wie die Website gefunden wird: Aufrufe je Seite, Herkunft, Gerät, Land.

    CLOUDFLARE_STATISTIK_TOKEN=… CLOUDFLARE_ACCOUNT_ID=… scripts/website-zahlen.py [tage]

Liest die Zählung, die `docs/website-server/_middleware.js` schreibt. Der
Schlüssel braucht nur „Account Analytics: Read“; er darf nichts ändern und
nichts hochladen. Das ist Absicht: Ein Bericht, der jede Woche läuft, soll mit
dem kleinsten Recht auskommen, das es gibt.

Die Tabellen gehen auf die Konsole und, im Ablauf, in die Zusammenfassung des
Laufs. **Das Repository ist öffentlich, und damit auch diese Zusammenfassung.**
Es stehen darin nur Summen, nichts über einzelne Besucher; wer die Zahlen
trotzdem nicht offen sehen will, stellt den Ablauf ab und ruft das Skript am
eigenen Rechner auf.
"""
import json
import os
import sys
import urllib.error
import urllib.request

DATENSATZ = "zaehlora_aufrufe"
MENSCH = "(blob4 = 'Telefon' OR blob4 = 'Tablet' OR blob4 = 'Rechner')"


def abfrage(sql):
    konto = os.environ["CLOUDFLARE_ACCOUNT_ID"]
    anfrage = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/accounts/{konto}/analytics_engine/sql",
        data=(sql + " FORMAT JSON").encode(),
        headers={"Authorization": f"Bearer {os.environ['CLOUDFLARE_STATISTIK_TOKEN']}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(anfrage, timeout=30) as antwort:
            return json.load(antwort).get("data", [])
    except urllib.error.HTTPError as fehler:
        # Die Antwort nennt den Grund, meist das fehlende Recht. Ohne sie
        # bliebe nur „403“, und das sagt nicht, welches Recht fehlt.
        sys.exit(f"Cloudflare antwortet {fehler.code}: {fehler.read().decode()[:400]}")


def tabelle(titel, kopf, zeilen):
    zeilen = list(zeilen)
    teile = [f"### {titel}", ""]
    if not zeilen:
        return "\n".join(teile + ["Noch nichts gezählt.", ""])
    teile += ["| " + " | ".join(kopf) + " |", "|" + "---|" * len(kopf)]
    teile += ["| " + " | ".join(str(z) for z in zeile) + " |" for zeile in zeilen]
    return "\n".join(teile + [""])


def gruppe(spalte, tage, filter_=MENSCH, grenze=15):
    return abfrage(
        f"SELECT {spalte} AS wert, SUM(_sample_interval) AS anzahl FROM {DATENSATZ} "
        f"WHERE timestamp > NOW() - INTERVAL '{tage}' DAY AND {filter_} "
        f"GROUP BY wert ORDER BY anzahl DESC LIMIT {grenze}"
    )


def main():
    tage = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    for name in ("CLOUDFLARE_STATISTIK_TOKEN", "CLOUDFLARE_ACCOUNT_ID"):
        if not os.environ.get(name):
            sys.exit(f"{name} fehlt. Anleitung: docs/website/CLOUDFLARE.md, Abschnitt Zählung")

    je_tag = abfrage(
        f"SELECT toStartOfInterval(timestamp, INTERVAL '1' DAY) AS tag, SUM(_sample_interval) AS anzahl "
        f"FROM {DATENSATZ} WHERE timestamp > NOW() - INTERVAL '{tage}' DAY AND {MENSCH} "
        f"GROUP BY tag ORDER BY tag"
    )
    gesamt = sum(int(z["anzahl"]) for z in je_tag)
    zahl = lambda z: int(z["anzahl"])  # noqa: E731

    teile = [
        f"## Website: {gesamt} Seitenaufrufe in {tage} Tagen",
        "",
        "Gezählt ohne Bots. Ein Aufruf ist eine geladene Seite, kein Mensch: "
        "Wer drei Seiten ansieht, zählt dreimal.",
        "",
        tabelle("Je Tag", ["Tag", "Aufrufe"], ((z["tag"][:10], zahl(z)) for z in je_tag)),
        tabelle("Je Seite", ["Seite", "Aufrufe"], ((z["wert"], zahl(z)) for z in gruppe("blob1", tage))),
        tabelle("Woher", ["Herkunft", "Aufrufe"], ((z["wert"], zahl(z)) for z in gruppe("blob2", tage))),
        tabelle("Selbst gesetzte Quelle (?von=)", ["Quelle", "Aufrufe"],
                ((z["wert"], zahl(z)) for z in gruppe("blob5", tage, f"{MENSCH} AND blob5 != ''"))),
        tabelle("Gerät", ["Gerät", "Aufrufe"], ((z["wert"], zahl(z)) for z in gruppe("blob4", tage, "1 = 1"))),
        tabelle("Land", ["Land", "Aufrufe"], ((z["wert"] or "unbekannt", zahl(z)) for z in gruppe("blob3", tage, grenze=8))),
    ]
    bericht = "\n".join(teile)
    print(bericht)
    ziel = os.environ.get("GITHUB_STEP_SUMMARY")
    if ziel:
        with open(ziel, "a", encoding="utf-8") as datei:
            datei.write(bericht + "\n")


if __name__ == "__main__":
    main()
