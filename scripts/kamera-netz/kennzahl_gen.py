"""Trainingsdaten für das Kennzahl-Netz: python3 kennzahl_gen.py <Anzahl> <Datei.npz> <Anfangswert>"""
import numpy as np, sys
from multiprocessing import Pool
import kennzahl_synth as K
def work(a):
    seed, n = a; rng = np.random.default_rng(seed)
    X = np.zeros((n, K.IH, K.IW), np.uint8); T = []
    for i in range(n):
        X[i], t = K.sample_any(rng); T.append(t)
    return X, T
if __name__ == '__main__':
    total = int(sys.argv[1]); out = sys.argv[2]; base = int(sys.argv[3])
    per = total // 16
    with Pool(4) as p: res = p.map(work, [(base + i, per) for i in range(16)])
    X = np.concatenate([r[0] for r in res]); T = sum([r[1] for r in res], [])
    np.savez_compressed(out, X=X, T=np.array(T, dtype=object), allow_pickle=True)
    print(X.shape, len(T), 'mit Kennzahl:', sum(1 for t in T if t))
