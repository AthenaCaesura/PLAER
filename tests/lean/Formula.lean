import Plaer.Extract

/-! Representative checks of the formula language: claims that have a formula, with the
exact LaTeX, and claims that have none. Every accepted formula has passed the kernel
check of `Plaer.Formula.Reflect`. -/

open Lean Meta Elab Plaer.Formula

namespace FormulaTests

def triangle (n : Nat) : Nat := n * (n + 1) / 2
def gauss : Prop := ∀ n : Nat, 2 * triangle n = n * (n + 1)
def fermat : Prop := ∀ n a b c : Nat, n > 2 ∧ a > 0 ∧ b > 0 ∧ c > 0 → a ^ n + b ^ n ≠ c ^ n
def exists_sum : Prop := ∀ n : Nat, n > 2 → ∃ p q : Nat, p + q = n
def numerals : Prop := 2 + 2 = 4
def integers : Prop := ∀ a b : Int, a - b + b = a ∧ ¬(a < b ∧ b < a)
def naturals : Prop := ∀ n m : Nat, n - m + m ≥ n ∧ n / 2 ≤ n
def curried : Prop := ∀ f : Nat → Nat → Nat, f 0 1 = f 1 0
-- outside the language: no formula
def succ_pos : Prop := ∀ n : Nat, n.succ > 0
def lambdas : Prop := (fun x : Nat => x + 1) = (fun y => y + 1)

elab "#test_formulas" : command => Command.liftTermElabM do
  let cases : List (Lean.Name × String) := [
    (``gauss, "\\forall n \\in \\mathbb{N} ,\\; 2 \\cdot \\operatorname{triangle} ( n ) = n \\cdot ( n + 1 )"),
    (``fermat, "\\forall n , a , b , c \\in \\mathbb{N} ,\\; n > 2 \\land a > 0 \\land b > 0 \\land c > 0 \\implies a ^{ n } + b ^{ n } \\neq c ^{ n }"),
    (``exists_sum, "\\forall n \\in \\mathbb{N} ,\\; n > 2 \\implies ( \\exists p , q \\in \\mathbb{N} ,\\; p + q = n )"),
    (``numerals, "( 2 + 2 : \\mathbb{N} ) = 4"),
    (``integers, "\\forall a , b \\in \\mathbb{Z} ,\\; a - b + b = a \\land \\neg ( a < b \\land b < a )"),
    (``naturals, "\\forall n , m \\in \\mathbb{N} ,\\; n \\mathbin{\\dot{-}} m + m \\ge n \\land \\left\\lfloor \\frac{ n }{ 2 } \\right\\rfloor \\le n"),
    (``curried, "\\forall f : ( \\mathbb{N} , \\mathbb{N} ) \\to \\mathbb{N} ,\\; f ( 0 , 1 ) = f ( 1 , 0 )")]
  let mut fixtures : Array Json := #[]
  for (name, expected) in cases do
    let (_, latex) ← statementFormula (← getConstInfoDefn name).value
    unless latex == expected do throwError "{name}: expected\n{expected}\ngot\n{latex}"
    fixtures := fixtures.push <| Json.mkObj [("source", toJson name.toString), ("latex", toJson latex)]
  for name in [``succ_pos, ``lambdas] do
    let refused ← try let _ ← statementFormula (← getConstInfoDefn name).value; pure false catch _ => pure true
    unless refused do throwError "{name} has no formula, but one was produced"
  -- A definition: `triangle(n) ≔ …`, checked against its value.
  let definition ← definitionLatex ``triangle
  unless definition == "\\operatorname{triangle} ( n ) \\coloneqq \\left\\lfloor \\frac{ n \\cdot ( n + 1 ) }{ 2 } \\right\\rfloor" do
    throwError "definition triangle: {definition}"
  fixtures := fixtures.push <| Json.mkObj [("source", toJson "definition triangle"), ("latex", toJson definition)]
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/latex-tests.json" (Json.arr fixtures).pretty
  logInfo "PASS: checked formulas, refusals, and a checked definition"

#test_formulas

end FormulaTests
