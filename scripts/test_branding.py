"""Check that offline exports use the actual canonical SVG branding assets."""

import base64
from html.parser import HTMLParser
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class BrandingParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = {}
        self.favicon = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "img" and attrs.get("class", "").startswith("brand-"):
            self.images[attrs["class"]] = attrs["src"]
        if tag == "link" and attrs.get("rel") == "icon":
            self.favicon = attrs["href"]


def main():
    html = (ROOT / "dist/index.html").read_text(encoding="utf-8")
    parser = BrandingParser()
    parser.feed(html)
    assert "__PLAER_" not in html, "An asset was not embedded"
    assert parser.images["brand-mark"] == parser.favicon
    assert 'url("' + parser.favicon + '")' in html, "Proof buttons do not share the brand icon"
    for key, file in [("brand-mark", "plaer-play.svg"), ("brand-wordmark", "plaer-wordmark.svg")]:
        uri = parser.images[key]
        assert uri.startswith("data:image/svg+xml;base64,")
        svg = base64.b64decode(uri.split(",", 1)[1])
        assert svg == (ROOT / "web/assets" / file).read_bytes()
        root = ET.fromstring(svg)
        assert not root.findall(".//{http://www.w3.org/2000/svg}image")
    assert (ROOT / "web/assets/plaer-wordmark.svg").read_bytes() == (ROOT / "design/logo/plaer-wordmark.svg").read_bytes()
    print("PASS: original SVG wordmark; identical play asset for header, favicon and proof controls; standalone embedding")


if __name__ == "__main__":
    main()
