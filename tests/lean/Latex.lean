import fixtures.Interval
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Data.Nat.Choose.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic

open Lean Meta Elab Term Plaer IntervalFixture

namespace LatexTests

def unmapped (n : Nat) : Nat := n + 7
def twice (n : Nat) : Nat := n + n
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
    ("∃ n : ℕ, 1 < n", "\\exists n : \\mathbb{N},\\ n > 1"),
    ("∀ x : ℝ, 0 ≤ x → x ≤ 1", "\\forall x : \\mathbb{R},\\ x \\ge 0 \\implies x \\le 1"),
    ("(1 : ℕ) < 2", "1 < 2"),
    ("((1 + 2) / 3 : ℝ)", "\\frac{1 + 2}{3}"),
    ("((1 / 2) ^ 3 : ℝ)", "\\left(\\frac{1}{2}\\right)^{3}"),
    ("(1 + (2 + 3) : ℕ)", "1 + (2 + 3)"),
    ("{y : ℝ | -1 < y ∧ y ≤ 2}", "\\left\\{y\\in\\mathbb{R}\\;\\middle|\\; - 1 < y \\le 2\\right\\}"),
    ("{y : ℝ | y = 0 ∨ y = 1}", "\\left\\{y\\in\\mathbb{R}\\;\\middle|\\; y = 0 \\lor y = 1\\right\\}"),
    ("∀ x : ℝ, ∃ x : ℝ, x = x", "\\forall x : \\mathbb{R},\\ \\exists x : \\mathbb{R},\\ x = x"),
    ("∀ s : Set ℝ, s = s", "\\forall s : \\mathcal{P}(\\mathbb{R}),\\ s = s"),
    ("∀ a b : ℕ, ∀ x : ℝ, 0 < a → 0 < b → a + b = b + a", "\\forall a, b : \\mathbb{N},\\ \\forall x : \\mathbb{R},\\ a > 0 \\land b > 0 \\implies a + b = b + a"),
    ("∀ p q : Prop, (p → q) → p → q", "\\forall p, q : \\mathbf{Prop},\\ (p \\implies q) \\land p \\implies q"),
    ("∀ a b : ℕ, a ∣ b → a ≤ b", "\\forall a, b : \\mathbb{N},\\ a \\mid b \\implies a \\le b"),
    ("∀ x : ℝ, |x| ≥ 0", "\\forall x : \\mathbb{R},\\ \\left|x\\right| \\ge 0"),
    ("∀ x : ℝ, x ≥ 0 → Real.sqrt x * Real.sqrt x = x", "\\forall x : \\mathbb{R},\\ x \\ge 0 \\implies \\sqrt{x} \\cdot \\sqrt{x} = x"),
    ("∀ n : ℕ, Nat.factorial (n + 1) = (n + 1) * Nat.factorial n", "\\forall n : \\mathbb{N},\\ (n + 1)! = (n + 1) \\cdot n!"),
    ("∀ n k : ℕ, Nat.choose n k ≤ 2 ^ n", "\\forall n, k : \\mathbb{N},\\ \\binom{n}{k} \\le 2^{n}"),
    ("∀ a b : ℕ, Nat.gcd a b ∣ a", "\\forall a, b : \\mathbb{N},\\ \\gcd(a, b) \\mid a"),
    ("∀ a b : ℕ, Nat.gcd a b * Nat.lcm a b = a * b", "\\forall a, b : \\mathbb{N},\\ \\gcd(a, b) \\cdot \\operatorname{lcm}(a, b) = a \\cdot b"),
    ("∀ a b : ℕ, min a b ≤ max a b", "\\forall a, b : \\mathbb{N},\\ \\min(a, b) \\le \\max(a, b)"),
    ("∀ x : ℝ, Real.log (Real.exp x) = x", "\\forall x : \\mathbb{R},\\ \\log(\\exp(x)) = x"),
    ("∀ x : ℝ, Real.sin x ^ 2 + Real.cos x ^ 2 = 1", "\\forall x : \\mathbb{R},\\ \\sin(x)^{2} + \\cos(x)^{2} = 1"),
    ("Real.pi > 3", "\\pi > 3"),
    ("∀ n : ℕ, ∑ i ∈ Finset.range (n + 1), i = n * (n + 1) / 2", "\\forall n : \\mathbb{N},\\ \\sum_{i = 0}^{n} i = \\frac{n \\cdot (n + 1)}{2}"),
    ("∀ n : ℕ, ∏ i ∈ Finset.range n, (i + 1) = Nat.factorial n", "\\forall n : \\mathbb{N},\\ \\prod_{i = 0}^{n - 1} (i + 1) = n!"),
    ("∀ x : ℕ, x ∈ Finset.range 3 → x < 3", "\\forall x : \\mathbb{N},\\ x \\in \\{0, \\ldots, 2\\} \\implies x < 3"),
    ("∀ f : ℕ → ℝ, f 0 = f 0", "\\forall f : \\mathbb{N} \\to \\mathbb{R},\\ f(0) = f(0)"),
    -- A name defined in this file, not imported, prints by its own name.
    ("LatexTests.unmapped 3 = 10", "\\operatorname{unmapped}(3) = 10")]
  let mut fixtures : Array Json := #[]
  for (source, expected) in cases do
    let latex ← renderTerm source
    unless latex == expected do
      throwError "Rendering {source}: expected {expected}, got {latex}"
    fixtures := fixtures.push <| Json.mkObj [("source", toJson source), ("latex", toJson latex)]
  -- An inner unsupported expression must fail too; no generic fallback may hide it.
  for source in ["Nat.pred 3", "1 + Nat.pred 3",
      "(let x : Nat := 1; x + 2)", "∀ x : ℕ, Nat.pred x = x", "(_ : ℕ)"] do
    let rejected ← try
      let _ ← renderTerm source
      pure false
    catch _ => pure true
    unless rejected do throwError "Strict rendering silently accepted: {source}"
  -- A function the file defines reads `twice(n) ≔ …`.
  let twice ← definitionLatex ``twice
  unless twice == "\\operatorname{twice}(n) \\coloneqq n + n" do throwError "Function definition: {twice}"
  fixtures := fixtures.push <| Json.mkObj [("source", toJson "definition twice"), ("latex", toJson twice)]
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
