#!/usr/bin/env python3
"""Schreibt ein Repository-Geheimnis, ohne dass jemand es abtippt.

**Warum das nötig ist.** Das Zertifikat aus `asc-zertifikat.py` ist rund
viertausend Zeichen Base64. Die aus einem Protokoll in ein Formularfeld zu
übertragen — auf einem Telefon — ist keine Automatisierung, sondern eine
Zumutung mit hoher Fehlerquote. Und ein privater Schlüssel, der durch die
Zwischenablage geht, liegt danach in der Zwischenablage.

GitHub nimmt Geheimnisse nur **versiegelt** entgegen: Der öffentliche Schlüssel
des Repositories wird geholt, der Wert damit in eine Sealed Box gelegt, und nur
die geht über die Leitung. Der Klartext verlässt diesen Lauf nie.

Aufruf:  python3 scripts/gh-geheimnis.py NAME WERT
Umgebung: GH_PAT (fein granuliert, nur dieses Repository, Secrets: Read and
          write), GITHUB_REPOSITORY
"""
import os
import sys

import requests
from nacl import encoding, public


def versiegeln(oeffentlich: str, wert: str) -> str:
    schluessel = public.PublicKey(oeffentlich.encode("utf-8"), encoding.Base64Encoder())
    return encoding.Base64Encoder().encode(
        public.SealedBox(schluessel).encrypt(wert.encode("utf-8"))
    ).decode("utf-8")


def main() -> None:
    if len(sys.argv) != 3:
        print("::error::Aufruf: gh-geheimnis.py NAME WERT")
        sys.exit(1)

    name, wert = sys.argv[1], sys.argv[2]
    token = os.environ.get("GH_PAT", "")
    repo = os.environ["GITHUB_REPOSITORY"]
    if not token:
        print("::error::GH_PAT fehlt.")
        sys.exit(1)

    kopf = {"Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"}

    antwort = requests.get(f"https://api.github.com/repos/{repo}/actions/secrets/public-key",
                           headers=kopf, timeout=30)
    if antwort.status_code != 200:
        rat = ""
        if antwort.status_code in (401, 403, 404):
            rat = ("Das Token darf hier nicht schreiben. Es muss **fein "
                   "granuliert** sein, dieses Repository umfassen und die "
                   "Berechtigung „Secrets: Read and write\" tragen. Ein "
                   "klassisches Token mit `repo` genügt **nicht** für "
                   "Actions-Geheimnisse.")
        print(f"::error::Der öffentliche Schlüssel ließ sich nicht holen "
              f"({antwort.status_code}). {rat}")
        sys.exit(1)

    daten = antwort.json()
    setzen = requests.put(
        f"https://api.github.com/repos/{repo}/actions/secrets/{name}",
        headers=kopf,
        json={"encrypted_value": versiegeln(daten["key"], wert),
              "key_id": daten["key_id"]},
        timeout=30,
    )
    # 201 = neu angelegt, 204 = ersetzt. Beides ist richtig.
    if setzen.status_code not in (201, 204):
        print(f"::error::{name} ließ sich nicht setzen ({setzen.status_code}): "
              f"{setzen.text[:300]}")
        sys.exit(1)

    print(f"{name} gesetzt ({'neu' if setzen.status_code == 201 else 'ersetzt'}).")


if __name__ == "__main__":
    main()
