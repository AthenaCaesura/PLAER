# PLAER branding

- `plaer-wordmark.svg`: the original mathematical-glyph SVG wordmark,
  copied unchanged from `design/logo/plaer-wordmark.svg`.
- `plaer-play.svg`: the compact circular play mark, shared by the header,
  favicon, and the buttons that run proof checks.

`scripts/brand_assets.py` embeds these canonical SVGs into the standalone
paper. No font downloads, image generation, or additional runtime requests
are required. The wordmark's actual KaTeX glyph sources are documented in
`design/logo/SVG-README.md`; the play mark is simple original SVG geometry.
