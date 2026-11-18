"""Guild Trip: alle uebrigen Grafiken als EIGENE Zeichnungen (keine fremden Bilder, keine Blizzard-Dateien).
Erzeugt:
  src/ONE_Core/Textures/Hero/TripHero.tga        1024x256, Startseiten-Hintergrund (ruhige Abenddaemmerung)
  src/ONE_Core/Textures/Common/CloseGlyph.tga    64x64, Schliessen-Kreuz
  src/ONE_Guild/Textures/MemberPin.tga           64x64, Kartenpunkt Gildenmitglied
  src/ONE_Guild/Textures/MemberPinSelected.tga   64x64, ausgewaehlter Kartenpunkt
  src/ONE_Nav/Textures/QuestGoal.tga             64x64, Quest-Symbol Zielgebiet (Karte/Minimap)
  src/ONE_Nav/Textures/QuestDone.tga             64x64, Quest-Symbol fertig/abgeben
  src/ONE_Nav/Textures/QuestAvailable.tga        64x64, Questgeber mit neuer Quest ("!")
Logo: scripts/build_logo.py, Navi-Pfeil: scripts/build_nav_arrow.py.
Aufruf: python3 scripts/build_textures.py
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / 'src'
GOLD = (236, 196, 110)
DARK = (14, 10, 6)


def lerp(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(len(a)))


def hero():
    """Startseite: ruhige Abenddaemmerung ueber Huegeln (0.7.1, Nutzer-Wunsch: ruhiges Bild).
    Links dunkler, damit Begruessung und Spruch gut lesbar sind."""
    S = 2
    W, H = 1024 * S, 256 * S
    im = Image.new('RGB', (W, H))
    px = im.load()
    sun = (W * .80, H * .56)
    for y in range(H):
        ty = y / H
        # Himmel: oben tiefes Schieferblau, zum Horizont warmes, gedaempftes Abendlicht
        sky = lerp((18, 22, 36), (104, 78, 72), min(1, max(0, (ty - .05) / .6)) ** 1.4)
        for x in range(W):
            dx, dy = (x - sun[0]) / W, (y - sun[1]) / H
            glow = max(0, 1 - math.sqrt(dx * dx * 4 + dy * dy * 9) * 2.2) ** 2
            c = lerp(sky, (196, 150, 108), glow * .55)
            px[x, y] = c
    d = ImageDraw.Draw(im, 'RGBA')
    # tief stehende Sonne, weich
    r = 26 * S
    sunimg = Image.new('RGBA', im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sunimg).ellipse((sun[0] - r, sun[1] - r, sun[0] + r, sun[1] + r), fill=(240, 206, 160, 150))
    im = Image.alpha_composite(im.convert('RGBA'), sunimg.filter(ImageFilter.GaussianBlur(6 * S)))
    # Huegelketten von hinten (dunstig) nach vorn (dunkel), dazwischen Nebel
    layers = [
        (.60, 26, (78, 66, 78), 1.3, 3),
        (.70, 30, (52, 46, 60), 2.1, 11),
        (.80, 26, (32, 30, 42), 3.0, 23),
        (.90, 20, (16, 17, 26), 4.2, 37),
    ]
    for base, amp, col, freq, seed in layers:
        rnd = random.Random(seed)
        ph = [rnd.uniform(0, 6.28) for _ in range(3)]
        hill = Image.new('RGBA', im.size, (0, 0, 0, 0))
        hd = ImageDraw.Draw(hill)
        pts = [(0, H)]
        for i in range(0, W + 8, 8):
            t = i / W
            yy = H * base - S * amp * (math.sin(t * math.pi * freq + ph[0]) * .6
                + math.sin(t * math.pi * freq * 2.3 + ph[1]) * .3 + math.sin(t * math.pi * freq * 5.1 + ph[2]) * .1)
            pts.append((i, yy))
        pts.append((W, H))
        hd.polygon(pts, fill=col + (255,))
        im = Image.alpha_composite(im, hill)
        fog = Image.new('RGBA', im.size, (0, 0, 0, 0))
        ImageDraw.Draw(fog).rectangle((0, H * base - 6 * S, W, H * base + 10 * S), fill=(170, 150, 150, 26))
        im = Image.alpha_composite(im, fog.filter(ImageFilter.GaussianBlur(8 * S)))
    # links abdunkeln (Text), sanft auslaufend
    shade = Image.new('RGBA', im.size, (0, 0, 0, 0))
    sp = shade.load()
    for x in range(W):
        a = int(170 * max(0, 1 - x / (W * .55)) ** 1.5)
        for y in range(H):
            sp[x, y] = (8, 9, 16, a)
    im = Image.alpha_composite(im, shade)
    out = ROOT / 'ONE_Core' / 'Textures' / 'Hero' / 'TripHero.tga'
    im.convert('RGB').resize((1024, 256), Image.LANCZOS).save(out)
    return out


def close_glyph():
    N = 256
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for a, b in (((64, 64), (192, 192)), ((192, 64), (64, 192))):
        d.line(a + b, fill=(255, 255, 255, 255), width=26)
    for p in ((64, 64), (192, 192), (192, 64), (64, 192)):
        d.ellipse((p[0] - 13, p[1] - 13, p[0] + 13, p[1] + 13), fill=(255, 255, 255, 255))
    out = ROOT / 'ONE_Core' / 'Textures' / 'Common' / 'CloseGlyph.tga'
    im.resize((64, 64), Image.LANCZOS).save(out)
    return out


def member_pin(selected):
    N = 256
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    c = N / 2
    if selected:
        glow = Image.new('RGBA', im.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((8, 8, N - 8, N - 8), fill=(90, 200, 255, 170))
        im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10)))
    d = ImageDraw.Draw(im)
    ring = (120, 220, 255, 255) if selected else GOLD + (255,)
    d.ellipse((c - 104, c - 104, c + 104, c + 104), fill=DARK + (255,))
    d.ellipse((c - 96, c - 96, c + 96, c + 96), fill=ring)
    d.ellipse((c - 74, c - 74, c + 74, c + 74), fill=(16, 40, 56, 255))
    # Raute mit Haken: "teilt freiwillig seinen Standort"
    d.polygon([(c, c - 54), (c + 54, c), (c, c + 54), (c - 54, c)], fill=(30, 70, 92, 255), outline=ring)
    d.line((c - 26, c + 2, c - 6, c + 22, c + 28, c - 18), fill=GOLD + (255,), width=14, joint='curve')
    name = 'MemberPinSelected.tga' if selected else 'MemberPin.tga'
    out = ROOT / 'ONE_Guild' / 'Textures' / name
    im.resize((64, 64), Image.LANCZOS).save(out)
    return out


def quest_pin(done):
    """Eigenes Quest-Symbol: Goldring mit Punkt (Ziel) bzw. mit Haken (fertig, abgeben)."""
    N = 256
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    c = N / 2
    d = ImageDraw.Draw(im)
    fill = (40, 92, 30, 255) if done else (70, 34, 10, 255)
    d.ellipse((c - 110, c - 110, c + 110, c + 110), fill=DARK + (255,))
    d.ellipse((c - 100, c - 100, c + 100, c + 100), fill=GOLD + (255,))
    d.ellipse((c - 76, c - 76, c + 76, c + 76), fill=fill)
    if done:
        d.line((c - 44, c + 2, c - 12, c + 36, c + 46, c - 34), fill=GOLD + (255,), width=26, joint='curve')
    else:
        d.ellipse((c - 30, c - 30, c + 30, c + 30), fill=GOLD + (255,))
    out = ROOT / 'ONE_Nav' / 'Textures' / ('QuestDone.tga' if done else 'QuestGoal.tga')
    im.resize((64, 64), Image.LANCZOS).save(out)
    return out


def quest_available():
    """Eigenes Questgeber-Symbol: Goldring mit goldenem Ausrufezeichen."""
    N = 256
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    c = N / 2
    d = ImageDraw.Draw(im)
    d.ellipse((c - 110, c - 110, c + 110, c + 110), fill=DARK + (255,))
    d.ellipse((c - 100, c - 100, c + 100, c + 100), fill=GOLD + (255,))
    d.ellipse((c - 76, c - 76, c + 76, c + 76), fill=(70, 34, 10, 255))
    d.polygon([(c - 20, c - 58), (c + 20, c - 58), (c + 11, c + 16), (c - 11, c + 16)], fill=GOLD + (255,))
    d.ellipse((c - 15, c + 28, c + 15, c + 58), fill=GOLD + (255,))
    out = ROOT / 'ONE_Nav' / 'Textures' / 'QuestAvailable.tga'
    im.resize((64, 64), Image.LANCZOS).save(out)
    return out


if __name__ == '__main__':
    for path in (hero(), close_glyph(), member_pin(False), member_pin(True), quest_pin(False), quest_pin(True), quest_available()):
        print('geschrieben:', path)
