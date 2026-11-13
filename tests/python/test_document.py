"""Build a throwaway paper with Lean: boxes, attached proofs, and rejected proofs."""
import shutil
from _support import ROOT
from document import LeanRejected, build_state
from package_document import declarations, package_document
from project import load_project

folder = ROOT / "tests" / "SelfTest"   # the lakefile lists `SelfTest` as a root for this test
shutil.rmtree(folder, ignore_errors=True)
(folder / "proofs").mkdir(parents=True)
MODULE = "SelfTest.Statements"
try:
    (folder / "Paper.md").write_text("""# Self test

```lean
import Mathlib.Data.Nat.Basic

/-- Tripling -/
def SelfTest.triple (n : ℕ) : ℕ := 3 * n

/-- Zero on the left
A caption. -/
def SelfTest.zero_add_statement : Prop := ∀ n : ℕ, 0 + n = n
-- proof: proofs/Good.lean SelfTest.Proofs.good
-- proof: proofs/Wrong.lean SelfTest.Proofs.wrong
-- proof: proofs/Sorry.lean SelfTest.Proofs.sorried
-- proof: proofs/Broken.lean SelfTest.Proofs.broken
-- proof: proofs/Missing.lean SelfTest.Proofs.missing

/-- A point -/
structure SelfTest.Point where
  x : ℕ

/-- No notation is registered for this -/
def SelfTest.unsupported_statement : Prop := ∀ n : ℕ, SelfTest.triple n = n + n + n
```

Prose after.
""", encoding="utf-8")
    header = f"import {MODULE}\n"
    (folder / "proofs/Good.lean").write_text(header + "theorem SelfTest.Proofs.good : SelfTest.zero_add_statement := by\n  intro n\n  simp\n", encoding="utf-8")
    # A valid proof of the wrong proposition must never verify the displayed statement.
    (folder / "proofs/Wrong.lean").write_text(header + "theorem SelfTest.Proofs.wrong : True := trivial\n", encoding="utf-8")
    (folder / "proofs/Sorry.lean").write_text(header + "theorem SelfTest.Proofs.sorried : SelfTest.zero_add_statement := by\n  sorry\n", encoding="utf-8")
    (folder / "proofs/Broken.lean").write_text(header + "theorem SelfTest.Proofs.broken : SelfTest.zero_add_statement := by\n  exact 1\n", encoding="utf-8")

    project = load_project(folder)
    assert project.source_module == MODULE

    state = build_state(project, run_proofs=True)
    boxes = {d["name"]: d for d in declarations(state)}
    assert list(boxes) == ["SelfTest.triple", "SelfTest.zero_add_statement",
                           "SelfTest.Point", "SelfTest.unsupported_statement"], list(boxes)
    assert boxes["SelfTest.triple"]["kind"] == "definition" and "\\coloneqq" in boxes["SelfTest.triple"]["latex"]
    statement = boxes["SelfTest.zero_add_statement"]
    assert (statement["kind"], statement["title"], statement["caption"]) == ("candidate", "Zero on the left", "A caption.")
    assert statement["statementLatex"] == "\\forall n : \\mathbb{N},\\ 0 + n = n", statement["statementLatex"]
    assert "ℕ" in statement["statementLean"] and "simp" not in str(statement["statementLean"])
    good, wrong, sorried, broken, missing = statement["proofs"]
    assert good["result"]["ok"] is True, good
    assert "does not prove the displayed proposition" in wrong["result"]["diagnostics"], wrong
    assert sorried["result"]["ok"] is False and "sorry" in sorried["result"]["diagnostics"], sorried
    assert broken["result"]["ok"] is False and missing["result"]["ok"] is False
    assert "not found" in missing["result"]["diagnostics"]
    checker = (project.output / good["checkerUrl"]).read_text(encoding="utf-8")
    assert checker.startswith("import Plaer.Check\n") and checker.rstrip().endswith(
        "#plaer_check_proof SelfTest.zero_add_statement SelfTest.Proofs.good")
    assert "Wrong" not in checker and "Broken" not in checker   # one check compiles one proof file
    # A structure is a definition with no formula: its box shows only the Lean.
    point = boxes["SelfTest.Point"]
    assert point["kind"] == "definition" and point["leanOnly"] and "structure" in point["source"], point
    # Unsupported notation keeps the Lean view and says why, instead of guessing or failing the build.
    unsupported = boxes["SelfTest.unsupported_statement"]
    assert unsupported["statementLatex"] is None and "No LaTeX" in unsupported["latexError"]

    page = package_document(project, state).read_text(encoding="utf-8")
    assert "intro n" not in page, "proof text must never be embedded in the page"
    assert (project.output / "audit.json").exists() and (project.output / "sources/proofs/Good.lean").exists()

    # Editing prose reuses every check; editing Lean marks them not checked.
    (folder / "Paper.md").write_text((folder / "Paper.md").read_text(encoding="utf-8") + "\nMore prose.\n", encoding="utf-8")
    again = {d["name"]: d for d in declarations(build_state(project, run_proofs=False))}
    assert again["SelfTest.zero_add_statement"]["proofs"][0]["result"]["ok"] is True
    text = (folder / "Paper.md").read_text(encoding="utf-8").replace("3 * n", "n * 3")
    (folder / "Paper.md").write_text(text, encoding="utf-8")
    again = {d["name"]: d for d in declarations(build_state(project, run_proofs=False))}
    assert again["SelfTest.zero_add_statement"]["proofs"][0]["result"].get("pending") is True
    # A theorem (which carries its proof) or sorry in the paper is rejected.
    (folder / "Paper.md").write_text(text + "\n```lean\ntheorem SelfTest.inline (n : ℕ) : n = n := rfl\n"
                                     "def SelfTest.half : ℕ → ℕ := sorry\n```\n", encoding="utf-8")
    try:
        build_state(project, run_proofs=False)
        raise AssertionError("a theorem or sorry in the paper was accepted")
    except LeanRejected as error:
        assert "SelfTest.inline as a conjecture" in str(error) and "`sorry` is not allowed" in str(error), error
    # An axiom is accepted, and gets its own box.
    (folder / "Paper.md").write_text(text + "\n```lean\n/-- Assumed -/\naxiom SelfTest.assumed : ∀ n : ℕ, n = n\n```\n",
                                     encoding="utf-8")
    assumed = {d["name"]: d for d in declarations(build_state(project, run_proofs=False))}["SelfTest.assumed"]
    assert assumed["kind"] == "axiom" and assumed["statementLatex"].startswith("\\forall n"), assumed
    print("PASS: boxes from one paper; good proof accepted; wrong, sorry, broken and missing proofs rejected; "
          "theorems and sorry refused in papers; axioms get boxes")
finally:
    shutil.rmtree(folder, ignore_errors=True)
    shutil.rmtree(ROOT / "dist" / "selftest", ignore_errors=True)
    shutil.rmtree(ROOT / "build" / "selftest", ignore_errors=True)
