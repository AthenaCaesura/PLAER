"""Invoke the same Lean proof checker used by the Verso code block."""

from __future__ import annotations

import json
import atexit
import hashlib
import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def documented_statements() -> dict:
    provenance = json.loads((ROOT / "dist/build.json").read_text(encoding="utf-8"))
    return {report["name"]: report for report in provenance["theorem_checks"]}


from toolchain import lean_environment


class WarmLean:
    """Own one Lean process; run a fresh check for each request in its loaded environment."""

    def __init__(self):
        self.lock = threading.RLock()
        self.process = None
        self.lines = queue.Queue()
        self.fingerprint = None
        self.warming = False
        self.error = None
        self.log = None
        atexit.register(self.close)

    @staticmethod
    def sources_hash() -> str:
        digest = hashlib.sha256()
        paths = [ROOT / "Worker.lean", ROOT / "lakefile.toml", ROOT / "lake-manifest.json",
                 ROOT / "lean-toolchain", *sorted((ROOT / "Plaer").rglob("*.lean")),
                 ROOT / "vendor/LeanTeX/LeanTeX.lean",
                 ROOT / "vendor/LeanTeX/lakefile.lean",
                 ROOT / "vendor/LeanTeX/lean-toolchain",
                 *sorted((ROOT / "vendor/LeanTeX/LeanTeX").glob("*.lean"))]
        for path in paths:
            digest.update(str(path.relative_to(ROOT)).encode())
            digest.update(path.read_bytes())
        return digest.hexdigest()

    @property
    def ready(self) -> bool:
        return bool(self.process and self.process.poll() is None
                    and self.fingerprint == self.sources_hash())

    def close(self):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
            self.process = None
        if self.log:
            self.log.close()
            self.log = None
        self.fingerprint = None

    def read(self, timeout=90) -> str:
        try:
            line = self.lines.get(timeout=timeout)
        except queue.Empty:
            self.close()
            raise RuntimeError("Lean did not respond in time. Retry to restart it.")
        if line is None:
            self.close()
            raise RuntimeError("Lean stopped. See build/lean-worker.log.")
        return line.rstrip("\r\n")

    def prepare(self) -> bool:
        with self.lock:
            if self.ready:
                return True
            self.close()
            fingerprint = self.sources_hash()
            lake, environment = lean_environment()
            (ROOT / "build").mkdir(exist_ok=True)
            build = subprocess.run(
                [lake, "build", "Plaer.Check"], cwd=ROOT, env=environment,
                capture_output=True, text=True, encoding="utf-8", timeout=180)
            (ROOT / "build/last-proof-check.log").write_text(build.stdout + build.stderr, encoding="utf-8")
            if build.returncode:
                self.error = "The external Lean source failed to compile."
                return False
            self.lines = queue.Queue()
            self.log = (ROOT / "build/lean-worker.log").open("w", encoding="utf-8")
            # Launch Lean directly so closing this owner also closes its worker on Windows.
            environment = json.loads(subprocess.check_output(
                [lake, "env", sys.executable, "-c", "import json,os; print(json.dumps(dict(os.environ)))"],
                cwd=ROOT, env=environment, text=True, encoding="utf-8", timeout=30))
            lean = shutil.which("lean", path=environment["PATH"])
            self.process = subprocess.Popen(
                [lean, "--run", "Worker.lean"], cwd=ROOT, env=environment,
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
                text=True, encoding="utf-8", bufsize=1)
            process, lines = self.process, self.lines

            def read_stdout():
                for line in process.stdout:
                    lines.put(line)
                lines.put(None)

            threading.Thread(target=read_stdout, daemon=True).start()
            while (line := self.read(timeout=180)) != "LEAN_WORKER_READY":
                self.log.write(line + "\n")
                self.log.flush()
            if self.sources_hash() != fingerprint:
                self.close()
                raise RuntimeError("Lean sources changed during loading. Retry the check.")
            self.fingerprint = fingerprint
            self.error = None
            return True

    def start_warmup(self):
        if self.warming:
            return
        with self.lock:
            if self.warming or self.ready or self.error:
                return
            self.warming = True

        def warm():
            try:
                self.prepare()
            except Exception as error:
                self.error = str(error)
            finally:
                self.warming = False

        threading.Thread(target=warm, daemon=True).start()

    def check(self, name: str) -> dict:
        documented = documented_statements()
        if not isinstance(name, str) or name not in documented:
            raise ValueError("Choose a statement from this document")
        expected = documented[name]
        started = time.perf_counter()
        with self.lock:
            if not self.prepare():
                return {**expected, "result": {"ok": False},
                        "wallMs": round((time.perf_counter() - started) * 1000)}
            self.process.stdin.write(name + "\n")
            self.process.stdin.flush()
            report = json.loads(self.read(timeout=60))
            if "error" in report:
                raise RuntimeError(report["error"])
            if report["name"] != name or report["statementHash"] != expected["statementHash"]:
                raise RuntimeError("The statement changed. Rebuild the document.")
            if report["statementLatex"] != expected["statementLatex"]:
                raise RuntimeError("The statement's notation changed. Rebuild the document.")
            if self.sources_hash() != self.fingerprint:
                raise RuntimeError("Lean sources changed during verification. Retry the check.")
            report["wallMs"] = round((time.perf_counter() - started) * 1000)
            return report


WARM_LEAN = WarmLean()


def verify_theorem(name: str) -> dict:
    """Recheck the external proof without returning any proof text."""
    return WARM_LEAN.check(name)


def verify_proof(point: int, source: str) -> dict:
    if point not in (0, 2) or not isinstance(source, str) or len(source) > 4096:
        raise ValueError("Choose one of the two displayed claims and a proof under 4096 characters")
    lake, environment = lean_environment()
    checks_dir = ROOT / "build/live-checks"
    checks_dir.mkdir(parents=True, exist_ok=True)
    program = (
        "import Plaer.Check\n"
        "set_option maxHeartbeats 2000000\n"
        "set_option maxRecDepth 2048\n"
        f"#check_point_proof {point} {json.dumps(source, ensure_ascii=False)}\n"
    )
    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="proof-", dir=checks_dir) as task_dir:
        check_file = Path(task_dir) / "Check.lean"
        check_file.write_text(program, encoding="utf-8")
        process = subprocess.run(
            [lake, "env", "lean", "--json", str(check_file)], cwd=ROOT,
            env=environment, capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
    reports = []
    errors = []
    for line in process.stdout.splitlines():
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        data = message.get("data", "")
        if isinstance(data, str) and data.startswith("LEAN_PROOF_RESULT="):
            reports.append(json.loads(data.removeprefix("LEAN_PROOF_RESULT=")))
        if message.get("severity") == "error":
            errors.append(data)
    if process.returncode != 0 or errors or len(reports) != 1:
        raise RuntimeError("\n".join(errors) or process.stderr.strip() or process.stdout.strip() or "Lean returned no verification result")
    report = reports[0]
    if report["point"] != point or report["source"] != source:
        raise RuntimeError("Lean's result does not match the requested proof")
    report["wallMs"] = round((time.perf_counter() - started) * 1000)
    return report


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("point", type=int, choices=(0, 2))
    parser.add_argument("--proof", default="by\n  norm_num [Plaer.I]")
    args = parser.parse_args()
    print(json.dumps(verify_proof(args.point, args.proof), indent=2, ensure_ascii=False))
