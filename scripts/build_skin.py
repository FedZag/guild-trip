"""Guild Trip: Grundtexturen des Aussehens "Nachtroute" (eigene Zeichnungen).
Alle Texturen sind weiss und werden im Spiel eingefaerbt (SetVertexColor), deshalb
gelten sie fuer jeden Skin.
Erzeugt in src/ONE_Core/Textures/Skin/:
  Round.tga   64x64, gefuellte Flaeche mit runden Ecken (Radius 16), Neun-Teile-Quelle
  Shadow.tga  64x64, weicher Schatten (Rand 16 px weich), Neun-Teile-Quelle
  Sheen.tga   8x64,  Licht von oben: Deckkraft 100 % oben -> 0 % unten
  Dot.tga     32x32, runder Punkt (Routen-Wegpunkte, Online-Punkt)
  Glow.tga    64x64, weiches Leuchten (Wegpunkt "hier")
  Ring.tga    16x16, 1 px Rahmen mit Radius 4 (Umriss-Knoepfe), Neun-Teile-Quelle 1:1
  Circle.tga  64x64, voller Kreis (Maske fuer runde Symbole, Kugelgrund)
  CircleRing.tga 64x64, Kreisring 4 px (Rand um runde Symbole, Glas-Look)
  RoundRing.tga 64x64, Umriss 2 px mit Radius 16 (Rand der Glasflaechen), Neun-Teile-Quelle
  Orb.tga     64x64, Kugel-Licht: oben links hell, nach unten dunkel (Glas-Look)
Aufruf: python3 scripts/build_skin.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Core' / 'Textures' / 'Skin'
SS = 8  # Ueberabtastung fuer glatte Kanten


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / name, compression=None)


def white_with_alpha(alpha):
    im = Image.new('RGBA', alpha.size, (255, 255, 255, 0))
    im.putalpha(alpha)
    return im


def round_rect(size, radius):
    a = Image.new('L', (size * SS, size * SS), 0)
    ImageDraw.Draw(a).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius * SS, fill=255)
    return a.resize((size, size), Image.LANCZOS)


def shadow():
    size, blur = 64, 16
    a = Image.new('L', (size, size), 0)
    ImageDraw.Draw(a).rounded_rectangle([blur, blur, size - blur - 1, size - blur - 1], 6, fill=255)
    a = a.filter(ImageFilter.GaussianBlur(blur / 2.6))
    return a


def sheen():
    a = Image.new('L', (8, 64))
    for y in range(64):
        v = int(255 * (1 - y / 63) ** 1.6)
        for x in range(8):
            a.putpixel((x, y), v)
    return a


def dot():
    return round_rect(32, 16)


def ring():
    size, r = 16, 4
    a = Image.new('L', (size * SS, size * SS), 0)
    d = ImageDraw.Draw(a)
    d.rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], r * SS, fill=255)
    d.rounded_rectangle([SS, SS, (size - 1) * SS - 1, (size - 1) * SS - 1], (r - 1) * SS, fill=0)
    return a.resize((size, size), Image.LANCZOS)


def glow():
    a = Image.new('L', (64, 64), 0)
    ImageDraw.Draw(a).ellipse([20, 20, 43, 43], fill=255)
    return a.filter(ImageFilter.GaussianBlur(7))


def circle(size=64):
    a = Image.new('L', (size * SS, size * SS), 0)
    ImageDraw.Draw(a).ellipse([0, 0, size * SS - 1, size * SS - 1], fill=255)
    return a.resize((size, size), Image.LANCZOS)


def circle_ring(size=64, width=4):
    a = Image.new('L', (size * SS, size * SS), 0)
    d = ImageDraw.Draw(a)
    d.ellipse([0, 0, size * SS - 1, size * SS - 1], fill=255)
    w = width * SS
    d.ellipse([w, w, size * SS - 1 - w, size * SS - 1 - w], fill=0)
    return a.resize((size, size), Image.LANCZOS)


def orb(size=64):
    # Glanzlicht: weisser Fleck oben links, Rest durchsichtig; liegt ueber der Kugelfarbe
    a = Image.new('L', (size, size), 0)
    ImageDraw.Draw(a).ellipse([12, 8, 34, 26], fill=150)
    a = a.filter(ImageFilter.GaussianBlur(6))
    m = circle(size)
    from PIL import ImageChops
    return ImageChops.multiply(a, m)


def round_ring(size=64, radius=16, width=2):
    a = Image.new('L', (size * SS, size * SS), 0)
    d = ImageDraw.Draw(a)
    d.rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius * SS, fill=255)
    w = width * SS
    d.rounded_rectangle([w, w, size * SS - 1 - w, size * SS - 1 - w], (radius - width) * SS, fill=0)
    return a.resize((size, size), Image.LANCZOS)


if __name__ == '__main__':
    save(white_with_alpha(round_ring()), 'RoundRing.tga')
    save(white_with_alpha(circle()), 'Circle.tga')
    save(white_with_alpha(circle_ring()), 'CircleRing.tga')
    save(white_with_alpha(orb()), 'Orb.tga')
    save(white_with_alpha(round_rect(64, 16)), 'Round.tga')
    save(white_with_alpha(shadow()), 'Shadow.tga')
    save(white_with_alpha(sheen()), 'Sheen.tga')
    save(white_with_alpha(dot()), 'Dot.tga')
    save(white_with_alpha(glow()), 'Glow.tga')
    save(white_with_alpha(ring()), 'Ring.tga')
    print('ok', OUT)
