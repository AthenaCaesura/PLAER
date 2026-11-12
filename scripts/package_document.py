"""Bundle the Verso output, local KaTeX, fonts, and interactions into one HTML file.

This is asset packaging only. All mathematical content and membership data have
already been produced by Lean in build/document.html.
"""

from __future__ import annotations

import base64
import hashlib
import json
import re
import html
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from explanations import read_cells
from brand_assets import inline_brand_assets

ROOT = Path(__file__).resolve().parents[1]


class DefinitionParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.definitions: list[dict] = []
        self.proof_blocks: list[dict] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if "data-definition" in attributes:
            self.definitions.append(json.loads(attributes["data-definition"]))
        if "data-proof" in attributes:
            self.proof_blocks.append(json.loads(attributes["data-proof"]))


def package_document() -> Path:
    document = (ROOT / "build/document.html").read_text(encoding="utf-8")
    parser = DefinitionParser()
    parser.feed(document)
    if len(parser.definitions) > 1:
        raise ValueError("This first prototype expects exactly one generated definition")
    definition = parser.definitions[0] if parser.definitions else {"leanVersion": "4.35.0", "name": None, "samples": [], "sourcePath": "Plaer/Definitions.lean", "latex": ""}
    notebook = html.escape(json.dumps(read_cells(), ensure_ascii=False), quote=True)
    document = document.replace('data-notebook="paper-explanations"',
        'data-notebook="paper-explanations" data-notebook-state="' + notebook + '"')
    if parser.definitions and len(definition["samples"]) != 201:
        raise ValueError("Missing checked slider positions")

    katex = ROOT / ".lake/packages/verso/vendored-js/katex"
    katex_css = (katex / "katex.min.css").read_text(encoding="utf-8")

    def embed_font(match: re.Match) -> str:
        encoded = base64.b64encode((katex / match[1]).read_bytes()).decode("ascii")
        return f"url(data:font/woff2;base64,{encoded}) format('woff2')"

    # One modern font format is enough. Remove the redundant woff/ttf fallbacks.
    katex_css = re.sub(
        r"url\((fonts/[^)]+\.woff2)\) format\([\"']?woff2[\"']?\)"
        r"(?:,url\([^)]+\) format\([^)]+\))*",
        embed_font,
        katex_css,
    )
    if re.search(r"url\((?!data:)", katex_css):
        raise ValueError("A KaTeX asset was not embedded")

    shell = (ROOT / "web/shell.html").read_text(encoding="utf-8")
    replacements = {
        "<!-- DOCUMENT -->": document,
        "/* KATEX_CSS */": katex_css,
        "/* PAPER_CSS */": (ROOT / "web/paper.css").read_text(encoding="utf-8"),
        "/* KATEX_JS */": (katex / "katex.min.js").read_text(encoding="utf-8"),
        "/* PAPER_JS */": (ROOT / "web/paper.js").read_text(encoding="utf-8"),
        "/* PROOF_JS */": (ROOT / "web/theorems.js").read_text(encoding="utf-8"),
        "/* LIVE_PROOF_JS */": (ROOT / "web/live-verification.js").read_text(encoding="utf-8"),
        "/* MARKED_JS */": "/*\n" + (ROOT / ".lake/packages/verso/vendored-js/marked/LICENSE.md").read_text(encoding="utf-8").replace("*/", "* /") + "\n*/\n" +
            (ROOT / ".lake/packages/verso/vendored-js/marked/marked.umd.min.js").read_text(encoding="utf-8"),
        "/* EXPLANATIONS_JS */": (ROOT / "web/explanations.js").read_text(encoding="utf-8"),
    }
    for marker, content in replacements.items():
        if shell.count(marker) != 1:
            raise ValueError(f"Expected one asset placeholder: {marker}")
        shell = shell.replace(marker, content)
    shell = inline_brand_assets(shell)
    destination = ROOT / "dist"
    destination.mkdir(exist_ok=True)
    output = destination / "index.html"
    output.write_text(shell, encoding="utf-8")

    # This file is useful for reproducing or auditing an archived document.
    provenance = {
        "built_at": datetime.now(timezone.utc).isoformat(),
        "lean_version": definition["leanVersion"],
        "definition": definition["name"],
        "checked_positions": len(definition["samples"]),
        "latex_generated_by": "Plaer/Latex.lean + vendor/LeanTeX",
        "latex_engine": json.loads((ROOT / "vendor/LeanTeX/UPSTREAM.json").read_text(encoding="utf-8")),
        "latex_sources_sha256": hashlib.sha256(b"".join(
            path.relative_to(ROOT).as_posix().encode() + b"\0" + path.read_bytes() + b"\0"
            for path in sorted([ROOT / "Plaer/Latex.lean",
                ROOT / "vendor/LeanTeX/LeanTeX.lean",
                *list((ROOT / "vendor/LeanTeX/LeanTeX").glob("*.lean"))])
        )).hexdigest(),
        "source_sha256": hashlib.sha256((ROOT / definition["sourcePath"]).read_bytes()).hexdigest(),
        "document_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "dependencies_sha256": hashlib.sha256((ROOT / "lake-manifest.json").read_bytes()).hexdigest(),
        "paper_source_sha256": hashlib.sha256((ROOT / "Paper.lean").read_bytes()).hexdigest(),
        "theorem_checks": [block["report"] for block in parser.proof_blocks],
    }
    (destination / "build.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    # Export the exact string produced by Lean, rather than reconstructing it here.
    (destination / "definition.tex").write_text(definition["latex"] + "\n", encoding="utf-8")
    return output


if __name__ == "__main__":
    output = package_document()
    print(f"Built single-file document: {output} ({output.stat().st_size:,} bytes)")
