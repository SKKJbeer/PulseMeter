"""Nachgebaute Kennzahl-Fenster für das Kennzahl-Netz (Kamera Stufe 2, docs/kamera/stufe-2.md).

Das Fenster liegt fest am Rahmen, den der Nutzer auf die Hauptziffern legt (`ObisWindow` in PulseCore):
FH = 1,3 Rahmenhöhen (hc) hoch, im Verhältnis 5 : 1, seine Mitte FX = 0,8 hc rechts der linken
Rahmenkante und FY = 0,3 hc über der Rahmenmitte. So liegen beide Bauarten darin, die die Fotos zeigen:
die Kennzahl links neben der Zahl (Landis, Logarex) und links darüber (Kaifa, Kamstrup). Ein Rahmen ist
fast immer breiter als die Zahl, deshalb steht die Kennzahl meist noch IM Rahmen, links.

Die Hauptzahl ragt von rechts herein.

**Soll** ist die kleine Nebenzahl an der Stelle einer Kennzahl, so wie sie dasteht („1.8.0“, „180“,
„004“), sonst leer. Was davon eine Kennzahl ist, entscheidet die Regel in PulseCore, nicht das Netz.
Die Hauptzahl, Einheiten, Wörter und das Typenschild sind nie Soll."""
import cv2, numpy as np
import synth as L

IH, IW = L.IH, L.IW
FH, FX, FY = 1.3, 0.8, 0.3
HC = IH / FH                                   # eine Rahmenhöhe in Fensterpunkten
RAHMEN_LINKS = IW / 2 - FX * HC                # linke Rahmenkante in Fensterpunkten
MITTE_X = RAHMEN_LINKS + 2.5 * HC; MITTE_Y = IH / 2 + FY * HC
BEKANNT = ['1.8.0', '1.8.1', '1.8.2', '2.8.0', '2.8.1', '2.8.2']
ANDERE = ['1.8.3', '1.8.4', '2.8.3', '1.7.0', '2.7.0', '3.8.0', '4.8.0', '0.9.1', '0.9.2', '1.6.0', '15.8.0', '16.7.0', '1.8.0', '2.8.0']
INDEX = ['004', '92', '012', '009', '01', '00', '62', '016', '1', '2', '001', '018', '028', '3']


def kz_text(rng):
    r = rng.random()
    if r < 0.62: k = BEKANNT[int(rng.integers(0, len(BEKANNT)))]
    elif r < 0.8: k = ANDERE[int(rng.integers(0, len(ANDERE)))]
    else: return INDEX[int(rng.integers(0, len(INDEX)))]
    q = rng.random()
    if q < 0.35: k = k.replace('.', '')                      # „180“: Display ohne Punkte (Logarex)
    elif q < 0.45 and k.count('.') == 2:                       # „18.0“, „1.80“: ein Punkt fehlt
        i = k.index('.') if rng.random() < .5 else k.rindex('.'); k = k[:i] + k[i + 1:]
    return k


def style(rng):
    s = dict(aspect=rng.uniform(0.42, 0.66), thick=rng.uniform(0.06, 0.23), gap=rng.uniform(0.0, 0.07),
             slant=rng.choice([0, 0, 0, rng.uniform(3, 18)]), chamfer=rng.uniform(0, 1), space=rng.uniform(0.14, 0.5),
             variant=int(rng.integers(0, 8)), dot=rng.uniform(1.0, 1.9))
    return s


def zeile(rng, text, hd, st, ghost, origin, font=None):
    if font is not None:
        letter, shear, _ = font
        return L.draw_line_font(rng, text, hd, font[2], letter, ghost, (IH, IW), origin, shear)
    return L.draw_line(rng, text, hd, st, 1.0, ghost, (IH, IW), origin)


def breite(text, hd, st, font):
    if font is not None: return L.font_metrics(font[2], text, font[0])[0] * hd
    nd = sum(1 for c in text if c in L.SEGS)
    return nd * (st['aspect'] + st['space']) * hd + 0.4 * text.count('.') * 0


def sample(rng):
    m = rng.uniform(1.25, 2.8)                      # Rahmenhöhe / Ziffernhöhe: Wer die Zahl in den Rahmen legt, füllt ihn
    haupt = L.rand_text(rng).replace(':', '')
    st = style(rng)
    font = None
    if L.FONT_FILES and rng.random() < 0.55:
        font = (rng.uniform(0.0, 0.35), rng.choice([0, 0, rng.uniform(-3, 14)]), L.FONT_FILES[int(rng.integers(0, len(L.FONT_FILES)))])
    wph = breite(haupt, 1.0, st, font) + 0.3
    hd = min(HC / m, 5 * HC * 0.9 / wph)            # der Rahmen ist 5 hc breit
    linew = breite(haupt, hd, st, font)
    dx = rng.uniform(-.12, .12) if rng.random() < .85 else rng.uniform(-.25, .25)
    dy = rng.uniform(-.15, .15)
    ox = MITTE_X - linew / 2 + dx * 5 * HC          # linke Kante der Hauptzahl in Fensterpunkten
    oy = MITTE_Y - hd / 2 + dy * HC
    gh = 0.0 if rng.random() < 0.45 else rng.uniform(0.06, 0.3)

    soll = ''
    kz = None
    if rng.random() < 0.65:
        kz = kz_text(rng)
        kst = dict(st) if rng.random() < 0.7 else style(rng)
        kfont = font if (font is not None and rng.random() < 0.7) else None
        for _ in range(6):                          # Lage würfeln, bis die Kennzahl ganz im Fenster steht
            s = hd * rng.uniform(0.45, 0.9)
            kw = breite(kz, s, kst, kfont)
            if rng.random() < 0.5:                  # links daneben, auf der Zeile der Zahl
                kx = ox - rng.uniform(0.2, 1.3) * hd - kw
                ky = oy + (hd - s) * rng.choice([1, 1, 0.5, 0])
            else:                                   # in der Zeile darüber
                ky = oy - rng.uniform(0.1, 0.7) * hd - s
                kx = ox + rng.uniform(-2.5, 0.6) * hd
            if kx > 2 and kx + kw < IW - 2 and ky > 1 and ky + s < IH - 1:
                soll = kz; break
        if not soll:
            kz = None
    wort = None
    if not soll and rng.random() < 0.35 and L.FONT14_FILES:
        wort = str(rng.choice(['E.T2', 'E.T1', 'ET1', 'ET2', 'T1', 'T2', 'T 2', 'A+', 'A-', 'P', 'Pin', 'L1', 'Er', 'E01', 'tAr2', 'HT', 'NT', 'r1', 'r2', 'In', 'Out']))
        ws = hd * rng.uniform(0.4, 0.9)
        if rng.random() < 0.5: wx, wy = ox - rng.uniform(0.2, 1.3) * hd - ws * 2.2, oy + (hd - ws) * rng.choice([1, 0.5, 0])
        else: wx, wy = ox + rng.uniform(-2.5, 0.6) * hd, oy - rng.uniform(0.1, 0.7) * hd - ws
    # Bild aufbauen: Gehäuse hell, Anzeige mit eigenem Grund
    bg_disp = rng.uniform(70, 215)
    contrast = rng.choice([rng.uniform(22, 60), rng.uniform(50, 130)])
    sign = 1 if rng.random() < 0.93 else -1
    img = np.full((IH, IW), bg_disp, np.float32)
    yy, xx = np.mgrid[0:IH, 0:IW].astype(np.float32)
    img += rng.uniform(-30, 30) * (xx / IW - .5) + rng.uniform(-30, 30) * (yy / IH - .5)
    links = min(ox, kx if kz else ox) - rng.uniform(0.3, 2.0) * hd
    oben = min(oy, ky if kz else oy) - rng.uniform(0.2, 1.2) * hd
    gehaeuse = np.zeros((IH, IW), np.float32)
    if rng.random() < 0.85 and links > 3:
        gehaeuse[:, :int(links)] = 1
    if rng.random() < 0.6 and oben > 2:
        gehaeuse[:int(oben), :] = 1
    if gehaeuse.any():
        hb = rng.uniform(120, 245)
        img = img * (1 - gehaeuse) + (hb + rng.normal(0, 3, img.shape)) * gehaeuse
        # Rand der Anzeige
        if rng.random() < 0.7:
            c = float(rng.uniform(30, 110))
            if links > 3: cv2.line(img, (int(links), int(max(0, oben))), (int(links), IH), c, int(rng.integers(1, 4)))
            if oben > 2: cv2.line(img, (int(max(0, links)), int(oben)), (IW, int(oben)), c, int(rng.integers(1, 4)))
        # Aufdruck auf dem Gehäuse: Typ, Klasse, Nummern. Nie Soll.
        mk = np.zeros((IH, IW), np.uint8)
        for _ in range(int(rng.integers(0, 4))):
            txt = rng.choice(['Klasse A', 'M24', '1259', 'UC2', 'IP 54', '50 Hz', '230V', '10(60)A', 'E320', 'LGZ', 'BZ-ET', '1000 imp/kWh',
                              'MA105H2', 'DE-M24', '0102', '2024', '5(60)A', 'Nr 4711', 'T1 T2'])
            sc = rng.uniform(0.3, 0.9) * IH / 48
            x = rng.uniform(-20, max(-19, links - 10)); y = rng.uniform(10, IH)
            if rng.random() < 0.5 and oben > 8: x = rng.uniform(0, IW - 30); y = rng.uniform(8, max(9, oben - 2))
            cv2.putText(mk, txt, (int(x), int(y)), int(rng.choice(L.FONTS[:4])), sc, 255, int(rng.integers(1, 3)), cv2.LINE_AA)
        mk = mk.astype(np.float32) / 255 * gehaeuse
        img -= mk * rng.uniform(60, 140)
    # Hauptzahl (ragt von rechts herein), Kennzahl, Nebenzeichen
    line, xend = zeile(rng, haupt, hd, st, gh, (ox, oy), font)
    ink = line
    if kz:
        kl, _ = zeile(rng, kz, s, kst, gh * rng.uniform(0, 1), (kx, ky), kfont)
        ink = np.maximum(ink, kl)
    elif wort is not None:
        from PIL import Image, ImageDraw
        path = L.FONT14_FILES[int(rng.integers(0, len(L.FONT14_FILES)))]
        f = L.get_font(path, max(6, int(ws * 3 * 1.35)))
        pim = Image.new('L', (IW * 3, IH * 3), 0); ImageDraw.Draw(pim).text((wx * 3, wy * 3), wort, fill=255, font=f)
        ink = np.maximum(ink, cv2.resize(np.asarray(pim, np.float32) / 255, (IW, IH), interpolation=cv2.INTER_AREA))
    elif rng.random() < 0.5:                       # leere Kennzahl-Stelle mit Geistersegmenten „8.8.8“
        s = hd * rng.uniform(0.4, 0.9)
        gx = ox - rng.uniform(0.3, 1.3) * hd - 3 * s * 0.8
        if gx > 2:
            gl, _ = L.draw_line(rng, '8.8.8', s, st, 1.0, 0.0, (IH, IW), (gx, oy + hd - s))
            ink = np.maximum(ink, gl * rng.uniform(0.05, 0.25))
    mk = np.zeros((IH, IW), np.uint8)
    if rng.random() < 0.4:                          # Wörter: INFO, T1, Pfeile
        L.blocky_text(mk, str(rng.choice(['INFO', 'T1', 'T2', 'kWh', 'HT', 'NT', 'A+', 'A-', 'L1 L2 L3', 'PIN'])),
                      rng.uniform(0, IW - 30), rng.uniform(8, IH), hd * rng.uniform(0.25, 0.5), rng)
    if rng.random() < 0.3:
        for _ in range(int(rng.integers(1, 4))):
            s0 = hd * rng.uniform(0.2, 0.5); px, py = rng.uniform(0, IW - s0), rng.uniform(0, IH - s0)
            cv2.fillPoly(mk, [np.array([[px, py + s0], [px + s0, py + s0], [px + s0 / 2, py]], np.int32)], 255)
    ink = np.maximum(ink, mk.astype(np.float32) / 255 * rng.uniform(0.6, 1.0))
    if rng.random() < 0.4: ink = np.maximum(ink, L.letters_layer(rng, hd, max(ox, 0), xend, oy, (IH, IW)) * (xx > 0))
    img -= sign * ink * contrast
    if rng.random() < 0.4: img = img + L.reflection(rng, (IH, IW))
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
    return img, soll


def sample_any(rng):
    if rng.random() < 0.1:
        img, _ = L.negative(rng); return img, ''
    return sample(rng)


if __name__ == '__main__':
    import sys
    rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
    tiles = [sample(rng) for _ in range(16)]
    for _, t in tiles: print(repr(t))
    cv2.imwrite('/tmp/kz/synth.png', np.vstack([t for t, _ in tiles]))
