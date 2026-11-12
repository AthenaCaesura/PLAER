"""Show the actual Lean-generated document in the conversation's preview surface."""

from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
from pathlib import Path

from package_document import ROOT, DefinitionParser
from brand_assets import inline_brand_assets


def scope_css(css: str, root: str) -> str:
    """Scope the existing product stylesheet, preserving nested media rules."""
    result = []
    position = 0
    while position < len(css):
        opening = css.find("{", position)
        if opening < 0:
            break
        heading = css[position:opening].strip()
        depth, end = 1, opening + 1
        while depth:
            depth += (css[end] == "{") - (css[end] == "}")
            end += 1
        body = css[opening + 1:end - 1]
        if heading.startswith("@media"):
            result.append(heading + "{" + scope_css(body, root) + "}")
        else:
            selectors = []
            for selector in heading.split(","):
                selector = selector.strip()
                selectors.append(root if selector in (":root", "body") else root + " " + selector)
            result.append(",".join(selectors) + "{" + body + "}")
        position = end
    return "\n".join(result)


def main(destination: Path) -> None:
    document = (ROOT / "build/document.html").read_text(encoding="utf-8")
    parser = DefinitionParser()
    parser.feed(document)
    definition = parser.definitions[0]
    # Typeset the exact LaTeX emitted by Lean before displaying the fragment.
    # This avoids a race between external math-library loading and widget startup.
    katex = ROOT / ".lake/packages/verso/vendored-js/katex/katex.min.js"
    render_code = "const k=require(process.argv[1]);let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>process.stdout.write(k.renderToString(JSON.parse(s),{displayMode:true,throwOnError:true,trust:false})));"
    rendered = subprocess.run(
        ["node", "-e", render_code, str(katex)], input=json.dumps(definition["latex"]),
        capture_output=True, text=True, encoding="utf-8", check=True,
    ).stdout
    document, replaced = re.subn(
        r'(<div\s+class="display-math"[^>]*>).*?(</div>)',
        lambda match: match[1] + rendered + match[2], document, flags=re.S,
    )
    if replaced != 1:
        raise ValueError("Expected exactly one mathematical definition")

    for block in parser.proof_blocks:
        for report in [block["report"]]:
            report["statementHtml"] = subprocess.run(
                ["node", "-e", render_code, str(katex)], input=json.dumps(report["statementLatex"]),
                capture_output=True, text=True, encoding="utf-8", check=True,
            ).stdout
    blocks = iter(parser.proof_blocks)
    document = re.sub(
        r'data-proof="[^"]*"',
        lambda match: 'data-proof="' + html.escape(json.dumps(next(blocks), ensure_ascii=False), quote=True) + '"',
        document,
    )

    script = (ROOT / "web/paper.js").read_text(encoding="utf-8")
    script = re.sub(r'  try \{\n    katex.render.*?\n  \}\n', '', script, count=1, flags=re.S)
    if "katex.render" in script:
        raise ValueError("Math is already typeset; remove the runtime rendering step")
    script = script.replace('for (const card of document.querySelectorAll', 'for (const card of root.querySelectorAll')
    script = script.replace('document.querySelector(".print-button").addEventListener("click", () => window.print());', '')
    proof_script = (ROOT / "web/theorems.js").read_text(encoding="utf-8")
    proof_script = proof_script.replace("const scope = document;", "const scope = document.getElementById('plaer-paper-preview');")
    script += "\n" + proof_script
    # A snapshot cannot call local Lean. Never present an inert Run proof control.
    script += "\nroot.querySelectorAll('[data-proof]').forEach(card => { const link = document.createElement('a'); link.className = 'verify-proof preview-link'; link.href = 'http://127.0.0.1:8767/'; link.target = '_blank'; link.rel = 'noopener'; link.textContent = 'Open runnable document'; card.querySelector('.verify-proof').replaceWith(link); });"
    script = '(() => {\nconst root = document.getElementById("plaer-paper-preview");\n' + script + '\n})();'

    css = scope_css(inline_brand_assets((ROOT / "web/paper.css").read_text(encoding="utf-8")), "#plaer-paper-preview")
    css += "\n#plaer-paper-preview{background:transparent}#plaer-paper-preview .paper{margin:0;max-width:none;padding:32px 28px 25px;}"
    css += "\n@media(max-width:480px){#plaer-paper-preview .paper{padding:22px 15px}}"
    shell = (ROOT / "web/preview-fragment.html").read_text(encoding="utf-8")
    shell = shell.replace("/* SCOPED_PAPER_CSS */", css)
    shell = shell.replace("<!-- DOCUMENT -->", document)
    shell = shell.replace("/* SCOPED_PAPER_JS */", script)
    if re.search(r"<!doctype|<html|<head|<body", shell, re.I):
        raise ValueError("The inline preview must be a fragment")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(shell, encoding="utf-8")
    (ROOT / "build/inline-preview.js").write_text(script, encoding="utf-8")
    print(f"Wrote {destination} ({destination.stat().st_size:,} bytes)")


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser(description=__doc__)
    argument_parser.add_argument("destination", type=Path)
    main(argument_parser.parse_args().destination)
