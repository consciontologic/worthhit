"""Rebuild original Worthhit vector artwork and platform exports.

Optional design tooling: CairoSVG 2.9.1, fonttools 4.67.0, Pillow 13.0.0.
Production builds use the committed exports and need none of these packages.
The generated raster concept is inspiration; this is separately authored art.
"""
import io
from pathlib import Path

import cairosvg
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets/brand"
WEB = ROOT / "web"
LIME = "#CAEF63"
INK = "#252A25"
DARK = "#161A18"
MARK = "M18 28H34L46 76L56 49H72L82 76L94 28H110L91 100H75L64 75L53 100H37Z"


def svg(body, width=128, height=128):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{body}</svg>\n'
    )


def png(source, path, size=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        bytestring=source.encode(), write_to=str(path),
        output_width=size, output_height=size,
    )


def lettering(text, x, y, size, color):
    font = instantiateVariableFont(
        TTFont(ROOT / "assets/fonts/SpaceGrotesk.ttf"), {"wght": 700}
    )
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = size / font["head"].unitsPerEm
    paths = []
    offset = 0
    for char in text:
        name = cmap[ord(char)]
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(pen)
        paths.append(f'<path transform="translate({offset} 0)" d="{pen.getCommands()}"/>')
        offset += glyphs[name].width
    return (
        f'<g fill="{color}" transform="translate({x} {y}) scale({scale} {-scale})">'
        + "".join(paths) + "</g>"
    )


def main():
    BRAND.mkdir(parents=True, exist_ok=True)
    for variant, color in [("light", INK), ("dark", LIME)]:
        mark = svg(f'<path fill="{color}" d="{MARK}"/>')
        (BRAND / f"mark-{variant}.svg").write_text(mark)
        png(mark, BRAND / f"mark-{variant}.png", 512)
        (WEB / f"favicon-{variant}.svg").write_text(mark)
        lockup = svg(
            f'<g transform="translate(0 4) scale(.75)"><path fill="{color}" d="{MARK}"/></g>'
            + lettering("worthhit", 108, 78, 76, color), 460, 108,
        )
        (BRAND / f"logo-{variant}.svg").write_text(lockup)
        png(lockup, BRAND / f"logo-{variant}.png")
    adaptive = svg(
        f'<style>path{{fill:{INK}}}@media(prefers-color-scheme:dark)'
        f'{{path{{fill:{LIME}}}}}</style><path d="{MARK}"/>'
    )
    (WEB / "favicon.svg").write_text(adaptive)
    mark = svg(f'<path fill="{LIME}" d="{MARK}"/>')
    # A dark tile remains visible on launcher surfaces of either brightness.
    tile = svg(
        f'<path fill="{DARK}" d="M0 0H128V128H0Z"/>'
        f'<path fill="{LIME}" d="{MARK}"/>'
    )
    for size in [192, 512]:
        png(mark, WEB / f"icons/Icon-{size}.png", size)
        png(tile, WEB / f"icons/Icon-maskable-{size}.png", size)
    png(tile, WEB / "icons/apple-touch-icon.png", 180)
    png(tile, WEB / "favicon.png", 32)
    image = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=tile.encode(), output_width=256, output_height=256)))
    image.save(WEB / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    social = svg(
        f'<path fill="{DARK}" d="M0 0H1200V630H0Z"/>'
        f'<path stroke="{LIME}" stroke-width="2" d="M64 160H1136M64 540H1136"/>'
        f'<g transform="translate(55 35) scale(.75)"><path fill="{LIME}" d="{MARK}"/></g>'
        + lettering("worthhit", 164, 113, 65, "#E9EDE1")
        + lettering("Know the range.", 64, 303, 84, "#E9EDE1")
        + lettering("Make a fair deal.", 64, 401, 84, LIME)
        + lettering("SECOND-HAND PRICE CHECKS", 67, 494, 25, "#E9EDE1")
        + lettering("worthhit.com", 67, 590, 24, "#E9EDE1"),
        1200, 630,
    )
    (BRAND / "social-card.svg").write_text(social)
    png(social, WEB / "social-card.png")
    print("Brand SVG, PNG, ICO and maskable exports generated.")


if __name__ == "__main__":
    main()
