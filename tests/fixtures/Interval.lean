module
public import Plaer.Extract
public import Mathlib.Tactic.NormNum
public meta import LeanTeX

public section
open Lean Meta Elab Term Plaer LeanTeX
namespace IntervalFixture

def I : Set ℝ := {x | 0 ≤ x ∧ x ≤ 1}
latex_pp_const_rule I := pure <| LatexData.atomString "I"

/-- The first renderer deliberately accepts only real intervals with integral bounds. -/
structure IntervalShape where
  lower : Int
  upper : Int
  lowerClosed : Bool
  upperClosed : Bool
  deriving Repr, ToJson

meta def integerLiteral (e : Expr) : MetaM Int := do
  if let some (n, _) ← getOfNatValue? e ``Real then
    return Int.ofNat n
  if e.getAppFn.isConstOf ``Neg.neg then
    let args := e.getAppArgs
    if let some (n, _) ← getOfNatValue? args.back! ``Real then
      return -(Int.ofNat n)
  throwError "The first mathematical renderer supports integral bounds; got {e}"

meta def relation (e : Expr) : MetaM (Expr × Expr × Bool) := do
  let args := e.getAppArgs
  if args.size = 4 && (e.getAppFn.isConstOf ``LE.le || e.getAppFn.isConstOf ``LT.lt) then
    return (args[2]!, args[3]!, e.getAppFn.isConstOf ``LE.le)
  throwError "Expected a ≤ or < comparison in the interval definition; got {e}"

/-- Inspect the elaborated value, rather than pattern-matching the source text. -/
meta def extractInterval (name : Name) : MetaM IntervalShape := do
  let info ← getConstInfoDefn name
  unless ← isDefEq info.type (← mkAppM ``Set #[mkConst ``Real]) do
    throwError "Expected a definition of type Set ℝ"
  let value ← whnf info.value
  lambdaTelescope value fun xs body => do
    unless xs.size = 1 && body.getAppFn.isConstOf ``And && body.getAppArgs.size = 2 do
      throwError "Supported form: a real interval with a lower and an upper comparison"
    let x := xs[0]!
    let (lower, lowerVariable, lowerClosed) ← relation body.getAppArgs[0]!
    let (upperVariable, upper, upperClosed) ← relation body.getAppArgs[1]!
    unless lowerVariable == x && upperVariable == x do
      throwError "Both comparisons must use the interval's bound variable"
    let lowerInt ← integerLiteral lower
    let upperInt ← integerLiteral upper
    return { lower := lowerInt, upper := upperInt, lowerClosed, upperClosed }

meta def IntervalShape.containsHundredth (shape : IntervalShape) (n : Int) : Bool :=
  (if shape.lowerClosed then shape.lower * 100 ≤ n else shape.lower * 100 < n) &&
  (if shape.upperClosed then n ≤ shape.upper * 100 else n < shape.upper * 100)

/--
Every slider position receives a proof about membership in the original real set.
Only the Boolean result is shipped to the browser. No browser-side predicate substitutes
for the formal definition.
-/
meta def certifiedSamples (name : Name) (shape : IntervalShape) : TermElabM Json := do
  let mut samples : Array Json := #[]
  for k in List.range 201 do
    let numerator := Int.ofNat k - 50
    let member := shape.containsHundredth numerator
    let nSyntax : Term ← if numerator < 0 then
      `(-($(quote numerator.natAbs) : ℝ))
    else
      `(($(quote numerator.toNat) : ℝ))
    let proposition ← elabType (← `(($nSyntax / (100 : ℝ)) ∈ $(mkIdent name)))
    let expected := if member then proposition else mkApp (mkConst ``Not) proposition
    let simpLemma ← `(Lean.Parser.Tactic.simpLemma| $(mkIdent name):term)
    let proof ← elabTerm (← `(by norm_num [$simpLemma])) (some expected)
    synthesizeSyntheticMVarsNoPostponing
    let proof ← instantiateMVars proof
    unless !proof.hasSorry && !proof.hasMVar do
      throwError "Unfinished membership certificate at {numerator}/100"
    checkWithKernel proof
    samples := samples.push <| Json.mkObj [
      ("numerator", toJson numerator), ("denominator", toJson (100 : Nat)),
      ("member", toJson member)]
  return .arr samples


end IntervalFixture
