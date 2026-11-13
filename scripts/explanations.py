"""Persist a project's authored notes without changing formal statements."""
from __future__ import annotations
import hashlib
import json
import re
import threading
from project import Project

CELL_LOCK = threading.Lock()

def read_cells(project: Project) -> dict:
    raw = project.notes.read_bytes()
    return {**json.loads(raw), "revision": hashlib.sha256(raw).hexdigest()}

def rendered_cells(project: Project) -> dict:
    from boxes import render_box
    state = read_cells(project)
    state["cells"] = [{**cell, **render_box(project, cell["kind"], cell["source"])}
        if cell["kind"] in ("definition", "theorem") else cell for cell in state["cells"]]
    return state

def save_cells(project: Project, request: dict) -> dict:
    if not isinstance(request, dict) or not isinstance(request.get("cells"), list) or len(request["cells"]) > 100:
        raise ValueError("Expected at most 100 explanation cells")
    seen, cleaned = set(), []
    proof_mappings = {entry["name"]: (entry["proof_file"], entry["proof_declaration"]) for entry in project.statements}
    for cell in request["cells"]:
        if not isinstance(cell, dict):
            raise ValueError("Invalid explanation cell")
        ident, kind, source = (cell.get(k) for k in ("id", "kind", "source"))
        if not isinstance(ident, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", ident) or ident in seen:
            raise ValueError("Each explanation needs a unique identifier")
        if kind not in ("markdown", "plot", "definition", "theorem") or not isinstance(source, str) or len(source) > 30000:
            raise ValueError("Choose a supported box with source under 30000 characters")
        if kind in ("definition", "theorem"):
            from boxes import render_box
            render_box(project, kind, source)
        if kind == "theorem":
            from boxes import proof_entry
            entry = proof_entry(project, source)
            mapping = (entry["proof_file"], entry["proof_declaration"])
            if entry["name"] in proof_mappings and proof_mappings[entry["name"]] != mapping:
                raise ValueError("A statement must have one consistent proof mapping")
            proof_mappings[entry["name"]] = mapping
        seen.add(ident)
        cleaned.append({"id": ident, "kind": kind, "source": source})
    with CELL_LOCK:
        if request.get("revision") != read_cells(project)["revision"]:
            raise ValueError("Explanations changed elsewhere. Reload before saving.")
        temporary = project.notes.with_suffix(".tmp")
        temporary.write_text(json.dumps({"cells": cleaned}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(project.notes)
        from package_document import package_document
        package_document(project)
        return rendered_cells(project)
