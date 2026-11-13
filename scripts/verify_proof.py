"""Check one attached proof against the statement the document displays.

The checker is a readable Lean file: the complete proof file, one added import,
and a final command that audits the proof's declaration against the statement.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import time

from project import IDENTIFIER, ROOT, Project, proof_path, relative
from lean_repl import ImportFailed, session_for, split_imports
from toolchain import lean_invocation

MARKER = "PLAER_PROOF_RESULT="


def run_lean(project: Project, file, timeout: int = 240, options=()) -> tuple[subprocess.CompletedProcess, list[dict]]:
    """Run Lean on one file inside the Lake workspace (as `lake env lean`); return its JSON messages."""
    lean, env = lean_invocation(project)
    process = subprocess.run([lean, "--json", *options, str(file)], cwd=ROOT, env=env,
                             capture_output=True, text=True, encoding="utf-8", timeout=timeout)
    messages = []
    for line in process.stdout.splitlines():
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(message, dict) and isinstance(message.get("data"), str):
            messages.append(message)
    return process, messages


def compile_module(project: Project) -> list[str]:
    """Compile the paper's Lean file to the module that proof files import.

    Lean runs directly, as Lake would run it: asking Lake costs seconds even when
    nothing changed. Returns Lean's errors, each naming a line of the paper.
    """
    out = ROOT / ".lake" / "build" / "lib" / "lean" / project.folder.name
    out.mkdir(parents=True, exist_ok=True)
    _, messages = run_lean(project, project.source, timeout=1800, options=[
        "-R", str(project.folder.parent), "-o", str(out / "Statements.olean"), "-i", str(out / "Statements.ilean")])
    return [f"{project.paper.name}:{m['pos']['line']}: {m['data']}"
            for m in messages if m.get("severity") == "error" and m.get("pos")]


def proof_messages(project: Project, statement: str, proof: dict, metadata: dict) -> tuple[bool, list[dict], str]:
    """Lean's messages for one proof check: (Lean failed, messages, other output).

    Usually one command in the long-running REPL, on top of the paper. A proof
    file importing modules the paper does not falls back to its own Lean process.
    """
    check = f"\n\n#plaer_check_proof {statement} {proof['declaration']}\n"
    session = session_for(project)
    paper_imports, paper_body = split_imports(project.source.read_text(encoding="utf-8"))
    proof_imports, proof_body = split_imports(proof_path(project, proof["file"]).read_text(encoding="utf-8"))
    if paper_imports is not None and proof_imports is not None:
        try:
            env, paper = session.paper(paper_imports, paper_body)
        except ImportFailed as error:
            return True, [], str(error)
        if any(m.get("severity") == "error" for m in paper):
            return True, [], "The paper's Lean has errors."
        if set(proof_imports) <= set(session.imports) | {project.source_module}:
            return False, session.command(proof_body + check, env), ""
    errors = compile_module(project)
    if errors:
        return True, [], "\n".join(errors)
    process, messages = run_lean(project, project.output / metadata["checkerUrl"])
    return process.returncode != 0, messages, process.stderr.strip()


def write_checker(project: Project, statement: str, proof: dict) -> dict:
    """Write the checker file and source snapshots; return what the page links to.

    `proof` is {"file", "declaration"}.
    """
    declaration = proof["declaration"]
    if not IDENTIFIER.fullmatch(statement) or not IDENTIFIER.fullmatch(declaration):
        raise ValueError(f"Not a Lean declaration name: {declaration}")
    proof_file = proof_path(project, proof["file"])
    original = proof_file.read_text(encoding="utf-8")
    # Preserve the complete proof file. Only an import and final claim audit are added.
    if re.match(r"\s*module\b", original):
        raise ValueError("Proof files use ordinary import headers, without the module command.")
    inside = os.path.relpath(proof_file, project.folder).replace(os.sep, "/")
    snapshot = project.output / "sources" / (inside if not inside.startswith("..") else "external/" + proof_file.name)
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_bytes(proof_file.read_bytes())

    stem = (statement + "--" + declaration).replace(".", "_").replace("'", "_prime")
    checker = project.output / "checks" / (stem + ".lean")
    checker.parent.mkdir(parents=True, exist_ok=True)
    checker.write_text(f"import Plaer.Check\n{original}\n\n#plaer_check_proof {statement} {declaration}\n",
                       encoding="utf-8")
    return {
        "proofFile": relative(proof_file), "proofDeclaration": declaration,
        "proofUrl": snapshot.relative_to(project.output).as_posix(),
        "checkerUrl": "checks/" + checker.name, "auditUrl": "checks/" + stem + ".json",
        "command": "lake env lean --json " + json.dumps(relative(checker)),
        "proofSha256": hashlib.sha256(original.encode()).hexdigest(),
    }


def check_proof(project: Project, statement: dict, proof: dict) -> dict:
    """Compile the checker. The report says whether the proof proves the statement."""
    name = statement["name"]
    try:
        metadata = write_checker(project, name, proof)
    except ValueError as error:
        # Nothing was compiled, but the answer is still about this statement.
        return {"name": name, "proofDeclaration": proof["declaration"],
                "statementHash": statement["statementHash"],
                "result": {"ok": False, "diagnostics": str(error)}}
    started = time.perf_counter()
    failed, messages, output = proof_messages(project, name, proof, metadata)
    reports = [json.loads(m["data"][len(MARKER):]) for m in messages if m["data"].startswith(MARKER)]
    errors = [m["data"] for m in messages if m.get("severity") == "error"]
    report = reports[0] if len(reports) == 1 else {}
    if failed or errors or not report:
        report = {"name": name, "proofDeclaration": proof["declaration"],
                  "result": {"ok": False, "diagnostics": "\n".join(errors) or output
                             or "Lean did not verify the attached proof declaration."}}
    if report.get("name") != name or report.get("proofDeclaration") != proof["declaration"]:
        raise RuntimeError("Lean checked a different proof declaration.")
    # A proof that fails to compile never reaches the audit command, so it reports
    # no hash. One that does must have been audited against the displayed statement.
    if report.get("statementHash") not in (None, statement["statementHash"]):
        raise RuntimeError("The proof was checked against a different statement. Rebuild.")
    report.update(metadata)
    report["statementHash"] = statement["statementHash"]
    report["wallMs"] = round((time.perf_counter() - started) * 1000)
    (project.output / metadata["auditUrl"]).write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report
