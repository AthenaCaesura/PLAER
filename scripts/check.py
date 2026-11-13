"""Run shared checks against every example, or one explicit project."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from project import ROOT, load_project

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project")
    args = parser.parse_args()
    node = shutil.which("node")
    if not node:
        parser.error("Install Node.js 22+ for frontend checks")
    manifests = [Path(args.project)] if args.project else sorted((ROOT / "examples").glob("*/project.json"))
    for index, manifest in enumerate(manifests):
        project = load_project(manifest)
        env = {**os.environ, "PLAER_PROJECT": str(project.manifest), "PLAER_OUTPUT": str(project.output)}
        def run(*arguments):
            print("+", " ".join(arguments), flush=True)
            subprocess.run(arguments, cwd=ROOT, env=env, check=True)
        run(sys.executable, "scripts/build.py", "--project", str(project.manifest), *(["--test"] if index == 0 else []))
        for name in ["test_latex", "test_statement_ui", "test_fermat"]:
            run(node, f"tests/js/{name}.cjs")
        for name in ["test_explanations", "test_branding", "test_verification", "test_proof_rejection", "test_boxes"]:
            run(sys.executable, f"tests/python/{name}.py")
    print("All PLAER project checks passed.", flush=True)

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
