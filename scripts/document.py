"""From a paper to the document the browser shows.

    Paper.md ──► Statements.lean ──► Lean (Plaer.moduleReport) ──► boxes
                                       └─ each `-- proof:` line ──► proof checks

All mathematics on the page comes from Lean's elaborated declarations. This
module only decides where each box goes and which proofs are attached to it.
"""
from __future__ import annotations

import hashlib
import json
import subprocess

import paper
from project import ROOT, Project, relative
from toolchain import lean_environment
from verify_proof import check_proof, run_lean

REPORT_MARKER = "PLAER_REPORT="


class LeanRejected(ValueError):
    """The paper's Lean does not compile. The message names lines of the paper."""


def engine_fingerprint() -> str:
    """Changes when the Lean side of PLAER or its dependencies change."""
    paths = [ROOT / "lakefile.toml", ROOT / "lake-manifest.json", ROOT / "lean-toolchain"]
    paths += sorted((ROOT / "Plaer").rglob("*.lean")) + sorted((ROOT / "vendor/LeanTeX").rglob("*.lean"))
    digest = hashlib.sha256()
    for path in paths:
        digest.update(relative(path).encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def write_statements(project: Project, markdown: str) -> None:
    """Write the paper's Lean file. Its line numbers are the paper's."""
    source = paper.lean_source(markdown)
    if not project.source.exists() or project.source.read_text(encoding="utf-8") != source:
        project.source.write_text(source, encoding="utf-8")


_built: dict = {}


def statements_built(project: Project) -> bool:
    """Whether this process already built the paper's Lean file as it is now."""
    return _built.get(project.source) == (project.source.read_text(encoding="utf-8"), engine_fingerprint())


def build_statements(project: Project) -> None:
    """Compile the paper's Lean file and PLAER's Lean engine. Quick when up to date."""
    lake, env = lean_environment(project)
    built = (project.source.read_text(encoding="utf-8"), engine_fingerprint())
    build = subprocess.run([lake, "build", "Plaer", project.source_module], cwd=ROOT, env=env,
                           capture_output=True, text=True, encoding="utf-8", timeout=1800)
    project.build_dir.mkdir(parents=True, exist_ok=True)
    (project.build_dir / "source-build.log").write_text(build.stdout + build.stderr, encoding="utf-8")
    if build.returncode == 0:
        _built[project.source] = built
        return
    # Ask Lean directly, so each error carries its line. Lines match the paper's.
    _, messages = run_lean(project, project.source)
    errors = [f"{project.paper.name}:{m['pos']['line']}: {m['data']}"
              for m in messages if m.get("severity") == "error" and m.get("pos")]
    raise LeanRejected("\n\n".join(errors) or (build.stdout + build.stderr)[-3000:])


class StaleSource(RuntimeError):
    """The paper changed while Lean was compiling it; that compile is discarded."""


def declarations(project: Project, blocks: list[paper.Block], compile: bool = True) -> tuple[list[dict], set[int], bool]:
    """Lean's report on every declaration in the paper, each located in its block.

    Returns (declarations, pending lean block indices, up to date). Cached until
    some Lean changes, so editing prose never waits for Lean. Without `compile`,
    Lean is never run: blocks whose text is unchanged since the last compile keep
    their boxes, and any other lean block is pending.
    """
    project.build_dir.mkdir(parents=True, exist_ok=True)
    lean_blocks = [block for block in blocks if block.kind == "lean"]
    key = hashlib.sha256((paper.lean_fingerprint(blocks) + engine_fingerprint()
                          + project.source_module).encode()).hexdigest()
    cache = project.build_dir / "declarations.json"
    saved = json.loads(cache.read_text(encoding="utf-8")) if cache.exists() else None
    if saved and saved["key"] == key:
        return ([{**d, "line": lean_blocks[d["block"]].line + d["offset"]} for d in saved["declarations"]],
                set(), True)
    if not compile:
        return (*reuse(saved, lean_blocks), False)

    expected = project.source.read_text(encoding="utf-8")
    build_statements(project)
    driver = project.build_dir / "Report.lean"
    driver.write_text(
        f"import {project.source_module}\nimport Plaer.Extract\n\nopen Lean\n\nrun_meta do\n"
        f"  let report ← Plaer.moduleReport (String.toName {json.dumps(project.source_module)})\n"
        f'  logInfo m!"{REPORT_MARKER}{{report.compress}}"\n', encoding="utf-8")
    process, messages = run_lean(project, driver)
    if project.source.read_text(encoding="utf-8") != expected:
        raise StaleSource("The paper changed during the compile")
    reports = [m["data"][len(REPORT_MARKER):] for m in messages if m["data"].startswith(REPORT_MARKER)]
    if process.returncode or len(reports) != 1:
        errors = [m["data"] for m in messages if m.get("severity") == "error"]
        raise RuntimeError("Lean could not describe the paper's declarations:\n"
                           + ("\n".join(errors) or process.stderr)[-3000:])
    found = json.loads(reports[0])
    for declaration in found:
        index = next(i for i, block in enumerate(lean_blocks)
                     if block.line <= declaration["line"] < block.line + block.text.count("\n") + 1)
        declaration["block"] = index
        declaration["offset"] = declaration["line"] - lean_blocks[index].line
        declaration["lines"] = declaration.pop("endLine") - declaration["line"] + 1
    temporary = cache.with_suffix(".tmp")
    temporary.write_text(json.dumps({"key": key, "texts": [b.text for b in lean_blocks],
                                     "declarations": found}, ensure_ascii=False), encoding="utf-8")
    temporary.replace(cache)
    return found, set(), True


def reuse(saved: dict | None, lean_blocks: list[paper.Block]) -> tuple[list[dict], set[int]]:
    """Boxes from the last compile for lean blocks whose text is unchanged."""
    texts = (saved or {}).get("texts", [])
    unused = list(range(len(texts)))
    mapping, pending = {}, set()
    for index, block in enumerate(lean_blocks):
        old = next((j for j in unused if texts[j] == block.text), None)
        if old is None:
            pending.add(index)
        else:
            unused.remove(old)
            mapping[old] = index
    found = [{**d, "block": mapping[d["block"]], "line": lean_blocks[mapping[d["block"]]].line + d["offset"]}
             for d in (saved or {}).get("declarations", []) if d["block"] in mapping]
    return found, pending


def attach_proofs(blocks: list[paper.Block], found: list[dict], pending: set[int] = frozenset()) -> None:
    """Give each statement its proofs: the `-- proof:` lines that follow it.

    Lean has not compiled a pending block yet, so its proof lines wait too.
    """
    lean_blocks = [block for block in blocks if block.kind == "lean"]
    for declaration in found:
        is_statement = declaration["kind"] in ("theorem", "candidate")
        # A theorem proved in the paper is its own first proof.
        declaration["proofs"] = ([{"inline": True, "declaration": declaration["name"]}]
                                 if declaration["kind"] == "theorem" else [])
        declaration["statement"] = is_statement
    for index, block in enumerate(lean_blocks):
        if index in pending:
            continue
        for offset, line in enumerate(block.text.splitlines()):
            match = paper.PROOF_LINE.match(line)
            if not match:
                continue
            above = [d for d in found if d["block"] == index and d["statement"]
                     and d["offset"] + d["lines"] <= offset]
            if not above:
                raise LeanRejected(f"Line {block.line + offset}: a `-- proof:` line must come "
                                   "after the statement it proves, in the same block.")
            above[-1]["proofs"].append({"file": match[1], "declaration": match[2]})


def proof_key(statement: dict, proof: dict) -> str:
    return "|".join([statement["name"], proof.get("file", ""), proof["declaration"]])


class Results:
    """Saved proof checks. One is reused only while the Lean it checked is unchanged."""

    def __init__(self, project: Project, fingerprint: str):
        self.path = project.build_dir / "proof-results.json"
        self.fingerprint = fingerprint
        self.saved = json.loads(self.path.read_text(encoding="utf-8")) if self.path.exists() else {}

    def get(self, key: str) -> dict | None:
        entry = self.saved.get(key)
        return entry["report"] if entry and entry["fingerprint"] == self.fingerprint else None

    def put(self, key: str, report: dict) -> None:
        self.saved[key] = {"fingerprint": self.fingerprint, "report": report}
        self.path.write_text(json.dumps(self.saved, ensure_ascii=False, indent=2), encoding="utf-8")


def box_title(declaration: dict) -> tuple[str, str]:
    """A box's title is the first line of its doc comment; the rest is its caption."""
    first, _, rest = declaration["doc"].partition("\n")
    return first.strip().rstrip(".") or declaration["name"].split(".")[-1], rest.strip()


def block_items(block: paper.Block, found: list[dict]) -> list[dict]:
    """What a lean block shows: a box per declaration, and any other code between."""
    starts = {d["line"]: d for d in found}
    items, code = [], []

    def flush():
        text = "\n".join(code).strip("\n")
        if text.strip():
            items.append({"type": "code", "text": text})
        code.clear()

    lines = block.text.splitlines()
    number = block.line
    while number < block.line + len(lines):
        if number in starts:
            flush()
            items.append({"type": "declaration", **starts[number]})
            number += starts[number]["lines"]
        else:
            if not paper.PROOF_LINE.match(lines[number - block.line]):
                code.append(lines[number - block.line])
            number += 1
    flush()
    return items


def build_state(project: Project, run_proofs: bool, log=lambda _: None, compile: bool = True) -> dict:
    """Read the paper and return everything the page needs.

    With `run_proofs`, every attached proof is checked now. Otherwise saved
    checks are reused where still valid and the rest are marked not checked.
    Without `compile`, Lean is not run at all (see `declarations`); the state's
    `compiled` is then false unless nothing in the Lean changed.
    """
    markdown = project.paper.read_text(encoding="utf-8")
    blocks = paper.parse(markdown)
    write_statements(project, markdown)
    found, pending, compiled = declarations(project, blocks, compile=compile or run_proofs)
    attach_proofs(blocks, found, pending)
    if run_proofs:
        build_statements(project)

    results = Results(project, paper.lean_fingerprint(blocks) + engine_fingerprint())
    (project.output / "checks").mkdir(parents=True, exist_ok=True)
    for declaration in found:
        declaration["title"], declaration["caption"] = box_title(declaration)
        for proof in declaration["proofs"]:
            key = proof_key(declaration, proof)
            report = results.get(key)
            if run_proofs:
                log(f"Check {declaration['name']} with {proof['declaration']}")
                report = check_proof(project, declaration, proof)
                results.put(key, report)
                log("  " + ("Proved" if report["result"]["ok"] else "Not proved"))
            proof.update(report or {"result": {"ok": False, "pending": True}})

    return {
        "project": project.id,
        "title": paper.title(blocks, project.folder.name),
        "revision": hashlib.sha256(markdown.encode()).hexdigest(),
        "paperFile": relative(project.paper), "paperUrl": "sources/" + project.paper.name,
        "sourceFile": relative(project.source), "sourceUrl": "sources/" + project.source.name,
        "sourceModule": project.source_module,
        "compiled": compiled,
        "blocks": [lean_or_markdown(block, found, lean_index, pending)
                   for block, lean_index in zip(blocks, lean_indices(blocks))],
    }


def lean_indices(blocks: list[paper.Block]) -> list[int | None]:
    """Each block's position among the lean blocks (None for Markdown)."""
    count, indices = 0, []
    for block in blocks:
        indices.append(count if block.kind == "lean" else None)
        count += block.kind == "lean"
    return indices


def lean_or_markdown(block: paper.Block, found: list[dict], lean_index: int | None, pending: set[int]) -> dict:
    data = {"kind": block.kind, "text": block.text, "line": block.line}
    if block.kind == "lean":
        data["items"] = block_items(block, found)
        if lean_index in pending:
            data["pending"] = True
    return data


def find_proof(state: dict, name: str, index: int) -> tuple[dict, dict]:
    """The statement called `name` in a document, and its proof number `index`."""
    for block in state["blocks"]:
        for item in block.get("items", []):
            if item["type"] == "declaration" and item["name"] == name and item["statement"]:
                if isinstance(index, int) and 0 <= index < len(item["proofs"]):
                    return item, item["proofs"][index]
    raise ValueError("Choose a proof attached to a statement in this document")
