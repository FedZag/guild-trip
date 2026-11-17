"""Guild Trip Wegenetz: eigene Routenpunkte für Weltkarte/Minimap (Gold wie der Navi-Pfeil).
Eigene Zeichnung, keine fremden Grafiken. Ausgabe: 32x32 TGA mit Alpha.
  RouteDot.tga  – Punkt auf dem Weg
  RouteTurn.tga – nächste Abbiegung (Ring mit hellem Kern)
  RouteFootL/R.tga – Fussabdruecke (Einstellung „Weg: Fußspuren“), Aufruf mit --feet nur diese
Aufruf: python3 scripts/build_route_dots.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

DIR = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Nav' / 'Textures'
S = 8      # Supersampling
N = 32
W = N * S
GOLD_TOP, GOLD_BOTTOM = (255, 226, 120), (196, 132, 30)
RIM = (46, 28, 8)


def disc(r, fill):
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    c = W / 2
    ImageDraw.Draw(img).ellipse((c - r * S, c - r * S, c + r * S, c + r * S), fill=fill)
    return img


def gradient_disc(r):
    """Goldener Punkt, oben heller (Licht von oben)"""
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    grad = Image.new('RGBA', (W, W))
    d = ImageDraw.Draw(grad)
    for y in range(W):
        t = y / (W - 1)
        col = tuple(round(GOLD_TOP[i] * (1 - t) + GOLD_BOTTOM[i] * t) for i in range(3))
        d.line((0, y, W, y), fill=(*col, 255))
    m = Image.new('L', (W, W), 0)
    c = W / 2
    ImageDraw.Draw(m).ellipse((c - r * S, c - r * S, c + r * S, c + r * S), fill=255)
    img.paste(grad, (0, 0), m)
    return img


def shadow(r):
    sh = disc(r + 1.5, (0, 0, 0, 150))
    return sh.filter(ImageFilter.GaussianBlur(2 * S))


def dot():
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    img = Image.alpha_composite(img, shadow(6))
    img = Image.alpha_composite(img, disc(7, (*RIM, 255)))
    img = Image.alpha_composite(img, gradient_disc(5.5))
    img = Image.alpha_composite(img, disc(1.8, (255, 248, 210, 170)).transform(
        (W, W), Image.AFFINE, (1, 0, 1.6 * S, 0, 1, 1.6 * S)))  # Glanzpunkt oben links
    return img


def turn():
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    img = Image.alpha_composite(img, shadow(12))
    img = Image.alpha_composite(img, disc(14, (*RIM, 255)))
    img = Image.alpha_composite(img, gradient_disc(12.5))
    img = Image.alpha_composite(img, disc(9.5, (*RIM, 255)))
    img = Image.alpha_composite(img, disc(8, (0, 0, 0, 0)).point(lambda v: 0))
    # Mitte durchsichtig ausstanzen, heller Kern
    a = img.split()[3]
    hole = Image.new('L', (W, W), 0)
    c = W / 2
    ImageDraw.Draw(hole).ellipse((c - 8 * S, c - 8 * S, c + 8 * S, c + 8 * S), fill=255)
    a = Image.composite(Image.new('L', (W, W), 0), a, hole)
    img.putalpha(a)
    img = Image.alpha_composite(img, gradient_disc(4.5))
    return img


def foot(left):
    """Fussabdruck (rechter Fuss, Zehen oben), gold mit dunklem Rand; links = gespiegelt.
    Wird im Spiel zur Laufrichtung gedreht (SetRotation)."""
    shape = Image.new('L', (W, W), 0)
    d = ImageDraw.Draw(shape)
    c = W / 2
    # Sohle (leicht schraeg), Ferse, fuenf Zehen
    d.ellipse((c - 5 * S, c - 6 * S, c + 5.5 * S, c + 6 * S), fill=255)
    d.ellipse((c - 4 * S, c + 4 * S, c + 3.5 * S, c + 11 * S), fill=255)
    for x, y, r in ((-4.2, -9.5, 2.4), (-0.6, -11.6, 2.5), (2.9, -10.6, 2.2), (5.4, -8.2, 1.8), (6.8, -5.4, 1.5)):
        d.ellipse((c + (x - r) * S, c + (y - r) * S, c + (x + r) * S, c + (y + r) * S), fill=255)
    rim = shape.filter(ImageFilter.MaxFilter(2 * S + 1))
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    sh = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    sh.putalpha(rim.filter(ImageFilter.GaussianBlur(1.5 * S)).point(lambda v: int(v * .55)))
    img = Image.alpha_composite(img, sh)
    dark = Image.new('RGBA', (W, W), (*RIM, 255))
    img.paste(dark, (0, 0), rim)
    grad = Image.new('RGBA', (W, W))
    g = ImageDraw.Draw(grad)
    for y in range(W):
        t = y / (W - 1)
        g.line((0, y, W, y), fill=(*tuple(round(GOLD_TOP[i] * (1 - t) + GOLD_BOTTOM[i] * t) for i in range(3)), 255))
    img.paste(grad, (0, 0), shape)
    if left:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


BUILDS = [('RouteDot.tga', dot), ('RouteTurn.tga', turn),
          ('RouteFootL.tga', lambda: foot(True)), ('RouteFootR.tga', lambda: foot(False))]
import sys
only_feet = '--feet' in sys.argv   # nur die Fussspuren neu (Punkte bleiben unveraendert)
for name, build in BUILDS:
    if only_feet and 'Foot' not in name:
        continue
    out = build().resize((N, N), Image.LANCZOS)
    out.save(DIR / name)
    print('geschrieben:', DIR / name)
