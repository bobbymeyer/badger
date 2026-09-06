"""Builds test/fixtures/badger-test.ttf, a tiny font with known metrics.

    python3 test/fixtures/build_test_font.py

Glyphs are rectangles and triangles so ink bounds are exact. Metrics:
upem 1000, ascender 800, descender -200, cap height 700, x height 500.
Kern pairs: A V -100, T A -80. Ligature: f i -> f_i.
"""

import os

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

# name: (advance, contour points)
GLYPHS = {
    ".notdef": (500, [(50, 0), (450, 0), (450, 700), (50, 700)]),
    "space": (250, []),
    "A": (600, [(0, 0), (600, 0), (300, 700)]),
    "V": (600, [(0, 700), (300, 0), (600, 700)]),
    "T": (500, [(0, 600), (500, 600), (500, 700), (0, 700)]),
    "I": (300, [(100, 0), (200, 0), (200, 700), (100, 700)]),
    "H": (600, [(0, 0), (600, 0), (600, 700), (0, 700)]),
    "O": (600, [(50, 0), (550, 0), (550, 700), (50, 700)]),
    "x": (500, [(50, 0), (450, 0), (450, 500), (50, 500)]),
    "f": (300, [(50, 0), (250, 0), (250, 800), (50, 800)]),
    "i": (250, [(75, 0), (175, 0), (175, 700), (75, 700)]),
    "f_i": (500, [(50, 0), (450, 0), (450, 800), (50, 800)]),
}

CMAP = {0x20: "space", ord("A"): "A", ord("V"): "V", ord("T"): "T", ord("I"): "I",
        ord("H"): "H", ord("O"): "O", ord("x"): "x", ord("f"): "f", ord("i"): "i"}

FEATURES = """
feature kern {
    pos A V -100;
    pos T A -80;
} kern;

feature liga {
    sub f i by f_i;
} liga;
"""


def build(path):
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(list(GLYPHS))
    fb.setupCharacterMap(CMAP)
    glyphs = {}
    metrics = {}
    for name, (advance, points) in GLYPHS.items():
        pen = TTGlyphPen(None)
        if points:
            pen.moveTo(points[0])
            for p in points[1:]:
                pen.lineTo(p)
            pen.closePath()
        glyphs[name] = pen.glyph()
        metrics[name] = (advance, min((x for x, _ in points), default=0))
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "Badger Test", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200,
                sCapHeight=700, sxHeight=500)
    fb.setupPost()
    addOpenTypeFeaturesFromString(fb.font, FEATURES)
    fb.save(path)


if __name__ == "__main__":
    build(os.path.join(os.path.dirname(__file__), "badger-test.ttf"))
