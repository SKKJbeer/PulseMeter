#!/usr/bin/env python3
"""Antwortet als Entwickler auf eine Rezension im App Store.

**Warum es das gibt.** Am 22. November 2026 wollte der Gründer auf eine
Rezension antworten (sieben Zähler, CSV im Mailtext statt als Datei), nachdem
die Lösung mit 1.8 im Laden stand. Die Schlüssel liegen nur in den
GitHub-Geheimnissen, also läuft die Antwort über einen Ablauf und nicht von
Hand.

**Der Text steht im Repository** (`docs/rezensionen/*.txt`), nicht in einem
Eingabefeld. Eine Antwort ist öffentlich und bleibt am Laden stehen; sie geht
deshalb durch git wie jeder andere Text, den Kunden lesen.

Zwei Modi:
- `probe`: sucht die Rezension und sagt, was gefunden wurde. Schreibt nichts.
- `senden`: wie `probe`, dann wird die Antwort veröffentlicht. Steht schon
  eine Antwort da, wird sie ersetzt (Apple kennt kein Ändern, nur Löschen und
  neu Anlegen).

Gesucht wird über den Spitznamen des Rezensenten, er ist im Laden öffentlich.
Gibt es keinen oder mehr als einen Treffer, wird nichts gesendet.

Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, MODUS, SPITZNAME, DATEI.
"""
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"
APP_ID = "6802262743"  # Zählora, trackId im Laden


def token() -> str:
    jetzt = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt, "exp": jetzt + 900,
                       "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})


def fehler(antwort: requests.Response) -> str:
    try:
        e = antwort.json()["errors"][0]
        return f"{antwort.status_code} {e.get('title', '')}: {e.get('detail', '')}"
    except Exception:
        return str(antwort.status_code)


def main() -> int:
    modus = os.environ.get("MODUS", "probe")
    spitzname = os.environ.get("SPITZNAME", "").strip()
    datei = os.environ.get("DATEI", "").strip()
    if not spitzname or not datei:
        print("::error::SPITZNAME und DATEI fehlen.")
        return 1
    # Nur Dateien aus docs/rezensionen — der Pfad kommt aus einem Eingabefeld.
    pfad = os.path.normpath(os.path.join("docs/rezensionen", os.path.basename(datei)))
    text = open(pfad, encoding="utf-8").read().strip()
    if not text or len(text) > 5970:
        print(f"::error::Antworttext leer oder zu lang ({len(text)} Zeichen, Apple erlaubt 5970).")
        return 1

    kopf = {"Authorization": f"Bearer {token()}"}
    treffer = []
    url = f"{BASIS}/v1/apps/{APP_ID}/customerReviews"
    params = {"sort": "-createdDate", "limit": 200, "include": "response"}
    while url:
        antwort = requests.get(url, params=params, headers=kopf, timeout=30)
        if antwort.status_code != 200:
            print(f"::error::Rezensionen ließen sich nicht lesen: {fehler(antwort)}")
            return 1
        daten = antwort.json()
        for r in daten.get("data", []):
            if r["attributes"].get("reviewerNickname", "").strip().lower() == spitzname.lower():
                treffer.append(r)
        url = daten.get("links", {}).get("next")
        params = None

    if len(treffer) != 1:
        print(f"::error::{len(treffer)} Rezensionen von „{spitzname}“ gefunden, erwartet genau eine. Nichts gesendet.")
        return 1
    r = treffer[0]
    a = r["attributes"]
    print(f"Gefunden: „{a.get('title')}“, {a.get('rating')} Sterne, {a.get('createdDate')}, {a.get('territory')}")
    bestehend = (r.get("relationships", {}).get("response", {}) or {}).get("data")
    print("Bisherige Antwort: " + ("ja" if bestehend else "keine"))
    print(f"Antwort ({len(text)} Zeichen):\n{text}")

    if modus != "senden":
        print("Probe: nichts gesendet.")
        return 0

    if bestehend:
        weg = requests.delete(f"{BASIS}/v1/customerReviewResponses/{bestehend['id']}",
                              headers=kopf, timeout=30)
        if weg.status_code not in (200, 204):
            print(f"::error::Alte Antwort ließ sich nicht löschen: {fehler(weg)}")
            return 1

    neu = requests.post(f"{BASIS}/v1/customerReviewResponses", headers=kopf, timeout=30, json={
        "data": {
            "type": "customerReviewResponses",
            "attributes": {"responseBody": text},
            "relationships": {"review": {"data": {"type": "customerReviews", "id": r["id"]}}},
        }})
    if neu.status_code not in (200, 201):
        print(f"::error::Antwort nicht angenommen: {fehler(neu)}")
        return 1
    zustand = neu.json()["data"]["attributes"].get("state")
    print(f"::notice::Antwort angenommen, Zustand bei Apple: {zustand}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
