"""Guild Trip: alle uebrigen Grafiken als EIGENE Zeichnungen (keine fremden Bilder, keine Blizzard-Dateien).
Erzeugt:
  src/ONE_Core/Textures/Hero/TripHero.tga        1024x256, Startseiten-Hintergrund (Reiseroute auf Nachtblau)
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
    S = 2
    W, H = 1024 * S, 256 * S
    im = Image.new('RGB', (W, H))
    px = im.load()
    # Nachtblauer Verlauf, links dunkler (dort liegt der Text)
    for y in range(H):
        for x in range(W):
            tx, ty = x / W, y / H
            base = lerp((6, 12, 24), (26, 52, 86), min(1, tx * 1.25))
            px[x, y] = lerp(base, (4, 8, 16), abs(ty - .45) * .9)
    d = ImageDraw.Draw(im, 'RGBA')
    # Kartengitter wie auf einer Reisekarte
    for gx in range(0, W, 64 * S):
        d.line((gx, 0, gx, H), fill=(120, 160, 210, 18), width=S)
    for gy in range(0, H, 64 * S):
        d.line((0, gy, W, gy), fill=(120, 160, 210, 18), width=S)
    # Reiseroute: gepunktete Goldlinie in der rechten Haelfte
    rnd = random.Random(7)
    pts = []
    for i in range(200):
        t = i / 199
        x = W * (.62 + .32 * t)
        y = H * (.72 - .42 * t + .16 * math.sin(t * math.pi * 2.3))
        pts.append((x, y))
    for i in range(0, len(pts) - 1, 4):
        d.line(pts[i] + pts[i + 1], fill=GOLD + (170,), width=4 * S)
    # Etappen-Punkte mit Ring
    for t, r in ((0, 13), (.45, 11), (1, 17)):
        x, y = pts[int(t * (len(pts) - 1))]
        r *= S
        d.ellipse((x - r - 4 * S, y - r - 4 * S, x + r + 4 * S, y + r + 4 * S), fill=DARK + (200,))
        d.ellipse((x - r, y - r, x + r, y + r), fill=GOLD + (255,))
        d.ellipse((x - r * .45, y - r * .45, x + r * .45, y + r * .45), fill=(30, 60, 100, 255))
    # Kompassrose als Wasserzeichen ganz rechts
    cx, cy, L = W * .9, H * .5, 110 * S
    rose = Image.new('RGBA', im.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rose)
    for k in range(8):
        a = math.radians(k * 45 - 90)
        ln = L if k % 2 == 0 else L * .55
        w = 26 * S if k % 2 == 0 else 16 * S
        tip = (cx + ln * math.cos(a), cy + ln * math.sin(a))
        l = (cx + w * math.cos(a - math.pi / 2), cy + w * math.sin(a - math.pi / 2))
        r_ = (cx + w * math.cos(a + math.pi / 2), cy + w * math.sin(a + math.pi / 2))
        rd.polygon([tip, l, (cx, cy), r_], fill=(236, 196, 110, 40))
    rd.ellipse((cx - L * .75, cy - L * .75, cx + L * .75, cy + L * .75), outline=(236, 196, 110, 40), width=3 * S)
    im = Image.alpha_composite(im.convert('RGBA'), rose.filter(ImageFilter.GaussianBlur(S)))
    # Sterne (sparsam)
    d = ImageDraw.Draw(im)
    for _ in range(60):
        x, y = rnd.uniform(W * .45, W), rnd.uniform(0, H)
        a = rnd.randint(40, 120)
        d.ellipse((x, y, x + 2 * S, y + 2 * S), fill=(220, 230, 255, a))
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
