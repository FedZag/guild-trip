#!/usr/bin/env python3
"""Guild Trip: Emoji-Bilder fuer den Chat bauen.

Quelle: Noto Emoji (Google, https://github.com/googlefonts/noto-emoji, 2D/png/72), heruntergeladen nach
~/Projekte/quellen/noto-emoji (uXXXX.png + LICENSE + README.md). Lizenz und Nennung: THIRD_PARTY.md.
Ergebnis: src/ONE_Chat/Textures/Emoji/<code>.tga, 64 x 64 (WoW braucht Zweierpotenzen).

  python3 -I scripts/build_emojis.py [quellordner]
"""
import os
import pathlib
import re
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.home() / "Projekte" / "quellen" / "noto-emoji"
OUT = ROOT / "src" / "ONE_Chat" / "Textures" / "Emoji"
LUA = ROOT / "src" / "ONE_Chat" / "Emoji.lua"
SIZE = 64


def wanted():
    """Alle Dateinamen, die Emoji.lua nennt."""
    text = LUA.read_text(encoding="utf-8")
    return sorted(set(re.findall(r'\{"([0-9a-f]{4,5})",', text)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    missing = []
    for code in wanted():
        src = SRC / ("u" + code + ".png")
        if not src.exists():
            missing.append(code)
            continue
        im = Image.open(src).convert("RGBA")
        # 72 -> 60 und mittig auf 64 (etwas Rand, damit nichts abgeschnitten wirkt)
        im = im.resize((60, 60), Image.LANCZOS)
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(im, (2, 2))
        canvas.save(OUT / (code + ".tga"), compression="tga_rle")
    for f in OUT.glob("*.tga"):
        if f.stem not in wanted():
            f.unlink()
    if missing:
        print("FEHLT:", " ".join(missing))
        sys.exit(1)
    print("OK:", len(wanted()), "Emojis in", OUT)


if __name__ == "__main__":
    main()
