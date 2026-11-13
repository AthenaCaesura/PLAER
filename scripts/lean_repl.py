"""One long-running Lean, through the community REPL (leanprover-community/repl).

Starting Lean and loading Mathlib costs seconds, every time. The REPL loads a
paper's imports once and keeps them. The paper's Lean then runs as one command
on top of them, and each proof as its own command on top of the paper. Proofs
never see each other: each starts from the paper's environment.

    session = session_for(project)
    paper = session.paper(imports, body)        # once per change to the paper
    response = session.command(text, paper)     # a proof, a report, ...
"""
from __future__ import annotations

import json
import re
import subprocess
import threading

from project import ROOT, Project
from toolchain import lean_invocation

REPL = ROOT / ".lake" / "packages" / "REPL" / ".lake" / "build" / "bin" / "repl"
IMPORT = re.compile(r"\s*import\s+(\S+)\s*(--.*)?\Z")
ENGINE = ["Plaer.Extract"]          # imports Plaer.Check and Plaer.Latex
RESTART_AFTER = 400                 # the REPL keeps every environment; start afresh now and then


def split_imports(text: str) -> tuple[list[str], str]:
    """The modules a file imports, and the file with those lines blanked.

    Lines keep their numbers, so Lean's messages point at the original file.
    Returns (None, text) when imports do not all come first.
    """
    lines = text.split("\n")
    modules = []
    for number, line in enumerate(lines):
        match = IMPORT.match(line)
        if match:
            modules.append(match.group(1))
            lines[number] = ""
        elif line.strip() and not line.lstrip().startswith("--"):
            rest = "\n".join(lines[number:])
            if re.search(r"^\s*import\s", rest, re.M):
                return None, text
            break
    return modules, "\n".join(lines)


class Session:
    def __init__(self, project: Project):
        self.project = project
        self.lock = threading.RLock()
        self.process = None
        self.imports = None       # what the running REPL has loaded
        self.base = None          # the environment right after the imports
        self.papers = {}          # paper text -> environment
        self.commands = 0

    def _start(self, imports: list[str]) -> None:
        self.close()
        if not REPL.exists():
            raise RuntimeError("The Lean REPL is not built. Run: lake build repl")
        _, env = lean_invocation(self.project)
        self.process = subprocess.Popen([str(REPL)], cwd=ROOT, env=env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True, encoding="utf-8", bufsize=1)
        self.imports, self.papers, self.commands = None, {}, 0
        header = "\n".join(f"import {m}" for m in imports)
        response = self._send({"cmd": header})
        errors = [m["data"] for m in response.get("messages", []) if m.get("severity") == "error"]
        if errors:
            self.close()
            raise ImportFailed("\n".join(errors))
        self.imports, self.base = imports, response["env"]

    def _send(self, request: dict) -> dict:
        self.process.stdin.write(json.dumps(request) + "\n\n")
        self.process.stdin.flush()
        lines = []
        while True:
            line = self.process.stdout.readline()
            if not line:
                error = self.process.stderr.read()[-3000:]
                self.close()
                raise RuntimeError("The Lean REPL stopped:\n" + error)
            if not line.strip():
                if lines:
                    break
                continue
            lines.append(line)
        self.commands += 1
        response = json.loads("".join(lines))
        if "env" not in response and "message" in response:
            raise RuntimeError("Lean REPL: " + response["message"])
        return response

    def paper(self, imports: list[str], body: str) -> tuple[int, list[dict]]:
        """Run the paper's Lean on its imports. Returns (environment, messages)."""
        wanted = sorted(set(imports) | set(ENGINE))
        with self.lock:
            if self.process is None or self.imports != wanted or self.commands > RESTART_AFTER:
                self._start(wanted)
            if body not in self.papers:
                response = self._send({"cmd": body, "env": self.base})
                self.papers = {body: (response["env"], response.get("messages", []))}
            return self.papers[body]

    def command(self, text: str, env: int) -> list[dict]:
        """Run Lean commands in an environment. Returns Lean's messages."""
        with self.lock:
            return self._send({"cmd": text, "env": env}).get("messages", [])

    def close(self) -> None:
        if self.process is not None:
            self.process.kill()
            self.process.wait()
        self.process = None


class ImportFailed(RuntimeError):
    """The paper's imports do not load."""


_sessions: dict = {}
_sessions_lock = threading.Lock()


def session_for(project: Project) -> Session:
    with _sessions_lock:
        if project.paper not in _sessions:
            _sessions[project.paper] = Session(project)
        return _sessions[project.paper]
