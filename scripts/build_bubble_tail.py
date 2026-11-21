#!/usr/bin/env python3
"""Zipfel fuer die Sprechblasen im Guild-Trip-Chat (Messenger-Stil).

64x32, weiss mit Alpha (wird im Spiel eingefaerbt). Rechte Haelfte = eckige
Blasen-Ecke oben links, linke Haelfte = Zipfel, der oben nach aussen zeigt
(Kante nach innen gewoelbt). Fuer Blasen rechts wird er im Spiel gespiegelt.
Aufruf: python3 scripts/build_bubble_tail.py
"""
from pathlib import Path
from PIL import Image

DIR = Path(__file__).resolve().parent.parent / "src/ONE_Chat/Textures"
OUT = DIR / "BubbleTail.tga"
RING = DIR / "BubbleTailRing.tga"  # Glasrand passend zum Zipfel (wie Skin/RoundRing)
RING_W = 4.0  # Texturpixel: im Spiel ca. 1,25 px wie der Rand der Blase
W, H, S = 64, 32, 8  # S = Unterabtastung fuer weiche Kanten


def inside(x, y):
    # x, y in Pixeln (0..W, 0..H), y = 0 oben
    if x >= 32:
        return True
    t = y / H
    edge = 32 * t ** 0.55          # Zipfelkante: oben ganz aussen, unten an der Blase
    if x < edge:
        return False
    # Spitze leicht abrunden
    if y < 3 and x < 3:
        return (x - 3) ** 2 + (y - 3) ** 2 <= 9
    return True


def solid(x, y):
    # Blase samt Umgebung: oben ausserhalb, unterhalb des Zipfels geht die Blase gerade weiter
    if y < 0:
        return False
    if y >= H:
        return x >= 32
    if x >= W:
        return True
    return inside(x, y)


def on_ring(x, y):
    if not solid(x, y):
        return False
    for k in range(12):
        import math
        a = 2 * math.pi * k / 12
        if not solid(x + RING_W * math.cos(a), y + RING_W * math.sin(a)):
            return True
    return False


def render(fn, out):
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for py in range(H):
        for pxl in range(W):
            n = sum(fn(pxl + (i + .5) / S, py + (j + .5) / S) for i in range(S) for j in range(S))
            px[pxl, py] = (255, 255, 255, round(255 * n / (S * S)))
    im.save(out, compression="tga_rle")
    print("geschrieben:", out)


def main():
    render(inside, OUT)
    render(on_ring, RING)


if __name__ == "__main__":
    main()
