"""Compile one configured proof file and audit its exported theorem against the statement."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from project import ROOT, Project, load_project
from toolchain import lean_environment

MARKER = "PLAER_PROOF_RESULT="

def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()

def source_fingerprint(project: Project) -> str:
    """Proof edits do not invalidate statements; statement/framework edits do."""
    proofs = {entry["proof_file"] for entry in project.statements}
    paths = {project.manifest, project.source, project.paper, ROOT / "lakefile.toml",
             ROOT / "lake-manifest.json", ROOT / "lean-toolchain"}
    paths.update((ROOT / "Plaer").rglob("*.lean"))
    paths.update((ROOT / "vendor/LeanTeX").glob("LeanTeX.lean"))
    paths.update((ROOT / "vendor/LeanTeX/LeanTeX").glob("*.lean"))
    paths.update(p for p in project.manifest.parent.rglob("*.lean")
                 if p not in proofs and "proofs" not in p.relative_to(project.manifest.parent).parts)
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(relative(path).encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()

def documented_statements(project: Project) -> dict:
    data = json.loads((project.output / "build.json").read_text(encoding="utf-8"))
    return {report["name"]: report for report in data["theorem_checks"]}

def prepare_source(project: Project) -> None:
    lake, env = lean_environment(project)
    result = subprocess.run([lake, "build", "Plaer.Check", project.source_module],
        cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", timeout=300)
    project.build_dir.mkdir(parents=True, exist_ok=True)
    (project.build_dir / "source-build.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode:
        raise RuntimeError("The statements file failed to compile. See the project's source-build.log.")

def proof_material(project: Project, entry: dict):
    source_hash = source_fingerprint(project)
    proof_bytes = entry["proof_file"].read_bytes()
    proof_hash = hashlib.sha256(proof_bytes).hexdigest()
    original = proof_bytes.decode("utf-8")
    # Preserve the complete proof file. Only an import and final claim audit are added.
    if re.match(r"\s*module\b", original):
        raise ValueError("Proof files currently use ordinary import headers, without the module command.")
    checker = ("import Plaer.Check\n" + original + "\n\n"
        f'#plaer_check_proof {entry["name"]} {entry["proof_declaration"]}\n')
    stem = entry["name"].replace(".", "_").replace("'", "_prime")
    filename = f"{stem}-{source_hash[:8]}-{proof_hash[:8]}.lean"
    check_dir = project.output / "checks"
    check_dir.mkdir(parents=True, exist_ok=True)
    checker_path = check_dir / filename
    checker_path.write_bytes(checker.encode("utf-8"))
    proof_snapshot = project.output / "sources/proofs" / (proof_hash[:12] + "-" + entry["proof_file"].name)
    proof_snapshot.parent.mkdir(parents=True, exist_ok=True)
    proof_snapshot.write_bytes(proof_bytes)
    source_snapshot = project.output / "sources" / project.source.name
    source_snapshot.parent.mkdir(parents=True, exist_ok=True)
    source_snapshot.write_bytes(project.source.read_bytes())
    metadata = {
        "proofFile": relative(entry["proof_file"]), "proofDeclaration": entry["proof_declaration"],
        "sourceFile": relative(project.source), "sourceUrl": "sources/" + project.source.name,
        "proofUrl": proof_snapshot.relative_to(project.output).as_posix(), "checkerUrl": "checks/" + filename,
        "command": "lake env lean --json " + json.dumps(relative(checker_path)),
        "proofSha256": proof_hash, "sourceFingerprint": source_hash,
        "checkerSha256": hashlib.sha256(checker_path.read_bytes()).hexdigest(),
        "auditUrl": "checks/" + filename.removesuffix(".lean") + ".json",
    }
    return checker_path, proof_bytes, metadata

def run_proof(project: Project, entry: dict, *, prepare: bool = True) -> dict:
    if prepare:
        prepare_source(project)
    checker_path, proof_bytes, metadata = proof_material(project, entry)
    source_hash, proof_hash = metadata['sourceFingerprint'], metadata['proofSha256']
    lake, env = lean_environment(project)
    started = time.perf_counter()
    process = subprocess.run([lake, "env", "lean", "--json", str(checker_path)],
        cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", timeout=240)
    diagnostics, reports = [], []
    for line in process.stdout.splitlines():
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        value = message.get("data", "")
        if isinstance(value, str) and value.startswith(MARKER):
            reports.append(json.loads(value[len(MARKER):]))
        if message.get("severity") == "error":
            diagnostics.append(str(value))
    if source_fingerprint(project) != source_hash or entry["proof_file"].read_bytes() != proof_bytes:
        raise RuntimeError("The source or proof file changed during checking. Run it again.")
    report = reports[0] if len(reports) == 1 else {}
    if process.returncode or diagnostics or not report:
        report = {"name": entry["name"], "proofDeclaration": entry["proof_declaration"],
                  "result": {"ok": False, "diagnostics": "\n".join(diagnostics)
                     or process.stderr.strip() or "Lean did not verify the configured proof declaration."}}
    if report.get("name") != entry["name"] or report.get("proofDeclaration") != entry["proof_declaration"]:
        raise RuntimeError("Lean checked a different proof declaration.")
    report.update(metadata)
    report["wallMs"] = round((time.perf_counter() - started) * 1000)
    (project.output / report["auditUrl"]).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    project.build_dir.mkdir(parents=True, exist_ok=True)
    stem = entry["name"].replace(".", "_").replace("'", "_prime")
    (project.build_dir / (stem + "-compiler.log")).write_text(process.stdout + process.stderr, encoding="utf-8")
    return report

def verify_theorem(project: Project, name: str) -> dict:
    documented = documented_statements(project)
    if not isinstance(name, str) or name not in documented:
        raise ValueError("Choose a statement from this document")
    saved = json.loads((project.output / "build.json").read_text(encoding="utf-8"))
    if saved["source_fingerprint"] != source_fingerprint(project):
        raise RuntimeError("The statements or framework changed. Rebuild the document.")
    entry = next((e for e in project.statements if e["name"] == name), None)
    if entry is None:
        from boxes import proof_entry
        from explanations import read_cells
        for cell in read_cells(project)["cells"]:
            if cell["kind"] == "theorem":
                candidate = proof_entry(project, cell["source"])
                if candidate["name"] == name:
                    entry = candidate
                    break
    if entry is None:
        raise ValueError("No proof file is mapped to that statement")
    report = run_proof(project, entry)
    expected = documented[name]
    if report.get("statementHash") is not None and report["statementHash"] != expected["statementHash"]:
        raise RuntimeError("The proof was checked against a different statement. Rebuild.")
    # A failing proof may never reach the final audit command; retain the displayed identity.
    return {**expected, **report, "statementHash": expected["statementHash"]}

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project")
    parser.add_argument("name")
    args = parser.parse_args()
    print(json.dumps(verify_theorem(load_project(args.project), args.name), ensure_ascii=False, indent=2))
