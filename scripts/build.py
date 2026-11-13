"""Build a paper into a readable document, and check every attached proof.

    python scripts/build.py examples/Fermat/Paper.md
"""
from __future__ import annotations

import argparse
import subprocess
import sys

from document import LeanRejected, build_state
from package_document import package_document
from project import ROOT, load_project
from toolchain import lean_environment


def prepare_dependencies(project) -> None:
    """First run only: resolve dependencies and fetch Mathlib's prebuilt files."""
    lake, environment = lean_environment(project)

    def run(*arguments):
        print("+", " ".join(str(a) for a in arguments), flush=True)
        subprocess.run(arguments, cwd=ROOT, env=environment, check=True)

    if not (ROOT / "lake-manifest.json").exists():
        run(lake, "update")
    cache = ROOT / ".lake/packages/mathlib/.lake/build/lib/lean/Mathlib/FieldTheory/Finite/Basic.olean"
    if not cache.exists():
        run(lake, "exe", "cache", "get")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paper", nargs="?", help="A Paper.md or its folder (default: $PLAER_PROJECT)")
    parser.add_argument("--project", help=argparse.SUPPRESS)   # the older spelling
    args = parser.parse_args()
    try:
        project = load_project(args.paper or args.project)
        prepare_dependencies(project)
        print(f"Compile {project.paper.relative_to(ROOT)} with Lean", flush=True)
        state = build_state(project, run_proofs=True, log=lambda line: print(line, flush=True))
    except LeanRejected as error:
        sys.exit(f"Lean rejected the paper:\n\n{error}")
    except ValueError as error:
        sys.exit(str(error))
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
    print("Open", package_document(project, state), flush=True)


if __name__ == "__main__":
    main()
