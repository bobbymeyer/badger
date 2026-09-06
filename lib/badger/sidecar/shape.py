"""Badger type sidecar.

Shapes text with HarfBuzz and extracts glyph outlines with fontTools. One
JSON request on stdin, one JSON response on stdout. All coordinates are in
font units with y up, exactly as the font stores them; the Ruby side scales
and flips.

Requests:
  {"op": "doctor"}
  {"op": "shape", "font": "/path/to/font.ttf", "text": "STOCKHOLM",
   "features": {"kern": true, "liga": true}, "variations": {"wght": 700},
   "direction": "ltr", "script": "Latn", "language": "en"}

The shape response carries the font's vertical metrics, one entry per
shaped glyph (gid, name, cluster, advance and offsets) and an outline map
keyed by gid so repeated glyphs are only serialized once.
"""

import json
import sys


def doctor():
    report = {"python": sys.version.split()[0]}
    for module, key in (("fontTools", "fonttools"), ("uharfbuzz", "uharfbuzz"), ("pathops", "skia-pathops")):
        try:
            mod = __import__(module)
            report[key] = getattr(mod, "version", None) or getattr(mod, "__version__", "present")
        except ImportError:
            report[key] = None
    return report


def shape(request):
    import uharfbuzz as hb
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.ttLib import TTFont

    path = request["font"]
    text = request.get("text", "")
    variations = request.get("variations") or {}
    features = request.get("features") or {}

    blob = hb.Blob.from_file_path(path)
    face = hb.Face(blob)
    font = hb.Font(face)
    if variations:
        font.set_variations(variations)

    buffer = hb.Buffer()
    buffer.add_str(text)
    buffer.guess_segment_properties()
    if request.get("direction"):
        buffer.direction = request["direction"]
    if request.get("script"):
        buffer.script = request["script"]
    if request.get("language"):
        buffer.language = request["language"]
    hb.shape(font, buffer, {k: bool(v) for k, v in features.items()})

    tt = TTFont(path)
    glyph_set = tt.getGlyphSet(location=variations or None)
    order = tt.getGlyphOrder()

    glyphs = []
    outlines = {}
    for info, pos in zip(buffer.glyph_infos, buffer.glyph_positions):
        gid = info.codepoint
        name = order[gid] if gid < len(order) else None
        glyphs.append({
            "gid": gid,
            "name": name,
            "cluster": info.cluster,
            "advance": pos.x_advance,
            "x_offset": pos.x_offset,
            "y_offset": pos.y_offset,
        })
        if gid not in outlines and name is not None:
            pen = SVGPathPen(glyph_set)
            glyph_set[name].draw(pen)
            outlines[gid] = pen.getCommands()

    return {
        "upem": tt["head"].unitsPerEm,
        "ascender": tt["hhea"].ascent,
        "descender": tt["hhea"].descent,
        "cap_height": vertical_metric(tt, glyph_set, "sCapHeight", "H", BoundsPen),
        "x_height": vertical_metric(tt, glyph_set, "sxHeight", "x", BoundsPen),
        "glyphs": glyphs,
        "outlines": {str(gid): d for gid, d in outlines.items()},
    }


def vertical_metric(tt, glyph_set, os2_field, fallback_glyph, BoundsPen):
    os2 = tt.get("OS/2")
    value = getattr(os2, os2_field, 0) if os2 is not None else 0
    if value:
        return value
    cmap = tt.getBestCmap() or {}
    name = cmap.get(ord(fallback_glyph))
    if name is None:
        return None
    pen = BoundsPen(glyph_set)
    glyph_set[name].draw(pen)
    return pen.bounds[3] if pen.bounds else None


def main():
    try:
        request = json.load(sys.stdin)
        op = request.get("op")
        if op == "doctor":
            result = doctor()
        elif op == "shape":
            result = shape(request)
        else:
            raise ValueError(f"unknown op {op!r}")
        json.dump(result, sys.stdout)
    except Exception as error:  # noqa: BLE001 - every failure must reach Ruby as JSON
        json.dump({"error": f"{type(error).__name__}: {error}"}, sys.stdout)
        sys.exit(1)


if __name__ == "__main__":
    main()
