"""ONE_Nav Richtungspfeil im WoW-Stil (Gold/Bronze, dunkle Kontur, weicher Schatten).
Eigene Zeichnung, keine fremden Grafiken. Ausgabe: 128x128 TGA mit Alpha, Spitze nach oben.
Aufruf: python3 scripts/build_nav_arrow.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Nav' / 'Textures' / 'Arrow.tga'
S = 4            # Supersampling
N = 128          # Endgroesse
W = N * S


def P(points):
    return [(x * S, y * S) for x, y in points]


# Pfeilform: schlanke Spitze mit Kerbe hinten (Pfeilspitze/Dart), mittig, Spitze oben.
SHAPE = [(64, 10), (104, 108), (64, 84), (24, 108)]
# Innere Flaeche (fuer Kante/Bevel) etwas kleiner
INNER = [(64, 22), (95, 99), (64, 78), (33, 99)]
# Linke Haelfte bekommt Glanz, rechte Haelfte Schatten (Licht von links oben)
LEFT = [(64, 22), (64, 78), (33, 99)]


def mask(points, grow=0):
    m = Image.new('L', (W, W), 0)
    ImageDraw.Draw(m).polygon(P(points), fill=255)
    if grow > 0:
        m = m.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    return m


def vertical_gradient(top, bottom):
    g = Image.new('RGBA', (W, W))
    d = ImageDraw.Draw(g)
    for y in range(W):
        t = y / (W - 1)
        col = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        d.line((0, y, W, y), fill=(*col, 255))
    return g


img = Image.new('RGBA', (W, W), (0, 0, 0, 0))

# 1) Weicher Schatten (leicht nach unten versetzt)
shadow_mask = mask(SHAPE, grow=3 * S).filter(ImageFilter.GaussianBlur(5 * S))
shadow_mask = ImageChops.offset(shadow_mask, 0, 3 * S)
shadow = Image.new('RGBA', (W, W), (0, 0, 0, 255))
shadow.putalpha(shadow_mask.point(lambda a: a * 0.75))
img = Image.alpha_composite(img, shadow)

# 2) Dunkle Kontur
outline = Image.new('RGBA', (W, W), (24, 14, 6, 255))
outline.putalpha(mask(SHAPE, grow=2 * S))
img = Image.alpha_composite(img, outline)

# 3) Bronzene Kante
edge = vertical_gradient((176, 120, 48), (96, 58, 22))
edge.putalpha(mask(SHAPE))
img = Image.alpha_composite(img, edge)

# 4) Goldene Innenflaeche
body = vertical_gradient((255, 226, 128), (204, 140, 40))
body.putalpha(mask(INNER))
img = Image.alpha_composite(img, body)

# 5) Glanz links, Schattierung rechts (Facetten-Effekt)
shine = vertical_gradient((255, 248, 200), (240, 196, 96))
shine.putalpha(mask(LEFT).point(lambda a: a * 0.55))
img = Image.alpha_composite(img, shine)

# 6) Feine helle Mittellinie (Grat)
ridge = Image.new('RGBA', (W, W), (0, 0, 0, 0))
ImageDraw.Draw(ridge).line(P([(64, 24), (64, 76)]), fill=(255, 250, 220, 150), width=2 * S)
ridge = ridge.filter(ImageFilter.GaussianBlur(S))
img = Image.alpha_composite(img, ridge)

img = img.resize((N, N), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print('geschrieben:', OUT, img.size)
