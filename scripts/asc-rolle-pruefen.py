#!/usr/bin/env python3
"""Sagt, ob ein App-Store-Connect-Schlüssel die Rolle Admin hat. Nur das.

Apple nennt die Rolle eines Schlüssels nirgends. Es gibt aber eine Anfrage,
die nur Admin (und der Kontoinhaber) stellen darf: die Liste der Nutzer des
Teams. Antwortet Apple darauf mit 200, ist der Schlüssel ein Admin; mit 403
nicht. Mehr als diese Antwort wird nicht gelesen.

**Ausgegeben wird nur der Statuscode und ein Wort.** Die Antwort enthält die
Namen und Mailadressen des Teams, und dieser Lauf steht in einem öffentlichen
Repository. Deshalb wird der Antworttext nie ausgegeben, auch nicht im Fehler.

Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8.
Ausgang: 0 = Admin, 1 = kein Admin oder nicht prüfbar.
"""
import os
import sys
import time

import jwt
import requests


def main() -> int:
    try:
        kennung, aussteller, schluessel = (os.environ[n] for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"))
    except KeyError:
        print("unvollständig")
        return 1
    if not (kennung and aussteller and schluessel):
        print("unvollständig")
        return 1
    jetzt = int(time.time())
    try:
        token = jwt.encode({"iss": aussteller, "iat": jetzt, "exp": jetzt + 600,
                            "aud": "appstoreconnect-v1"},
                           schluessel, algorithm="ES256", headers={"kid": kennung})
    except Exception:
        # Meist ein p8 mit zerhackten Zeilenumbrüchen. Den Fehlertext nicht
        # ausgeben: Er kann Teile des Schlüssels enthalten.
        print("Schlüssel nicht lesbar")
        return 1
    antwort = requests.get("https://api.appstoreconnect.apple.com/v1/users",
                           params={"limit": 1},
                           headers={"Authorization": f"Bearer {token}"}, timeout=30)
    if antwort.status_code == 200:
        print("Admin (200)")
        return 0
    if antwort.status_code == 403:
        print("kein Admin (403)")
    elif antwort.status_code == 401:
        print("von Apple nicht angenommen (401)")
    else:
        print(f"nicht prüfbar ({antwort.status_code})")
    return 1


if __name__ == "__main__":
    sys.exit(main())
