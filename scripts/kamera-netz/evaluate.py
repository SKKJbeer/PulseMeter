"""Die Messung, auf die es ankommt: Was bekommt der Nutzer vorgeschlagen, wenn er die Zahl in den Rahmen hält?
Sechs Bilder, drei gleiche nötig (ReadingConsensus), der Leser im Modus „eingerahmt". Je Foto viele Versuche."""
import sys, json, numpy as np, torch
import realtest as RT
from train import Net, decode

def sig(s): return len(s.lstrip('0'))

def read_value(text, conf, fmt, rng_val=None):
    """Python-Spiegel von MeterTextReader (nur der Teil, den das Ziffernnetz erreicht: eingerahmt)."""
    I, F = fmt
    if not text or ':' in text or text.count('.') > 1 or text.startswith('.') or text.endswith('.'): return None
    if not all(c.isdigit() or c == '.' for c in text): return None
    dd = [c for c in text if c.isdigit()]
    if len(dd) >= 4 and all(c == '8' for c in dd): return None        # Displaytest
    if '.' in text:
        a, b = text.split('.')
        if len(b) > F or sig(a) > I: return None
        val = float(a + '.' + b); raw = len(a)
    else:
        if F > 0 and len(text) == I + F: val = float(text[:-F] + '.' + text[-F:]); raw = I
        else:
            if sig(text) > I: return None
            if F > 0 and len(text) > I: return None        # verlorener Punkt: nicht raten
            val = float(text); raw = len(text)
    strong = raw >= I
    marked = '.' in text or text.startswith('0')
    if not rng_val and not marked: return None        # erste Ablesung: nur mit Merkmal
    if not rng_val and not strong: return None
    if rng_val and not (rng_val[0] <= val <= rng_val[1]): return None
    need = 0.5 if strong else 0.6
    return val if conf >= need else None

def consensus(vals, required=3, window=6):
    rec = vals[-window:]
    from collections import Counter
    c = Counter(v for v in rec if v is not None)
    if not c: return None
    best, n = c.most_common(1)[0]
    if n < required: return None
    if any(k != best and v > 1 for k, v in c.items()): return None
    return best

def run(net, trials=60, seed=1, verbose=True, modes=('erste', 'zweite')):
    nets = net if isinstance(net, list) else [net]
    rng = np.random.default_rng(seed); [n.eval() for n in nets]; res = {}
    for nr in RT.ZIFFERN:
        soll_text = RT.ZIFFERN[nr][1]; stand = RT.STAND[nr]; fmt = RT.FORMAT[nr]
        for mode in modes:
            rv = None
            if mode == 'zweite' and stand is not None:
                s = float(stand); rv = (s - 50, s + max(100, s * 0.5))
            richtig = falsch = nichts = 0; frames_ok = frames_bad = frames_n = 0; wrongs = []
            for t in range(trials):
                m = rng.uniform(1.5, 2.8); bx = rng.uniform(-.1, .1); by = rng.uniform(-.15, .15)
                imgs = [RT.frame(nr, m, bx + rng.uniform(-.03, .03), by + rng.uniform(-.05, .05), 1 + rng.uniform(-.05, .05)) for _ in range(6)]
                with torch.no_grad():
                    X_ = torch.tensor(np.stack(imgs), dtype=torch.float32)[:, None] / 255
                    alle = [decode(n(X_)) for n in nets]
                outs = []
                for k_ in range(len(imgs)):
                    ts_ = [a[k_] for a in alle]
                    same = all(t_[0] == ts_[0][0] for t_ in ts_)
                    outs.append((ts_[0][0], min(t_[1] for t_ in ts_)) if same else ('', 0.0))
                vals = []
                for s_, c_ in outs:
                    v = read_value(s_, c_, fmt, rv); vals.append(v)
                    frames_n += 1
                    if v is not None:
                        if stand is not None and abs(v - float(stand)) < 1e-9: frames_ok += 1
                        else: frames_bad += 1
                win = consensus(vals)
                if win is None: nichts += 1
                elif stand is not None and abs(win - float(stand)) < 1e-9: richtig += 1
                else: falsch += 1; wrongs.append(win)
            res[(nr, mode)] = (richtig, falsch, nichts, frames_ok, frames_bad, frames_n, wrongs[:3])
    return res

def table(res, trials):
    lines = []; tot = {(g, m): [0, 0, 0] for g in ('alt', 'neu') for m in ('erste', 'zweite')}
    for (nr, mode), (r, f, n, fo, fb, fn, w) in res.items():
        if RT.STAND[nr] is None and mode == 'zweite': continue
        g = 'neu' if nr in RT.NEU else 'alt'
        lines.append(f'{nr} {g} {mode:6s} richtig {r:3d} falsch {f:3d} nichts {n:3d} | Einzelbilder richtig {fo:3d} falsch {fb:3d} von {fn} {("falsch: "+str(w)) if f else ""}')
        t = tot[(g, mode)]; t[0] += r; t[1] += f; t[2] += n
    for (g, m), (r, f, n) in tot.items(): lines.append(f'== {g} (Fotos {"neu, nie trainiert" if g == "neu" else "die ersten sieben"}) {m}: richtig {r} falsch {f} nichts {n} (von {r+f+n})')
    return '\n'.join(lines)

if __name__ == '__main__':
    nets = []
    for p_ in sys.argv[1].split(','):
        n_ = Net(); n_.load_state_dict(torch.load(p_)); nets.append(n_)
    trials = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    torch.set_num_threads(2)
    print(table(run(nets, trials), trials))
