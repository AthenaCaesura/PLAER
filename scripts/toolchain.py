"""Resolve Lean on Windows, macOS, and Linux without changing system settings."""

import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def lean_environment() -> tuple[str, dict]:
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
    lake = shutil.which("lake", path=environment["PATH"])
    if not lake:
        raise RuntimeError("Install Lean with elan (see README.md), then reopen your terminal.")
    return lake, environment
