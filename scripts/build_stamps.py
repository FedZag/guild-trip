"""Guild Trip Reisepass: Stempel-Grafiken (eigene Zeichnung, keine fremden Bilder).
Weiss mit ungleichmaessig aufgetragener "Farbe" (Koernung) – im Spiel per Vertex-Farbe in
Stempelfarbe (rot, blau, braun, gruen) eingefaerbt; Name/Datum setzt das Addon als Schrift darueber.
Erzeugt in src/ONE_Dungeons/Textures/:
  StampRound.tga  128x128  runder Stempel (Dungeon): doppelter Ring, Sterne links/rechts
  StampRect.tga   128x128  eckiger Stempel (Gildenausflug): doppelter Rahmen mit runden Ecken
  StampSlot.tga   128x128  gestrichelter Kreis fuer noch freie Felder
Aufruf: python3 -I scripts/build_stamps.py [vorschau.png]
"""
import math
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Dungeons' / 'Textures'
S = 512   # Zeichengroesse, danach 128


def grain(mask, seed, strength=1.0):
    """Stempelfarbe ungleich: feine Koernung + groessere fleckige Stellen."""
    rng = np.random.default_rng(seed)

    def noise(scale):
        small = Image.fromarray((rng.random((S // scale, S // scale)) * 255).astype(np.uint8))
        a = np.asarray(small.resize((S, S), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale / 3))).astype(np.float32) / 255
        return (a - a.min()) / max(1e-6, a.max() - a.min())
    g = np.clip(noise(3) * .9 + noise(48) * .55 + .02, 0, 1) ** (.7 * strength)
    a = np.asarray(mask).astype(np.float32) / 255 * g
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.clip(a * 245, 0, 255)
    return Image.fromarray(out).resize((128, 128), Image.LANCZOS)


def star(d, cx, cy, r):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * .45
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    d.polygon(pts, fill=255)


def round_stamp():
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    c = S / 2
    d.ellipse([22, 22, S - 22, S - 22], outline=255, width=22)
    d.ellipse([70, 70, S - 70, S - 70], outline=255, width=8)
    star(d, 46 + 4, c, 15)
    star(d, S - 46 - 4, c, 15)
    return grain(m, 5)


def rect_stamp():
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([20, 92, S - 20, S - 92], radius=26, outline=255, width=20)
    d.rounded_rectangle([50, 122, S - 50, S - 122], radius=12, outline=255, width=7)
    return grain(m, 9)


def slot():
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    r = S / 2 - 30
    c = S / 2
    for i in range(36):
        a0 = i * 10
        d.arc([c - r, c - r, c + r, c + r], a0, a0 + 6, fill=255, width=10)
    return Image.fromarray(np.dstack([np.full((S, S, 3), 255, np.uint8), (np.asarray(m) * .9).astype(np.uint8)])).resize((128, 128), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    imgs = {'StampRound.tga': round_stamp(), 'StampRect.tga': rect_stamp(), 'StampSlot.tga': slot()}
    for name, im in imgs.items():
        im.save(OUT / name, compression='tga_rle')
        print('geschrieben:', OUT / name)
    if len(sys.argv) > 1:
        sheet = Image.new('RGBA', (3 * 136, 136), (226, 205, 160, 255))
        for i, (name, im) in enumerate(imgs.items()):
            col = Image.new('RGBA', im.size, (140, 30, 20, 255) if i == 0 else (40, 52, 110, 255) if i == 1 else (90, 60, 30, 255))
            col.putalpha(im.split()[3])
            sheet.alpha_composite(col, (4 + i * 136, 4))
        sheet.save(sys.argv[1])


if __name__ == '__main__':
    main()
