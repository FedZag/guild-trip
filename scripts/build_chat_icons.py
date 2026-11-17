"""Guild Trip Chat: eigene kleine Grafiken (keine fremden Bilder).
Erzeugt in src/ONE_Chat/Textures/:
  Shield.tga  32x32  Wappenschild, weiss mit dunklem Rand (im Spiel in Klassenfarbe eingefaerbt)
  Pill.tga    64x32  abgerundete Zahl-Pille (weiss, wird rot/gedaempft eingefaerbt), feiner Goldrand
  Dot.tga     16x16  runder Punkt (online = gruen eingefaerbt)
Aufruf: python3 -I scripts/build_chat_icons.py [vorschau.png]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Chat' / 'Textures'
K = 8   # Zeichenmassstab (danach verkleinert = glatte Kanten)


def shield():
    s = 32 * K
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    outer = [(3 * K, 3 * K), (29 * K, 3 * K), (29 * K, 17 * K), (16 * K, 30 * K), (3 * K, 17 * K)]
    d.polygon(outer, fill=(20, 14, 8, 255))
    inner = [(5.5 * K, 5.5 * K), (26.5 * K, 5.5 * K), (26.5 * K, 16 * K), (16 * K, 26.5 * K), (5.5 * K, 16 * K)]
    d.polygon(inner, fill=(255, 255, 255, 255))
    # Lichtkante oben links, leichter Schatten unten rechts (bleibt beim Einfaerben sichtbar)
    shade = Image.new('L', (s, s), 0)
    ImageDraw.Draw(shade).polygon([(16 * K, 5.5 * K), (26.5 * K, 5.5 * K), (26.5 * K, 16 * K), (16 * K, 26.5 * K)], fill=60)
    shade = shade.filter(ImageFilter.GaussianBlur(2 * K))
    px = im.load()
    sp = shade.load()
    for y in range(s):
        for x in range(s):
            r, g, b, a = px[x, y]
            if a and r > 200:
                k = sp[x, y]
                px[x, y] = (r - k, g - k, b - k, a)
    return im.resize((32, 32), Image.LANCZOS)


def pill():
    w, h = 64 * K, 32 * K
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2 * K, 4 * K, 62 * K, 28 * K], radius=12 * K, fill=(201, 162, 74, 255))
    d.rounded_rectangle([4 * K, 6 * K, 60 * K, 26 * K], radius=10 * K, fill=(255, 255, 255, 255))
    return im.resize((64, 32), Image.LANCZOS)


def dot():
    s = 16 * K
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([1 * K, 1 * K, 15 * K, 15 * K], fill=(0, 0, 0, 255))
    d.ellipse([3 * K, 3 * K, 13 * K, 13 * K], fill=(255, 255, 255, 255))
    return im.resize((16, 16), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    images = {'Shield.tga': shield(), 'Pill.tga': pill(), 'Dot.tga': dot()}
    for name, im in images.items():
        im.save(OUT / name, compression='tga_rle')
        print('geschrieben:', OUT / name)
    if len(sys.argv) > 1:
        sheet = Image.new('RGBA', (160, 40), (30, 30, 30, 255))
        x = 4
        for im in images.values():
            sheet.alpha_composite(im, (x, 4))
            x += im.width + 8
        sheet.save(sys.argv[1])


if __name__ == '__main__':
    main()
