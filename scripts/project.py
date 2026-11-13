"""Load a repository-contained PLAER project manifest without selecting a demo."""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
_IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_']*(?:\.[A-Za-z_][A-Za-z0-9_']*)*\Z")
_PROJECT_ID = re.compile(r"[a-z][a-z0-9_-]*\Z")


@dataclass(frozen=True)
class Project:
    manifest: Path
    id: str
    title: str
    source: Path
    source_module: str
    paper: Path
    paper_module: str
    notes: Path
    output: Path
    build_dir: Path
    statements: tuple[dict, ...]


def _text(value: object, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be a nonempty string")
    return value


def _identifier(value: object, field: str) -> str:
    value = _text(value, field)
    if not _IDENTIFIER.fullmatch(value):
        raise ValueError(f"{field} must be a dotted Lean identifier using ASCII letters, digits, underscores, or apostrophes")
    return value


def _path(value: object, field: str, base: Path, *, suffix: str | None = None,
          file_required: bool = True) -> Path:
    value = _text(value, field)
    path = (base / value).resolve()
    if not path.is_relative_to(ROOT) or path == ROOT:
        raise ValueError(f"{field} must stay inside the repository")
    if suffix and path.suffix != suffix:
        raise ValueError(f"{field} must name a {suffix} file")
    if file_required and not path.is_file():
        raise ValueError(f"{field} file does not exist: {path.relative_to(ROOT)}")
    if not file_required and path.exists() and not path.is_dir():
        raise ValueError(f"{field} must be a directory")
    return path


def load_project(manifest: str | Path | None = None) -> Project:
    """Resolve paths relative to the manifest; require --project or PLAER_PROJECT."""
    chosen = manifest if manifest is not None else os.environ.get("PLAER_PROJECT")
    if chosen is None or not str(chosen).strip():
        raise ValueError("Choose a project with --project <manifest.json> or set PLAER_PROJECT")
    manifest_path = Path(chosen).resolve()
    if not manifest_path.is_relative_to(ROOT) or not manifest_path.is_file():
        raise ValueError("The project manifest must be an existing file inside the repository")
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"Could not read project manifest: {error}") from error
    if not isinstance(data, dict):
        raise ValueError("A project manifest must be a JSON object")
    fields = {"version", "id", "title", "source", "source_module", "paper",
              "paper_module", "notes", "output", "statements"}
    if missing := fields - data.keys():
        raise ValueError("Missing project fields: " + ", ".join(sorted(missing)))
    if unknown := data.keys() - fields:
        raise ValueError("Unknown project fields: " + ", ".join(sorted(unknown)))
    if type(data["version"]) is not int or data["version"] != 1:
        raise ValueError("Unsupported project manifest version; expected 1")
    project_id = _text(data["id"], "id")
    if not _PROJECT_ID.fullmatch(project_id):
        raise ValueError("id must start with a lowercase letter and contain only lowercase letters, digits, underscores, or hyphens")
    title = _text(data["title"], "title")
    base = manifest_path.parent
    source = _path(data["source"], "source", base, suffix=".lean")
    paper = _path(data["paper"], "paper", base, suffix=".lean")
    notes = _path(data["notes"], "notes", base, suffix=".json")
    output = _path(data["output"], "output", base, file_required=False)
    statements = data["statements"]
    if not isinstance(statements, list):
        raise ValueError("statements must be a list; use [] for an initially empty document")
    resolved = []
    seen = set()
    for index, statement in enumerate(statements):
        field = f"statements[{index}]"
        if not isinstance(statement, dict):
            raise ValueError(f"{field} must be an object")
        required = {"name", "title", "proof_file", "proof_declaration"}
        if set(statement) != required:
            raise ValueError(f"{field} must contain name, title, proof_file, and proof_declaration")
        name = _identifier(statement["name"], field + ".name")
        if name in seen:
            raise ValueError(f"Duplicate statement name: {name}")
        seen.add(name)
        resolved.append({
            **statement,
            "name": name,
            "title": _text(statement["title"], field + ".title"),
            "proof_file": _path(statement["proof_file"], field + ".proof_file", base, suffix=".lean"),
            "proof_declaration": _identifier(statement["proof_declaration"], field + ".proof_declaration"),
        })
    return Project(
        manifest=manifest_path, id=project_id, title=title, source=source,
        source_module=_identifier(data["source_module"], "source_module"),
        paper=paper, paper_module=_identifier(data["paper_module"], "paper_module"),
        notes=notes, output=output, build_dir=ROOT / "build" / project_id,
        statements=tuple(resolved),
    )
