"""Aufruf: python3 stoertest.py <Versuche>   (STOER=name misst nur eine Störung)

Dieselbe Messung wie evaluate.py — sechs Sucherbilder, vier gleiche, beide Netze müssen sich
einig sein —, aber jedes Bild wird vorher so verdorben, wie es am Zähler passiert: verwackelt,
unscharf, dunkel, flau, schräg gehalten, verrauscht, stark komprimiert, mit Spiegelung.

Die Frage ist nicht, wie oft die Kamera trotzdem liest. Die Frage ist, ob sie bei schlechten
Bildern **schweigt statt falsch vorzuschlagen**. Ein falscher Vorschlag, den jemand übernimmt,
ist ein falscher Zählerstand; kein Vorschlag heißt nur: eintippen."""
import os, sys, cv2, numpy as np, torch
import realtest as RT
import evaluate as EV
from train import Net

_frame = RT.frame
_rng = np.random.default_rng(7)

def unscharf(im):     return cv2.GaussianBlur(im, (0, 0), 1.3)
def verwackelt(im):
    k = np.zeros((9, 9), np.float32); k[4, :] = 1 / 9
    return cv2.filter2D(im, -1, k)
def dunkel(im):       return np.clip(im.astype(np.float32) * 0.35, 0, 255).astype(np.uint8)
def flau(im):         return np.clip(128 + (im.astype(np.float32) - 128) * 0.35, 0, 255).astype(np.uint8)
def schraeg(im):
    h, w = im.shape; a = _rng.choice([-1, 1]) * _rng.uniform(3, 6)
    M = cv2.getRotationMatrix2D((w / 2, h / 2), a, 1.0)
    return cv2.warpAffine(im, M, (w, h), borderMode=cv2.BORDER_REPLICATE)
def rauschen(im):     return np.clip(im + _rng.normal(0, 14, im.shape), 0, 255).astype(np.uint8)
def jpeg(im):
    ok, b = cv2.imencode('.jpg', im, [cv2.IMWRITE_JPEG_QUALITY, 18])
    return cv2.imdecode(b, cv2.IMREAD_GRAYSCALE)
def spiegelung(im):
    h, w = im.shape; yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = _rng.uniform(0.2, 0.8) * w, _rng.uniform(0.2, 0.8) * h
    fleck = 150 * np.exp(-(((xx - cx) / (w * 0.12)) ** 2 + ((yy - cy) / (h * 0.5)) ** 2))
    return np.clip(im + fleck, 0, 255).astype(np.uint8)

STOERUNGEN = {f.__name__: f for f in (unscharf, verwackelt, dunkel, flau, schraeg, rauschen, jpeg, spiegelung)}

if __name__ == '__main__':
    trials = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    nets = []
    for p_ in ('ziffernnetz-1.pt', 'ziffernnetz-2.pt'):
        n_ = Net(); n_.load_state_dict(torch.load(p_)); nets.append(n_)
    torch.set_num_threads(int(os.environ.get('THREADS', 2)))
    nur = os.environ.get('STOER')
    for name, f in STOERUNGEN.items():
        if nur and name != nur: continue
        RT.frame = lambda *a, f=f, **k: f(_frame(*a, **k))
        res = EV.run(nets, trials, seed=3)
        r = fa = ni = 0; fehl = []
        for (nr, mode), (r_, f_, n_, *_rest, w) in res.items():
            if RT.STAND[nr] is None and mode == 'zweite': continue
            r += r_; fa += f_; ni += n_
            if f_: fehl.append(f'{nr}/{mode}: {f_}x {w}')
        print(f'{name:11s} richtig {r:4d}  falsch {fa:3d}  nichts {ni:4d}  (von {r+fa+ni})  {"; ".join(fehl)}', flush=True)
