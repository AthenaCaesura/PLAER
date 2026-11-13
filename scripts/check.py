"""Run every check: build each example paper, then the Lean, JavaScript, and Python tests."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from project import ROOT, load_project
from toolchain import lean_environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paper", nargs="?", help="Check one paper instead of every example")
    args = parser.parse_args()
    node = shutil.which("node")
    if not node:
        parser.error("Install Node.js 22+ for the KaTeX check")
    lake, lean_env = lean_environment()

    def run(*arguments, env=None):
        print("+", " ".join(str(a) for a in arguments), flush=True)
        subprocess.run(arguments, cwd=ROOT, env=env or lean_env, check=True)

    papers = [Path(args.paper)] if args.paper else sorted((ROOT / "examples").glob("*/Paper.md"))
    for paper in papers:
        project = load_project(paper)
        env = {**os.environ, "PLAER_PROJECT": str(project.paper)}
        run(sys.executable, "scripts/build.py", str(project.paper))
        for name in ["test_branding", "test_server"]:
            run(sys.executable, f"tests/python/{name}.py", env=env)

    # The LaTeX engine: PLAER's notation rules, strict rejection, and the LeanTeX fork.
    run(lake, "build", "fixtures.Interval")
    for path in ["tests/lean/Latex.lean", "vendor/LeanTeX/test/basic.lean", "vendor/LeanTeX/test/subscript.lean"]:
        run(lake, "env", "lean", path)
    run(node, "tests/js/test_latex.cjs")
    for name in ["test_paper", "test_document"]:
        run(sys.executable, f"tests/python/{name}.py")
    print("All PLAER checks passed.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
