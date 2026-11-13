module
public import LeanTeX
public meta import LeanTeX

public meta section

/-! PLAER's notation rules on top of the vendored LeanTeX expression printer.
Typesetting reads elaborated expressions and has no dependency on example declarations.

This module imports no Mathlib, because every paper imports it and Mathlib
imports are what make a paper slow to compile. Rules for Mathlib constants are
keyed by name (`kind := const.<full name>`), so they apply whenever the paper
itself imports that constant. A misspelled name is not an error, so the LaTeX
tests cover each of these rules.
-/

open Lean Meta LeanTeX

namespace Plaer

latex_pp_rules (kind := const.Real)
  | _ => pure <| LatexData.atomString "\\mathbb{R}"
latex_pp_const_rule Rat := pure <| LatexData.atomString "\\mathbb{Q}"
latex_pp_const_rule True := pure <| LatexData.atomString "\\top"
latex_pp_const_rule False := pure <| LatexData.atomString "\\bot"

def_latex_binop LE.le " \\le " 50 .none
def_latex_binop GE.ge " \\ge " 50 .none
def_latex_binop And " \\land " 35 .right
def_latex_binop Or " \\lor " 30 .right

/-- A plain number such as `2`. -/
def isNumeral (e : Expr) : Bool := e.isAppOfArity ``OfNat.ofNat 3 || e.isRawNatLit

/-- Put the variable first when comparing with a plain number: `2 < n` prints as `n > 2`
and `0 ≤ x` as `x ≥ 0`. Lean stores `n > 2` as `2 < n`, so this is how either was written. -/
meta def flippedComparison (op : String) (small big : Expr) : LatexPrinterM LatexData := do
  unless isNumeral small && !isNumeral big do failure
  let big ← latexPP big
  let small ← latexPP small
  return (big.protectRight 50 ++ op ++ small.protectLeft 50).resetBP (.NonAssoc 50) (.NonAssoc 50)

latex_pp_app_rules (const := LT.lt)
  | _, #[_, _, small, big] => flippedComparison " > " small big
latex_pp_app_rules (const := LE.le)
  | _, #[_, _, small, big] => flippedComparison " \\ge " small big

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

latex_pp_app_rules (kind := const.Set)
  | _, #[domain] => do
    let domain ← latexPP domain
    return LatexData.atomString "\\mathcal{P}" ++ domain.parens

latex_pp_app_rules (kind := const.Set.ofPred)
  | _, #[domain, predicate] => do
    let domain ← latexPP domain
    withBindingBodyUnusedName' predicate none fun name body => do
      let condition ← latexPP body
      return LatexData.atomString <|
        "\\left\\{" ++ name.toLatex ++ "\\in" ++ domain.latex.1 ++
        "\\;\\middle|\\; " ++ condition.latex.1 ++ "\\right\\}"

latex_pp_app_rules (kind := const.Nat.Prime)
  | _, #[p] => do
    let p ← latexPP p
    return LatexData.atomString "\\operatorname{Prime}" ++ p.parens

latex_pp_app_rules (const := Nat.cast)
  | _, #[_, _, n] => latexPP n

latex_pp_app_rules (kind := const.Int.ModEq)
  | _, #[modulus, a, b] => do
    let modulus ← latexPP modulus
    let a ← latexPP a
    let b ← latexPP b
    return (a.protectRight 50 ++ " \\equiv " ++ b.protectLeft 50 ++
      " \\pmod{" ++ modulus.latex.1 ++ "}").resetBP (.NonAssoc 50) (.NonAssoc 50)

/-- A name the paper itself defines prints as that name, `\operatorname{triangle}`,
so `triangle n` reads `triangle(n)`. The paper's own declarations belong to no
imported module. Every other constant still needs a notation rule. -/
latex_pp_rules (kind := const)
  | .const c _ => do
    if (← findModuleOf? c).isSome then failure
    let name := c.getString!.replace "_" "\\_"
    return LatexData.atomString ("\\operatorname{" ++ name ++ "}")

/-! Common Mathlib notation. Each rule checks its argument count and otherwise
declines, so an unexpected form shows "No LaTeX" rather than something wrong. -/

/-- `\name(x)` for a named function of one argument, such as `\exp` or `\sin`. -/
meta def namedFunction (command : String) (args : Array Expr) (arity : Nat) : LatexPrinterM LatexData := do
  unless args.size == arity do failure
  let x ← latexPP args.back!
  -- One atom, so a power reads `\sin(x)^{2}` rather than `(\sin(x))^{2}`.
  return LatexData.atomString (command ++ "(" ++ x.latex.1 ++ ")")

/-- `\name(a, b)` for a named function of two arguments, such as `\gcd`. -/
meta def namedFunction₂ (command : String) (args : Array Expr) (arity : Nat) : LatexPrinterM LatexData := do
  unless args.size == arity do failure
  let a ← latexPP args[arity - 2]!
  let b ← latexPP args[arity - 1]!
  return LatexData.atomString (command ++ "(" ++ a.latex.1 ++ ", " ++ b.latex.1 ++ ")")

latex_pp_app_rules (kind := const.Real.exp) | _, args => namedFunction "\\exp" args 1
latex_pp_app_rules (kind := const.Real.log) | _, args => namedFunction "\\log" args 1
latex_pp_app_rules (kind := const.Real.sin) | _, args => namedFunction "\\sin" args 1
latex_pp_app_rules (kind := const.Real.cos) | _, args => namedFunction "\\cos" args 1
latex_pp_app_rules (kind := const.Nat.gcd) | _, args => namedFunction₂ "\\gcd" args 2
latex_pp_app_rules (kind := const.Nat.lcm) | _, args => namedFunction₂ "\\operatorname{lcm}" args 2
latex_pp_app_rules (kind := const.Min.min) | _, args => namedFunction₂ "\\min" args 4
latex_pp_app_rules (kind := const.Max.max) | _, args => namedFunction₂ "\\max" args 4
latex_pp_rules (kind := const.Real.pi) | _ => pure <| LatexData.atomString "\\pi"

/-- Divisibility, `a ∣ b`. -/
latex_pp_app_rules (kind := const.Dvd.dvd)
  | _, #[_, _, a, b] => do
    let a ← latexPP a
    let b ← latexPP b
    return (a.protectRight 50 ++ " \\mid " ++ b.protectLeft 50).resetBP (.NonAssoc 50) (.NonAssoc 50)

/-- Absolute value, `|x|`. -/
latex_pp_app_rules (kind := const.abs)
  | _, args => do
    unless args.size == 4 do failure
    let x ← latexPP args.back!
    return LatexData.atomString ("\\left|" ++ x.latex.1 ++ "\\right|")

/-- Square root, `√x`. -/
latex_pp_app_rules (kind := const.Real.sqrt)
  | _, #[x] => do
    let x ← latexPP x
    return LatexData.atomString ("\\sqrt{" ++ x.latex.1 ++ "}")

/-- Factorial, `n!`. -/
latex_pp_app_rules (kind := const.Nat.factorial)
  | _, #[n] => do
    let n ← latexPP n
    return (n.protect 1024 ++ "!").resetBP .Infinity .Infinity

/-- Binomial coefficient, `\binom{n}{k}`. -/
latex_pp_app_rules (kind := const.Nat.choose)
  | _, #[n, k] => do
    let n ← latexPP n
    let k ← latexPP k
    return LatexData.atomString ("\\binom{" ++ n.latex.1 ++ "}{" ++ k.latex.1 ++ "}")

/-- The last element of `Finset.range n`: `m` when `n` is `m + 1`, `2` when `n` is `3`,
otherwise `n - 1`. -/
meta def rangeTop (n : Expr) : LatexPrinterM String := do
  if let some k := n.nat? then
    if k > 0 then return toString (k - 1)
  let args := n.getAppArgs
  if n.isAppOfArity ``HAdd.hAdd 6 && isNumeral args[5]! && args[5]!.getAppArgs[1]?.bind (·.rawNatLit?) == some 1 then
    return (← latexPP args[4]!).latex.1
  return (← latexPP n).protectRight 65 |>.latex.1 |> (· ++ " - 1")

/-- `Finset.range n` is `\{0, …, n - 1\}`. -/
latex_pp_app_rules (kind := const.Finset.range)
  | _, #[n] => do
    return LatexData.atomString ("\\{0, \\ldots, " ++ (← rangeTop n) ++ "\\}")

/-- `∑ i ∈ s, f i` and `∏ i ∈ s, f i`; over `Finset.range n`, with limits `0` and `n - 1`. -/
meta def bigOperator (symbol : String) (s f : Expr) : LatexPrinterM LatexData := do
  withBindingBodyUnusedName' f `i fun name body => do
    let i := name.toLatex
    let limits ←
      if s.isAppOfArity `Finset.range 1 then
        pure s!"_\{{i} = 0}^\{{← rangeTop s.appArg!}}"
      else
        pure s!"_\{{i} \\in {(← latexPP s).latex.1}}"
    let body ← latexPP body
    return (LatexData.atomString (symbol ++ limits ++ " ") ++ body.protect 70)
      |>.resetBP (lbp := .Infinity) |>.mergeBP (rbp := .NonAssoc 65)

latex_pp_app_rules (kind := const.Finset.sum)
  | _, #[_, _, _, s, f] => bigOperator "\\sum" s f
latex_pp_app_rules (kind := const.Finset.prod)
  | _, #[_, _, _, s, f] => bigOperator "\\prod" s f

/-- The same strict printer is used for saved statements and live verification. -/
meta def expressionLatex (expression : Expr) : MetaM String := do
  let result ← run_latexPP expression { strict := true, collectHypotheses := true }
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
