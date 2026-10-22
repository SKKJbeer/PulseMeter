"""Referenzwerte für Swift und JavaScript: gleiche Eingabe, gleiche Ausgabe wie in Python."""
import sys, json, base64, numpy as np
import export as E, realtest as RT, lcdsynth as L
from area import resample
from train import decode
import torch

def b64(a): return base64.b64encode(np.ascontiguousarray(a).tobytes()).decode()

def build(ts, net, cases):
    rng = np.random.default_rng(3)
    # Verkleinerung: ein kleines, unruhiges Bild, ein Rechteck mit Bruchteilen, das über den Rand ragt
    img = (np.random.default_rng(11).integers(0, 256, (37, 61))).astype(np.uint8)
    rect = [-3.5, 4.25, 70.0, 20.5]
    res = resample(img, *rect, 12, 5)
    out = {'verkleinern': {'breite': 61, 'hoehe': 37, 'pixel': b64(img), 'rechteck': rect, 'ziel': [12, 5],
                           'erwartet': [round(float(v), 6) for v in res.reshape(-1)]}, 'faelle': []}
    for name, x, soll in cases:
        lg = E.forward_np(ts, x)
        t = torch.tensor(lg)[None]
        s, c = decode(t)[0]
        out['faelle'].append({'name': name, 'soll': soll, 'pixel': b64(x), 'text': s, 'sicherheit': round(c, 4),
                              'ausgabe': [round(float(v), 4) for v in lg.reshape(-1)] if len(out['faelle']) < 3 else None})
    return out

if __name__ == '__main__':
    import torch
    from train import Net
    net = Net(); net.load_state_dict(torch.load(sys.argv[1])); net.eval()
    ts = E.tensors(net)
    cases = []
    for nr in RT.ZIFFERN:
        for m in (1.6, 2.4):
            x, soll = RT.mitte(nr, m); cases.append((f'{nr}-m{m}', x, soll))
    json.dump(build(ts, net, cases), open(sys.argv[2], 'w'), ensure_ascii=False, separators=(',', ':'))
    print(len(cases), 'Fälle')
