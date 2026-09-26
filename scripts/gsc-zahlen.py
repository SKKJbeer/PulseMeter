#!/usr/bin/env python3
"""Was Google über die Website weiß: Suchbegriffe, Einblendungen, Klicks.

    GOOGLE_SC_SCHLUESSEL='{…json…}' scripts/gsc-zahlen.py [tage]

Liest die Search Console über ein Dienstkonto und meldet bei jedem Lauf die
Sitemap an, damit Google eine neue Seite nicht erst beim nächsten Vorbeikommen
findet. Das Dienstkonto muss in der Search Console als Nutzer der Property
eingetragen sein, mit „Vollständig“, sonst darf es die Sitemap nicht melden.

**Die Zahlen hinken zwei bis drei Tage nach.** Das ist Google, nicht dieses
Skript; der jüngste Tag im Bericht ist deshalb selten gestern.
"""
import json
import os
import sys
import urllib.parse

PROPERTY = "https://zaehlora.pages.dev/"
SITEMAP = PROPERTY + "sitemap.xml"
API = "https://searchconsole.googleapis.com/webmasters/v3/sites/" + urllib.parse.quote(PROPERTY, safe="")


def sitzung():
    # Erst hier, damit `--hilfe` und die Formprüfung ohne die Pakete laufen.
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession

    roh = os.environ.get("GOOGLE_SC_SCHLUESSEL", "")
    if not roh:
        sys.exit("GOOGLE_SC_SCHLUESSEL fehlt. Anleitung: docs/13-zugaenge.md")
    zugang = service_account.Credentials.from_service_account_info(
        json.loads(roh), scopes=["https://www.googleapis.com/auth/webmasters"])
    return AuthorizedSession(zugang), zugang.service_account_email


def pruefe(antwort, was, email):
    if antwort.status_code == 403:
        sys.exit(f"{was}: Google verweigert (403). Ist {email} in der Search Console "
                 f"unter Einstellungen › Nutzer und Berechtigungen mit „Vollständig“ eingetragen?")
    if antwort.status_code >= 400:
        sys.exit(f"{was}: {antwort.status_code} {antwort.text[:300]}")
    return antwort


def tabelle(titel, kopf, zeilen):
    teile = [f"### {titel}", ""]
    if not zeilen:
        return "\n".join(teile + ["Noch nichts bei Google.", ""])
    teile += ["| " + " | ".join(kopf) + " |", "|" + "---|" * len(kopf)]
    teile += ["| " + " | ".join(str(z) for z in zeile) + " |" for zeile in zeilen]
    return "\n".join(teile + [""])


def main():
    tage = int(sys.argv[1]) if len(sys.argv) > 1 else 28
    s, email = sitzung()

    pruefe(s.put(f"{API}/sitemaps/{urllib.parse.quote(SITEMAP, safe='')}"), "Sitemap melden", email)

    import datetime
    bis = datetime.date.today()
    von = bis - datetime.timedelta(days=tage)

    def abfrage(dimension, grenze=15):
        antwort = pruefe(s.post(f"{API}/searchAnalytics/query", json={
            "startDate": von.isoformat(), "endDate": bis.isoformat(),
            "dimensions": [dimension], "rowLimit": grenze}), f"Abfrage {dimension}", email)
        return antwort.json().get("rows", [])

    def zeile(r):
        return (r["keys"][0], int(r["clicks"]), int(r["impressions"]),
                f"{r['ctr'] * 100:.1f} %", f"{r['position']:.1f}")

    kopf = ["", "Klicks", "Einblendungen", "Klickrate", "Position"]
    gesamt = abfrage("date", 400)
    klicks = sum(int(r["clicks"]) for r in gesamt)
    einblendungen = sum(int(r["impressions"]) for r in gesamt)
    bericht = "\n".join([
        f"## Google: {einblendungen} Einblendungen, {klicks} Klicks in {tage} Tagen",
        "",
        "Einblendung heißt: Die Seite stand in einem Suchergebnis. Position 1 ist ganz oben.",
        "",
        tabelle("Suchbegriffe", ["Suchbegriff"] + kopf[1:], [zeile(r) for r in abfrage("query")]),
        tabelle("Seiten", ["Seite"] + kopf[1:],
                [(r["keys"][0].replace(PROPERTY, "/"),) + zeile(r)[1:] for r in abfrage("page")]),
        tabelle("Geräte", ["Gerät"] + kopf[1:], [zeile(r) for r in abfrage("device", 5)]),
        f"Sitemap gemeldet: {SITEMAP}",
    ])
    print(bericht)
    ziel = os.environ.get("GITHUB_STEP_SUMMARY")
    if ziel:
        with open(ziel, "a", encoding="utf-8") as datei:
            datei.write(bericht + "\n")


if __name__ == "__main__":
    main()
