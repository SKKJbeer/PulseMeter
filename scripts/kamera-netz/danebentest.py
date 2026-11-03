"""Aufruf: python3 danebentest.py <Versuche je Foto>

Was schlägt die Kamera vor, wenn der Rahmen **nicht** auf der Anzeige liegt? Auf einem Zähler
steht mehr als der Stand: Seriennummer, Baujahr, Impulse je kWh, Strichcode, Prüfzeichen. Hält
jemand den Rahmen knapp daneben, darf daraus kein Vorschlag werden.

Gemessen wird mit denselben Regeln wie evaluate.py (beide Netze einig, Leser „eingerahmt",
vier gleiche von sechs). Die Rahmen liegen zufällig auf dem Foto, ohne die Ziffern zu
berühren. Jeder Vorschlag ist ein Fehler."""
import os, sys, numpy as np, torch
import realtest as RT
import evaluate as EV
from train import Net, decode
import synth as L

def ausserhalb(nr, rng, m):
    im = RT.photo(nr); H, W = im.shape; ax0, ay0, ax1, ay1 = RT.box(nr)
    hd = ay1 - ay0; hc = hd * m; wc = hc * L.IW / L.IH
    for _ in range(200):
        cx = rng.uniform(wc / 2, max(wc / 2 + 1, W - wc / 2)); cy = rng.uniform(hc / 2, max(hc / 2 + 1, H - hc / 2))
        # kein Überlapp mit dem Ziffernfeld
        if cx + wc / 2 < ax0 or cx - wc / 2 > ax1 or cy + hc / 2 < ay0 or cy - hc / 2 > ay1:
            return cx, cy, hc
    return None

if __name__ == '__main__':
    trials = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    nets = []
    for p_ in ('ziffernnetz-1.pt', 'ziffernnetz-2.pt'):
        n_ = Net(); n_.load_state_dict(torch.load(p_)); n_.eval(); nets.append(n_)
    torch.set_num_threads(int(os.environ.get('THREADS', 2)))
    rng = np.random.default_rng(11)
    gesamt = {'erste': [0, 0], 'zweite': [0, 0]}; funde = []
    for nr in RT.ZIFFERN:
        fmt = RT.FORMAT[nr]; stand = RT.STAND[nr]
        for t in range(trials):
            m = rng.uniform(1.5, 2.8); ort = ausserhalb(nr, rng, m)
            if ort is None: continue
            cx, cy, hc = ort
            imgs = [RT.crop_at(RT.photo(nr), cx + rng.uniform(-.03, .03) * hc * 5, cy + rng.uniform(-.05, .05) * hc,
                               hc * (1 + rng.uniform(-.05, .05))) for _ in range(6)]
            with torch.no_grad():
                X_ = torch.tensor(np.stack(imgs), dtype=torch.float32)[:, None] / 255
                alle = [decode(n(X_)) for n in nets]
            outs = []
            for k in range(6):
                ts_ = [a[k] for a in alle]
                outs.append((ts_[0][0], min(x[1] for x in ts_)) if all(x[0] == ts_[0][0] for x in ts_) else ('', 0.0))
            for mode in ('erste', 'zweite'):
                if mode == 'zweite' and stand is None: continue
                rv = None if mode == 'erste' else (float(stand) - 50, float(stand) + max(100, float(stand) * 0.5))
                vals = [EV.read_value(s, c, fmt, rv) for s, c in outs]
                win = EV.consensus(vals, 4, 6)
                gesamt[mode][1] += 1
                if win is not None:
                    gesamt[mode][0] += 1; funde.append(f'{nr}/{mode}: {win} (gelesen {[s for s, _ in outs]})')
    for mode, (f, n) in gesamt.items():
        print(f'daneben {mode:6s}: {f} Vorschläge in {n} Versuchen')
    for z in funde[:20]: print('  ', z)
