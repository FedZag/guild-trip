"""Guild Trip: Schrift Inter (SIL Open Font License 1.1) fuer WoW aufbereiten.
WoW liest nur TrueType-Umrisse. Die OTF-Dateien von Inter (CFF) werden in
TrueType umgewandelt und auf Latein, Kyrillisch und gaengige Zeichen gekuerzt.
Erzeugt: src/ONE_Core/Fonts/Inter-Regular.ttf, Inter-SemiBold.ttf
Aufruf: python3 scripts/build_fonts.py [Ordner mit Inter-*.otf]
Benoetigt: pip install fonttools
"""
import sys
from pathlib import Path
from fontTools.ttLib import TTFont, newTable
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools import subset

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else '/usr/share/fonts/opentype/inter')
OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Core' / 'Fonts'
UNICODES = [*range(0x20, 0x7F), *range(0xA0, 0x250), *range(0x370, 0x3FF), *range(0x400, 0x4FF),
            *range(0x2000, 0x206F), 0x20AC, *range(0x2190, 0x21FF), 0x2212, 0x2713, 0x2715,
            0x25B2, 0x25B6, 0x25BC, 0x25C0, 0x25CF, 0x2026]


def otf_to_ttf(font):
    glyph_order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()
    glyf = newTable('glyf')
    glyf.glyphOrder = glyph_order
    glyf.glyphs = {}
    for name in glyph_order:
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, 1.0, reverse_direction=True))
        glyf.glyphs[name] = pen.glyph()
    font['glyf'] = glyf
    font['loca'] = newTable('loca')
    for tag in ('CFF ', 'CFF2', 'VORG'):
        if tag in font:
            del font[tag]
    maxp = font['maxp']
    maxp.tableVersion = 0x00010000
    for attr, val in (('maxZones', 1), ('maxTwilightPoints', 0), ('maxStorage', 0), ('maxFunctionDefs', 0),
                      ('maxInstructionDefs', 0), ('maxStackElements', 0), ('maxSizeOfInstructions', 0),
                      ('maxComponentElements', 0), ('maxPoints', 0), ('maxContours', 0),
                      ('maxCompositePoints', 0), ('maxCompositeContours', 0), ('maxComponentDepth', 0)):
        setattr(maxp, attr, val)
    font['head'].glyphDataFormat = 0
    font['post'].formatType = 2.0
    font['post'].extraNames = []
    font['post'].mapping = {}
    font.sfntVersion = '\x00\x01\x00\x00'


def build(weight):
    font = TTFont(SRC / f'Inter-{weight}.otf')
    opts = subset.Options()
    opts.layout_features = ['kern', 'liga', 'calt', 'tnum']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=UNICODES)
    sub.subset(font)
    otf_to_ttf(font)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f'Inter-{weight}.ttf'
    font.save(path)
    print(path, path.stat().st_size)


if __name__ == '__main__':
    build('Regular')
    build('SemiBold')
