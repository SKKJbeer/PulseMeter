"""Flächengemittelte Verkleinerung, Punkt für Punkt wie GrayImage.resampled in Swift und das Gegenstück im Klick-Dummy."""
import math, numpy as np

def weights(start, length, count, limit):
    step = length / count; rows = []
    for o in range(count):
        a = start + o * step; b = a + step; e = {}
        i = math.floor(a)
        while i < b:
            ov = min(b, i + 1) - max(a, i)
            if ov > 0: e[min(max(i, 0), limit - 1)] = e.get(min(max(i, 0), limit - 1), 0) + ov
            i += 1
        if not e: e[min(max(math.floor(a), 0), limit - 1)] = step
        tot = sum(e.values()); rows.append(sorted((k, v / tot) for k, v in e.items()))
    return rows

def resample(img, x, y, w, h, ow, oh):
    """img: 2D uint8. Ergebnis ow x oh, Werte 0..1 (float32)."""
    H, W = img.shape
    ry = weights(y, h, oh, H); rx = weights(x, w, ow, W)
    Ay = np.zeros((oh, H), np.float64); Ax = np.zeros((ow, W), np.float64)
    for i, r in enumerate(ry):
        for k, v in r: Ay[i, k] = v
    for i, r in enumerate(rx):
        for k, v in r: Ax[i, k] = v
    return ((Ay @ img.astype(np.float64) @ Ax.T) / 255).astype(np.float32)
