import fixtures.Interval

open Lean Meta Elab Term Plaer IntervalFixture

namespace LatexTests

def unmapped (n : Nat) : Nat := n + 7
def alternate : Set ℝ := {y | y = 0 ∨ y = 1}
theorem quantified (n : Nat) : n + 0 = n := Nat.add_zero n

private meta def renderTerm (source : String) : TermElabM String := do
  let parsed ← match Parser.runParserCategory (← getEnv) `term source with
    | .ok parsed => pure parsed
    | .error message => throwError "{message}"
  let expression ← elabTerm parsed none
  synthesizeSyntheticMVarsNoPostponing
  expressionLatex (← instantiateMVars expression)

elab "#test_latex" : command => Command.liftTermElabM do
  let cases := [
    ("(0 : ℝ) ∈ IntervalFixture.I", "0 \\in I"),
    ("(2 : ℝ) ∉ IntervalFixture.I", "2 \\notin I"),
    ("∀ x : ℝ, x ≤ 1 → x + 1 ≤ 2", "\\forall x : \\mathbb{R},\\ x \\le 1 \\implies x + 1 \\le 2"),
    ("∃ n : ℕ, 1 < n", "\\exists n : \\mathbb{N},\\ 1 < n"),
    ("((1 + 2) / 3 : ℝ)", "\\frac{1 + 2}{3}"),
    ("((1 / 2) ^ 3 : ℝ)", "\\left(\\frac{1}{2}\\right)^{3}"),
    ("(1 + (2 + 3) : ℕ)", "1 + (2 + 3)"),
    ("{y : ℝ | -1 < y ∧ y ≤ 2}", "\\left\\{y\\in\\mathbb{R}\\;\\middle|\\; - 1 < y \\le 2\\right\\}"),
    ("{y : ℝ | y = 0 ∨ y = 1}", "\\left\\{y\\in\\mathbb{R}\\;\\middle|\\; y = 0 \\lor y = 1\\right\\}"),
    ("∀ x : ℝ, ∃ x : ℝ, x = x", "\\forall x : \\mathbb{R},\\ \\exists x : \\mathbb{R},\\ x = x")]
  let mut fixtures : Array Json := #[]
  for (source, expected) in cases do
    let latex ← renderTerm source
    unless latex == expected do
      throwError "Rendering {source}: expected {expected}, got {latex}"
    fixtures := fixtures.push <| Json.mkObj [("source", toJson source), ("latex", toJson latex)]
  -- An inner unsupported expression must fail too; no generic fallback may hide it.
  for source in ["LatexTests.unmapped 3", "1 + LatexTests.unmapped 3",
      "(let x : Nat := 1; x + 2)", "∀ x : ℕ, LatexTests.unmapped x = x", "(_ : ℕ)"] do
    let rejected ← try
      let _ ← renderTerm source
      pure false
    catch _ => pure true
    unless rejected do throwError "Strict rendering silently accepted: {source}"
  let definition ← definitionLatex ``I
  unless definition == "I \\coloneqq \\left\\{x\\in\\mathbb{R}\\;\\middle|\\; 0 \\le x \\le 1\\right\\}" do
    throwError "The paper definition changed unexpectedly: {definition}"
  fixtures := fixtures.push <| Json.mkObj [("source", toJson "definition I"), ("latex", toJson definition)]
  -- Unsupported plot shapes can still have supported mathematical notation.
  let alternate ← definitionLatex ``alternate
  fixtures := fixtures.push <| Json.mkObj [("source", toJson "definition alternate"), ("latex", toJson alternate)]
  let report ← statementReport ``quantified
  let latex ← ofExcept <| report.getObjValAs? String "statementLatex"
  unless latex == "\\forall n : \\mathbb{N},\\ n + 0 = n" do
    throwError "The shared proof checker did not use the general renderer: {latex}"
  fixtures := fixtures.push <| Json.mkObj [("source", toJson "theorem quantified"), ("latex", toJson latex)]
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/latex-tests.json" (Json.arr fixtures).pretty
  logInfo "PASS: LeanTeX expressions, strict rejection, definitions, and general theorem checks"

#test_latex

end LatexTests
