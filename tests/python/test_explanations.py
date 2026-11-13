"""Notes belong to the selected project; writes preserve source and reject stale revisions."""
from dataclasses import replace
import json
from pathlib import Path
import tempfile
from _support import ROOT
from project import load_project
import explanations
import package_document

original = load_project()
with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="notes-") as directory:
    notes = Path(directory) / "notes.json"
    notes.write_bytes(original.notes.read_bytes())
    project = replace(original, notes=notes)
    original_package = package_document.package_document
    calls = []
    package_document.package_document = lambda p: calls.append(p.id)
    try:
        source = project.source.read_bytes()
        state = explanations.read_cells(project)
        state["cells"][0]["source"] = "A note about $n + 0 = n$."
        result = explanations.save_cells(project, state)
        assert explanations.read_cells(project)["cells"][0]["source"] == state["cells"][0]["source"]
        assert project.source.read_bytes() == source
        assert calls == [project.id]
        try:
            explanations.save_cells(project, state)
            raise AssertionError("Stale write accepted")
        except ValueError:
            pass
        assert original.notes.read_bytes() != notes.read_bytes()
    finally:
        package_document.package_document = original_package
print("PASS: project-scoped notes persist without changing statements; stale writes rejected")
