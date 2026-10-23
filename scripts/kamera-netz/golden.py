"""Referenzwerte für Swift und JavaScript: gleiche Eingabe, gleiche Ausgabe wie in Python."""
import sys, json, base64, numpy as np
import export as E, realtest as RT, synth as L
from area import resample
from train import decode
import torch

def b64(a): return base64.b64encode(np.ascontiguousarray(a).tobytes()).decode()

def build(tss, cases):
    """tss: Gewichte je Netz. Je Fall der Text jedes Netzes, die Ausgabe der ersten Fälle, und das Ergebnis des Ensembles."""
    img = (np.random.default_rng(11).integers(0, 256, (37, 61))).astype(np.uint8)
    rect = [-3.5, 4.25, 70.0, 20.5]
    res = resample(img, *rect, 12, 5)
    out = {'verkleinern': {'breite': 61, 'hoehe': 37, 'pixel': b64(img), 'rechteck': rect, 'ziel': [12, 5],
                           'erwartet': [round(float(v), 6) for v in res.reshape(-1)]}, 'faelle': []}
    for name, x, soll in cases:
        texte, sich, ausg = [], [], []
        for ts in tss:
            lg = E.forward_np(ts, x)
            s, c = decode(torch.tensor(lg)[None])[0]
            if not s: c = 0.0          # keine Zeichen, keine Sicherheit (wie DigitLine.confidence)
            texte.append(s); sich.append(round(c, 4)); ausg.append([round(float(v), 4) for v in lg.reshape(-1)])
        einig = all(t == texte[0] for t in texte)
        out['faelle'].append({'name': name, 'soll': soll, 'pixel': b64(x), 'texte': texte, 'sicherheiten': sich,
                              'text': texte[0] if einig else '', 'sicherheit': (min(sich) if einig and texte[0] else 0.0),
                              'ausgaben': ausg if len(out['faelle']) < 2 else None})
    return out

if __name__ == '__main__':
    import torch
    from train import Net
    tss = []
    for p in sys.argv[2:]:
        net = Net(); net.load_state_dict(torch.load(p)); net.eval(); tss.append(E.tensors(net))
    cases = []
    for nr in RT.ZIFFERN:
        for m in ((2.0,) if nr in RT.NEU else (1.7, 2.3)):
            x, soll = RT.mitte(nr, m); cases.append((f'{nr}-m{m}', x, soll))
    json.dump(build(tss, cases), open(sys.argv[1], 'w'), ensure_ascii=False, separators=(',', ':'))
    print(len(cases), 'Fälle,', len(tss), 'Netze')
