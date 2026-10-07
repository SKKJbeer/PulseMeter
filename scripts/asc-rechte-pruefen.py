#!/usr/bin/env python3
"""Welche Anfragen ein App-Store-Connect-Schlüssel stellen darf, als Tabelle.

`asc-rolle-pruefen.py` fragt nur nach der Teamliste und schließt daraus auf
Admin. Das war am 7. Oktober ein zu schwacher Beweis: Derselbe Schlüssel bekam
dort 200 und auf die Analytics-Berichte 403. Diese Tabelle fragt breiter, und
jede Zeile ist eine Anfrage, die Apple an eine bestimmte Rolle bindet.

**Ausgegeben wird nur Name der Anfrage und Statuscode**, nie ein Antworttext:
Die Antworten enthalten Namen und Adressen des Teams, und der Lauf ist öffentlich.

Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, optional ASC_APP_ID.
"""
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"


def token() -> str:
    jetzt = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt, "exp": jetzt + 600,
                       "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})


def main() -> int:
    app = os.environ.get("ASC_APP_ID", "6802262743")
    kopf = {"Authorization": f"Bearer {token()}"}
    anfragen = [
        ("Apps lesen", f"/v1/apps/{app}", {}),
        ("Bundle-IDs lesen", "/v1/bundleIds", {"limit": 1}),
        ("Zertifikate lesen", "/v1/certificates", {"limit": 1}),
        ("Teamnutzer lesen", "/v1/users", {"limit": 1}),
        ("Einladungen lesen", "/v1/userInvitations", {"limit": 1}),
        ("Analytics-Anfragen der App lesen", f"/v1/apps/{app}/analyticsReportRequests", {}),
        ("Beta-Tester lesen", "/v1/betaTesters", {"limit": 1}),
    ]
    for name, pfad, params in anfragen:
        code = requests.get(BASIS + pfad, params=params, headers=kopf, timeout=30).status_code
        print(f"{name}: {code}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
