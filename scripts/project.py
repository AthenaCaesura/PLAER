"""Locate a project from its paper. There is no manifest: the paper is the project.

    examples/Fermat/Paper.md         the one file you write
    examples/Fermat/Statements.lean  generated from it; the Lean that is compiled
    examples/Fermat/proofs/*.lean    proofs, attached with `-- proof:` lines
    dist/fermat/                     the readable document and its audit files
"""
from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_']*(?:\.[A-Za-z_][A-Za-z0-9_']*)*\Z")


@dataclass(frozen=True)
class Project:
    paper: Path

    @property
    def folder(self) -> Path:
        return self.paper.parent

    @property
    def id(self) -> str:
        return self.folder.name.lower()

    @property
    def source(self) -> Path:
        """The generated Lean file. Proof files import it as `<Folder>.Statements`."""
        return self.folder / "Statements.lean"

    @property
    def source_module(self) -> str:
        return self.folder.name + ".Statements"

    @property
    def output(self) -> Path:
        return ROOT / "dist" / self.id

    @property
    def build_dir(self) -> Path:
        return ROOT / "build" / self.id


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_project(paper: str | Path | None = None) -> Project:
    """Accepts a Paper.md or its folder. Falls back to the PLAER_PROJECT variable."""
    chosen = paper if paper is not None else os.environ.get("PLAER_PROJECT")
    if chosen is None or not str(chosen).strip():
        raise ValueError("Choose a paper, for example: examples/Basics/Paper.md")
    path = Path(chosen).resolve()
    if path.is_dir():
        path = path / "Paper.md"
    if path.suffix != ".md" or not path.is_file():
        raise ValueError(f"No Markdown paper at {chosen}")
    if not path.is_relative_to(ROOT):
        raise ValueError("The paper must be inside the repository")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", path.parent.name):
        raise ValueError("The paper's folder names its Lean module, so it must be a Lean "
                         "identifier such as Fermat")
    return Project(path)


def proof_path(project: Project, file: str) -> Path:
    """A proof file named in the paper, relative to the paper's folder."""
    path = (project.folder / file).resolve()
    if not path.is_relative_to(ROOT) or path.suffix != ".lean":
        raise ValueError(f"A proof must be a .lean file inside the repository: {file}")
    if not path.is_file():
        raise ValueError(f"Proof file not found: {file}")
    return path
