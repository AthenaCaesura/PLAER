"""Persist editable explanation cells; formal Lean statements stay separate."""

from __future__ import annotations

import hashlib
import json
import re
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CELL_FILE = ROOT / "Explanations/cells.json"
CELL_LOCK = threading.Lock()


def read_cells() -> dict:
    raw = CELL_FILE.read_bytes()
    return {**json.loads(raw), "revision": hashlib.sha256(raw).hexdigest()}


def save_cells(request: dict) -> dict:
    if not isinstance(request, dict):
        raise ValueError("Expected an explanation notebook")
    cells = request.get("cells")
    if not isinstance(cells, list) or len(cells) > 100:
        raise ValueError("Expected at most 100 explanation cells")
    seen = set()
    cleaned = []
    for cell in cells:
        if not isinstance(cell, dict):
            raise ValueError("Invalid explanation cell")
        ident, kind, source = (cell.get(key) for key in ("id", "kind", "source"))
        if not isinstance(ident, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", ident) or ident in seen:
            raise ValueError("Each explanation cell needs a unique identifier")
        if kind not in ("markdown", "plot") or not isinstance(source, str) or len(source) > 30000:
            raise ValueError("Choose Markdown or plot, with source under 30000 characters")
        seen.add(ident)
        cleaned.append({"id": ident, "kind": kind, "source": source})
    with CELL_LOCK:
        if request.get("revision") != read_cells()["revision"]:
            raise ValueError("Explanations changed elsewhere. Reload before saving.")
        temporary = CELL_FILE.with_suffix(".tmp")
        temporary.write_text(json.dumps({"cells": cleaned}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(CELL_FILE)
        # Updating explanations never starts Lean or alters its formal declarations.
        from package_document import package_document
        package_document()
        return read_cells()
