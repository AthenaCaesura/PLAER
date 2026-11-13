"""Build a chosen document from statements, then check each separate proof file."""
from __future__ import annotations
import argparse
import json
import os
import subprocess
import sys
from project import ROOT, load_project
from package_document import package_document
from toolchain import lean_environment
from verify_proof import run_proof

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", help="Path to a document's project.json")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args()
    project = load_project(args.project)
    lake, environment = lean_environment(project)
    os.environ.update(environment)
    def run(*arguments):
        print("+", " ".join(str(a) for a in arguments), flush=True)
        subprocess.run(arguments, cwd=ROOT, env=environment, check=True)
    if not (ROOT / "lake-manifest.json").exists():
        run(lake, "update")
    cache = ROOT / ".lake/packages/mathlib/.lake/build/lib/lean/Mathlib/FieldTheory/Finite/Basic.olean"
    if not cache.exists():
        run(lake, "exe", "cache", "get", "Mathlib.Basic.Real.Basic", "Mathlib.Tactic.NormNum", "Mathlib.FieldTheory.Finite.Basic")
    run(lake, "build", "Plaer.Check", project.paper_module)
    project.build_dir.mkdir(parents=True, exist_ok=True)
    driver = project.build_dir / "Render.lean"
    destination = project.build_dir / "document.html"
    driver.write_text(f"import {project.paper_module}\n\ndef main (_ : List String) : IO UInt32 :=\n"
        f"  Plaer.renderPaper (%doc {project.paper_module}) {json.dumps(str(destination.as_posix()))}\n", encoding="utf-8")
    if args.test:
        run(lake, "build", "TestFixtures")
        for path in ["tests/lean/Renderer.lean", "tests/lean/Latex.lean",
                     "vendor/LeanTeX/test/basic.lean", "vendor/LeanTeX/test/subscript.lean"]:
            run(lake, "env", "lean", path)
    run(lake, "env", "lean", "--run", str(driver))
    reports = []
    for entry in project.statements:
        print("+ Check proof file:", entry["proof_file"].relative_to(ROOT), flush=True)
        report = run_proof(project, entry, prepare=False)
        reports.append(report)
        print(f"  {entry['name']}: {'Proved' if report['result']['ok'] else 'Not proved'}", flush=True)
    (project.build_dir / "check-results.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Open", package_document(project), flush=True)

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
