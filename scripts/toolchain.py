"""Resolve Lean on Windows, macOS, and Linux without changing system settings."""

import os
from pathlib import Path
import shutil

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
    source_roots = [ROOT]
    if project is not None:
        for path, module in [(project.source, project.source_module), (project.paper, project.paper_module)]:
            for _ in module.split("."):
                path = path.parent
            source_roots.append(path)
    environment["LEAN_SRC_PATH"] = os.pathsep.join([str(p) for p in source_roots] +
        [environment.get("LEAN_SRC_PATH", "")])
    lake = shutil.which("lake", path=environment["PATH"])
    if not lake:
        raise RuntimeError("Install Lean with elan (see README.md), then reopen your terminal.")
    return lake, environment
