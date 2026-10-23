"""Synthetische Siebensegment-Anzeigen für das Training. Alles Zufall mit festem Anfangswert."""
import cv2, numpy as np, math, os, glob
from PIL import Image, ImageDraw, ImageFont

# Echte Siebensegment-Schriften (DSEG, SIL Open Font License) als zweite Quelle für die Ziffern.
# Nur im Training benutzt; in der App läuft das Netz, nicht die Schrift.
FONT_DIR = os.environ.get('DSEG_DIR', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dseg'))
FONT_FILES = sorted(glob.glob(FONT_DIR + '/DSEG7*.ttf'))
FONT14_FILES = sorted(glob.glob(FONT_DIR + '/DSEG14*.ttf'))
WORDS = ['REC', 'kWh', 'KWH', 'kW', 'Wh', 'Norm', 'NORM', 'T1', 'T2', 'L1', 'L2', 'F1', 'MAX', 'Err', 'ERR', 'A', 'V', 'm3', 'MWh', 'tot', 'TOT', 'In', 'OUT', 'LOAD', 'Hz', 'CUM']
_fonts = {}
def get_font(path, size):
    k = (path, int(size))
    if k not in _fonts: _fonts[k] = ImageFont.truetype(path, int(size))
    return _fonts[k]

def font_metrics(path, text, letter):
    """Breite der Zeile bezogen auf die Ziffernhöhe, und Abstand der Oberkante zur Textposition."""
    f = get_font(path, 100); b = f.getbbox('0'); h = b[3] - b[1]
    w = sum(f.getlength(c) for c in text) + letter * h * max(0, len(text) - 1)
    return w / h, b[1], h

def draw_line_font(rng, text, hd, path, letter, ghost, canvas_shape, origin, shear, ss=3, jit=0.0):
    Hc, Wc = canvas_shape
    wph, top100, h100 = font_metrics(path, text, letter)
    size = 100 * hd * ss / h100
    f = get_font(path, size); top = f.getbbox('0')[1]
    def render(txt, fill):
        im = Image.new('L', (Wc * ss, Hc * ss), 0); d = ImageDraw.Draw(im); x = origin[0] * ss
        for c in txt:
            d.text((x, origin[1] * ss - top), c, fill=fill, font=f); x += f.getlength(c) + letter * hd * ss * (1 + jit * rng.uniform(0, 1.5))
        return np.asarray(im, np.float32) / 255
    img = render(text, 255)
    if ghost > 0:
        g = render(''.join('8' if c.isdigit() else c for c in text), 255) * ghost
        img = np.maximum(img, g)
    if abs(shear) > 1e-3:
        t = math.tan(math.radians(shear)); y0 = (origin[1] + hd / 2) * ss
        M = np.float32([[1, t, -t * y0], [0, 1, 0]])
        img = cv2.warpAffine(img, M, (Wc * ss, Hc * ss))
    return cv2.resize(img, (Wc, Hc), interpolation=cv2.INTER_AREA), origin[0] + wph * hd

IH, IW = 48, 240              # Eingabe des Netzes
CHARS = "0123456789.:"         # Klasse 0 ist 'leer' (CTC), Zeichen k hat Klasse k+1
SEGS = {  # a b c d e f g
    '0': 'abcdef', '1': 'bc', '2': 'abged', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd',
    '6': 'afgedc', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg'}

def poly_h(x0, x1, yc, t, chamfer):
    c = t / 2 * chamfer
    return [(x0, yc), (x0 + c, yc - t / 2), (x1 - c, yc - t / 2), (x1, yc), (x1 - c, yc + t / 2), (x0 + c, yc + t / 2)]

def poly_v(xc, y0, y1, t, chamfer):
    c = t / 2 * chamfer
    return [(xc, y0), (xc + t / 2, y0 + c), (xc + t / 2, y1 - c), (xc, y1), (xc - t / 2, y1 - c), (xc - t / 2, y0 + c)]

def digit_polys(ch, w, h, t, g, chamfer, variant):
    segs = SEGS[ch]
    if ch == '6' and variant & 1: segs = segs.replace('a', '')
    if ch == '9' and variant & 2: segs = segs.replace('d', '')
    if ch == '7' and variant & 4: segs += 'f'
    P = {}
    P['a'] = poly_h(t * .5 + g, w - t * .5 - g, t / 2, t, chamfer)
    P['g'] = poly_h(t * .5 + g, w - t * .5 - g, h / 2, t, chamfer)
    P['d'] = poly_h(t * .5 + g, w - t * .5 - g, h - t / 2, t, chamfer)
    P['b'] = poly_v(w - t / 2, t * .5 + g, h / 2 - g - t * .1, t, chamfer)
    P['c'] = poly_v(w - t / 2, h / 2 + g + t * .1, h - t * .5 - g, t, chamfer)
    P['f'] = poly_v(t / 2, t * .5 + g, h / 2 - g - t * .1, t, chamfer)
    P['e'] = poly_v(t / 2, h / 2 + g + t * .1, h - t * .5 - g, t, chamfer)
    return {k: P[k] for k in P}, segs

def draw_line(rng, text, hd, style, ink, ghost, canvas_shape, origin, ss=3):
    """Zeichnet eine Ziffernzeile (Tinte = Wert 1.0, Geister = ghost) in ein Float-Bild. Gibt Breite zurück."""
    Hc, Wc = canvas_shape
    img = np.zeros((Hc * ss, Wc * ss), np.float32)
    w = hd * style['aspect']; t = hd * style['thick']; g = hd * style['gap']
    sh = math.tan(math.radians(style['slant']))
    x = origin[0]; y0 = origin[1]
    def tr(pts, ox):
        return np.array([[(ox + px + (hd - py) * sh) * ss, (y0 + py) * ss] for px, py in pts], np.int32)
    for ch in text:
        if ch in SEGS:
            polys, segs = digit_polys(ch, w, hd, t, g, style['chamfer'], style['variant'])
            if ghost > 0:
                for k, p in polys.items():
                    if k not in segs: cv2.fillPoly(img, [tr(p, x)], ghost)
            for k in segs: cv2.fillPoly(img, [tr(polys[k], x)], 1.0)
            x += w + style['space'] * hd
        elif ch == '.':
            d = max(t * style['dot'], 1.5)
            cx = x - style['space'] * hd * .5; cy = hd - d / 2
            pts = [(cx - d / 2, cy - d / 2), (cx + d / 2, cy - d / 2), (cx + d / 2, cy + d / 2), (cx - d / 2, cy + d / 2)]
            cv2.fillPoly(img, [tr(pts, 0)], 1.0)
            x += style['space'] * hd * .15
        elif ch == ':':
            d = max(t * style['dot'], 1.5)
            cx = x - style['space'] * hd * .5
            for cy in (hd * .32, hd * .68):
                pts = [(cx - d / 2, cy - d / 2), (cx + d / 2, cy - d / 2), (cx + d / 2, cy + d / 2), (cx - d / 2, cy + d / 2)]
                cv2.fillPoly(img, [tr(pts, 0)], 1.0)
            x += style['space'] * hd * .15
    return cv2.resize(img, (Wc, Hc), interpolation=cv2.INTER_AREA), x

def letters_layer(rng, hd, ox, xend, oy, canvas_shape, ss=3):
    """Wörter in 14-Segment-Schrift als Nebenzeichen: rechts als Einheit, links in Ziffernhöhe (REC), oder klein darunter/darüber."""
    Hc, Wc = canvas_shape; layer = np.zeros((Hc * ss, Wc * ss), np.float32)
    if not FONT14_FILES: return np.zeros((Hc, Wc), np.float32)
    im = Image.new('L', (Wc * ss, Hc * ss), 0); d = ImageDraw.Draw(im)
    for _ in range(int(rng.integers(1, 3))):
        path = FONT14_FILES[int(rng.integers(0, len(FONT14_FILES)))]; word = WORDS[int(rng.integers(0, len(WORDS)))]
        kind = rng.random()
        if kind < 0.35: h = hd * rng.uniform(0.9, 1.05); region = 'links'
        elif kind < 0.7: h = hd * rng.uniform(0.3, 0.8); region = 'rechts'
        else: h = hd * rng.uniform(0.25, 0.55); region = 'unten'
        f0 = get_font(path, 100); b0 = f0.getbbox('E'); h100 = b0[3] - b0[1]
        f = get_font(path, 100 * h * ss / h100); top = f.getbbox('E')[1]; w = sum(f.getlength(c) for c in word) / ss
        if region == 'links':
            if ox - w - 0.1 * Wc < 2: continue
            x = rng.uniform(2, ox - w - 0.1 * Wc); y = oy + (hd - h) * rng.choice([0, 0.5, 1])
        elif region == 'rechts':
            x = xend + rng.uniform(1, 8)
            if x + w > Wc - 2: continue
            y = oy + hd - h
        else:
            x = rng.uniform(2, max(3, Wc - w - 2)); y = oy + hd + rng.uniform(0.15, 0.5) * hd
            if y + h > Hc - 1: continue
        d.text((x * ss, y * ss - top), word, fill=255, font=f)
    layer = np.asarray(im, np.float32) / 255
    return cv2.resize(layer, (Wc, Hc), interpolation=cv2.INTER_AREA)

def reflection(rng, shape):
    """Spiegelung im Glas: weiche helle Bänder und Flecken, die auch über die Ziffern laufen."""
    Hc, Wc = shape; m = np.zeros((Hc, Wc), np.float32)
    for _ in range(int(rng.integers(1, 4))):
        if rng.random() < 0.5:
            pts = np.array([[rng.uniform(-20, Wc), rng.uniform(-10, Hc)] for _ in range(4)], np.int32); cv2.fillConvexPoly(m, pts, 1.0)
        else:
            cv2.ellipse(m, (int(rng.uniform(0, Wc)), int(rng.uniform(0, Hc))), (int(rng.uniform(10, 90)), int(rng.uniform(4, 30))), rng.uniform(0, 180), 0, 360, 1.0, -1)
    return cv2.GaussianBlur(m, (0, 0), rng.uniform(3, 12)) * rng.uniform(15, 70) * rng.choice([1, 1, -0.6])

def rand_text(rng):
    r = rng.random()
    if r < 0.12:    # Uhrzeit oder Datum: darf nie als Stand gelten, wird als solche gelesen
        a = ["%02d" % rng.integers(0, 60) for _ in range(3)]
        return rng.choice([':', ':', '.']).join(a)
    if r < 0.62:    # Ein Zählwerk fester Breite mit führenden Nullen. Neue Zähler stehen bei kleinen Zahlen:
        # 000000, 000010, 00001. Gleichverteilte Ziffern erzeugen die kaum, und dünne Einsen unter vielen Nullen
        # waren genau das, was das Netz auf unbekannten Fotos verlor.
        n = int(rng.integers(4, 9))
        v = 0 if rng.random() < 0.05 else int(10 ** rng.uniform(0, n))
        digs = str(min(v, 10 ** n - 1)).zfill(n)
        if rng.random() < 0.3 and n >= 4:
            k = int(rng.integers(1, 4)); digs = digs[:n - k] + '.' + digs[n - k:]
        return digs
    n = int(rng.integers(3, 9))
    digs = ''.join(str(int(rng.integers(0, 10))) for _ in range(n))
    if rng.random() < 0.35:  # führende Nullen
        z = int(rng.integers(1, max(2, n)))
        digs = '0' * z + digs[z:]
    if rng.random() < 0.3 and n >= 3:   # Komma
        p = int(rng.integers(1, n)); digs = digs[:p] + '.' + digs[p:]
    return digs

def blocky_text(mk, txt, x, y, h, rng, fill=255):
    """Einheit oder Beschriftung im Display: kantige Buchstaben, so hoch wie h (Grundlinie bei y)."""
    font = int(rng.choice([cv2.FONT_HERSHEY_SIMPLEX, cv2.FONT_HERSHEY_DUPLEX, cv2.FONT_HERSHEY_COMPLEX]))
    scale = max(0.25, h / 22.0)
    cv2.putText(mk, txt, (int(x), int(y)), font, scale, fill, max(1, int(scale * rng.uniform(1.4, 2.6))), cv2.LINE_AA)

def sample(rng):
    """Ein Trainingsbild (IH x IW, uint8) und der Soll-Text. Soll ist nur die Hauptzahl: die großen
    Ziffern in der Mitte. Einheit, Kennzahl, Tarifziffer und Symbole sind Nebenzeichen."""
    text = rand_text(rng)
    style = dict(aspect=rng.uniform(0.42, 0.66), thick=rng.uniform(0.05, 0.23), gap=rng.uniform(0.0, 0.07),
                 slant=rng.choice([0, 0, rng.uniform(3, 28)]) * rng.choice([1, 1, 1, 0]),
                 chamfer=rng.uniform(0, 1), space=rng.uniform(0.14, 0.5), variant=int(rng.integers(0, 8)),
                 dot=rng.uniform(1.0, 1.9))
    if style['slant'] == 0 and rng.random() < 0.15: style['slant'] = -rng.uniform(1, 4)
    ndig = sum(1 for c in text if c in SEGS)
    font_path = None
    if FONT_FILES and rng.random() < 0.55:
        font_path = FONT_FILES[int(rng.integers(0, len(FONT_FILES)))]
        letter = rng.uniform(0.0, 0.35); fshear = rng.choice([0, 0, rng.uniform(-3, 14)])
        linew_per_h = font_metrics(font_path, text, letter)[0]
    else:
        linew_per_h = ndig * (style['aspect'] + style['space']) + 0.4 * text.count('.') + 0.2 * text.count(':')
    m = rng.uniform(1.3, 3.2)                       # Bildhöhe / Ziffernhöhe
    hd = min(IH / m, IW * 0.9 / (linew_per_h + 0.3))
    if hd < 11: hd = 11
    CH, CW = IH, IW
    linew = linew_per_h * hd
    if rng.random() < 0.8:      # der Nutzer legt die Zahl in die Mitte des Rahmens
        ox = (IW - linew) / 2 + rng.uniform(-0.12, 0.12) * IW
        oy = (IH - hd) / 2 + rng.uniform(-0.12, 0.12) * IH
    else:
        ox = rng.uniform(0.02 * IW, max(0.03 * IW, IW - linew - 0.02 * IW)); oy = rng.uniform(0.04 * IH, max(0.05 * IH, IH - hd - 0.04 * IH))
    ox = min(max(ox, 0.02 * IW), max(0.03 * IW, IW - linew - 0.02 * IW)); oy = min(max(oy, 0.03 * IH), max(0.04 * IH, IH - hd - 0.03 * IH))
    bg = rng.uniform(70, 225)
    contrast = rng.choice([rng.uniform(22, 60), rng.uniform(50, 130)])
    dark_on_light = rng.random() < 0.93
    sign = 1 if dark_on_light else -1
    gh = 0.0 if rng.random() < 0.45 else rng.uniform(0.06, 0.3)
    if font_path:
        line, xend = draw_line_font(rng, text, hd, font_path, letter, gh, (CH, CW), (ox, oy), fshear, jit=0.0)
    else:
        line, xend = draw_line(rng, text, hd, style, 1.0, gh, (CH, CW), (ox, oy))
    img = np.full((CH, CW), bg, np.float32)
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    img += rng.uniform(-30, 30) * (xx / CW - .5) + rng.uniform(-30, 30) * (yy / CH - .5)
    if rng.random() < 0.4:
        cx, cy, sg = rng.uniform(0, CW), rng.uniform(0, CH), rng.uniform(20, 120)
        img += rng.uniform(-40, 60) * np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * sg * sg))
    if rng.random() < 0.6:
        for _ in range(int(rng.integers(1, 4))):
            thick = int(rng.integers(1, 4)); col = bg - rng.uniform(30, 120) * rng.choice([1, 1, -0.5])
            if rng.random() < .5:
                yv = int(rng.uniform(0, oy * .8) if (rng.random() < .5 or oy + hd * 1.15 >= IH) else rng.uniform(oy + hd * 1.15, IH))
                cv2.line(img, (0, yv), (IW, yv), float(col), thick)
            else:
                xv = int(rng.uniform(0, IW)); cv2.line(img, (xv, 0), (xv, IH), float(col), thick)
    # Nebenzeichen, jeweils nur wo Platz ist. Sie tragen die Tinte des Displays, aber ihr Soll ist leer.
    ink_extra = np.zeros((CH, CW), np.float32)
    mk = np.zeros((CH, CW), np.uint8)
    free_left, free_right = ox - 0.1 * IW, IW - xend - 0.04 * IW
    if rng.random() < 0.8 and free_right > 14:      # Einheit rechts, fast so hoch wie die Ziffern
        h = hd * rng.uniform(0.4, 0.9)
        blocky_text(mk, rng.choice(["kWh", "kW h", "m3", "kWh", "m\u00b3", "h", "kW", "Wh", "kWh"]), min(xend + 1 + rng.uniform(0, 5), IW - 12), min(oy + hd, IH - 2), h, rng)
    if rng.random() < 0.65 and free_left > 20:       # kleine Ziffern links: Kennzahl, Tarif, Zählerindex
        small = hd * rng.uniform(0.3, 0.7)
        extra, _ = draw_line(rng, rng.choice(["180", "004", "18", "1.8.0", "001", "8", "1.8.1"]), small, dict(style), 1.0, 0.0, (CH, CW),
                             (rng.uniform(1, max(2, free_left - 0.35 * small * 3)), oy + (hd - small) * rng.choice([0, 0.5, 1])))
        ink_extra = np.maximum(ink_extra, extra)
    if rng.random() < 0.35 and (free_left > hd * 1.4 or free_right > hd * 1.4):   # große Tarifziffer, mit Abstand
        wd = hd * style['aspect']
        if free_left > hd * 1.4 and (rng.random() < 0.6 or free_right <= hd * 1.4):
            x0 = rng.uniform(1, max(2, ox - wd - 0.12 * IW))
        else:
            x0 = min(IW - wd - 2, xend + 0.12 * IW + rng.uniform(0, 10))
        if x0 > 0 and x0 + wd < IW and (x0 + wd < ox - 0.08 * IW or x0 > xend + 0.08 * IW):
            extra, _ = draw_line(rng, str(int(rng.integers(0, 10))), hd, dict(style), 1.0, 0.0, (CH, CW), (x0, oy))
            ink_extra = np.maximum(ink_extra, extra)
    if rng.random() < 0.3:                            # Symbole: Dreieck, Pfeil, Balken, Kästchen
        for _ in range(int(rng.integers(1, 4))):
            s0 = hd * rng.uniform(0.2, 0.5)
            px, py = rng.uniform(0, IW - s0), rng.uniform(0, IH - s0)
            if px + s0 > ox - 3 and px < xend + 3 and py + s0 > oy - 2 and py < oy + hd + 2: continue
            k = rng.integers(0, 3)
            if k == 0: cv2.fillPoly(mk, [np.array([[px, py + s0], [px + s0, py + s0], [px + s0 / 2, py]], np.int32)], 255)
            elif k == 1: cv2.rectangle(mk, (int(px), int(py)), (int(px + s0), int(py + s0 * 0.5)), 255, -1)
            else: cv2.line(mk, (int(px), int(py)), (int(px + s0), int(py + s0)), 255, max(1, int(s0 / 5)))
    ink_extra = np.maximum(ink_extra, mk.astype(np.float32) / 255)
    if rng.random() < 0.5: ink_extra = np.maximum(ink_extra, letters_layer(rng, hd, ox, xend, oy, (CH, CW)))
    img -= sign * ink_extra * contrast * rng.uniform(0.6, 1.0)
    img -= sign * line * contrast
    if rng.random() < 0.4: img = img + reflection(rng, (CH, CW))
    ang = rng.uniform(-3, 3)
    M = cv2.getRotationMatrix2D((IW / 2, IH / 2), ang, 1.0)
    img = cv2.warpAffine(img, M, (IW, IH), borderMode=cv2.BORDER_REPLICATE)
    if rng.random() < .5:
        d = rng.uniform(0, 0.05) * IW
        src = np.float32([[0, 0], [IW, 0], [IW, IH], [0, IH]]); dst = src + rng.uniform(-d, d, (4, 2)).astype(np.float32) * np.float32([1, .4])
        img = cv2.warpPerspective(img, cv2.getPerspectiveTransform(src, dst), (IW, IH), borderMode=cv2.BORDER_REPLICATE)
    img = cv2.GaussianBlur(img, (0, 0), rng.uniform(0.3, 1.8))
    img += rng.normal(0, rng.uniform(0.5, 7), img.shape)
    img = np.clip(img, 0, 255).astype(np.uint8)
    if rng.random() < .6:
        q = int(rng.integers(35, 92)); ok, buf = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, q]); img = cv2.imdecode(buf, 0)
    return img, text

FONTS = [cv2.FONT_HERSHEY_SIMPLEX, cv2.FONT_HERSHEY_DUPLEX, cv2.FONT_HERSHEY_COMPLEX, cv2.FONT_HERSHEY_TRIPLEX,
         cv2.FONT_HERSHEY_PLAIN, cv2.FONT_HERSHEY_SCRIPT_SIMPLEX]

def negative(rng):
    """Kein Siebensegment im Bild: Soll ist leer. Gedruckte Ziffern (Typenschild) gehören dazu."""
    bg = rng.uniform(60, 230)
    img = np.full((IH, IW), bg, np.float32)
    yy, xx = np.mgrid[0:IH, 0:IW].astype(np.float32)
    img += rng.uniform(-30, 30) * (xx / IW - .5) + rng.uniform(-30, 30) * (yy / IH - .5)
    kind = rng.random()
    mk = np.zeros((IH, IW), np.uint8)
    if kind < 0.6:
        for _ in range(int(rng.integers(1, 4))):
            txt = ''.join(rng.choice(list("0123456789ABCDEFGHKLMNPRSTUVWkWhm/-.()")) for _ in range(int(rng.integers(2, 10))))
            sc = rng.uniform(0.5, 1.8)
            cv2.putText(mk, txt, (int(rng.uniform(-10, IW * .6)), int(rng.uniform(14, IH))), int(rng.choice(FONTS)), sc, 255, int(rng.integers(1, 3)), cv2.LINE_AA)
    elif kind < 0.85:
        for _ in range(int(rng.integers(1, 6))):
            if rng.random() < .5: cv2.line(mk, (0, int(rng.uniform(0, IH))), (IW, int(rng.uniform(0, IH))), 255, int(rng.integers(1, 4)))
            else: cv2.rectangle(mk, (int(rng.uniform(0, IW)), int(rng.uniform(0, IH))), (int(rng.uniform(0, IW)), int(rng.uniform(0, IH))), 255, int(rng.integers(1, 3)))
    if rng.random() < 0.3:      # nur Nebenzeichen: kleine Ziffern und Einheit, deutlich kleiner als jede Hauptzahl
        st = dict(aspect=rng.uniform(0.42, 0.66), thick=rng.uniform(0.05, 0.23), gap=rng.uniform(0.0, 0.07), slant=0.0,
                  chamfer=rng.uniform(0, 1), space=rng.uniform(0.14, 0.5), variant=int(rng.integers(0, 8)), dot=1.2)
        small = rng.uniform(8, 0.22 * IH)
        extra, _ = draw_line(rng, rng.choice(["180", "004", "1.8.0", "18"]), small, st, 1.0, 0.0, (IH, IW),
                             (rng.uniform(2, IW * 0.6), rng.uniform(2, IH - small - 2)))
        mk = np.maximum(mk, (extra * 255).astype(np.uint8))
    img -= mk.astype(np.float32) / 255 * rng.uniform(20, 130) * rng.choice([1, 1, 1, -1])
    img = cv2.GaussianBlur(img, (0, 0), rng.uniform(0.3, 1.6)) + rng.normal(0, rng.uniform(0.5, 6), img.shape)
    return np.clip(img, 0, 255).astype(np.uint8), ""

def sample_any(rng):
    return negative(rng) if rng.random() < 0.16 else sample(rng)

def label_ids(text): return [CHARS.index(c) + 1 for c in text]

if __name__ == '__main__':
    rng = np.random.default_rng(1)
    tiles = [sample(rng) for _ in range(24)]
    rows = []
    for i in range(0, 24, 2):
        rows.append(np.hstack([tiles[i][0], tiles[i + 1][0]]))
    cv2.imwrite('synth.png', np.vstack(rows))
    print([t for _, t in tiles])
