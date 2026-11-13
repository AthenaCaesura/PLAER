"""Package a chosen document; all mathematical expressions come from Lean."""
from __future__ import annotations
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from project import ROOT, Project, load_project
from explanations import rendered_cells
from brand_assets import inline_brand_assets
from verify_proof import source_fingerprint, relative

class DefinitionParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.definitions, self.proof_blocks = [], []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "data-definition" in attrs:
            self.definitions.append(json.loads(attrs["data-definition"]))
        if "data-proof" in attrs:
            self.proof_blocks.append(json.loads(attrs["data-proof"]))

def package_document(project: Project) -> Path:
    document = (project.build_dir / "document.html").read_text(encoding="utf-8")
    parser = DefinitionParser()
    parser.feed(document)
    for definition in parser.definitions:
        if definition["sourceModule"] != project.source_module:
            raise ValueError("Definition boxes must reference the project's statements file")
        definition.update({"sourceFile": relative(project.source), "sourceUrl": "sources/" + project.source.name})
    definitions = iter(parser.definitions)
    document = re.sub(r'data-definition="[^"]*"', lambda _: 'data-definition="' +
        html.escape(json.dumps(next(definitions), ensure_ascii=False), quote=True) + '"', document)
    checked = {r["name"]: r for r in json.loads((project.build_dir / "check-results.json").read_text(encoding="utf-8"))}
    configured = {e["name"]: e for e in project.statements}
    seen = set()
    for block in parser.proof_blocks:
        display = block["report"]
        if display["sourceModule"] != project.source_module:
            raise ValueError("Theorem boxes must reference the project's statements file")
        name = display["name"]
        if name not in configured or name not in checked:
            raise ValueError(f"No proof file configured for displayed statement: {name}")
        report = checked[name]
        if report.get("statementHash") is not None and report["statementHash"] != display["statementHash"]:
            raise ValueError("The checked proof and displayed statement differ")
        block["report"] = {**display, **report, "statementHash": display["statementHash"]}
        seen.add(name)
    if seen != set(configured):
        raise ValueError("Every configured statement must appear in the paper")
    blocks = iter(parser.proof_blocks)
    document = re.sub(r'data-proof="[^"]*"', lambda _: 'data-proof="' +
        html.escape(json.dumps(next(blocks), ensure_ascii=False), quote=True) + '"', document)
    notebook_state = rendered_cells(project)
    notebook = html.escape(json.dumps(notebook_state, ensure_ascii=False), quote=True)
    document = document.replace('data-notebook="paper-explanations"',
        'data-notebook="paper-explanations" data-notebook-state="' + notebook + '"')
    katex = ROOT / ".lake/packages/verso/vendored-js/katex"
    css = (katex / "katex.min.css").read_text(encoding="utf-8")
    def embed(match):
        return "url(data:font/woff2;base64," + base64.b64encode((katex / match[1]).read_bytes()).decode() + ") format('woff2')"
    css = re.sub(r"url\((fonts/[^)]+\.woff2)\) format\([\"']?woff2[\"']?\)(?:,url\([^)]+\) format\([^)]+\))*", embed, css)
    if re.search(r"url\((?!data:)", css):
        raise ValueError("A KaTeX asset was not embedded")
    shell = (ROOT / "web/shell.html").read_text(encoding="utf-8")
    replacements = {
        "<!-- DOCUMENT -->": document, "/* KATEX_CSS */": css,
        "/* KATEX_JS */": (katex / "katex.min.js").read_text(encoding="utf-8"),
        "/* PAPER_CSS */": (ROOT / "web/paper.css").read_text(encoding="utf-8"),
        "/* PAPER_JS */": (ROOT / "web/paper.js").read_text(encoding="utf-8"),
        "/* PROOF_JS */": (ROOT / "web/theorems.js").read_text(encoding="utf-8"),
        "/* LIVE_PROOF_JS */": (ROOT / "web/live-verification.js").read_text(encoding="utf-8"),
        "/* EXPLANATIONS_JS */": (ROOT / "web/explanations.js").read_text(encoding="utf-8"),
        "/* MARKED_JS */": "/*\n" + (ROOT / ".lake/packages/verso/vendored-js/marked/LICENSE.md").read_text(encoding="utf-8").replace("*/", "* /") + "\n*/\n" +
            (ROOT / ".lake/packages/verso/vendored-js/marked/marked.umd.min.js").read_text(encoding="utf-8"),
    }
    for marker, content in replacements.items():
        if shell.count(marker) != 1:
            raise ValueError("Expected one placeholder: " + marker)
        shell = shell.replace(marker, content)
    shell = inline_brand_assets(shell).replace("__PLAER_TITLE__", html.escape(project.title, quote=True))
    project.output.mkdir(parents=True, exist_ok=True)
    (project.output / "sources").mkdir(exist_ok=True)
    (project.output / "sources" / project.source.name).write_bytes(project.source.read_bytes())
    output = project.output / "index.html"
    output.write_text(shell, encoding="utf-8")
    reports = [block["report"] for block in parser.proof_blocks]
    reports += [cell["report"] for cell in notebook_state["cells"] if cell["kind"] == "theorem"]
    audit = {
        "project": project.id, "manifest": relative(project.manifest),
        "execution": "The statements module compiles normally. Each play button compiles only its configured proof file, with an appended exact-proposition audit.",
        "source": relative(project.source), "sourceModule": project.source_module,
        "sourceSha256": hashlib.sha256(project.source.read_bytes()).hexdigest(),
        "checks": reports,
    }
    (project.output / "audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    provenance = {
        "built_at": datetime.now(timezone.utc).isoformat(), "project": project.id,
        "lean_version": "4.35.0", "source": relative(project.source),
        "source_fingerprint": source_fingerprint(project),
        "source_sha256": hashlib.sha256(project.source.read_bytes()).hexdigest(),
        "document_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "paper_source_sha256": hashlib.sha256(project.paper.read_bytes()).hexdigest(),
        "dependencies_sha256": hashlib.sha256((ROOT / "lake-manifest.json").read_bytes()).hexdigest(),
        "latex_generated_by": "Plaer/Latex.lean + vendor/LeanTeX",
        "latex_engine": json.loads((ROOT / "vendor/LeanTeX/UPSTREAM.json").read_text(encoding="utf-8")),
        "theorem_checks": reports, "definitions": parser.definitions,
    }
    (project.output / "build.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (project.output / "definitions.tex").write_text("\n".join(d["latex"] for d in parser.definitions) + "\n", encoding="utf-8")
    return output

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project")
    args = parser.parse_args()
    print(package_document(load_project(args.project)))
