# PLAER: deterministic SVG concepts

`plaer-wordmark.svg` uses these actual LaTeX glyphs:

```latex
\mathbb{P}\,\lfloor\,\forall\,\exists\,\mathbb{R}
```

The app uses the original wordmark, copied unchanged to
`web/assets/plaer-wordmark.svg`. Its compact logo is
`web/assets/plaer-play.svg`: a play triangle in a circle, also used for proof
checks and the favicon. This SVG is maintained directly.

All visible letter outlines come directly from the bundled KaTeX TTF fonts,
converted to SVG paths with fontTools. Glyph shapes are preserved; glyphs are
uniformly scaled and positioned at a common visual height. No image generation,
tracing, external font loading, or embedded bitmap is used. `GLYPHS.json`
records the exact font/codepoint mappings. The SVGs remain sharp at any size.

Font sources: `KaTeX_AMS-Regular` and `KaTeX_Main-Regular`, distributed with
the project's pinned Verso/KaTeX package. Font metadata credits Design Science,
Inc. (2009–2010) and Khan Academy (2014–2018), under the SIL Open Font License
1.1, with the respective KaTeX font names reserved. These files are artwork
exports, not replacement font files.

To rebuild, install the optional design dependencies `fonttools` and `resvg-py`,
then run `python design/logo/build_svg.py` from the repository root to rebuild
the wordmark source. The regular app has no dependency on these design tools.
