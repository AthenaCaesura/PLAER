import Dictionary.Statements

/-! Representative checks of PLAER's LaTeX: each claim is printed through the dictionary
and read back by Lean as exactly the claim; claims outside the dictionary have none. -/

open Lean Meta Elab Plaer.Latex

namespace LatexTests

def triangle (n : ℕ) : ℕ := ∑ i ∈ Finset.range (n + 1), i
def gauss : Prop := ∀ n : ℕ, 2 * triangle n = n * (n + 1)
def fermat : Prop := ∀ n a b c : ℕ, n > 2 ∧ a > 0 ∧ b > 0 ∧ c > 0 → a ^ n + b ^ n ≠ c ^ n
def naturals : Prop := ∀ n m : ℕ, n - m + m ≥ n ∧ n / 2 ≤ n
def integers : Prop := ∀ a b : ℤ, a - b + b = a
def primes : Prop := ∃ p q : ℕ, p.Prime ∧ q.Prime ∧ p + q = 100
-- outside the dictionary: no LaTeX
def pred_claim : Prop := ∀ n : ℕ, Nat.pred (n + 1) = n
def lambdas : Prop := (fun x : ℕ => x + 1) = (fun y => y + 1)

elab "#test_latex" : command => Command.liftTermElabM do
  let cases : List (Lean.Name × String) := [
    (``gauss, "\\forall n \\in \\mathbb{N},\\; 2 \\cdot \\operatorname{triangle}(n) = n \\cdot (n + 1)"),
    (``fermat, "\\forall n, a, b, c \\in \\mathbb{N},\\; n > 2 \\land a > 0 \\land b > 0 \\land c > 0 \\implies a^{n} + b^{n} \\neq c^{n}"),
    (``naturals, "\\forall n, m \\in \\mathbb{N},\\; n \\mathbin{\\dot{-}} m + m \\ge n \\land \\left\\lfloor\\frac{n}{2}\\right\\rfloor \\le n"),
    (``integers, "\\forall a, b \\in \\mathbb{Z},\\; a - b + b = a"),
    (``primes, "\\exists p, q \\in \\mathbb{N},\\; \\operatorname{Prime}(p) \\land \\operatorname{Prime}(q) \\land p + q = 100")]
  let mut fixtures : Array Json := #[]
  for (name, expected) in cases do
    let latex ← statementLatex (← getConstInfoDefn name).value
    unless latex == expected do throwError "{name}: expected\n{expected}\ngot\n{latex}"
    fixtures := fixtures.push <| Json.mkObj [("source", toJson name.toString), ("latex", toJson latex)]
  for name in [``pred_claim, ``lambdas] do
    let refused ← try let _ ← statementLatex (← getConstInfoDefn name).value; pure false catch _ => pure true
    unless refused do throwError "{name} is outside the dictionary, but has LaTeX"
  let definition ← definitionLatex ``triangle
  unless definition == "\\operatorname{triangle}(n) \\coloneqq \\sum_{i=0}^{n} i" do
    throwError "definition triangle: {definition}"
  fixtures := fixtures.push <| Json.mkObj [("source", toJson "definition triangle"), ("latex", toJson definition)]
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/latex-tests.json" (Json.arr fixtures).pretty
  logInfo "PASS: claims read back exactly through the dictionary; others refused"

#test_latex

end LatexTests
