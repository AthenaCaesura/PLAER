"""Run every check: build each example paper, then the Lean, JavaScript, and Python tests."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from project import ROOT, load_project
from toolchain import lean_environment, lean_invocation


class Failure(Exception):
    def __init__(self, command, output):
        super().__init__(f"FAILED: {command}\n{output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paper", nargs="?", help="Check one paper instead of every example")
    args = parser.parse_args()
    node = shutil.which("node")
    if not node:
        parser.error("Install Node.js 22+ for the KaTeX check")
    lake, lean_env = lean_environment()

    lean, lean_direct = lean_invocation()
    python = sys.executable

    def run(*arguments, env=None):
        """Run one command; its output is printed only if it fails."""
        done = subprocess.run(arguments, cwd=ROOT, env=env or lean_env, capture_output=True, text=True)
        if done.returncode:
            raise Failure(" ".join(str(a) for a in arguments), done.stdout + done.stderr)

    def step(name, *commands):
        """A named step: its commands run in order. Steps run at the same time."""
        def go():
            started = time.perf_counter()
            for command, env in commands:
                run(*command, env=env)
            return name, time.perf_counter() - started
        return go

    papers = [Path(args.paper)] if args.paper else sorted((ROOT / "examples").glob("*/Paper.md"))
    projects = [load_project(paper) for paper in papers]
    # Build the shared Lean libraries once, so parallel steps never build them twice at once.
    started = time.perf_counter()
    run(lake, "build", "Plaer", "fixtures.Interval")
    print(f"  {time.perf_counter() - started:5.1f}s  Lean libraries", flush=True)

    steps = []
    for index, project in enumerate(projects):
        env = {**os.environ, "PLAER_PROJECT": str(project.paper)}
        commands = [((python, "scripts/build.py", str(project.paper)), None),
                    ((python, "tests/python/test_branding.py"), env)]
        if index == len(projects) - 1:   # the server code is the same for every paper: test it once
            commands.append(((python, "tests/python/test_server.py"), env))
        steps.append(step(f"build {project.folder.name}", *commands))
    # The LaTeX engine: PLAER's notation rules, strict rejection, and the LeanTeX fork.
    for path in ["tests/lean/Latex.lean", "vendor/LeanTeX/test/basic.lean", "vendor/LeanTeX/test/subscript.lean"]:
        latex = [((lean, path), lean_direct)]
        if path == "tests/lean/Latex.lean":
            latex.append(((node, "tests/js/test_latex.cjs"), None))
        steps.append(step(Path(path).name, *latex))
    steps.append(step("paper format", ((python, "tests/python/test_paper.py"), None)))
    steps.append(step("proof checks", ((python, "tests/python/test_document.py"), None)))

    with ThreadPoolExecutor(len(steps)) as pool:
        for future in as_completed([pool.submit(s) for s in steps]):
            name, seconds = future.result()
            print(f"  {seconds:5.1f}s  {name}", flush=True)
    print("All PLAER checks passed.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Failure as error:
        sys.exit(str(error))
