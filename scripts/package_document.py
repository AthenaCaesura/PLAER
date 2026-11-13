"""Write a document's standalone page and audit files into its output folder."""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path

from brand_assets import inline_brand_assets
from document import engine_fingerprint
from project import ROOT, Project, relative

WEB = ROOT / "web"


def declarations(state: dict) -> list[dict]:
    return [item for block in state["blocks"] for item in block.get("items", [])
            if item["type"] == "declaration"]


def package_document(project: Project, state: dict) -> Path:
    """Returns the path of the page. It embeds its fonts, scripts, and logos."""
    replacements = {
        "/* KATEX_CSS */": (WEB / "vendor/katex.css").read_text(encoding="utf-8"),
        "/* PAPER_CSS */": (WEB / "paper.css").read_text(encoding="utf-8"),
        "/* KATEX_JS */": (WEB / "vendor/katex.min.js").read_text(encoding="utf-8"),
        "/* MARKED_JS */": (WEB / "vendor/marked.min.js").read_text(encoding="utf-8"),
        "/* PAPER_JS */": (WEB / "paper.js").read_text(encoding="utf-8"),
        "/* PLAER_STATE */": json.dumps(state, ensure_ascii=False).replace("</", "<\\/"),
    }
    shell = (WEB / "shell.html").read_text(encoding="utf-8")
    for marker, content in replacements.items():
        if shell.count(marker) != 1:
            raise ValueError("Expected one placeholder: " + marker)
        shell = shell.replace(marker, content)
    shell = inline_brand_assets(shell).replace("__PLAER_TITLE__", html.escape(state["title"], quote=True))

    sources = project.output / "sources"
    sources.mkdir(parents=True, exist_ok=True)
    for file in (project.paper, project.source):
        (sources / file.name).write_bytes(file.read_bytes())
    page = project.output / "index.html"
    page.write_text(shell, encoding="utf-8")

    found = declarations(state)
    checks = [proof for d in found for proof in d.get("proofs", [])]
    audit = {
        "project": project.id, "paper": relative(project.paper),
        "execution": "The paper's Lean compiles as one module. Each play button compiles only "
                     "its attached proof file, with an appended exact-proposition audit.",
        "source": relative(project.source), "sourceModule": project.source_module,
        "sourceSha256": hashlib.sha256(project.source.read_bytes()).hexdigest(),
        "checks": checks,
    }
    write_json(project.output / "audit.json", audit)
    write_json(project.output / "build.json", {
        "built_at": datetime.now(timezone.utc).isoformat(), "project": project.id,
        "lean_version": (ROOT / "lean-toolchain").read_text(encoding="utf-8").strip().split(":v")[-1],
        "paper": relative(project.paper), "source": relative(project.source),
        "paper_sha256": hashlib.sha256(project.paper.read_bytes()).hexdigest(),
        "source_sha256": audit["sourceSha256"],
        "document_sha256": hashlib.sha256(page.read_bytes()).hexdigest(),
        "engine_fingerprint": engine_fingerprint(),
        "latex_generated_by": "Plaer/Latex.lean + vendor/LeanTeX",
        "latex_engine": json.loads((ROOT / "vendor/LeanTeX/UPSTREAM.json").read_text(encoding="utf-8")),
        "state": state,
    })
    latex = [d.get("latex") or d.get("statementLatex") for d in found]
    (project.output / "definitions.tex").write_text(
        "\n".join(line for line in latex if line) + "\n", encoding="utf-8")
    return page


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
