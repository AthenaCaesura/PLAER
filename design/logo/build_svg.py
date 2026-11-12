"""Build PLAER from real KaTeX font outlines, without image generation.

Optional design dependencies: pip install fonttools resvg-py
The app itself does not need these packages or any fonts for the output SVGs.
"""

from pathlib import Path
import sys
import html
import json
import logging

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".tools/logo-fonts"))
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen

logging.getLogger("fontTools.ttLib.tables._h_e_a_d").setLevel(logging.ERROR)
OUT = Path(__file__).resolve().parent
FONTS = ROOT / ".lake/packages/verso/vendored-js/katex/fonts"
TEAL = "#134D43"
PAPER = "#FCFBF6"


def glyph(font_name, codepoint):
    font = TTFont(FONTS / (font_name + ".ttf"))
    glyphs = font.getGlyphSet()
    name = font.getBestCmap()[codepoint]
    pen = SVGPathPen(glyphs)
    glyphs[name].draw(pen)
    bounds = BoundsPen(glyphs)
    glyphs[name].draw(bounds)
    return pen.getCommands(), bounds.bounds


def outline(data, left, top, height, fill="currentColor"):
    path, (x0, y0, x1, y1) = data
    scale = height / (y1 - y0)
    width = (x1 - x0) * scale
    tx, ty = left - x0 * scale, top + y1 * scale
    return (f'<path fill="{fill}" d="{path}" '
            f'transform="matrix({scale:.8f} 0 0 {-scale:.8f} {tx:.8f} {ty:.8f})"/>'), width


def svg(width, height, title, description, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:g} {height:g}" '
            f'width="{width:g}" height="{height:g}" role="img" aria-labelledby="title desc" '
            f'style="color:{TEAL}">\n<title id="title">{html.escape(title)}</title>\n'
            f'<desc id="desc">{html.escape(description)}</desc>\n'
            '<!-- Actual KaTeX font outlines; no generated bitmap or external font dependency. -->\n'
            + "\n".join(body) + "\n</svg>\n")


def main():
    # These are KaTeX's actual font/codepoint mappings, including the AMS
    # blackboard-bold glyphs stored at the ordinary ASCII P/R positions.
    specs = [
        (r"\mathbb{P}", "KaTeX_AMS-Regular", ord("P")),
        (r"\lfloor", "KaTeX_Main-Regular", 0x230A),
        (r"\forall", "KaTeX_Main-Regular", 0x2200),
        (r"\exists", "KaTeX_Main-Regular", 0x2203),
        (r"\mathbb{R}", "KaTeX_AMS-Regular", ord("R")),
    ]
    glyphs = [glyph(font, code) for _, font, code in specs]
    body, x = [], 24.0
    for data in glyphs:
        path, width = outline(data, x, 24, 120)
        body.append(path)
        x += width + 20
    wordmark = svg(x + 4, 168, "PLAER", "PLAER: P, floor bracket, universal quantifier, existential quantifier, R. Actual LaTeX glyph outlines.", body)
    (OUT / "plaer-wordmark.svg").write_text(wordmark, encoding="utf-8")

    # A single initial remains recognizable when the whole name would be too small.
    p = glyphs[0]
    _, (x0, y0, x1, y1) = p
    p_height = 72
    p_width = (x1 - x0) / (y1 - y0) * p_height
    p_path, _ = outline(p, (128 - p_width) / 2, 28, p_height, PAPER)
    icon = svg(128, 128, "PLAER icon", "Blackboard-bold P inside a circular teal field.",
        [f'<circle cx="64" cy="64" r="62" fill="{TEAL}"/>', p_path])
    (OUT / "plaer-circle.svg").write_text(icon, encoding="utf-8")
    (OUT / "GLYPHS.json").write_text(json.dumps([
        {"latex": latex, "font": font, "codepoint_in_font": hex(code)}
        for latex, font, code in specs], indent=2) + "\n", encoding="utf-8")

    import resvg_py
    # Raster previews are rendered from the finished SVGs, never generated.
    for name, sizes in [("plaer-wordmark", [960]), ("plaer-circle", [512, 64, 32, 16])]:
        source = (OUT / (name + ".svg")).read_text(encoding="utf-8")
        for width in sizes:
            png = resvg_py.svg_to_bytes(svg_string=source, width=width)
            (OUT / f"{name}-{width}.png").write_bytes(png)
    print("Built two path-only SVGs and raster previews from actual KaTeX glyphs.")


if __name__ == "__main__":
    main()
