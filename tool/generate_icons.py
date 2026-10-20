"""Rebuild Worthhit's original UI icon font, transparent SVGs and review sheet.

Optional design dependencies: fonttools 4.67.0, CairoSVG 2.9.1, Pillow 13.0.0.
Run with the same project-local Python environment as tool/brand_assets.py.
Production builds consume committed exports and do not need this tooling.

Each icon is authored on a 24-unit grid with a two-unit angular stroke.
Geometry below is the master; font and SVG exports share exactly the same paths.
"""

import io
import json
import math
from pathlib import Path

import cairosvg
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/icons"
FAMILY = "WorthhitIcons"
UNITS = 1008  # 42 font units per design-grid unit.
STROKE = 2
EPOCH = 3780604800  # Fixed OpenType timestamp: 2023-10-20.
RTL = {"arrow_forward"}


def line(*points):
    return (list(points), False, False)


def loop(*points):
    return (list(points), True, False)


def solid(*points):
    return (list(points), True, True)


def octagon(x, y, radius):
    return loop(*[
        (x + radius * math.cos(math.pi / 8 + i * math.pi / 4),
         y + radius * math.sin(math.pi / 8 + i * math.pi / 4))
        for i in range(8)
    ])


# Keep names and order stable: published glyph codepoints must never change.
ICONS = {
    "expand_less": [line((6, 15), (12, 9), (18, 15))],
    "shopping_bag_outlined": [
        loop((4, 7), (20, 7), (20, 19), (18, 21), (4, 21)),
        line((8, 7), (8, 4), (10, 2), (14, 2), (16, 4), (16, 7)),
    ],
    "sell_outlined": [
        loop((3, 3), (12, 3), (21, 12), (12, 21), (3, 12)),
        solid((6, 6), (8, 6), (8, 8), (6, 8)),
    ],
    "arrow_forward": [line((3, 12), (20, 12)), line((13, 5), (20, 12), (13, 19))],
    "receipt_long_outlined": [
        loop((5, 3), (19, 3), (19, 21), (15.5, 19), (12, 21), (8.5, 19), (5, 21)),
        line((8, 8), (16, 8)), line((8, 12), (16, 12)),
    ],
    "compare_arrows": [
        line((3, 7), (21, 7)), line((17, 3), (21, 7), (17, 11)),
        line((21, 17), (3, 17)), line((7, 13), (3, 17), (7, 21)),
    ],
    "visibility_outlined": [
        loop((2, 12), (6, 7), (10, 5), (14, 5), (18, 7), (22, 12),
             (18, 17), (14, 19), (10, 19), (6, 17)),
        octagon(12, 12, 3),
    ],
    "handshake_outlined": [
        line((2, 7), (6, 5), (10, 8)),
        line((22, 7), (18, 5), (14, 5), (9, 10), (12, 12), (15, 9), (21, 15)),
        line((2, 15), (6, 19), (9, 19), (12, 21), (21, 12)),
        line((2, 7), (2, 15)), line((22, 7), (22, 13)),
        line((8, 14), (13, 19)), line((11, 12), (16, 17)),
    ],
    "play_arrow_outlined": [loop((7, 3), (21, 12), (7, 21))],
    "close": [line((5, 5), (19, 19)), line((19, 5), (5, 19))],
    "edit_outlined": [
        loop((4, 15), (16, 3), (21, 8), (9, 20), (3, 21)),
        line((13, 6), (18, 11)), line((4, 15), (9, 20)),
    ],
    "download_outlined": [
        line((12, 2), (12, 16)), line((6, 10), (12, 16), (18, 10)),
        line((3, 17), (3, 21), (21, 21), (21, 17)),
    ],
    "remove": [line((4, 12), (20, 12))],
    "menu": [line((3, 5), (21, 5)), line((3, 12), (21, 12)), line((3, 19), (21, 19))],
    "tune": [
        line((2, 6), (6, 6)), line((10, 6), (22, 6)), loop((6, 3), (10, 3), (10, 9), (6, 9)),
        line((2, 17), (14, 17)), line((18, 17), (22, 17)), loop((14, 14), (18, 14), (18, 20), (14, 20)),
    ],
    "add": [line((4, 12), (20, 12)), line((12, 4), (12, 20))],
    "devices_outlined": [
        line((12, 17), (2, 17), (2, 3), (19, 3), (19, 7)),
        loop((14, 9), (22, 9), (22, 21), (14, 21)), line((5, 21), (11, 21)),
        line((8, 17), (8, 21)),
    ],
    "search": [octagon(10, 10, 7), line((15, 15), (21, 21))],
    "visibility_off_outlined": [
        line((3, 3), (21, 21)), line((8, 5), (14, 5), (18, 7), (22, 12), (19, 16)),
        line((5, 8), (2, 12), (6, 17), (10, 19), (14, 19), (16, 18)),
        line((10, 10), (9, 12), (12, 15), (14, 14)),
    ],
    "delete_outline": [
        line((3, 6), (21, 6)), loop((8, 6), (8, 3), (16, 3), (16, 6)),
        line((5, 6), (5, 19), (7, 21), (19, 21), (19, 6)),
        line((10, 10), (10, 17)), line((14, 10), (14, 17)),
    ],
    "refresh": [
        line((20, 10), (18, 5), (14, 3), (8, 3), (4, 7), (3, 12),
             (5, 18), (10, 21), (16, 20), (20, 16)),
        line((14, 10), (20, 10), (20, 4)),
    ],
    "hub_outlined": [
        loop((9, 9), (15, 9), (15, 15), (9, 15)),
        loop((2, 2), (6, 2), (6, 6), (2, 6)),
        loop((18, 2), (22, 2), (22, 6), (18, 6)),
        loop((2, 18), (6, 18), (6, 22), (2, 22)),
        loop((18, 18), (22, 18), (22, 22), (18, 22)),
        line((6, 6), (9, 9)), line((15, 9), (18, 6)),
        line((6, 18), (9, 15)), line((15, 15), (18, 18)),
    ],
    "info_outline": [
        loop((7, 2), (17, 2), (22, 7), (22, 17), (17, 22), (7, 22), (2, 17), (2, 7)),
        solid((11, 6), (13, 6), (13, 8), (11, 8)),
        line((10, 11), (12, 11), (12, 18)), line((9, 18), (15, 18)),
    ],
    "expand_more": [line((6, 9), (12, 15), (18, 9))],
    "check": [line((3, 12), (9, 18), (21, 6))],
    "content_copy": [
        loop((8, 8), (21, 8), (21, 21), (8, 21)),
        line((4, 16), (3, 16), (3, 3), (16, 3), (16, 4)),
    ],
    "open_in_new": [
        line((12, 3), (3, 3), (3, 21), (21, 21), (21, 12)),
        line((9, 15), (21, 3)), line((14, 3), (21, 3), (21, 10)),
    ],
    "language": [
        octagon(12, 12, 10), line((3, 8), (21, 8)), line((3, 16), (21, 16)),
        loop((12, 2), (16, 8), (16, 16), (12, 22), (8, 16), (8, 8)),
    ],
    "dark_mode_outlined": [
        loop((11, 2), (6, 4), (3, 8), (2, 13), (5, 19), (10, 22),
             (16, 21), (21, 17), (15, 17), (10, 13), (9, 8)),
    ],
    "light_mode_outlined": [
        octagon(12, 12, 4.5),
        line((12, 1), (12, 4)), line((12, 20), (12, 23)),
        line((1, 12), (4, 12)), line((20, 12), (23, 12)),
        line((4, 4), (6, 6)), line((18, 18), (20, 20)),
        line((4, 20), (6, 18)), line((18, 6), (20, 4)),
    ],
    "update": [
        line((20, 9), (18, 5), (14, 3), (8, 3), (4, 7), (3, 12),
             (5, 18), (10, 21), (16, 20), (20, 16)),
        line((15, 9), (20, 9), (20, 4)), line((12, 7), (12, 12), (16, 14)),
    ],
    "help_outline": [
        loop((7, 2), (17, 2), (22, 7), (22, 17), (17, 22), (7, 22), (2, 17), (2, 7)),
        line((8, 8), (9, 6), (14, 6), (16, 8), (16, 10), (12, 13), (12, 15)),
        solid((11, 17), (13, 17), (13, 19), (11, 19)),
    ],
    "code": [
        line((7, 6), (2, 12), (7, 18)), line((17, 6), (22, 12), (17, 18)),
        line((14, 4), (10, 20)),
    ],
    "shield_outlined": [
        loop((3, 5), (12, 2), (21, 5), (21, 14), (17, 19), (12, 22), (7, 19), (3, 14)),
        line((7, 12), (11, 16), (17, 9)),
    ],
    "notifications_outlined": [
        loop((4, 17), (6, 14), (6, 7), (9, 4), (15, 4), (18, 7), (18, 14), (20, 17)),
        line((9, 21), (15, 21)), line((12, 2), (12, 4)),
    ],
}


def stroke_contours(points, closed):
    """Offset centerlines to mitered outlines, with flat ends on open paths."""
    normals = []
    pairs = list(zip(points, points[1:] + ([points[0]] if closed else [])))
    for (x1, y1), (x2, y2) in pairs:
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy)
        normals.append((-dy / length, dx / length))

    sides = []
    for sign in (1, -1):
        side = []
        for index, (x, y) in enumerate(points):
            before = normals[index - 1] if index or closed else normals[0]
            after = normals[index] if index < len(normals) else normals[-1]
            mx, my = before[0] + after[0], before[1] + after[1]
            denominator = mx * after[0] + my * after[1]
            scale = sign * STROKE / 2 / denominator
            side.append((x + mx * scale, y + my * scale))
        sides.append(side)
    if closed:
        return [sides[0], list(reversed(sides[1]))]
    return [sides[0] + list(reversed(sides[1]))]


def contours(shapes):
    result = []
    for points, closed, filled in shapes:
        result.extend([points] if filled else stroke_contours(points, closed))
    return result


def svg_path(outlines):
    return " ".join(
        "M" + "L".join(f"{x:.4f},{y:.4f}" for x, y in contour) + "Z"
        for contour in outlines
    )


def svg(outlines, color="currentColor"):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
        f'viewBox="0 0 24 24"><path fill="{color}" d="{svg_path(outlines)}"/></svg>\n'
    )


def generate_font(geometry):
    order = [".notdef", *geometry]
    font = FontBuilder(UNITS, isTTF=True)
    font.setupGlyphOrder(order)
    font.setupCharacterMap({0xE900 + i: name for i, name in enumerate(geometry)})
    glyphs = {}
    for name in order:
        pen = TTGlyphPen(None)
        for contour in geometry.get(name, []):
            points = [(round(x * 42), round((24 - y) * 42)) for x, y in contour]
            pen.moveTo(points[0])
            for point in points[1:]:
                pen.lineTo(point)
            pen.closePath()
        glyphs[name] = pen.glyph()
        # Some composite symbols overlap their strokes intentionally.
        if name != ".notdef" and len(glyphs[name].flags):
            glyphs[name].flags[0] |= 0x40  # OVERLAP_SIMPLE
    font.setupGlyf(glyphs)
    font.setupHorizontalMetrics({
        name: (UNITS, getattr(glyphs[name], "xMin", 0)) for name in order
    })
    font.setupHorizontalHeader(ascent=UNITS, descent=0)
    font.setupNameTable({
        "familyName": FAMILY,
        "styleName": "Regular",
        "uniqueFontIdentifier": "Worthhit: UI Icons: 1.1",
        "fullName": "Worthhit Icons",
        "psName": FAMILY,
        "version": "Version 1.100",
        "copyright": "Original Worthhit UI artwork. MIT License.",
        "licenseDescription": "MIT License; see the project LICENSE.",
    })
    font.setupOS2(
        sTypoAscender=UNITS, sTypoDescender=0, usWinAscent=UNITS,
        usWinDescent=0, sxHeight=UNITS, sCapHeight=UNITS,
    )
    font.setupPost()
    font.setupMaxp()
    font.font["head"].created = EPOCH
    font.font["head"].modified = EPOCH
    font.font.recalcTimestamp = False
    font.save(DEST / f"{FAMILY}.ttf")


def generate_dart():
    lines = [
        "// Generated by tool/generate_icons.py; edit the master geometry there.",
        "// ignore_for_file: constant_identifier_names",
        "",
        "import 'package:flutter/widgets.dart';",
        "",
        "/// Worthhit's angular, theme-aware UI symbols.",
        "///",
        "/// Use at 18–24 logical pixels, inside accessible targets of at least 44 pixels.",
        "/// Every interactive icon still needs a localized tooltip or label.",
        "abstract final class WorthhitIcons {",
        "  static const fontFamily = 'WorthhitIcons';",
        "",
    ]
    for index, name in enumerate(ICONS):
        single_line = (
            f"  static const {name} = IconData(0x{0xE900 + index:x}, "
            "fontFamily: fontFamily);"
        )
        if name not in RTL and len(single_line) <= 80:
            lines.append(single_line)
            continue
        lines += [
            f"  static const {name} = IconData(",
            f"    0x{0xE900 + index:x},",
            "    fontFamily: fontFamily,",
            *("    matchTextDirection: true," for _ in [0] if name in RTL),
            "  );",
        ]
    lines.append("}")
    (ROOT / "lib/ui/worthhit_icons.dart").write_text("\n".join(lines) + "\n")


def review_sheet(geometry):
    """Review both theme colors at actual 20/24px and enlarged 48px sizes."""
    columns, cell_w, cell_h = 5, 210, 126
    rows = math.ceil(len(geometry) / columns)
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h * 2), "#E8E9DF")
    draw = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(str(ROOT / "assets/fonts/Roboto-Regular.ttf"), 12)
    for theme, background, foreground in [
        (0, "#E8E9DF", "#252A25"), (1, "#161A18", "#E9EDE1")
    ]:
        draw.rectangle((0, rows * cell_h * theme, sheet.width,
                        rows * cell_h * (theme + 1)), fill=background)
        for index, (name, outline) in enumerate(geometry.items()):
            x = (index % columns) * cell_w
            y = ((index // columns) + theme * rows) * cell_h
            for size, offset in [(20, 20), (24, 63), (48, 113)]:
                raster = cairosvg.svg2png(bytestring=svg(outline, foreground).encode(),
                                         output_width=size, output_height=size)
                image = Image.open(io.BytesIO(raster)).convert("RGBA")
                sheet.paste(image, (x + offset, y + 24 + (48 - size) // 2), image)
            draw.text((x + 12, y + 88), name, fill=foreground, font=label_font)
    review = ROOT / ".impeccable/review"
    review.mkdir(parents=True, exist_ok=True)
    sheet.save(review / "worthhit-icons-contact-sheet.png")


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    geometry = {name: contours(shapes) for name, shapes in ICONS.items()}
    for name, outline in geometry.items():
        (DEST / f"{name}.svg").write_text(svg(outline))
    generate_font(geometry)
    generate_dart()
    manifest = {
        "family": FAMILY,
        "design_size": 24,
        "stroke_width": STROKE,
        "license": "MIT",
        "glyphs": [
            {"name": name, "codepoint": 0xE900 + i, "mirrors_in_rtl": name in RTL}
            for i, name in enumerate(ICONS)
        ],
    }
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    review_sheet(geometry)
    font = TTFont(DEST / f"{FAMILY}.ttf")
    assert set(font.getBestCmap().values()) == set(ICONS)
    print(f"Generated {len(ICONS)} transparent SVGs and {FAMILY}.ttf; contact sheet in .impeccable/review.")


if __name__ == "__main__":
    main()
