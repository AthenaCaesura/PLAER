module
public import LeanTeX
public meta import LeanTeX
public import Plaer.Definitions
public import Mathlib.FieldTheory.Finite.Basic

public meta section

/-! PLAER's notation rules on top of the vendored LeanTeX expression printer.
The interval extractor is used only for the illustration; typesetting reads Expr directly.
-/

open Lean Meta LeanTeX

namespace Plaer

latex_pp_const_rule Real := pure <| LatexData.atomString "\\mathbb{R}"
latex_pp_const_rule Rat := pure <| LatexData.atomString "\\mathbb{Q}"
latex_pp_const_rule I := pure <| LatexData.atomString "I"
latex_pp_const_rule True := pure <| LatexData.atomString "\\top"
latex_pp_const_rule False := pure <| LatexData.atomString "\\bot"

def_latex_binop LE.le " \\le " 50 .none
def_latex_binop GE.ge " \\ge " 50 .none
def_latex_binop And " \\land " 35 .right
def_latex_binop Or " \\lor " 30 .right

/-- Compact a pair of comparisons sharing their middle term, without changing their order. -/
latex_pp_app_rules (const := And)
  | _, #[left, right] => do
    let leftArgs := left.getAppArgs
    let rightArgs := right.getAppArgs
    unless leftArgs.size == 4 && rightArgs.size == 4 do failure
    unless (left.getAppFn.isConstOf ``LE.le || left.getAppFn.isConstOf ``LT.lt) &&
        (right.getAppFn.isConstOf ``LE.le || right.getAppFn.isConstOf ``LT.lt) do failure
    unless leftArgs[3]! == rightArgs[2]! do failure
    let a ← latexPP leftArgs[2]!
    let x ← latexPP leftArgs[3]!
    let b ← latexPP rightArgs[3]!
    let lop := if left.getAppFn.isConstOf ``LE.le then " \\le " else " < "
    let rop := if right.getAppFn.isConstOf ``LE.le then " \\le " else " < "
    return (a.protectRight 50 ++ lop ++ x.protect 50 ++ rop ++ b.protectLeft 50)
      |>.resetBP (.NonAssoc 50) (.NonAssoc 50)

latex_pp_app_rules (const := Set)
  | _, #[domain] => do
    let domain ← latexPP domain
    return LatexData.atomString "\\mathcal{P}" ++ domain.parens

latex_pp_app_rules (const := Set.ofPred)
  | _, #[domain, predicate] => do
    let domain ← latexPP domain
    withBindingBodyUnusedName' predicate none fun name body => do
      let condition ← latexPP body
      return LatexData.atomString <|
        "\\left\\{" ++ name.toLatex ++ "\\in" ++ domain.latex.1 ++
        "\\;\\middle|\\; " ++ condition.latex.1 ++ "\\right\\}"

latex_pp_app_rules (const := Nat.Prime)
  | _, #[p] => do
    let p ← latexPP p
    return LatexData.atomString "\\operatorname{Prime}" ++ p.parens

latex_pp_app_rules (const := Nat.cast)
  | _, #[_, _, n] => latexPP n

latex_pp_app_rules (const := Int.ModEq)
  | _, #[modulus, a, b] => do
    let modulus ← latexPP modulus
    let a ← latexPP a
    let b ← latexPP b
    return (a.protectRight 50 ++ " \\equiv " ++ b.protectLeft 50 ++
      " \\pmod{" ++ modulus.latex.1 ++ "}").resetBP (.NonAssoc 50) (.NonAssoc 50)

/-- The same strict printer is used for saved statements and live verification. -/
meta def expressionLatex (expression : Expr) : MetaM String := do
  let result ← run_latexPP expression { strict := true }
  let normalized := " ".intercalate <| result.split Char.isWhitespace |>.toList |>.map (·.toString) |>.filter (!·.isEmpty)
  if normalized.length > 180 then
    let rows := normalized.split " \\implies " |>.toList |>.map (·.toString)
    return "\\begin{gathered}" ++ " \\\\ \\implies ".intercalate rows ++ "\\end{gathered}"
  return normalized

/-- Typeset the declaration's actual value, rather than rebuilding it from plot metadata. -/
meta def definitionLatex (name : Name) : MetaM String := do
  let info ← getConstInfoDefn name
  let body ← expressionLatex info.value
  return name.getString!.toLatex ++ " \\coloneqq " ++ body

end Plaer
