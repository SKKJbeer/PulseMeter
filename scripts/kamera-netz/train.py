import sys, time, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
import lcdsynth as L, realtest as RT
torch.set_num_threads(4); torch.manual_seed(0)
NC = len(L.CHARS) + 1

class Net(nn.Module):
    def __init__(self):
        super().__init__()
        def blk(i, o, pool):
            m = [nn.Conv2d(i, o, 3, padding=1, bias=False), nn.BatchNorm2d(o), nn.ReLU()]
            if pool: m.append(nn.MaxPool2d(pool))
            return m
        self.cnn = nn.Sequential(*blk(1, 16, (2, 2)), *blk(16, 32, (2, 1)), *blk(32, 48, (2, 1)), *blk(48, 64, (2, 1)))
        # Höhe 48 -> 24 -> 12 -> 6 -> 3, Breite 240 -> 120
        self.collapse = nn.Sequential(nn.Conv2d(64, 96, (3, 1), bias=False), nn.BatchNorm2d(96), nn.ReLU())
        self.seq = nn.Sequential(nn.Conv1d(96, 96, 5, padding=2, bias=False), nn.BatchNorm1d(96), nn.ReLU(),
                                 nn.Conv1d(96, 96, 5, padding=2, bias=False), nn.BatchNorm1d(96), nn.ReLU(),
                                 nn.Conv1d(96, NC, 1))
    def forward(self, x):                 # x: N,1,48,240 in 0..1
        m = x.mean((2, 3), keepdim=True); s = x.std((2, 3), keepdim=True) + 0.02
        x = (x - m) / s
        x = self.collapse(self.cnn(x)).squeeze(2)
        return self.seq(x)                # N,C,T

def decode(logits):
    p = logits.softmax(1); best = p.argmax(1); out = []
    for b in range(best.shape[0]):
        s = ''; conf = 1.0; prev = 0; run = 0.0
        for t in range(best.shape[1]):
            k = int(best[b, t]); pk = float(p[b, k, t])
            if k != 0 and k != prev: s += L.CHARS[k - 1]; run = pk; conf = min(conf, pk) if s else conf
            elif k != 0 and k == prev: pass
            prev = k
        # Sicherheit: kleinste Wahrscheinlichkeit eines gelesenen Zeichens (grob)
        mins = []
        prev = 0
        for t in range(best.shape[1]):
            k = int(best[b, t])
            if k != 0 and k != prev: mins.append(float(p[b, k, t]))
            elif k != 0 and mins: mins[-1] = max(mins[-1], float(p[b, k, t]))
            prev = k
        out.append((s, min(mins) if mins else 1.0))
    return out

def real_eval(net, n=24, verbose=False):
    net.eval(); rng = np.random.default_rng(5); res = {}
    with torch.no_grad():
        for nr in RT.ZIFFERN:
            vs = RT.variants(nr, rng, n); X = torch.tensor(np.stack([v[0] for v in vs]), dtype=torch.float32)[:, None] / 255
            res[nr] = (RT.ZIFFERN[nr][1], decode(net(X)))
    return res

def norm(s): return s.replace('.', '')

def report(res, thr=0.0):
    ok = wrong = none = 0; per = {}
    for nr, (soll, outs) in res.items():
        o = w = z = 0
        for s, c in outs:
            if c < thr or not s: z += 1
            elif s.lstrip('0') == soll.lstrip('0') or (s == soll): o += 1
            else: w += 1
        per[nr] = (o, w, z); ok += o; wrong += w; none += z
    return ok, wrong, none, per

if __name__ == '__main__':
    data = sys.argv[3] if len(sys.argv) > 3 else 'train.npz'
    d = np.load(data, allow_pickle=True); X = d['X']; T = list(d['T'])
    v = np.load('val2.npz', allow_pickle=True); XV = torch.tensor(v['X'], dtype=torch.float32)[:, None] / 255; TV = list(v['T'])
    net = Net(); print(sum(p.numel() for p in net.parameters()), 'Gewichte')
    if len(sys.argv) > 2 and sys.argv[2] != '-': net.load_state_dict(torch.load(sys.argv[2])); print('weiter ab', sys.argv[2])
    peak = float(sys.argv[4]) if len(sys.argv) > 4 else 3e-3
    out_name = sys.argv[5] if len(sys.argv) > 5 else 'net.pt'
    EP = int(sys.argv[1]); BS = 128
    opt = torch.optim.AdamW(net.parameters(), 2e-3, weight_decay=1e-4)
    steps = EP * (len(X) // BS); sched = torch.optim.lr_scheduler.OneCycleLR(opt, peak, total_steps=steps, pct_start=0.15)
    ctc = nn.CTCLoss(blank=0, zero_infinity=True)
    ids = [L.label_ids(t) for t in T]
    t0 = time.time()
    for ep in range(EP):
        net.train(); perm = np.random.permutation(len(X)); tot = 0
        for bi in range(len(X) // BS):
            idx = perm[bi * BS:(bi + 1) * BS]
            x = torch.tensor(X[idx], dtype=torch.float32)[:, None] / 255
            # leichte Zusatzänderungen: Helligkeit, Kontrast, Rauschen
            x = x * torch.empty(len(idx), 1, 1, 1).uniform_(0.8, 1.2) + torch.empty(len(idx), 1, 1, 1).uniform_(-0.08, 0.08)
            x = x + torch.randn_like(x) * 0.01
            tg = [ids[i] for i in idx]
            tgt = torch.tensor(sum(tg, []), dtype=torch.long); tl = torch.tensor([len(t) for t in tg])
            lg = net(x); lp = lg.log_softmax(1).permute(2, 0, 1)
            loss = ctc(lp, tgt, torch.full((len(idx),), lg.shape[2], dtype=torch.long), tl)
            opt.zero_grad(); loss.backward(); nn.utils.clip_grad_norm_(net.parameters(), 5); opt.step(); sched.step(); tot += float(loss.detach())
        net.eval()
        with torch.no_grad(): dv = decode(net(XV))
        acc = np.mean([a == b for (a, _), b in zip(dv, TV)])
        ok, wrong, none, per = report(real_eval(net))
        print(f'Epoche {ep+1}/{EP} Verlust {tot/(len(X)//BS):.3f} synth-richtig {acc:.3f} echt: richtig {ok} falsch {wrong} nichts {none} | {per} | {time.time()-t0:.0f}s', flush=True)
        torch.save(net.state_dict(), out_name)
