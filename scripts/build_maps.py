"""Guild Trip: gezeichnete Kartenbilder fuer Kopfbereiche (eigene Zeichnung, keine fremden Bilder).
Alte Sepia-Landkarte mit Hoehenlinien, Wellen, Baeumen/Bergen, gestrichelter roter Route, Kreuz am Ziel
und Kompassrose. Keine eingezeichneten Namen – Titel/Ort setzt das Addon als Text darueber.
Erzeugt in src/ONE_Dungeons/Textures/:
  Map1.tga  Kueste      Map2.tga  Berge
  Map3.tga  Wald        Map4.tga  Wueste/Steppe
je 512x128 (Seitenverhaeltnis 4:1, reicht fuer ~420x90 im Fenster), links heller fuer Text.
Aufruf: python3 -I scripts/build_maps.py [vorschau.png]
"""
import math
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Dungeons' / 'Textures'
W, H = 1380, 345          # Zeichenflaeche (danach auf 1024x256)
INK = (70, 42, 20, 255)
RED = (140, 28, 18, 255)


def noise(rng, w, h, scale):
    sw, sh = max(2, w // scale), max(2, h // scale)
    a = Image.fromarray((rng.random((sh, sw)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    a = np.asarray(a.filter(ImageFilter.GaussianBlur(scale / 3))).astype(np.float32) / 255
    return (a - a.min()) / max(1e-6, a.max() - a.min())


def draw_map(seed, kind):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    land = .6 * noise(rng, W, H, 170) + .3 * noise(rng, W, H, 55) + .1 * noise(rng, W, H, 14)
    if kind == 'kueste':
        land = land + .45 * (xx / W) - .18
    elif kind == 'berge':
        land = land * .8 + .25
    elif kind == 'wald':
        land = land * .7 + .28
    else:
        land = land * .6 + .3
    sea = land < .42
    base = np.array([198, 170, 122], np.float32) if kind != 'wueste' else np.array([206, 176, 120], np.float32)
    img = base * (.86 + .18 * noise(rng, W, H, 40)[..., None])
    img[sea] = img[sea] * np.array([.78, .84, .86])
    for lv in (.42, .52, .62, .72, .82):
        band = np.abs(land - lv) < (.006 if lv == .42 else .0035)
        img[band] = img[band] * (.55 if lv == .42 else .8)
    wave = (np.sin(yy / 6 + np.sin(xx / 40) * 2) > .96) & sea & (land < .38)
    img[wave] *= .86
    if kind == 'wueste':
        dune = (np.sin(xx / 28 + yy / 60 + noise(rng, W, H, 60) * 6) > .97) & ~sea
        img[dune] *= .88
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(im)
    count = {'berge': 90, 'wald': 140, 'kueste': 60, 'wueste': 25}[kind]
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(10, H - 10)
        h = land[int(y), int(x)]
        if h < .44:
            continue
        if kind == 'berge' or h > .7:
            s = rng.uniform(7, 13)
            d.polygon([(x, y - s), (x - s * .8, y + s * .4), (x + s * .8, y + s * .4)], outline=(90, 60, 30, 210))
            d.line([(x, y - s), (x + s * .25, y - s * .2)], fill=(90, 60, 30, 160))
        elif kind == 'wald' or rng.random() < .6:
            d.ellipse([x - 4, y - 8, x + 4, y], outline=(80, 70, 30, 190))
            d.line([x, y, x, y + 5], fill=(80, 70, 30, 190))
        else:
            d.line([x - 5, y, x + 5, y], fill=(110, 80, 40, 150))
    # Route: von links-mittig nach rechts, gestrichelt, Kreuz am Ziel
    pts = [(rng.uniform(.38, .46) * W, rng.uniform(.55, .8) * H)]
    for _ in range(3):
        px, py = pts[-1]
        pts.append((px + rng.uniform(.08, .12) * W, float(np.clip(py + rng.uniform(-.25, .25) * H, .15 * H, .85 * H))))
    path = []
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        for t in np.linspace(0, 1, 40, endpoint=False):
            path.append((x0 + (x1 - x0) * t + math.sin(t * 6 + i) * 6, y0 + (y1 - y0) * t))
    path.append(pts[-1])
    for i in range(0, len(path) - 1, 3):
        d.line([path[i], path[i + 1]], fill=RED, width=4)
    ex, ey = pts[-1]
    d.line([ex - 11, ey - 11, ex + 11, ey + 11], fill=RED, width=6)
    d.line([ex - 11, ey + 11, ex + 11, ey - 11], fill=RED, width=6)
    sx, sy = pts[0]
    d.ellipse([sx - 7, sy - 7, sx + 7, sy + 7], outline=RED, width=4)
    # Kompassrose rechts unten
    cx, cy, r = W - 92, H - 92, 58
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=2)
    d.ellipse([cx - r + 9, cy - r + 9, cx + r - 9, cy + r - 9], outline=(70, 42, 20, 140), width=1)
    for a in range(0, 360, 45):
        L = r - 4 if a % 90 == 0 else r * .6
        ang = math.radians(a - 90)
        tip = (cx + math.cos(ang) * L, cy + math.sin(ang) * L)
        s1 = (cx + math.cos(ang + math.pi / 2) * 8, cy + math.sin(ang + math.pi / 2) * 8)
        s2 = (cx + math.cos(ang - math.pi / 2) * 8, cy + math.sin(ang - math.pi / 2) * 8)
        d.polygon([tip, s1, (cx, cy)], fill=INK)
        d.polygon([tip, s2, (cx, cy)], fill=(180, 150, 100, 255), outline=INK)
    nx = cx - 6
    d.line([nx, cy - r - 24, nx, cy - r - 8], fill=INK, width=3)
    d.line([nx + 12, cy - r - 24, nx + 12, cy - r - 8], fill=INK, width=3)
    d.line([nx, cy - r - 24, nx + 12, cy - r - 8], fill=INK, width=3)
    # Alterung: Raender dunkler, Flecken
    a = np.asarray(im).astype(np.float32)
    edge = np.minimum.reduce([xx, W - xx, yy * 3, (H - yy) * 3]) / 120
    a[..., :3] *= (.62 + .38 * np.clip(edge, 0, 1))[..., None]
    a[..., :3] *= (1 - .12 * np.clip((noise(rng, W, H, 30) - .6) * 3, 0, 1))[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).resize((512, 128), Image.LANCZOS)


KINDS = [('Map1.tga', 'kueste', 3), ('Map2.tga', 'berge', 11), ('Map3.tga', 'wald', 23), ('Map4.tga', 'wueste', 31)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    images = []
    for name, kind, seed in KINDS:
        im = draw_map(seed, kind)
        im.convert('RGB').save(OUT / name, compression='tga_rle')
        images.append(im)
        print('geschrieben:', OUT / name)
    if len(sys.argv) > 1:
        sheet = Image.new("RGB", (512, 128 * 4))
        for i, im in enumerate(images):
            sheet.paste(im.convert("RGB"), (0, i * 128))
        sheet.save(sys.argv[1])


if __name__ == '__main__':
    main()
