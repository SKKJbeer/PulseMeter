#!/usr/bin/env python3
"""Baut die Beispielzähler des Klick-Dummys (`const FOTOS` in docs/prototype/index.html).

Je Beispiel: das Foto (klein, zum Ansehen), der Rahmen, den ein Nutzer im Sucher auf die
Ziffern legte, und ein **hochaufgelöster Ausschnitt um diesen Rahmen**, aus dem der Klick-Dummy
die Sucherbilder schneidet. Das Ziffernnetz rechnet darauf wirklich, mit denselben Gewichten
und derselben Rechnung wie die App (`scripts/kamera-gewichte.py`).

Warum ein Ausschnitt und nicht das 460-Punkte-Foto: Eine Kamera liefert die Ziffern in voller
Auflösung, nicht auf Vorschaugröße. Das Foto hier dient zum Ansehen, der Ausschnitt zum Lesen.

Rollenzähler (Gas, Siemens) liest in der App die Texterkennung des Telefons; im Klick-Dummy ist
sie nachgestellt (`texte`), wie seit 0.135.0.

    scripts/kamera-beispiele.py            schreibt `const FOTOS` neu
    scripts/kamera-beispiele.py --pruefen  bricht ab, wenn es vom Erzeugten abweicht
"""
import base64, io, json, pathlib, re, sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
KAMERA = ROOT / "docs/kamera"
HTML = ROOT / "docs/prototype/index.html"

# (Kennung, Foto-Nummer, Beschriftung, nachgestellter Text bei Rollen oder None)
BEISPIELE = [
    ("landis", "25", "Strom, Display", None),
    ("aidon", "02", "Strom, blasses Display", None),
    ("logarex", "04", "Strom, großes Display", None),
    ("meterus", "27", "Strom, Display mit Punkt", None),
    ("openway", "28", "Strom, zwei Zahlen", None),
    ("kamstrup", "29", "Strom, kleine Anzeige", None),
    ("gruen", "32", "Strom, Display im Dunkeln", None),
    ("metrix", "11", "Gas, Rollen", ['00047,36 m³', 'G4', '6G4L', 'Nr 113457', '2007']),
    ("siemens", "07", "Strom, Rollen", ['655219', 'SIEMENS', 'kWh', 'Wechselstromzähler', '220 V', '10(60) A', '50 Hz', '375 U/kWh', '6.047.178']),
    ("datum", "01", "Display zeigt das Datum", None),
    ("leer", "06", "Display leer", None),
]
RAHMEN_M = 1.8      # Höhe des Rahmens im Sucher, in Ziffernhöhen
CROP_M = 2.6        # Höhe des Ausschnitts, aus dem die Sucherbilder geschnitten werden
CROP_W, CROP_H = 720, 144

def jpeg(im, q):
    b = io.BytesIO(); im.save(b, "JPEG", quality=q, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()

def eintrag(kennung, nr, label, texte, fotos):
    f = next(x for x in fotos if x["datei"].split("/")[1].startswith(nr))
    foto = Image.open(KAMERA / f["datei"]).convert("RGB")
    W, H = foto.size
    out = {"id": kennung, "label": label, "src": jpeg(foto.resize((460, round(460 * H / W)), Image.LANCZOS), 62)}
    if texte:
        out["texte"] = texte
        return out
    l, t, r, b = f["ziffern"]
    x0, y0, x1, y1 = l * W, t * H, r * W, b * H
    cx, cy, hd = (x0 + x1) / 2, (y0 + y1) / 2, y1 - y0
    hc = max(hd * CROP_M, (x1 - x0) / 0.9 / 5)           # die Zeile muss in den Rahmen passen
    hr = hc * RAHMEN_M / CROP_M
    wc, wr = hc * 5, hr * 5
    gray = foto.convert("L")
    crop = gray.transform((CROP_W, CROP_H), Image.AFFINE, (wc / CROP_W, 0, cx - wc / 2, 0, hc / CROP_H, cy - hc / 2), Image.BICUBIC)
    out["rahmen"] = [round((cx - wr / 2) / W, 4), round((cy - hr / 2) / H, 4), round((cx + wr / 2) / W, 4), round((cy + hr / 2) / H, 4)]
    out["crop"] = jpeg(crop, 88)
    out["cropRahmen"] = [round(CROP_W * (1 - hr / hc) / 2), round(CROP_H * (1 - hr / hc) / 2), round(CROP_W * hr / hc), round(CROP_H * hr / hc)]
    out["anzeige"] = f["anzeige"]
    return out

def main():
    fotos = json.loads((KAMERA / "fotos.json").read_text(encoding="utf-8"))["fotos"]
    liste = [eintrag(*b, fotos) for b in BEISPIELE]
    neu = "const FOTOS = " + json.dumps(liste, ensure_ascii=False, separators=(",", ":")) + ";"
    html = HTML.read_text(encoding="utf-8")
    alt = re.search(r"^const FOTOS = .*;$", html, re.M)
    if not alt: sys.exit("const FOTOS fehlt im Klick-Dummy")
    if "--pruefen" in sys.argv:
        if alt.group(0) != neu:
            print("✗ Die Beispielzähler im Klick-Dummy weichen von scripts/kamera-beispiele.py ab."); sys.exit(1)
        print(f"Beispielzähler im Klick-Dummy: {len(liste)}, wie erzeugt."); return
    HTML.write_text(html[:alt.start()] + neu + html[alt.end():], encoding="utf-8")
    print(f"{len(liste)} Beispiele, {len(neu) // 1024} KB")

main()
