"""Render user-added formal boxes from declarations in the project's Lean source."""
from __future__ import annotations
import hashlib
import html
import json
from pathlib import Path
import subprocess
from project import Project, ROOT, _identifier, _path
from toolchain import lean_environment
from verify_proof import source_fingerprint, proof_material

def specification(project: Project, kind: str, source: str) -> dict:
    if kind not in ("definition", "theorem"):
        raise ValueError("Choose a definition or theorem box")
    spec = json.loads(source)
    required = {"name", "title"} | ({"proof_file", "proof_declaration"} if kind == "theorem" else set())
    if not isinstance(spec, dict) or set(spec) != required:
        raise ValueError("A formal box needs its declaration name, title, and theorem proof mapping")
    _identifier(spec["name"], "Declaration")
    if not isinstance(spec["title"], str) or not 0 < len(spec["title"]) <= 200:
        raise ValueError("Choose a title under 200 characters")
    if kind == "theorem":
        _identifier(spec["proof_declaration"], "Proof declaration")
        path = _path(spec["proof_file"], "Proof file", project.manifest.parent, suffix=".lean")
        for entry in project.statements:
            if entry["name"] == spec["name"] and (path != entry["proof_file"] or spec["proof_declaration"] != entry["proof_declaration"]):
                raise ValueError("This statement already has a different proof mapping")
    return spec

def proof_entry(project: Project, source: str) -> dict:
    spec = specification(project, "theorem", source)
    return {"name": spec["name"], "title": spec["title"],
            "proof_file": _path(spec["proof_file"], "Proof file", project.manifest.parent, suffix=".lean"),
            "proof_declaration": spec["proof_declaration"]}

def render_box(project: Project, kind: str, source: str) -> dict:
    spec = specification(project, kind, source)
    renderer_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    fingerprint = source_fingerprint(project)
    key = hashlib.sha256((fingerprint + renderer_hash + str(project.output) + kind + json.dumps(spec, sort_keys=True)).encode()).hexdigest()
    cache = project.build_dir / "boxes" / (key + ".json")
    if cache.exists():
        return json.loads(cache.read_text(encoding="utf-8"))
    cache.parent.mkdir(parents=True, exist_ok=True)
    driver = cache.with_suffix(".lean")
    function = "definitionReport" if kind == "definition" else "statementReport"
    driver.write_text(f"import {project.source_module}\nimport Plaer.Extract\n\nopen Lean\n\nrun_meta do\n"
        f"  let report ← Plaer.{function} (String.toName {json.dumps(spec['name'])})\n"
        '  logInfo m!"PLAER_BOX_RESULT={report.compress}"\n', encoding="utf-8")
    lake, env = lean_environment(project)
    run = subprocess.run([lake, "env", "lean", "--json", str(driver)], cwd=ROOT, env=env,
                         capture_output=True, text=True, encoding="utf-8", timeout=240)
    reports, errors = [], []
    for line in run.stdout.splitlines():
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        value = message.get("data", "")
        if isinstance(value, str) and value.startswith("PLAER_BOX_RESULT="):
            reports.append(json.loads(value[len("PLAER_BOX_RESULT="):]))
        if message.get("severity") == "error":
            errors.append(str(value))
    if run.returncode or errors or len(reports) != 1:
        raise ValueError("Lean could not render that declaration: " + ("\n".join(errors) or run.stderr)[-1500:])
    if source_fingerprint(project) != fingerprint:
        raise RuntimeError("The statements changed while rendering. Rebuild and add the box again.")
    report = reports[0]
    if report["sourceModule"] != project.source_module:
        raise ValueError("Choose a declaration from the project's statements file")
    e = lambda value: html.escape(str(value), quote=True)
    title = e(spec["title"])
    if kind == "definition":
        report.update({"sourceFile": project.source.relative_to(ROOT).as_posix(),
                       "sourceUrl": "sources/" + project.source.name})
        payload = e(json.dumps(report, ensure_ascii=False))
        markup = f'''<section class="definition" data-definition="{payload}" aria-label="{title}">
<div class="definition-heading"><div><p class="eyebrow">Definition</p><h2>{title}</h2></div>
<div class="view-toggle" role="tablist" aria-label="Definition representation"><button type="button" role="tab" data-view="latex" aria-selected="true">LaTeX</button><button type="button" role="tab" data-view="lean" aria-selected="false">Lean</button></div></div>
<div class="definition-body"><div class="definition-panel math-panel" role="tabpanel"><div class="display-math" data-latex="{e(report["latex"])}"></div></div><div class="definition-panel lean-panel" role="tabpanel" hidden><pre><code class="lean-source">{e(report["source"])}</code></pre></div></div></section>'''
    else:
        entry = proof_entry(project, source)
        _, _, metadata = proof_material(project, entry)
        report.update(metadata)
        report["result"] = {"ok": False, "pending": True}
        audit_path = project.output / report["auditUrl"]
        if not audit_path.exists():
            audit_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        payload = e(json.dumps({"title": spec["title"], "report": report}, ensure_ascii=False))
        markup = f'''<section class="proof-check" data-proof="{payload}" aria-label="Theorem statement and proof verification">
<div class="proof-heading"><div><p class="eyebrow theorem-label">Statement</p><h2 class="theorem-title"></h2></div><div class="view-toggle" role="tablist" aria-label="Theorem statement representation"><button type="button" role="tab" data-theorem-view="latex" aria-selected="true">LaTeX</button><button type="button" role="tab" data-theorem-view="lean" aria-selected="false">Lean</button></div></div>
<div class="theorem-statement"><div data-statement-panel="latex" role="tabpanel"><div class="theorem-math"></div></div><div data-statement-panel="lean" role="tabpanel" hidden><pre class="theorem-lean"></pre></div></div><div class="proof-actions"><button type="button" class="verify-proof" disabled>Run proof</button><span class="proof-result" role="status" aria-live="polite"><span class="proof-status">Not checked</span></span></div></section>'''
    result = {"rendered": markup, "report": report, "kind": kind}
    cache.write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
    return result
