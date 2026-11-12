"""Check the Lean/Verso sources and build the self-contained paper."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from package_document import ROOT, package_document


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test", action="store_true", help="Also check the renderer and LeanTeX fork regression tests")
    args = parser.parse_args()
    os.chdir(ROOT)
    from toolchain import lean_environment
    lake, environment = lean_environment()
    os.environ.update(environment)

    def run(*arguments: str) -> None:
        print("+", " ".join(arguments), flush=True)
        subprocess.run(arguments, cwd=ROOT, check=True)

    # Updating an existing manifest can move pinned transitive revisions. Leave it
    # alone, and let Lake materialize its recorded dependencies during the build.
    if not (ROOT / "lake-manifest.json").exists():
        os.environ["MATHLIB_NO_CACHE_ON_UPDATE"] = "1"
        run(lake, "update")
    cache_target = ROOT / ".lake/packages/mathlib/.lake/build/lib/lean/Mathlib/FieldTheory/Finite/Basic.olean"
    if not cache_target.exists():
        run(lake, "exe", "cache", "get", "Mathlib.Basic.Real.Basic", "Mathlib.Tactic.NormNum", "Mathlib.FieldTheory.Finite.Basic")
    run(lake, "build", "Paper")
    if args.test:
        run(lake, "env", "lean", "tests/lean/Renderer.lean")
        run(lake, "env", "lean", "tests/lean/Latex.lean")
        run(lake, "env", "lean", "vendor/LeanTeX/test/basic.lean")
        run(lake, "env", "lean", "vendor/LeanTeX/test/subscript.lean")
    run(lake, "env", "lean", "--run", "Main.lean")
    output = package_document()
    print(f"\nOpen {output}\nThe document is self-contained and works offline.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
