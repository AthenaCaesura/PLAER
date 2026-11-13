"""A valid proof of the wrong proposition must never verify the displayed statement."""
from dataclasses import replace
import tempfile
from pathlib import Path
from _support import ROOT
from project import load_project
from verify_proof import run_proof

project = load_project()
with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="proof-audit-") as directory:
    folder = Path(directory)
    # This unrelated broken proof must not be loaded by the chosen check.
    (folder / "Unrelated.lean").write_text("theorem broken : False := by exact True.intro\n", encoding="utf-8")
    wrong = folder / "Wrong.lean"
    wrong.write_text(f"import {project.source_module}\ntheorem Wrong.exported : True := by trivial\n", encoding="utf-8")
    entry = {**project.statements[0], "proof_file": wrong, "proof_declaration": "Wrong.exported"}
    isolated = replace(project, output=folder / "output")
    report = run_proof(isolated, entry)
    assert report["result"]["ok"] is False
    assert "does not prove the displayed proposition" in report["result"]["diagnostics"], report
    checker = (isolated.output / report["checkerUrl"]).read_text(encoding="utf-8")
    assert "Unrelated" not in checker
    assert "sorry" not in checker
    print("PASS: a compiling proof of True is rejected; unrelated broken proof file is not compiled")
