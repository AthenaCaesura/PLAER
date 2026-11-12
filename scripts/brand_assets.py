"""Embed the canonical PLAER SVGs in standalone HTML and CSS."""

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "__PLAER_PLAY_URI__": "plaer-play.svg",
    "__PLAER_WORDMARK_URI__": "plaer-wordmark.svg",
}


def inline_brand_assets(source: str) -> str:
    for marker, filename in ASSETS.items():
        if marker in source:
            encoded = base64.b64encode((ROOT / "web/assets" / filename).read_bytes()).decode("ascii")
            source = source.replace(marker, "data:image/svg+xml;base64," + encoded)
    return source
