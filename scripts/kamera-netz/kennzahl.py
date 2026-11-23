"""Messung für Kamera Stufe 2: Liest das Ziffernnetz die Kennzahl (1.8.0, 2.8.0 …)?

Aufruf: python3 kennzahl.py ziffernnetz-1.pt,ziffernnetz-2.pt <Versuche>

Teil A, Kennzahl allein: Ein Fenster 5:1 um die Kennzahl (von Hand gesetzt, `kennzahl` in fotos*.json),
Höhe 1,4- bis 3-mal die Kennzahl, verschoben. Gezählt je Bild: richtig, **falsch** (eine ANDERE bekannte
Kennzahl, der schlimmste Fall: die Zahl landete beim falschen Zählwerk), nichts.

Teil B, wie in der App: Der Nutzer legt den Rahmen auf die Hauptziffern (wie evaluate.py). Die App sucht
die Kennzahl in festen Fenstern links und links oben vom Rahmen. Gezählt je Versuch (sechs Bilder, Einigung
vier von sechs): richtig, falsch, nichts. Auf Fotos OHNE Kennzahl ist jede gelesene Kennzahl falsch.

Die Fotos werden nur gemessen, nie trainiert (README)."""
import sys, os, numpy as np, torch
from collections import Counter, defaultdict
import realtest as RT
import synth as L
from train import Net, decode

BEKANNT = ['1.8.0', '1.8.1', '1.8.2', '2.8.0', '2.8.1', '2.8.2']


def kennzahl_aus(text):
    """Spiegel von ObisCodeReader.code(from:) in PulseCore. d.d.d oder ddd, nur bekannte Kennzahlen."""
    t = text.strip('.')
    if len(t) == 5 and t[1] == '.' and t[3] == '.' and t.replace('.', '').isdigit(): k = t
    elif len(t) == 3 and t.isdigit(): k = t[0] + '.' + t[1] + '.' + t[2]
    elif len(t) == 4 and t.replace('.', '').isdigit() and t.count('.') == 1:   # 1.80 oder 18.0: ein Punkt fehlt
        d = t.replace('.', ''); k = d[0] + '.' + d[1] + '.' + d[2]
    else: return None
    return k if k in BEKANNT else None


def lesen(nets, imgs):
    with torch.no_grad():
        X = torch.tensor(np.stack(imgs), dtype=torch.float32)[:, None] / 255
        alle = [decode(n(X)) for n in nets]
    out = []
    for k in range(len(imgs)):
        ts = [a[k] for a in alle]
        out.append(ts[0][0] if all(t[0] == ts[0][0] for t in ts) else '')
    return out


def kz_box(nr):
    im = RT.photo(nr); H, W = im.shape; l, t, r, b = RT.FOTOS[nr]['kennzahl']
    return l * W, t * H, r * W, b * H


import kennzahl_synth as KS     # Lage des Fensters: FH, FX, FY


def app_fenster(nr, m, dx, dy, sc):
    """Rahmen wie RT.frame, dazu das Kennzahl-Fenster. Gibt (Rahmenbild, Fensterbild) zurück."""
    im = RT.photo(nr); ax0, ay0, ax1, ay1 = RT.box(nr)
    hd = ay1 - ay0; hc = max(hd * m, (ax1 - ax0) / 0.9 / (L.IW / L.IH)) * sc
    wc = hc * L.IW / L.IH
    cx = (ax0 + ax1) / 2 + dx * wc; cy = (ay0 + ay1) / 2 + dy * hc
    return RT.crop_at(im, cx, cy, hc), RT.crop_at(im, cx - wc / 2 + KS.FX * hc, cy - KS.FY * hc, KS.FH * hc)


def teil_a(nets, trials, rng):
    print('=== Teil A: Fenster um die Kennzahl ===')
    for nr, f in RT.FOTOS.items():
        if 'kennzahl' not in f: continue
        soll = f['kennzahl_text']; im = RT.photo(nr); x0, y0, x1, y1 = kz_box(nr)
        imgs = []
        for _ in range(trials):
            h = (y1 - y0) * rng.uniform(1.4, 3.0); h = max(h, (x1 - x0) / 0.9 / 5)
            imgs.append(RT.crop_at(im, (x0 + x1) / 2 + rng.uniform(-.1, .1) * 5 * h, (y0 + y1) / 2 + rng.uniform(-.15, .15) * h, h))
        texte = lesen(nets, imgs); c = Counter()
        for t in texte:
            k = kennzahl_aus(t)
            c['richtig' if k == soll else 'FALSCH' if k else 'nichts'] += 1
        print(f'{nr} soll {soll}: richtig {c["richtig"]:3d} FALSCH {c["FALSCH"]:3d} nichts {c["nichts"]:3d}  gelesen z. B. {Counter(texte).most_common(4)}')
        if os.environ.get('BILDER'):
            import cv2; cv2.imwrite(f'/tmp/kz/{nr}-a.png', np.vstack(imgs[:6]))


def teil_b(nets, trials, rng):
    print('=== Teil B: wie in der App (Rahmen auf den Ziffern, Fenster links/links oben, vier von sechs) ===')
    tot = Counter(); falsch_gelesen = defaultdict(Counter)
    for nr, f in RT.FOTOS.items():
        if not RT.ZIFFERN[nr][1]: continue          # leeres Display
        soll = f.get('kennzahl_text'); c = Counter()
        for t in range(trials):
            m = rng.uniform(1.5, 2.8); bx = rng.uniform(-.1, .1); by = rng.uniform(-.15, .15)
            bilder = []
            for _ in range(6):
                _, fen = app_fenster(nr, m, bx + rng.uniform(-.03, .03), by + rng.uniform(-.05, .05), 1 + rng.uniform(-.05, .05))
                bilder.append(fen)
            je_bild = [kennzahl_aus(x) for x in lesen(nets, bilder)]
            if os.environ.get('BILDER') and t < 2:
                import cv2; cv2.imwrite(f'/tmp/kz/{nr}-b{t}.png', np.vstack(bilder))
            for k in je_bild:                                     # je Bild, zum Ansehen
                if k: c['bild_' + ('ok' if k == soll else 'falsch')] += 1
                if k and k != soll: falsch_gelesen[nr][k] += 1
            z = Counter(k for k in je_bild if k)
            if not z: c['nichts'] += 1; continue
            k, n = z.most_common(1)[0]
            if n < 3 or len(z) > 1: c['nichts'] += 1        # ObisVote: drei gleiche, kein Widerspruch
            elif k == soll: c['richtig'] += 1
            else: c['FALSCH'] += 1
        tot.update(c)
        print(f'{nr} soll {soll or "-":6s} richtig {c["richtig"]:3d} FALSCH {c["FALSCH"]:3d} nichts {c["nichts"]:3d} | Einzelbilder ok {c["bild_ok"]:3d} falsch {c["bild_falsch"]:3d}')
    print(f'== gesamt: {dict(tot)}')
    print('== falsch gelesen je Foto:', {k: dict(v) for k, v in falsch_gelesen.items()})
    return tot


if __name__ == '__main__':
    nets = []
    for p in sys.argv[1].split(','):
        n = Net(); n.load_state_dict(torch.load(p)); n.eval(); nets.append(n)
    trials = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    torch.set_num_threads(4)
    rng = np.random.default_rng(7)
    if os.environ.get('TEIL', 'ab') in ('a', 'ab'): teil_a(nets, trials, rng)
    if os.environ.get('TEIL', 'ab') in ('b', 'ab'): teil_b(nets, trials, rng)


def gepolstert(im, x0, y0, x1, y1):
    """Ausschnitt (x0..x1, y0..y1) auf 48 Höhe gebracht, in die Mitte eines 48 × 240-Bildes gesetzt,
    der Rest mit dem Randwert gefüllt. So steht die Kennzahl da, wo das Netz die Hauptzahl erwartet."""
    from area import resample
    h = y1 - y0; w = x1 - x0; ow = int(round(min(240, L.IH * w / h)))
    if ow < 8: return None
    if ow >= 240: return RT.crop_at(im, (x0 + x1) / 2, (y0 + y1) / 2, max(h, w / 5))
    a = np.round(resample(im, x0, y0, w, h, ow, L.IH) * 255).astype(np.uint8)
    rand = np.concatenate([a[:, 0], a[:, -1], a[0], a[-1]])
    out = np.full((L.IH, L.IW), int(np.median(rand)), np.uint8)
    o = (L.IW - ow) // 2; out[:, o:o + ow] = a
    return out


def teil_p(nets, trials, rng):
    print('=== Teil P: Kennzahl gepolstert ===')
    import cv2
    for nr, f in RT.FOTOS.items():
        if 'kennzahl' not in f: continue
        soll = f['kennzahl_text']; im = RT.photo(nr); x0, y0, x1, y1 = kz_box(nr); h = y1 - y0
        imgs = []
        for _ in range(trials):
            mx = rng.uniform(0.1, 0.8) * h; my = rng.uniform(0.15, 0.8) * h
            sx = rng.uniform(-.25, .25) * h; sy = rng.uniform(-.2, .2) * h
            g = gepolstert(im, x0 - mx + sx, y0 - my + sy, x1 + mx + sx, y1 + my + sy)
            if g is not None: imgs.append(g)
        texte = lesen(nets, imgs); c = Counter()
        for t in texte:
            k = kennzahl_aus(t); c['richtig' if k == soll else 'FALSCH' if k else 'nichts'] += 1
        print(f'{nr} soll {soll}: richtig {c["richtig"]:3d} FALSCH {c["FALSCH"]:3d} nichts {c["nichts"]:3d}  gelesen z. B. {Counter(texte).most_common(5)}')
        if os.environ.get('BILDER'): cv2.imwrite(f'/tmp/kz/{nr}-p.png', np.vstack(imgs[:6]))


if __name__ == '__main__' and os.environ.get('TEIL') == 'p':
    teil_p(nets, trials, rng)
