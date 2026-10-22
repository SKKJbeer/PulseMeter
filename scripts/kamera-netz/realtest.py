"""Das echte Prüfmaterial: Sucherausschnitte um die Hauptziffern der LCD-Fotos, in vielen Varianten.
Die Rahmen stehen in docs/kamera/fotos.json ('ziffern', 'anzeige')."""
import json, cv2, numpy as np
import lcdsynth as L
from area import resample
R = '/home/user/PulseMeter/docs/kamera/'

def _laden():
    d = json.load(open(R + 'fotos.json', encoding='utf-8'))['fotos']
    out = {}
    for f in d:
        if 'ziffern' in f:
            out[f['datei'].split('/')[1][:2]] = f
    return out
FOTOS = _laden()
ZIFFERN = {nr: (None, f['anzeige']) for nr, f in FOTOS.items()}       # Soll-Text je Foto
FORMAT = {nr: (f['vorkommastellen'], f['nachkommastellen']) for nr, f in FOTOS.items()}
STAND = {nr: f['stand'] for nr, f in FOTOS.items()}
_bilder = {}

def photo(nr):
    if nr not in _bilder: _bilder[nr] = cv2.imread(R + FOTOS[nr]['datei'], cv2.IMREAD_GRAYSCALE)
    return _bilder[nr]

def box(nr):
    im = photo(nr); H, W = im.shape; l, t, r, b = FOTOS[nr]['ziffern']
    return l * W, t * H, r * W, b * H

def crop_at(im, cx, cy, hc):
    """Ausschnitt 5:1 mit Höhe hc um (cx, cy) in Fotopunkten, flächengemittelt wie in der App."""
    wc = hc * L.IW / L.IH
    return np.round(resample(im, cx - wc / 2, cy - hc / 2, wc, hc, L.IW, L.IH) * 255).astype(np.uint8)

def frame(nr, m, dx=0.0, dy=0.0, scale=1.0):
    """Ein Sucherbild: Rahmenhöhe = m * Ziffernhöhe, verschoben um dx, dy (in Rahmenbreiten/-höhen)."""
    im = photo(nr); ax0, ay0, ax1, ay1 = box(nr)
    hd = ay1 - ay0; hc = max(hd * m, (ax1 - ax0) / 0.9 / (L.IW / L.IH)) * scale
    wc = hc * L.IW / L.IH
    return crop_at(im, (ax0 + ax1) / 2 + dx * wc, (ay0 + ay1) / 2 + dy * hc, hc)

def variants(nr, rng, n=24):
    out = []
    for i in range(n):
        out.append((frame(nr, rng.uniform(1.4, 3.0), rng.uniform(-.12, .12), rng.uniform(-.2, .2)), ZIFFERN[nr][1]))
    return out

def mitte(nr, m=2.0):
    return frame(nr, m), ZIFFERN[nr][1]
