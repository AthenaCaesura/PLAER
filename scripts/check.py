"""Build PLAER and run its Lean, frontend, persistence, and live endpoint checks."""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--proof-mutation", action="store_true",
        help="Also test rejection after temporarily changing and restoring the proof source",
    )
    args = parser.parse_args()
    node = shutil.which("node")
    if not node:
        parser.error("Install Node.js 22+ to run the frontend checks.")

    def run(*arguments: str) -> None:
        print("+", " ".join(arguments), flush=True)
        subprocess.run(arguments, cwd=ROOT, check=True)

    run(sys.executable, "scripts/build.py", "--test")
    for name in ["test_latex", "test_fermat", "test_statement_ui"]:
        run(node, f"tests/js/{name}.cjs")
    for name in ["test_explanations", "test_branding", "test_verification"]:
        run(sys.executable, f"tests/python/{name}.py")
    if args.proof_mutation:
        run(sys.executable, "tests/python/test_proof_rejection.py")
    print("\nAll PLAER checks passed.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
