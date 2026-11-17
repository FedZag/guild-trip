"""Guild Trip: Aussehen "Altes Buch" – eigene Zeichnungen (keine fremden Bilder).
Erzeugt:
  src/ONE_Core/Textures/Book/Book.tga      1024x1024, ganzes Fenster: Ledereinband,
                                           aufgeschlagenes Buch mit zwei Seiten und Falz
  src/ONE_Core/Textures/Book/Tab.tga       128x64, Lederreiter des Daumenregisters
  src/ONE_Core/Textures/Book/Seal.tga      64x64, Wachssiegel (Hauptaktion)
  src/ONE_Core/Textures/Book/Wear.tga      1024x1024, Abrieb ueber den Seiten (nur: --wear)
  src/ONE_Core/Textures/Book/TabWorn.tga   128x64, abgegriffener Lederreiter (--tabs)
  src/ONE_Core/Textures/Book/TabIcons.tga  256x256, 4x4 Goldsymbole der Reiter (--tabs)
  scratch: Vorschau als PNG (Pfad als Argument, optional)
Masse in Fenster-Einheiten (774 x 548, wie UI.WINDOW); das Bild reicht 24 Einheiten
ueber das Fenster hinaus (Schatten). Die Falz liegt bei x = 387, genau in der Mitte
der Inhaltsflaeche (contentX 24 + 726/2). Kopfzeilen der Seiten bei y 40..70.
Aufruf: python3 scripts/build_book.py [vorschau.png]   bzw.   python3 scripts/build_book.py --wear [vorschau.png]
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Core' / 'Textures' / 'Book'
W, H = 774, 548          # Fenster
M = 24                   # Rand um das Fenster fuer den Schatten (Bild ist groesser als das Fenster)
S = 2                    # Zeichenmassstab
CW, CH = (W + 2 * M) * S, (H + 2 * M) * S
GUTTER = 387
COVER_L, COVER_R, COVER_T, COVER_B = -9, W + 9, 22, H + 9
PAGE_L, PAGE_R, PAGE_T, PAGE_B = 14, 760, 40, 536
rng = np.random.default_rng(7)


def U(v):
    """Fenster-Einheit -> Bildpunkt"""
    return (v + M) * S


def noise(scale, w=CW, h=CH):
    """Weiches Rauschen 0..1 in der Groesse w x h (Strukturgroesse ~scale Pixel)."""
    sw, sh = max(2, w // scale), max(2, h // scale)
    small = Image.fromarray((rng.random((sh, sw)) * 255).astype(np.uint8))
    big = small.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale / 3))
    a = np.asarray(big).astype(np.float32) / 255
    return (a - a.min()) / max(1e-6, a.max() - a.min())


def dip(x, power=3):
    """0 aussen, 1 an der Falz: das Buch woelbt sich zur Mitte hin nach unten/oben."""
    t = np.clip(np.abs(np.asarray(x, np.float32) - GUTTER) / (GUTTER - COVER_L), 0, 1)
    return (1 - t) ** power


def outline(left, right, top, bottom, sink_top, sink_bottom, radius, inset=0.0):
    """Umriss eines aufgeschlagenen Buchs als Punktliste (Fenster-Einheiten)."""
    l, r = left + inset, right - inset
    pts = []
    xs = np.linspace(l + radius, r - radius, 240)
    # Ecke oben links
    for a in np.linspace(np.pi, 1.5 * np.pi, 10):
        cx, cy = l + radius, top + inset + sink_top * dip(l + radius) + radius
        pts.append((cx + radius * np.cos(a), cy + radius * np.sin(a)))
    for x in xs:
        pts.append((x, top + inset + sink_top * dip(x)))
    for a in np.linspace(1.5 * np.pi, 2 * np.pi, 10):
        cx, cy = r - radius, top + inset + sink_top * dip(r - radius) + radius
        pts.append((cx + radius * np.cos(a), cy + radius * np.sin(a)))
    for a in np.linspace(0, .5 * np.pi, 10):
        cx, cy = r - radius, bottom - inset - sink_bottom * dip(r - radius) - radius
        pts.append((cx + radius * np.cos(a), cy + radius * np.sin(a)))
    for x in xs[::-1]:
        pts.append((x, bottom - inset - sink_bottom * dip(x)))
    for a in np.linspace(.5 * np.pi, np.pi, 10):
        cx, cy = l + radius, bottom - inset - sink_bottom * dip(l + radius) - radius
        pts.append((cx + radius * np.cos(a), cy + radius * np.sin(a)))
    return pts


def mask_of(pts):
    m = Image.new('L', (CW, CH), 0)
    ImageDraw.Draw(m).polygon([(U(x), U(y)) for x, y in pts], fill=255)
    return np.asarray(m) > 127


def cover_pts(inset=0.0):
    return outline(COVER_L, COVER_R, COVER_T, COVER_B, 13, 10, 3, inset)


def page_pts(grow=0.0):
    return outline(PAGE_L - grow, PAGE_R + grow, PAGE_T - grow * .3, PAGE_B + grow, 10, 8, 1)


def fray(mask, strength=4.0):
    """Ausgefranste Papierkante: Kante weichzeichnen und mit feinem Rauschen neu schneiden."""
    soft = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(strength * S * .6))
    v = np.asarray(soft).astype(np.float32) / 255
    jag = .55 * noise(4) + .45 * noise(14)
    return v + (jag - .5) * .9 > .5


def tears(inside, d_page):
    """Kleine Einrisse an den Aussenkanten und ein Eselsohr oben rechts."""
    m = Image.fromarray((inside * 255).astype(np.uint8))
    d = ImageDraw.Draw(m)
    for x, y, dx, dy in ((PAGE_L, 210, 1, 0), (PAGE_R, 330, -1, 0), (150, PAGE_B, 0, -1), (612, PAGE_B - 1, 0, -1), (PAGE_L, 430, 1, 0)):
        w = rng.uniform(3, 6)
        depth = rng.uniform(9, 16)
        if dx:
            pts = [(x - dx * 2, y - w), (x + dx * depth, y + rng.uniform(-2, 2)), (x - dx * 2, y + w)]
        else:
            pts = [(x - w, y - dy * 2), (x + rng.uniform(-2, 2), y + dy * depth), (x + w, y - dy * 2)]
        d.polygon([(U(a), U(b)) for a, b in pts], fill=0)
    # Weitere Einrisse (15.11.2026, Nutzer: "Seiten duerfen eingerissen sein"): ausgefranste,
    # zweiteilige Risse rundum; Kopfzeilen (oben um x 205/569) und Versionszeile (unten
    # um x 205) bleiben frei. Eigener Zufall (Saat 31), damit sich sonst wenig aendert.
    tr = np.random.default_rng(31)
    spots = ([(x, PAGE_T, 0, 1) for x in (40, 72, 345, 372, 430, 700, 735)]
             + [(x, PAGE_B, 0, -1) for x in (60, 300, 352, 425, 470, 520, 690, 740)]
             + [(PAGE_L, y, 1, 0) for y in (90, 150, 300, 365, 490)]
             + [(PAGE_R, y, -1, 0) for y in (110, 180, 250, 410, 470, 510)])
    for x, y, dx, dy in spots:
        w = tr.uniform(3, 9)
        depth = tr.uniform(10, 20) if tr.random() < .65 else tr.uniform(26, 40)
        bend = tr.uniform(-7, 7)
        if dx:
            pts = [(x - dx * 2, y - w), (x + dx * depth * .55, y + bend - w * .3), (x + dx * depth, y + bend),
                   (x + dx * depth * .5, y + bend + w * .4), (x - dx * 2, y + w)]
        else:
            pts = [(x - w, y - dy * 2), (x + bend - w * .3, y + dy * depth * .55), (x + bend, y + dy * depth),
                   (x + bend + w * .4, y + dy * depth * .5), (x + w, y - dy * 2)]
        d.polygon([(U(a), U(b)) for a, b in pts], fill=0)
    # Eselsohr: Ecke oben rechts umgeknickt
    ear = 34
    cx, cy = PAGE_R, PAGE_T
    d.polygon([(U(cx - ear), U(cy - 2)), (U(cx + 2), U(cy - 2)), (U(cx + 2), U(cy + ear))], fill=0)
    return np.asarray(m) > 127, (cx, cy, ear)


def leather():
    base = np.array([40, 19, 9], np.float32)
    n = .55 * noise(90) + .3 * noise(24) + .15 * noise(5)
    img = base[None, None, :] * (0.72 + .5 * n[..., None])
    pores = noise(3) > .82
    img[pores] *= .82
    # Buchruecken: dunkler Streifen in der Mitte
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    ux = xx / S - M
    spine = np.exp(-((ux - GUTTER) / 7) ** 2)
    img *= (1 - .35 * spine)[..., None]
    # abgewetzte, hellere Stellen (vor allem an Ecken und Kanten) und Kratzer
    uy = yy / S - M
    edge = np.minimum.reduce([np.abs(ux - COVER_L), np.abs(COVER_R - ux), np.abs(uy - COVER_T), np.abs(COVER_B - uy)])
    near = np.clip(1 - edge / 26, 0, 1)
    corner = np.clip(1 - np.minimum(np.abs(ux - COVER_L), np.abs(COVER_R - ux)) / 60, 0, 1) * \
        np.clip(1 - np.minimum(np.abs(uy - COVER_T), np.abs(COVER_B - uy)) / 60, 0, 1)
    wear = np.clip((noise(30) - .35) * 2.4, 0, 1) * np.clip(near * 1.1 + corner * 1.6, 0, 1)
    # auch mitten auf dem Einband abgegriffene Flaechen
    wear = np.maximum(wear, np.clip((noise(70) - .62) * 2.5, 0, 1) * .55)
    scuff = np.array([104, 70, 46], np.float32)
    img = img * (1 - .8 * wear[..., None]) + scuff * .8 * wear[..., None]
    # Wasserflecken: dunklere Raender
    for _ in range(4):
        cx, cy, r0 = rng.uniform(0, CW), rng.uniform(0, CH), rng.uniform(40, 110) * S
        r = np.hypot(xx - cx, yy - cy) / r0
        stain = np.exp(-((r - 1) / .08) ** 2) * .35 + (r < 1) * .1
        img *= (1 - stain * (.6 + .4 * noise(12)))[..., None]
    # durchgescheuerte Ecken: die Pappe darunter schaut hervor
    board = np.array([128, 104, 76], np.float32) * (.85 + .3 * noise(6))[..., None]
    for cx, cy in ((COVER_L, COVER_T), (COVER_R, COVER_T), (COVER_L, COVER_B), (COVER_R, COVER_B)):
        dist = (np.abs(ux - cx) + np.abs(uy - cy)) / rng.uniform(26, 38)
        through = np.clip((1 - dist) * 2 + (noise(5) - .5) * 1.2, 0, 1)
        img = img * (1 - through[..., None]) + board * through[..., None]
    # Risse am Buchruecken (oben und unten) und quer ueber die Kanten
    crack = np.zeros_like(ux, bool)
    for y0 in (COVER_T + 3, COVER_B - 3):
        for _ in range(5):
            yc = y0 + rng.uniform(-6, 6)
            crack |= (np.abs(ux - GUTTER - rng.uniform(-8, 8)) < rng.uniform(6, 14)) & (np.abs(uy - yc) < .5)
    img[crack] = np.array([140, 112, 82], np.float32)
    # Aussenkante hell abgewetzt (das Leder ist an der Kante duenn gerieben)
    rim = np.clip(1 - edge / 3.5, 0, 1) * np.clip((noise(8) - .25) * 2, 0, 1)
    img = img * (1 - .85 * rim[..., None]) + np.array([132, 98, 68], np.float32) * .85 * rim[..., None]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im, 'RGBA')
    for _ in range(260):
        x0, y0 = rng.uniform(0, CW), rng.uniform(0, CH)
        ang, length = rng.uniform(0, np.pi), rng.uniform(8, 40) * S
        d.line([x0, y0, x0 + np.cos(ang) * length, y0 + np.sin(ang) * length],
               fill=(150, 112, 78, int(rng.uniform(70, 170))), width=int(rng.choice([2, 2, 3])))
    return np.asarray(im).astype(np.float32)


def pages(img):
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    ux, uy = xx / S - M, yy / S - M
    inside = fray(mask_of(page_pts()))
    # Schatten der Seiten auf dem Leder
    shadow = Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * S))
    sh = np.asarray(shadow).astype(np.float32) / 255
    sh = np.roll(np.roll(sh, 3 * S, axis=0), 2 * S, axis=1)
    img *= (1 - .5 * sh)[..., None]
    # Seitenstapel: Linien an den Aussenkanten und unten
    stack = inside.copy()
    for i in range(1, 5):
        ring = fray(mask_of(page_pts(i * 1.3)), 2.5) & ~stack
        img[ring] = np.array([158, 134, 94] if i % 2 else [104, 82, 54], np.float32)
        stack |= ring
    # Pergament
    # dunkler, vergilbter Ton (Stand 6: Nutzer wollte dunklere, abgenutztere Seiten)
    base = np.array([186, 154, 106], np.float32)
    blot = .6 * noise(140) + .4 * noise(40)
    fiber = noise(2)
    paper = base[None, None, :] * (.8 + .24 * blot[..., None] + .08 * (fiber[..., None] - .5))
    # Schmutz und Abrieb: grosse, unregelmaessige dunkle Wolken
    grime = np.clip((noise(55) - .5) * 2.2, 0, 1) * (.6 + .4 * noise(9))
    paper *= (1 - .2 * grime[..., None] * np.array([.8, .9, 1.0], np.float32))
    spot = np.clip((noise(70) - .7) / .25, 0, 1) ** 2 * 1.0
    spot = np.asarray(Image.fromarray((spot * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * S))) / 255
    paper *= (1 - spot[..., None] * np.array([.07, .1, .16], np.float32))
    # Aussenraender dunkler (Alterung): Abstand zum Seitenrand ueber Weichzeichnen der Maske
    edge = Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14 * S))
    age = np.clip((np.asarray(edge).astype(np.float32) / 255 - .5) * 2, 0, 1)
    paper *= (.55 + .45 * age)[..., None]
    paper[..., 2] *= (.92 + .08 * age)
    # Falz: tiefer Schatten zur Mitte, helle Woelbung daneben, feine Linie
    g = np.abs(ux - GUTTER)
    fold = np.clip(g / 46, 0, 1)
    paper *= (.5 + .5 * fold ** .6)[..., None]
    hump = np.exp(-((g - 30) / 14) ** 2)
    paper *= (1 + .05 * hump)[..., None]
    paper[g < .8] *= .7
    # Daumenspuren: unten an den Aussenecken dunkler und speckig
    for cx, cy in ((PAGE_L + 20, PAGE_B - 20), (PAGE_R - 20, PAGE_B - 20), (PAGE_R - 30, 300)):
        r = np.hypot(ux - cx, uy - cy)
        thumb = np.exp(-(r / 65) ** 2) * (.7 + .3 * noise(20))
        paper *= (1 - .38 * thumb)[..., None]
    # Stockflecken: kleine braune Punkte
    fox = np.clip((noise(6) - .84) / .1, 0, 1) * np.clip((noise(120) - .3) * 3, 0, 1)
    paper *= (1 - .45 * fox[..., None] * np.array([.6, .8, 1.0], np.float32))
    # alter Tassenrand auf der linken Seite
    r = np.hypot(ux - 255, uy - 430)
    ring = np.exp(-((r - 38) / 3.5) ** 2) * (.35 + .65 * noise(10)) + np.exp(-((r - 36) / 10) ** 2) * .12
    ring *= (r < 50)
    paper *= (1 - .17 * ring[..., None] * np.array([.5, .75, 1.0], np.float32))
    # Wasserfleck rechts oben: dunkler Rand, leicht aufgehellte Mitte
    r = np.hypot((ux - 640) * 1.3, uy - 150) * (1 + .15 * (noise(30) - .5))
    stain = np.exp(-((r - 60) / 5) ** 2) * .6 + np.exp(-((r - 58) / 18) ** 2) * .15
    paper *= (1 - .3 * stain[..., None] * np.array([.6, .8, 1.0], np.float32))
    # Knicke: alte Faltlinien quer ueber die Seiten (dunkle Kante, helle Kante daneben)
    for (x0, y0, x1, y1) in ((30, 150, 360, 110), (420, 470, 745, 405), (60, 520, 200, 300), (520, 60, 700, 300)):
        dx, dy = x1 - x0, y1 - y0
        n = np.hypot(dx, dy)
        d = ((ux - x0) * dy - (uy - y0) * dx) / n
        t = ((ux - x0) * dx + (uy - y0) * dy) / n ** 2
        on = np.clip(1 - np.abs(t - .5) * 2, 0, 1) ** .4 * (.5 + .5 * noise(15))
        paper *= (1 - .22 * np.exp(-(d / .9) ** 2) * on)[..., None]
        paper *= (1 + .07 * np.exp(-((d - 1.8) / 1.2) ** 2) * on)[..., None]
    # feine Kratzer
    scr = Image.new('L', (CW, CH), 0)
    dr = ImageDraw.Draw(scr)
    for _ in range(70):
        x, y = rng.uniform(PAGE_L, PAGE_R), rng.uniform(PAGE_T, PAGE_B)
        a, l = rng.uniform(0, np.pi), rng.uniform(8, 40)
        dr.line([(U(x), U(y)), (U(x + l * np.cos(a)), U(y + l * np.sin(a)))], fill=int(rng.uniform(60, 140)), width=1)
    sc = np.asarray(scr).astype(np.float32) / 255
    paper *= (1 - .25 * sc)[..., None]
    whole = inside
    inside, ear = tears(inside, None)
    img[inside] = np.clip(paper[inside], 0, 255)
    # In Einrissen und unter dem Eselsohr sieht man die naechste Seite (etwas dunkler, mit Schatten)
    gap = whole & ~inside
    below = np.clip(paper * .82, 0, 255)
    edge_sh = Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5 * S))
    es = np.asarray(edge_sh).astype(np.float32) / 255
    img[gap] = below[gap] * (1 - .35 * es[gap])[..., None]
    # umgeknickte Klappe des Eselsohrs (Rueckseite, etwas dunkler, mit Schatten)
    cx, cy, e = ear
    flap = Image.new('L', (CW, CH), 0)
    ImageDraw.Draw(flap).polygon([(U(cx - e), U(cy)), (U(cx), U(cy + e)), (U(cx - e + 4), U(cy + e - 4))], fill=255)
    fl = np.asarray(flap) > 127
    shade = Image.fromarray((fl * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3 * S))
    sh2 = np.roll(np.roll(np.asarray(shade).astype(np.float32) / 255, 2 * S, 0), -2 * S, 1)
    img[inside] *= (1 - .35 * sh2[inside])[..., None]
    img[fl] = np.array([196, 168, 120], np.float32) * (.92 + .1 * noise(8)[fl])[..., None]
    return img


def tooling(im):
    """Goldpraegung entlang des Einbands, Eckrauten, Kapitalband, Zierlinien unter den Kopfzeilen."""
    d = ImageDraw.Draw(im, 'RGBA')
    dark = (30, 14, 6, 200)

    def path(pts, col, width, off=0):
        xy = [(U(x) + off, U(y) + off) for x, y in pts]
        d.line(xy + [xy[0]], fill=col, width=int(width * S), joint='curve')
    # Blindpraegung: ins Leder gedrueckte Linie (dunkle Rinne, heller Grat darunter), kein Gold
    groove, ridge = (12, 5, 2, 190), (96, 62, 40, 90)
    for inset in (5.5,):
        pts = cover_pts(inset)
        path(pts, ridge, 1, S)
        path(pts, groove, 1.2)
    # Kapitalband an der Falz oben und unten
    top_y = PAGE_T + 10 - 5
    for y0 in (top_y, PAGE_B - 8 - 4):
        for i in range(6):
            col = (150, 30, 25, 255) if i % 2 == 0 else (220, 190, 120, 255)
            x = U(GUTTER - 6 + i * 2)
            d.rectangle([x, U(y0), x + 2 * S - 1, U(y0 + 6)], fill=col)
    # Zierlinie unter den Kopfzeilen beider Seiten (Tinte)
    ink = (92, 58, 28, 200)
    for cx in ((PAGE_L + GUTTER) / 2 + 4, (GUTTER + PAGE_R) / 2 - 4):
        y = U(66)
        d.line([U(cx - 120), y, U(cx - 8), y], fill=ink, width=S)
        d.line([U(cx + 8), y, U(cx + 120), y], fill=ink, width=S)
        k = 3 * S
        d.polygon([(U(cx), y - k), (U(cx) + k, y), (U(cx), y + k), (U(cx) - k, y)], fill=ink)


def book(preview=None):
    img = leather()
    img = pages(img)
    cover = mask_of(cover_pts())
    # Leder-Vignette zum Rand des Einbands
    soft = Image.fromarray((cover * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10 * S))
    v = np.asarray(soft).astype(np.float32) / 255
    img *= (.7 + .3 * np.clip((v - .5) * 2, 0, 1))[..., None]
    rgba = np.dstack([np.clip(img, 0, 255), cover * 255.0]).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    gold_layer = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    tooling(gold_layer)
    # Gold stellenweise abgerieben
    a = np.asarray(gold_layer).astype(np.float32)
    rub = np.clip((noise(12) - .1) * 1.8, .4, 1)
    rub[mask_of(page_pts())] = 1          # Zierlinien auf den Seiten bleiben ganz
    a[..., 3] *= rub
    im.alpha_composite(Image.fromarray(a.astype(np.uint8), 'RGBA'))
    im.putalpha(Image.fromarray((cover * 255).astype(np.uint8)))
    # Schatten unter dem Buch (ausserhalb des Einbands, halbdurchsichtig)
    sh = Image.fromarray((cover * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9 * S))
    sh = np.roll(np.roll(np.asarray(sh), 7 * S, axis=0), 4 * S, axis=1).astype(np.float32) * .6
    shadow = Image.fromarray(np.dstack([np.zeros((CH, CW, 3), np.uint8), sh.astype(np.uint8)]), 'RGBA')
    final = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    final.alpha_composite(shadow)
    final.alpha_composite(im)
    ROOT.mkdir(parents=True, exist_ok=True)
    out = ROOT / 'Book.tga'
    final.resize((1024, 1024), Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        bg = Image.new('RGBA', (CW, CH), (40, 48, 60, 255))
        bg.alpha_composite(final)
        bg.resize(((W + 2 * M), (H + 2 * M)), Image.LANCZOS).save(preview)
        print('Vorschau:', preview)


def index_tab(preview=None):
    """Lederreiter fuer das Daumenregister: Leder mit Naht, rechts gerundet, Pergamentschild.
    Hell gezeichnet; der aktive Reiter wird im Spiel heller eingefaerbt."""
    w, h = 128 * 4, 64 * 4
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    shape = Image.new('L', (w, h), 0)
    ImageDraw.Draw(shape).rounded_rectangle([-40, 6, w - 6, h - 6], radius=40, fill=255)
    a = np.asarray(shape).astype(np.float32) / 255
    lea = np.array([92, 50, 26], np.float32) * (.75 + .45 * noise(18, w, h))[..., None]
    wear = np.clip((noise(10, w, h) - .55) * 2.5, 0, 1)
    lea = lea * (1 - .5 * wear[..., None]) + np.array([130, 92, 60], np.float32) * .5 * wear[..., None]
    # Woelbung: oben heller, unten dunkler
    lea *= (1.1 - .35 * (yy / h))[..., None]
    img = Image.fromarray(np.dstack([np.clip(lea, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    d = ImageDraw.Draw(img)
    # Naht
    for x in range(30, w - 50, 22):
        d.line([x, 22, x + 12, 22], fill=(170, 130, 90, 200), width=4)
        d.line([x, h - 22, x + 12, h - 22], fill=(170, 130, 90, 200), width=4)
    # Pergamentschild
    lab = [70, 52, w - 52, h - 52]
    paper = Image.new('RGBA', (lab[2] - lab[0], lab[3] - lab[1]))
    pa = np.array([222, 198, 150], np.float32) * (.88 + .16 * noise(20, paper.width, paper.height))[..., None]
    paper = Image.fromarray(np.dstack([np.clip(pa, 0, 255), np.full(pa.shape[:2], 255.)]).astype(np.uint8), 'RGBA')
    img.alpha_composite(paper, (lab[0], lab[1]))
    d.rectangle(lab, outline=(60, 34, 16, 255), width=5)
    out = ROOT / 'Tab.tga'
    img.resize((128, 64), Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        img.resize((128, 64), Image.LANCZOS).save(preview.replace('.png', '_tab.png'))


def worn_tab(preview=None):
    """Daumenregister A+ (15.11.2026): kleiner, stark abgegriffener Lederreiter ohne Schild.
    Links flach (liegt unter dem Einband), rechts gerundet und abgewetzt. 128x64,
    hell gezeichnet; ruhend/aktiv/Maus faerbt das Spiel ein (SetVertexColor)."""
    global rng
    old, rng = rng, np.random.default_rng(41)
    w, h = 128 * 4, 64 * 4
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    shape = Image.new('L', (w, h), 0)
    ImageDraw.Draw(shape).rounded_rectangle([-60, 10, w - 10, h - 10], radius=70, fill=255)
    a = np.asarray(shape.filter(ImageFilter.GaussianBlur(3))).astype(np.float32) / 255
    # ausgefranste, abgewetzte Kante
    jag = .6 * noise(6, w, h) + .4 * noise(20, w, h)
    a = np.clip((a + (jag - .5) * .55 - .5) * 6 + .5, 0, 1)
    lea = np.array([104, 62, 34], np.float32) * (.72 + .5 * noise(16, w, h))[..., None]
    # abgegriffen: helle, matte Stellen (Leder blank gerieben) und dunkle Flecken
    rub = np.clip((noise(9, w, h) - .45) * 2.2, 0, 1)
    lea = lea * (1 - .55 * rub[..., None]) + np.array([150, 112, 76], np.float32) * .55 * rub[..., None]
    spot = np.clip((noise(30, w, h) - .62) * 3, 0, 1)
    lea *= (1 - .35 * spot)[..., None]
    # Kante heller abgewetzt
    edge = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(np.float32) / 255
    rim = np.clip((.85 - edge) * 3, 0, 1) * a
    lea = lea * (1 - .45 * rim[..., None]) + np.array([170, 130, 90], np.float32) * .45 * rim[..., None]
    lea *= (1.1 - .3 * (yy / h))[..., None]
    img = Image.fromarray(np.dstack([np.clip(lea, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    d = ImageDraw.Draw(img)
    for _ in range(12):   # wenige, matte Kratzer
        x, y = rng.uniform(20, w - 40), rng.uniform(20, h - 20)
        ang, l = rng.normal(0, .6), rng.uniform(20, 70)
        d.line([x, y, x + l * np.cos(ang), y + l * np.sin(ang)], fill=(140, 104, 72, int(rng.uniform(40, 90))), width=int(rng.uniform(2, 3)))
    # Rissfalte im Leder
    d.line([w * .55, h * .2, w * .6, h * .45, w * .57, h * .7], fill=(40, 22, 12, 160), width=5)
    img.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    out = ROOT / 'TabWorn.tga'
    img.resize((128, 64), Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        img.resize((128, 64), Image.LANCZOS).save(preview.replace('.png', '_tabworn.png'))
    rng = old


TAB_ICONS = ['home', 'guild', 'calendar', 'dungeons', 'crafting', 'classes', 'quests', 'nav', 'options', 'book']


def tab_icons(preview=None):
    """Gepraegte Goldsymbole fuer die Lederreiter: 4x4 Felder je 64x64 in TabIcons.tga
    (256x256), Reihenfolge TAB_ICONS. Gold mit Praegeschatten, stellenweise abgerieben."""
    global rng
    old, rng = rng, np.random.default_rng(43)
    C = 256                          # Zeichengroesse je Feld (wird auf 64 verkleinert)
    sheet = Image.new('RGBA', (4 * C, 4 * C), (0, 0, 0, 0))
    def draw(d, name, col, o):
        cx, cy, k = C / 2 + o, C / 2 + o, C / 64
        w = int(4.2 * k)
        def L(*p): d.line([(cx + x * k, cy + y * k) for x, y in zip(p[::2], p[1::2])], fill=col, width=w, joint='curve')
        def R(x0, y0, x1, y1): d.rectangle([cx + x0 * k, cy + y0 * k, cx + x1 * k, cy + y1 * k], outline=col, width=w)
        def E(x0, y0, x1, y1, fill=False):
            d.ellipse([cx + x0 * k, cy + y0 * k, cx + x1 * k, cy + y1 * k], outline=None if fill else col, fill=col if fill else None, width=w)
        def P(*p, fill=False): d.polygon([(cx + x * k, cy + y * k) for x, y in zip(p[::2], p[1::2])], outline=None if fill else col, fill=col if fill else None, width=w)
        if name == 'home':
            L(-18, 0, 0, -18, 18, 0); R(-13, 0, 13, 18); P(-4, 18, -4, 7, 4, 7, 4, 18, fill=True)
        elif name == 'guild':
            L(-14, -22, -14, 22); P(-14, -20, 16, -20, 8, -8, 16, 4, -14, 4)
        elif name == 'calendar':
            R(-17, -13, 17, 18); L(-17, -4, 17, -4); L(-8, -20, -8, -10); L(8, -20, 8, -10)
            for gx in (-9, 0, 9):
                for gy in (4, 12): E(gx - 2.5, gy - 2.5, gx + 2.5, gy + 2.5, fill=True)
        elif name == 'dungeons':
            d.arc([cx - 17 * k, cy - 20 * k, cx + 17 * k, cy + 10 * k], 180, 360, fill=col, width=w)
            L(-17, -5, -17, 20); L(17, -5, 17, 20); L(-22, 20, 22, 20); L(0, -18, 0, 20)
        elif name == 'crafting':
            d.line([cx - 14 * k, cy + 20 * k, cx + 8 * k, cy - 4 * k], fill=col, width=int(6 * k))
            P(0, -16, 14, -2, 22, -10, 8, -24, fill=True)
        elif name == 'classes':
            P(-17, -19, 17, -19, 17, 0, 0, 21, -17, 0); L(0, -14, 0, 12); L(-8, -6, 8, -6)
        elif name == 'quests':
            P(-4, -22, 4, -22, 2, 8, -2, 8, fill=True); E(-4, 13, 4, 21, fill=True)
        elif name == 'nav':
            E(-19, -19, 19, 19); P(0, -15, 6, 0, 0, 15, -6, 0, fill=True); E(-2, -2, 2, 2)
        elif name == 'options':
            for t in range(8):
                ang = t * np.pi / 4
                d.line([cx + 10 * k * np.cos(ang), cy + 10 * k * np.sin(ang), cx + 20 * k * np.cos(ang), cy + 20 * k * np.sin(ang)], fill=col, width=int(7 * k))
            E(-14, -14, 14, 14); E(-4, -4, 4, 4, fill=True)
        else:   # book
            R(-18, -14, 0, 16); R(0, -14, 18, 16); L(0, -14, 0, 16)
    for i, name in enumerate(TAB_ICONS):
        cell = Image.new('RGBA', (C, C), (0, 0, 0, 0))
        shadow = Image.new('RGBA', (C, C), (0, 0, 0, 0))
        draw(ImageDraw.Draw(shadow), name, (26, 14, 6, 230), 5)
        shadow = shadow.filter(ImageFilter.GaussianBlur(3))
        gold = Image.new('RGBA', (C, C), (0, 0, 0, 0))
        draw(ImageDraw.Draw(gold), name, (255, 255, 255, 255), 0)
        g = np.asarray(gold).astype(np.float32)
        yy, xx = np.mgrid[0:C, 0:C].astype(np.float32)
        tone = np.array([224, 182, 98], np.float32) * (.82 + .32 * (1 - yy / C))[..., None]   # oben heller (Praegung)
        tone *= (.85 + .3 * noise(10, C, C))[..., None]
        rub = np.clip((noise(7, C, C) - .5) * 2.6, 0, 1)                                      # Gold abgerieben
        alpha = g[..., 3] * (1 - .55 * rub)
        gold = Image.fromarray(np.dstack([np.clip(tone, 0, 255), alpha]).astype(np.uint8), 'RGBA')
        cell.alpha_composite(shadow)
        cell.alpha_composite(gold)
        sheet.alpha_composite(cell, ((i % 4) * C, (i // 4) * C))
    out = ROOT / 'TabIcons.tga'
    sheet.resize((256, 256), Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        bg = Image.new('RGBA', (256, 256), (80, 48, 28, 255))
        bg.alpha_composite(sheet.resize((256, 256), Image.LANCZOS))
        bg.save(preview.replace('.png', '_icons.png'))
    rng = old


def seal(preview=None):
    """Rotes Wachssiegel ohne Buchstaben: unregelmaessiger Rand, Pressring, Rosette."""
    n = 256
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    c = n / 2
    ang = np.arctan2(yy - c, xx - c)
    r = np.hypot(xx - c, yy - c)
    edge = 112 + 7 * np.sin(ang * 7) + 5 * np.sin(ang * 13 + 1) + 6 * (noise(16, n, n) - .5)
    alpha = np.clip((edge - r) / 2, 0, 1)
    shade = .75 + .35 * (1 - (yy + xx) / (2 * n))           # Licht von oben links
    ring = np.exp(-((r - 78) / 5) ** 2)
    inner = np.exp(-((r - 70) / 4) ** 2)
    col = np.array([150, 24, 18], np.float32)[None, None, :] * shade[..., None]
    col *= (1 - .3 * ring + .25 * inner)[..., None]
    # Rosette: acht Blaetter
    petal = (np.cos(ang * 8) * .5 + .5) * np.exp(-((r - 34) / 16) ** 2)
    col *= (1 + .35 * petal - .15 * np.exp(-(r / 10) ** 2))[..., None]
    col *= (.9 + .2 * noise(8, n, n))[..., None]
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), alpha * 255]).astype(np.uint8), 'RGBA')
    out = ROOT / 'Seal.tga'
    img.resize((64, 64), Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        img.resize((64, 64), Image.LANCZOS).save(preview.replace('.png', '_seal.png'))


def sheet(name, w0, h0, size, preview=None, seed=11):
    """Loses Pergamentblatt fuer eigene Fenster (Tagesueberblick, Hinweise): gleiche
    Alterungsregeln wie die Buchseiten, rundum zerfaserter Rand, transparent aussen.
    Gezeichnet im Seitenverhaeltnis des Fensters (w0 x h0), gespeichert als size (2er-Potenz)."""
    global rng
    old, rng = rng, np.random.default_rng(seed)
    s = 2
    w, h = w0 * s, h0 * s
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ux, uy = xx / s, yy / s
    # zerfaserter Rand: weichgezeichnetes Rechteck + Rauschen, dazu kleine Einrisse
    rect = Image.new('L', (w, h), 0)
    dr = ImageDraw.Draw(rect)
    dr.rectangle([7 * s, 7 * s, w - 7 * s, h - 7 * s], fill=255)
    for _ in range(max(3, (w0 + h0) // 160)):
        side = rng.integers(4)
        t = rng.uniform(.1, .9)
        d, wd = rng.uniform(5, 12), rng.uniform(3, 7)
        if side == 0: x, y, pts = t * w0, 7, [(t * w0 - wd, 6), (t * w0 + wd, 6), (t * w0, 7 + d)]
        elif side == 1: pts = [(t * w0 - wd, h0 - 6), (t * w0 + wd, h0 - 6), (t * w0, h0 - 7 - d)]
        elif side == 2: pts = [(6, t * h0 - wd), (6, t * h0 + wd), (7 + d, t * h0)]
        else: pts = [(w0 - 6, t * h0 - wd), (w0 - 6, t * h0 + wd), (w0 - 7 - d, t * h0)]
        dr.polygon([(px * s, py * s) for px, py in pts], fill=0)
    blur = np.asarray(rect.filter(ImageFilter.GaussianBlur(3 * s))).astype(np.float32) / 255
    inside = (blur + (noise(3, w, h) - .5) * .45 + (noise(14, w, h) - .5) * .25) > .5
    # Pergament wie im Buch
    base = np.array([186, 154, 106], np.float32)
    blot = .6 * noise(140, w, h) + .4 * noise(40, w, h)
    paper = base[None, None, :] * (.8 + .24 * blot[..., None] + .08 * (noise(2, w, h)[..., None] - .5))
    grime = np.clip((noise(55, w, h) - .5) * 2.2, 0, 1) * (.6 + .4 * noise(9, w, h))
    paper *= (1 - .2 * grime[..., None] * np.array([.8, .9, 1.0], np.float32))
    spot = np.clip((noise(70, w, h) - .7) / .25, 0, 1) ** 2
    spot = np.asarray(Image.fromarray((spot * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * s))) / 255
    paper *= (1 - spot[..., None] * np.array([.07, .1, .16], np.float32))
    # Raender dunkler, ganz aussen fast verbrannt
    edge = np.asarray(Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(16 * s))).astype(np.float32) / 255
    age = np.clip((edge - .5) * 2, 0, 1)
    paper *= (.5 + .5 * age)[..., None]
    rim = np.asarray(Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5 * s))).astype(np.float32) / 255
    paper *= (.55 + .45 * np.clip((rim - .5) * 2, 0, 1))[..., None]
    # Daumenspuren unten an den Ecken
    for cx, cy in ((20, h0 - 20), (w0 - 20, h0 - 20)):
        r = np.hypot(ux - cx, uy - cy)
        paper *= (1 - .3 * np.exp(-(r / 50) ** 2) * (.7 + .3 * noise(20, w, h)))[..., None]
    # Stockflecken
    fox = np.clip((noise(6, w, h) - .84) / .1, 0, 1) * np.clip((noise(120, w, h) - .3) * 3, 0, 1)
    paper *= (1 - .45 * fox[..., None] * np.array([.6, .8, 1.0], np.float32))
    # Wasserfleck (Ring) irgendwo rechts
    rcx, rcy, rr = w0 * rng.uniform(.6, .85), h0 * rng.uniform(.3, .7), min(w0, h0) * .16
    r = np.hypot(ux - rcx, uy - rcy) * (1 + .15 * (noise(30, w, h) - .5))
    stain = np.exp(-((r - rr) / 4) ** 2) * .6 + np.exp(-((r - rr + 2) / 14) ** 2) * .15
    paper *= (1 - .3 * stain[..., None] * np.array([.6, .8, 1.0], np.float32))
    # Knicke: eine waagrechte und eine senkrechte Faltlinie (Blatt war gefaltet)
    for (x0, y0, x1, y1) in ((0, h0 * .5, w0, h0 * .47), (w0 * .52, 0, w0 * .5, h0)):
        dx, dy = x1 - x0, y1 - y0
        n = np.hypot(dx, dy)
        d = ((ux - x0) * dy - (uy - y0) * dx) / n
        on = (.3 + .7 * noise(25, w, h)) * (.6 + .4 * noise(6, w, h))
        paper *= (1 - .11 * np.exp(-(d / 1.6) ** 2) * on)[..., None]
        paper *= (1 + .05 * np.exp(-((d - 2.6) / 2.2) ** 2) * on)[..., None]
    # Kratzer
    scr = Image.new('L', (w, h), 0)
    sd = ImageDraw.Draw(scr)
    for _ in range(int(w0 * h0 / 4000)):
        x, y = rng.uniform(0, w0), rng.uniform(0, h0)
        a, l = rng.uniform(0, np.pi), rng.uniform(8, 40)
        sd.line([(x * s, y * s), ((x + l * np.cos(a)) * s, (y + l * np.sin(a)) * s)], fill=int(rng.uniform(60, 140)), width=1)
    paper *= (1 - .25 * np.asarray(scr).astype(np.float32)[..., None] / 255)
    img = Image.fromarray(np.dstack([np.clip(paper, 0, 255), inside * 255.0]).astype(np.uint8), 'RGBA')
    out = ROOT / name
    img.resize(size, Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        bg = Image.new('RGBA', (w0, h0), (40, 48, 60, 255))
        bg.alpha_composite(img.resize((w0, h0), Image.LANCZOS))
        bg.save(preview.replace('.png', '_' + name.replace('.tga', '.png')))
    rng = old


def wear(preview=None):
    """Abrieb ueber den Seiten (gealterte Tinte, 15.11.2026): halbdurchsichtige Pergament-
    Flecken, feine Punkte und Kratzer, die Schrift und Linien stellenweise verblassen lassen.
    Gleiches Raster wie Book.tga (liegt im Spiel genau darueber). Eigener Zufall (Saat 23),
    damit die anderen Bilder unveraendert bleiben."""
    global rng
    old, rng = rng, np.random.default_rng(23)
    page = mask_of(page_pts())
    paper = np.array([214, 194, 150], np.float32)
    # feine Punkte (Abrieb einzelner Stellen) – nur wenige, damit Text lesbar bleibt
    dots = np.clip((noise(3) - .78) / .22, 0, 1) * .42
    # weiche groessere Stellen (abgegriffen)
    blot = np.clip((noise(40) - .55) / .45, 0, 1) * .16
    # Ecken und Raender staerker abgegriffen, Mitte (Falz) leicht
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    edge = np.clip(1 - np.minimum.reduce([xx - U(PAGE_L), U(PAGE_R) - xx, yy - U(PAGE_T), U(PAGE_B) - yy]) / (60 * S), 0, 1) * .14
    alpha = np.clip(dots + blot + edge, 0, .5)
    # Kratzer
    scr = Image.new('L', (CW, CH), 0)
    sd = ImageDraw.Draw(scr)
    for _ in range(140):
        x, y = rng.uniform(U(PAGE_L), U(PAGE_R)), rng.uniform(U(PAGE_T), U(PAGE_B))
        ang, l = rng.normal(.4, .5), rng.uniform(15, 90) * S
        sd.line([(x, y), (x + l * np.cos(ang), y + l * np.sin(ang))], fill=int(rng.uniform(50, 120)), width=1)
    scr = np.asarray(scr.filter(ImageFilter.GaussianBlur(.7))).astype(np.float32) / 255
    alpha = np.clip(alpha + scr * .5, 0, .55) * page
    tint = paper * (.92 + .16 * noise(25)[..., None])
    rgba = np.dstack([np.clip(tint, 0, 255), alpha * 255]).astype(np.uint8)
    out = ROOT / 'Wear.tga'
    Image.fromarray(rgba, 'RGBA').resize((1024, 1024), Image.LANCZOS).save(out, compression='tga_rle')
    print('geschrieben:', out)
    if preview:
        bg = Image.new('RGBA', (CW, CH), (40, 30, 20, 255))
        bg.alpha_composite(Image.fromarray(rgba, 'RGBA'))
        bg.resize(((W + 2 * M), (H + 2 * M)), Image.LANCZOS).save(preview.replace('.png', '_wear.png'))
    rng = old


if __name__ == '__main__':
    p = sys.argv[1] if len(sys.argv) > 1 else None
    if p == '--wear':        # nur das Abrieb-Bild neu erzeugen
        wear(sys.argv[2] if len(sys.argv) > 2 else None)
        sys.exit(0)
    if p == '--tabs':        # nur Buch (Einrisse), Lederreiter und Symbole neu erzeugen
        q = sys.argv[2] if len(sys.argv) > 2 else None
        book(q)
        worn_tab(q)
        tab_icons(q)
        sys.exit(0)
    book(p)
    index_tab(p)
    seal(p)
    sheet('Sheet.tga', 590, 440, (1024, 512), p)      # Tagesueberblick
    sheet('Strip.tga', 440, 112, (512, 128), p, 12)    # Hinweisfenster
