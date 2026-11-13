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

/-- On sets, Lean's order is inclusion: `s ≤ t`, which is also how `s ⊆ t` elaborates for
`Set`, is `s ⊆ t`. -/
latex_pp_app_rules (const := LE.le)
  | _, #[type, _, s, t] => do
    unless type.isAppOfArity `Set 1 || type.isAppOfArity `Finset 1 do failure
    let s ← latexPP s
    let t ← latexPP t
    return (s.protectRight 50 ++ " \\subseteq " ++ t.protectLeft 50).resetBP (.NonAssoc 50) (.NonAssoc 50)
latex_pp_app_rules (kind := const.HasSubset.Subset)
  | _, #[_, _, s, t] => do
    let s ← latexPP s
    let t ← latexPP t
    return (s.protectRight 50 ++ " \\subseteq " ++ t.protectLeft 50).resetBP (.NonAssoc 50) (.NonAssoc 50)

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

/-- `{x ∈ α | p x}`: the elements of `α` that satisfy `predicate`. -/
meta def setBuilder (domain predicate : Expr) : LatexPrinterM LatexData := do
  let domain ← latexPP domain
  withBindingBodyUnusedName' predicate none fun name body => do
    let condition ← latexPP body
    return LatexData.atomString <|
      "\\left\\{" ++ name.toLatex ++ "\\in" ++ domain.latex.1 ++
      "\\;\\middle|\\; " ++ condition.latex.1 ++ "\\right\\}"

latex_pp_app_rules (kind := const.Set.ofPred)
  | _, #[domain, predicate] => setBuilder domain predicate

latex_pp_app_rules (kind := const.Nat.Prime)
  | _, #[p] => do
    let p ← latexPP p
    return LatexData.atomString "\\operatorname{Prime}" ++ p.parens

latex_pp_app_rules (kind := const.Int.ModEq)
  | _, #[modulus, a, b] => do
    let modulus ← latexPP modulus
    let a ← latexPP a
    let b ← latexPP b
    return (a.protectRight 50 ++ " \\equiv " ++ b.protectLeft 50 ++
      " \\pmod{" ++ modulus.latex.1 ++ "}").resetBP (.NonAssoc 50) (.NonAssoc 50)

/-- A declared name as a formula writes it: its last component, upright when it is a
word (see `Lean.Name.toLatex`). -/
meta def nameText (name : Name) : String := (Name.mkSimple name.getString!).toLatex

/-- A name the paper itself defines prints as that name, `\operatorname{triangle}`,
so `triangle n` reads `triangle(n)`. The paper's own declarations belong to no
imported module. Every other constant still needs a notation rule. -/
latex_pp_rules (kind := const)
  | .const c _ => do
    if (← findModuleOf? c).isSome then failure
    return LatexData.atomString (nameText c)

/-- A class, such as `Group` or `Fintype`, prints as its own name, so the assumption
`[Group G]` reads `\operatorname{Group}(G)`. This holds for every class: a class is a
named structure, and its name is how a mathematician refers to it. -/
latex_pp_rules (kind := const)
  | .const c _ => do
    unless isClass (← getEnv) c do failure
    return LatexData.atomString (nameText c)

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

/-! ## Lean's encodings, shown as the objects they encode

Lean builds familiar objects out of types and functions. Where an encoding is
exactly a standard object, it prints as that object. -/

/-- `Fin n` is the set `{0, …, n - 1}`. -/
latex_pp_app_rules (const := Fin)
  | _, #[n] => return LatexData.atomString ("\\{0, \\ldots, " ++ (← rangeTop n) ++ "\\}")

/-- A subtype `{x // p x}` is the set `{x ∈ α | p x}`, used as a type. -/
latex_pp_app_rules (const := Subtype)
  | _, #[domain, predicate] => setBuilder domain predicate

/-- A structure's constructor applied to all its fields is a tuple of the fields: `⟨1, 2⟩`
is `(1, 2)`. Proofs are never shown, so fields that are proofs are left out, and a value
with one remaining field, such as `⟨x, h⟩ : {x // p x}`, is just that field. Classes are
excluded: an instance is a structure Lean finds, not a value a claim talks about. -/
latex_pp_rules (kind := app) | e => do
  let .const ctor _ := e.getAppFn | failure
  let env ← getEnv
  let some (.ctorInfo info) := env.find? ctor | failure
  unless isStructure env info.induct && !isClass env info.induct do failure
  let args := e.getAppArgs
  unless args.size == info.numParams + info.numFields do failure
  let mut fields := #[]
  for field in args[info.numParams:] do
    unless ← Meta.isProof field do
      fields := fields.push (← latexPP field)
  match fields with
  | #[] => failure
  | #[field] => return field
  | _ => return (LatexData.intercalate ", " fields).parens

/-- A limit: `Tendsto f l₁ l₂` says `f(x)` tends to the limit point of `l₂` as `x` tends to
that of `l₁`. Only filters that are limit points print: `atTop` is `∞`, `atBot` is `-∞`,
and `𝓝 a` is `a`. Any other filter declines. -/
meta def limitPoint (filter : Expr) : LatexPrinterM String := do
  match filter.getAppFn.constName?, filter.getAppNumArgs with
  | some `Filter.atTop, 2 => return "\\infty"
  | some `Filter.atBot, 2 => return "-\\infty"
  | some `nhds, 3 => return (← latexPP filter.appArg!).latex.1
  | _, _ => failure

latex_pp_app_rules (kind := const.Filter.Tendsto)
  | _, #[_, _, f, source, target] => do
    let source ← limitPoint source
    let target ← limitPoint target
    withBindingBodyUnusedName' f `x fun name body => do
      let body ← latexPP body
      return (LatexData.atomString s!"\\lim_\{{name.toLatex} \\to {source}} " ++ body.protect 65 ++
        " = " ++ target).resetBP (.NonAssoc 50) (.NonAssoc 50)

/-- `∀ᶠ x in l, p x`: `p(x)` holds from some point on (`atTop`), or near a point (`𝓝 a`). -/
latex_pp_app_rules (kind := const.Filter.Eventually)
  | _, #[_, p, filter] => do
    let range ← match filter.getAppFn.constName?, filter.getAppNumArgs with
      | some `Filter.atTop, 2 => pure fun x => s!"\\text\{for all sufficiently large } {x}"
      | some `Filter.atBot, 2 => pure fun x => s!"\\text\{for all sufficiently small } {x}"
      | some `nhds, 3 =>
        let a := (← latexPP filter.appArg!).latex.1
        pure fun x => s!"\\text\{for all } {x} \\text\{ sufficiently close to } {a}"
      | _, _ => failure
    withBindingBodyUnusedName' p `x fun name body => do
      let body ← latexPP body
      return (body.protect 35 ++ ",\\ " ++ range name.toLatex).resetBP (.NonAssoc 30) (.NonAssoc 30)

/-- The number of elements of a finite type, `|α|`. -/
latex_pp_app_rules (kind := const.Fintype.card)
  | _, #[α, _] => return LatexData.atomString ("\\left|" ++ (← latexPP α).latex.1 ++ "\\right|")

/-- `ZMod n`, the integers modulo `n`. -/
latex_pp_app_rules (kind := const.ZMod)
  | _, #[n] => do
    let n ← latexPP n
    return LatexData.atomString ("\\mathbb{Z}/" ++ (n.protect 1024).latex.1 ++ "\\mathbb{Z}")

/-! ## An operation that means something unusual looks unusual

Where Lean's operation differs from the textbook one for ordinary inputs, it never
prints with the textbook symbol. `notationNotes` explains each symbol on the box. -/

/-- The type of an arithmetic operation's operands, when it is `ℕ` or `ℤ`. -/
def integerType? (type : Expr) : Option Name :=
  if type.isConstOf ``Nat then some ``Nat else if type.isConstOf ``Int then some ``Int else none

/-- Subtraction on `ℕ` stops at `0`: `n ∸ m`. -/
latex_pp_app_rules (const := HSub.hSub)
  | _, #[type, _, _, _, a, b] => do
    unless integerType? type == some ``Nat do failure
    let a ← latexPP a
    let b ← latexPP b
    return a.protectRight 65 ++ LatexData.leftAssocOp " \\mathbin{\\dot{-}} " 65 ++ b.protectLeft 65

/-- Division on `ℕ` rounds down, `⌊a / b⌋`; on `ℤ` it is Euclidean, `a div b`. -/
latex_pp_app_rules (const := HDiv.hDiv)
  | _, #[type, _, _, _, a, b] => do
    match integerType? type with
    | some ``Nat =>
      let a ← withExtraSmallness 1 <| latexPP a
      let b ← withExtraSmallness 1 <| latexPP b
      return LatexData.atomString ("\\left\\lfloor " ++ (LatexData.frac a b).latex.1 ++ " \\right\\rfloor")
    | some ``Int =>
      let a ← latexPP a
      let b ← latexPP b
      return a.protectRight 70 ++ LatexData.leftAssocOp " \\mathbin{\\mathrm{div}} " 70 ++ b.protectLeft 70
    | _ => failure

/-- The remainder on `ℕ` and `ℤ`, `a mod b`. -/
latex_pp_app_rules (const := HMod.hMod)
  | _, #[type, _, _, _, a, b] => do
    unless (integerType? type).isSome do failure
    let a ← latexPP a
    let b ← latexPP b
    return a.protectRight 70 ++ LatexData.leftAssocOp " \\bmod " 70 ++ b.protectLeft 70

/-- An inverse, `x⁻¹`. -/
latex_pp_app_rules (const := Inv.inv)
  | _, #[_, _, x] => return (← latexPP x).sup (LatexData.atomString "-1")

/-- Notes for the symbols above that a reader could misread, one per kind of operation
in `e`. They are about what Lean computes, so they hold for every expression. -/
meta def notationNotes (e : Expr) : Array String := Id.run do
  -- Only full applications: `HDiv.hDiv α β γ inst a b`, `Inv.inv α inst x`
  let found (head : Name) (test : Expr → Bool) : Bool :=
    (e.find? fun sub => sub.isAppOfArity head (if head == ``Inv.inv then 3 else 6) && test sub).isSome
  let typeIs (name : Name) (sub : Expr) := integerType? sub.getAppArgs[0]! == some name
  let field (sub : Expr) := (integerType? sub.getAppArgs[0]!).isNone
  let mut notes := #[]
  if found ``HSub.hSub (typeIs ``Nat) then
    notes := notes.push "$a \\mathbin{\\dot{-}} b$ is subtraction in $\\mathbb{N}$: it is $0$ when $b > a$."
  if found ``HDiv.hDiv (typeIs ``Nat) then
    notes := notes.push "$\\lfloor a / b \\rfloor$ is division in $\\mathbb{N}$, rounded down; dividing by $0$ gives $0$."
  if found ``HDiv.hDiv (typeIs ``Int) then
    notes := notes.push "$a \\mathbin{\\mathrm{div}} b$ is division in $\\mathbb{Z}$ that leaves a remainder $a \\bmod b \\ge 0$; dividing by $0$ gives $0$."
  if found ``HDiv.hDiv field || found ``Inv.inv (fun _ => true) then
    notes := notes.push "As in Lean, $x / 0 = 0$ and $0^{-1} = 0$."
  return notes

/-! ## A conversion shows only when it can change a value

`ℕ ⊆ ℤ ⊆ ℚ ⊆ ℝ`: a number placed in a larger number system is the same number, and
prints as itself. A conversion is invisible exactly when it is injective, which for the
casts from `ℕ`, `ℤ` and `ℚ` is when the target has characteristic zero (`CharZero`).
Any other conversion, such as `ℤ → ℤ/nℤ`, prints as `[a]_T`, `a` as an element of `T`. -/

/-- Whether the casts into `target` are injective: whether `CharZero target` holds. -/
meta def castIsInjective (target : Expr) : MetaM Bool := do
  try
    -- Leave the ring structure open: `mkAppM` would fix one that need not be the instance's.
    let charZero ← mkAppOptM `CharZero #[target, none]
    return (← synthInstance? charZero).isSome
  catch _ => return false

meta def castLatex (target value : Expr) : LatexPrinterM LatexData := do
  let value ← latexPP value
  if ← castIsInjective target then return value
  let target ← withExtraSmallness 2 <| latexPP target
  return LatexData.atomString ("\\left[" ++ value.latex.1 ++ "\\right]_{" ++ target.latex.1 ++ "}")

latex_pp_app_rules (const := Nat.cast)
  | _, #[target, _, n] => castLatex target n
latex_pp_app_rules (const := Int.cast)
  | _, #[target, _, n] => castLatex target n
latex_pp_app_rules (kind := const.Rat.cast)
  | _, #[target, _, n] => castLatex target n

/-- A structure whose other fields are all proofs, such as `{x // p x}` or `Fin n`, is its
one data field with a guarantee about it. Taking that field out, `↑x`, can never make two
different values equal, so it prints as nothing: `↑x` is `x`. -/
latex_pp_rules (kind := app) | e => do
  let .const projection _ := e.getAppFn | failure
  let some info ← getProjectionFnInfo? projection | failure
  if info.fromClass then failure
  unless e.getAppNumArgs == info.numParams + 1 do failure
  let ctor ← getConstInfoCtor info.ctorName
  let onlyData ← forallTelescope ctor.type fun binders _ => do
    let fields := binders[info.numParams:].toArray
    let mut others := true
    for field in fields, index in [0:fields.size] do
      if index != info.i then
        others := others && (← Meta.isProp (← Meta.inferType field))
    return others
  unless onlyData do failure
  latexPP e.appArg!

/-- Rounding to an integer: `⌊x⌋` and `⌈x⌉`, into `ℤ` or `ℕ`. -/
latex_pp_app_rules (kind := const.Int.floor)
  | _, #[_, _, _, _, x] => return LatexData.atomString ("\\lfloor " ++ (← latexPP x).latex.1 ++ " \\rfloor")
latex_pp_app_rules (kind := const.Int.ceil)
  | _, #[_, _, _, _, x] => return LatexData.atomString ("\\lceil " ++ (← latexPP x).latex.1 ++ " \\rceil")
latex_pp_app_rules (kind := const.Nat.floor)
  | _, #[_, _, _, _, x] => return LatexData.atomString ("\\lfloor " ++ (← latexPP x).latex.1 ++ " \\rfloor")
latex_pp_app_rules (kind := const.Nat.ceil)
  | _, #[_, _, _, _, x] => return LatexData.atomString ("\\lceil " ++ (← latexPP x).latex.1 ++ " \\rceil")

/-- The notes a box shows under an expression: `notationNotes`, and one for a
conversion that can change a value. -/
meta def boxNotes (e : Expr) : MetaM (Array String) := do
  let mut notes := notationNotes e
  let mut lossy := false
  for head in [``Nat.cast, ``Int.cast, `Rat.cast] do
    if let some cast := e.find? (fun sub => sub.isAppOfArity head 3) then
      unless ← castIsInjective cast.getAppArgs[0]! do lossy := true
  if lossy then
    notes := notes.push "$[a]_T$ is $a$ as an element of $T$, where different numbers can become equal."
  return notes

/-- The same strict printer is used for saved statements and live verification. -/
meta def expressionLatex (expression : Expr) : MetaM String := do
  let result ← run_latexPP expression { strict := true, collectHypotheses := true, mathFunctions := true, elementBinders := true,
                                         familySubscripts := false }
  let normalized := " ".intercalate <| result.split Char.isWhitespace |>.toList |>.map (·.toString) |>.filter (!·.isEmpty)
  if normalized.length > 180 then
    let rows := normalized.split " \\implies " |>.toList |>.map (·.toString)
    return "\\begin{gathered}" ++ " \\\\ \\implies ".intercalate rows ++ "\\end{gathered}"
  return normalized

/-- A declared name as formulas write it: a paper's own names print upright, as
themselves. Any other name falls back to its last component. -/
meta def nameLatex (name : Name) : MetaM String := do
  let info ← getConstInfo name
  try expressionLatex (.const name (info.levelParams.map .param))
  catch _ => return nameText name

/-- Typeset the declaration's actual value, rather than rebuilding it from plot metadata. -/
meta def definitionLatex (name : Name) : MetaM String := do
  let info ← getConstInfoDefn name
  -- A function reads the usual way, `triangle(n) ≔ …`, with its arguments named as in
  -- its definition. The type line above it gives the domain and range.
  let applied ← try
      lambdaTelescope info.value fun xs body => do
        if xs.isEmpty then throwError "not a function"
        let lhs ← expressionLatex (mkAppN (.const name (info.levelParams.map .param)) xs)
        return some (lhs ++ " \\coloneqq " ++ (← expressionLatex body))
    catch _ => pure none
  if let some latex := applied then return latex
  return (← nameLatex name) ++ " \\coloneqq " ++ (← expressionLatex info.value)

end Plaer
