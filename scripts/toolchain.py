"""Resolve Lean on Windows, macOS, and Linux without changing system settings."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def lean_environment(project=None) -> tuple[str, dict]:
    environment = os.environ.copy()
    candidates = []
    if environment.get("PLAER_LEAN_BIN"):
        candidates.append(Path(environment["PLAER_LEAN_BIN"]))
    if os.name == "nt":
        candidates.append(ROOT / ".tools/lean-4.35.0-windows/bin")
    candidates.append(Path.home() / ".elan/bin")
    directories = [str(path) for path in candidates if path.is_dir()]
    environment["PATH"] = os.pathsep.join(directories + [environment.get("PATH", "")])
    environment.setdefault("LEAN_NUM_THREADS", "2")
    environment.setdefault("PYTHONUTF8", "1")
    # Lean reads declaration sources through this path: `Fermat.Statements`
    # is found from the folder that contains `Fermat/`.
    source_roots = [ROOT] + ([project.folder.parent] if project is not None else [])
    environment["LEAN_SRC_PATH"] = os.pathsep.join([str(p) for p in source_roots] +
        [environment.get("LEAN_SRC_PATH", "")])
    lake = shutil.which("lake", path=environment["PATH"])
    if not lake:
        raise RuntimeError("Install Lean with elan (see README.md), then reopen your terminal.")
    return lake, environment


_lean_paths: dict = {}


def lean_invocation(project=None) -> tuple[str, dict]:
    """The `lean` binary and an environment equivalent to `lake env lean`.

    `lake env` spends seconds loading every package's configuration, so its
    paths are asked for once and reused until the Lake configuration changes.
    """
    lake, environment = lean_environment(project)
    stamp = (tuple((ROOT / name).stat().st_mtime_ns for name in ("lakefile.toml", "lake-manifest.json", "lean-toolchain")),
             environment["LEAN_SRC_PATH"])
    if _lean_paths.get("stamp") != stamp:
        probe = ("import json, os, shutil; print(json.dumps([shutil.which('lean'), "
                 "os.environ.get('LEAN_PATH', ''), os.environ.get('LEAN_SRC_PATH', '')]))")
        output = subprocess.run([lake, "env", sys.executable, "-I", "-c", probe], cwd=ROOT, env=environment,
                                capture_output=True, text=True, encoding="utf-8", check=True).stdout
        lean, lean_path, source_path = json.loads(output.strip().splitlines()[-1])
        if not lean:
            raise RuntimeError("Lake did not find a lean binary. Run `lake env lean --version` to diagnose.")
        _lean_paths.update(stamp=stamp, lean=lean, path=lean_path, source=source_path)
    environment["LEAN_PATH"] = _lean_paths["path"]
    environment["LEAN_SRC_PATH"] = _lean_paths["source"]
    return _lean_paths["lean"], environment
