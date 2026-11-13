module

public import Lean
public import Plaer.Latex.Dictionary
public meta import Lean
public meta import Plaer.Latex.Dictionary

public meta section

/-! # From a declaration to LaTeX, and back

`toLatex` writes a statement in the LaTeX of the dictionary. It is not trusted:
`checkLatex` has Lean read the LaTeX back, through the same dictionary, and the box
shows the LaTeX only if what Lean reads is exactly the statement. -/

open Lean Meta Elab Term

namespace Plaer.Latex

/-- LaTeX and the precedence of its outermost form. -/
abbrev Out := String × Nat

def maxPrec : Nat := 1024

def greek : List (String × String) :=
  [("α", "\\alpha"), ("β", "\\beta"), ("γ", "\\gamma")]

/-- A name as LaTeX: one letter as itself, a word upright, with `_` written `\_`. -/
def nameLatex (n : Name) : MetaM String := do
  let s := n.eraseMacroScopes.getString!
  if let some (_, g) := greek.find? (·.1 == s) then return g
  if s.length == 1 && s.all Char.isAlpha then return s
  unless s.all fun c => c.isAlphanum || c == '_' do throwError "The name {s} has no LaTeX"
  return "\\operatorname{" ++ s.replace "_" "\\_" ++ "}"

/-- A type as LaTeX. -/
partial def tyLatex (t : Expr) : MetaM Out := do
  let t ← instantiateMVars t
  if t.isProp then return ("\\mathbf{Prop}", maxPrec)
  if t.isConstOf ``Nat then return ("\\mathbb{N}", maxPrec)
  if t.isConstOf ``Int then return ("\\mathbb{Z}", maxPrec)
  if t.isConstOf `Real then return ("\\mathbb{R}", maxPrec)
  if t.isArrow then
    -- `α → β → γ` takes two inputs: `(α, β) → γ`
    let mut inputs := #[t.bindingDomain!]
    let mut out := t.bindingBody!
    while out.isArrow && !(← isProp out) do
      inputs := inputs.push out.bindingDomain!
      out := out.bindingBody!
    let (o, _) ← tyLatex out
    if inputs.size == 1 then
      let (i, p) ← tyLatex inputs[0]!
      let i := if p ≤ 25 then "(" ++ i ++ ")" else i
      return (i ++ " \\to " ++ o, 25)
    let is ← inputs.mapM fun i => return (← tyLatex i).1
    return ("(" ++ ", ".intercalate is.toList ++ ") \\to " ++ o, 25)
  match t with
  | .const c _ =>
    unless (← findModuleOf? c).isNone do throwError "No dictionary entry for the type {c}"
    return (← nameLatex c, maxPrec)
  | .fvar id => return (← nameLatex (← id.getDecl).userName, maxPrec)
  | _ => throwError "No LaTeX for the type {t}"

/-- `x` in brackets when its precedence is below `p`. -/
def atPrec (p : Nat) : Out → String
  | (s, q) => if q < p then "(" ++ s ++ ")" else s

/-- Whether values of `t` are elements, written `x \in T`, rather than functions or
propositions, written `f : T`. -/
def isElementType (t : Expr) : MetaM Bool := do
  return !t.isArrow && !t.isProp && !(← isProp t) && !t.isForall

/-- The outermost operation of `e`: its head constant, or `→` for an implication. Two
expressions written with different operations are shown differently, even when one
unfolds to the other (`a ≠ b` to `a = b → False`). -/
def headOf (e : Expr) : Option Name :=
  if e.isArrow then some `arrow else e.getAppFn.constName?

/-- The outermost operation of an entry's definition. -/
def entryHead (decl : Name) : MetaM (Option Name) := do
  let info ← getConstInfo decl
  let some v := info.value? | return none
  lambdaTelescope v fun _ body => return headOf body

mutual
/-- A statement or term as LaTeX. -/
partial def toLatex (e : Expr) : MetaM Out := do
  let e ← instantiateMVars e
  match e with
  | .mdata _ e => toLatex e
  | .fvar id => return (← nameLatex (← id.getDecl).userName, maxPrec)
  | .lit (.natVal k) => return (toString k, maxPrec)
  | _ =>
  if let some out ← entryLatex? e then return out
  if e.isForall then return ← forallLatex e
  if e.isAppOfArity ``Exists 2 then return ← existsLatex e.appFn!.appArg! e.appArg!
  -- a conversion, such as ℕ into ℤ, is written as Lean writes it: `(p : \mathbb{Z})`
  if let .const c _ := e.getAppFn then
    if let some info ← getCoeFnInfo? c then
      if info.type == .coe && e.getAppNumArgs == info.numArgs then
        let (t, _) ← tyLatex (← inferType e)
        return ("(" ++ (← toLatex e.getAppArgs[info.coercee]!).1 ++ " : " ++ t ++ ")", maxPrec)
  -- `∑ i ∈ Finset.range (n + 1), f`
  if (e.isAppOfArity `Finset.sum 5 || e.isAppOfArity `Finset.prod 5) then
    let args := e.getAppArgs
    let s := args[3]!
    if s.isAppOfArity `Finset.range 1 then
      let top := s.appArg!
      if top.isAppOfArity ``HAdd.hAdd 6 && (top.appArg!.nat? == some 1 || top.appArg!.rawNatLit? == some 1) then
        if let .lam i _ body _ := args[4]! then
          return ← withLocalDecl i .default (← inferType s).appArg! fun x => do
            let op := if e.isAppOfArity `Finset.sum 5 then "\\sum" else "\\prod"
            return (op ++ "_{" ++ (← nameLatex i) ++ "=0}^{" ++ (← toLatex top.appFn!.appArg!).1 ++ "} " ++
              atPrec 67 (← toLatex (body.instantiate1 x)), 67)
  if e.isAppOfArity ``OfNat.ofNat 3 then
    if let some k := e.appFn!.appArg!.rawNatLit? then return (toString k, maxPrec)
  match e.getAppFn with
  | .const c _ =>
    -- only the paper's own names are shown by name; anything else needs an entry
    unless (← findModuleOf? c).isNone do throwError "No dictionary entry for {c}"
    callLatex (← nameLatex c) e
  | .fvar id => callLatex (← nameLatex (← id.getDecl).userName) e
  | _ => throwError "No LaTeX for {e}"

/-- `f(a, b)`: a function applied to its explicit arguments. -/
partial def callLatex (f : String) (e : Expr) : MetaM Out := do
  let args := e.getAppArgs
  if args.isEmpty then return (f, maxPrec)
  let info ← getFunInfoNArgs e.getAppFn args.size
  let mut shown := #[]
  for a in args, i in [0:args.size] do
    let explicit := (info.paramInfo[i]?.map (·.binderInfo.isExplicit)).getD true
    if explicit then shown := shown.push (← toLatex a).1
    -- an implicit argument is determined by the explicit ones; Lean reads it back
  return (f ++ "(" ++ ", ".intercalate shown.toList ++ ")", maxPrec)

/-- The first dictionary entry whose definition is `e`, with its holes filled. -/
partial def entryLatex? (e : Expr) : MetaM (Option Out) := do
  for entry in entries (← getEnv) do
    unless (← entryHead entry.decl) == headOf e do continue
    let info ← getConstInfo entry.decl
    let saved ← saveState
    let lvls ← info.levelParams.mapM fun _ => mkFreshLevelMVar
    let (args, binders, _) ← forallMetaTelescopeReducing (info.type.instantiateLevelParams info.levelParams lvls)
    let lhs := mkAppN (.const entry.decl lvls) args
    let matched ← try withReducible (isDefEq lhs e) catch _ => pure false
    let ok ← if matched then
        -- every instance argument must be found, as when Lean reads the LaTeX back
        args.zip binders |>.allM fun (a, b) => do
          if b.isInstImplicit && !(← a.mvarId!.isAssigned) then
            match ← synthInstance? (← inferType a) with
            | some v => isDefEq a v
            | none => pure false
          else pure true
      else pure false
    if ok then
      let fill ← (args.zip binders).filterMapM fun (a, b) => do
        if b.isExplicit then return some (← instantiateMVars a) else return none
      let names ← forallTelescopeReducing info.type fun xs _ =>
        xs.filterMapM fun x => do
          let d ← x.fvarId!.getDecl
          return if d.binderInfo.isExplicit then some d.userName else none
      let mut out := ""
      for piece in entry.pieces do
        match piece with
        | .text s => out := out ++ s
        | .hole n p =>
          let some i := names.findIdx? (· == n) | throwError "Hole {n} is not an argument"
          out := out ++ atPrec p (← toLatex fill[i]!)
      restoreState saved
      return some (out, entry.prec)
    restoreState saved
  return none

/-- `\forall x, y \in T,\; P`: consecutive variables over one type share a quantifier. -/
partial def forallLatex (e : Expr) : MetaM Out := do
  let t := e.bindingDomain!
  let rec go (e : Expr) (names : Array String) : MetaM Out := do
    withLocalDecl e.bindingName! e.binderInfo e.bindingDomain! fun x => do
      let names := names.push (← nameLatex e.bindingName!)
      let body := e.bindingBody!.instantiate1 x
      if body.isForall && !body.isArrow && body.bindingDomain! == t && body.binderInfo.isExplicit then
        go body names
      else
        let (tl, _) ← tyLatex t
        let sep := if ← isElementType t then " \\in " else " : "
        return ("\\forall " ++ ", ".intercalate names.toList ++ sep ++ tl ++ ",\\; " ++ (← toLatex body).1, 0)
  unless e.binderInfo.isExplicit do throwError "No LaTeX for an implicit or instance argument"
  go e #[]

/-- `\exists x, y \in T,\; P`: consecutive variables over one type share it. -/
partial def existsLatex (t p : Expr) : MetaM Out := do
  let rec go (p : Expr) (names : Array String) : MetaM Out := do
    let .lam n _ body _ := p | throwError "No LaTeX for {p}"
    withLocalDecl n .default t fun x => do
      let names := names.push (← nameLatex n)
      let body := body.instantiate1 x
      if body.isAppOfArity ``Exists 2 && body.appFn!.appArg! == t then
        go body.appArg! names
      else
        let (tl, _) ← tyLatex t
        let sep := if ← isElementType t then " \\in " else " : "
        return ("\\exists " ++ ", ".intercalate names.toList ++ sep ++ tl ++ ",\\; " ++ (← toLatex body).1, 0)
  go p #[]
end

/-! ## Reading the LaTeX back -/

/-- The namespaces of the paper's own names in `e` (those declared by the paper, not
imported), so that `\operatorname{triangle}` reads back as `Basics.triangle`. -/
def namespacesOf (e : Expr) : MetaM (List Name) := do
  let mut found : List Name := []
  for c in e.getUsedConstants do
    if (← findModuleOf? c).isNone then
      let ns := c.getPrefix
      if !ns.isAnonymous && !found.contains ns then found := ns :: found
  return found

/-- What Lean reads from `latex`: `⟪latex⟫` as a term, or `⟪latex⟫ₜ` as a type. -/
def readBack (latex : String) (asType : Bool) (opens : List Name) (expected? : Option Expr) : TermElabM Expr := do
  let source := latex.replace "\\_" "_"
  let cat := if asType then `texTy else `tex
  let stx ← match Parser.runParserCategory (← getEnv) cat source with
    | .ok stx => pure stx
    | .error msg => throwError "Lean cannot read the LaTeX: {msg}"
  let term : Term ← if asType then `(⟪$(⟨stx⟩)⟫ₜ) else `(⟪$(⟨stx⟩)⟫)
  let decls := opens.map fun ns => OpenDecl.simple ns []
  withTheReader Core.Context (fun ctx => { ctx with openDecls := decls ++ ctx.openDecls }) do
    let e ← elabTerm term expected?
    synthesizeSyntheticMVarsNoPostponing
    instantiateMVars e

/-- Check that Lean reads `latex` back as exactly `e`, and that the kernel agrees. -/
def checkLatex (latex : String) (e : Expr) (asType := false) : TermElabM Unit := do
  let expected? ← if asType then pure none else pure (some (← inferType e))
  let back ← readBack latex asType (← namespacesOf e) expected?
  if back.hasMVar then throwError "The LaTeX leaves something undetermined: {back}"
  unless ← withTransparency .instances (isDefEq back e) do
    throwError "Lean reads the LaTeX as {back}, not {e}"
  -- the kernel, not the elaborator, has the last word
  let lctx ← getLCtx
  let fvars := lctx.getFVars
  let type ← mkForallFVars fvars (← mkEq back e)
  let proof ← mkLambdaFVars fvars (← mkEqRefl back)
  withoutModifyingEnv do
    addDecl (Declaration.thmDecl { name := `Plaer.Latex.readBackCheck, levelParams := [], type, value := proof })

/-- A statement's LaTeX, checked. -/
def statementLatex (e : Expr) : TermElabM String := do
  let (latex, _) ← toLatex e
  checkLatex latex e
  return latex

/-- A type's LaTeX, checked. -/
def typeLatex (t : Expr) : TermElabM String := do
  let (latex, _) ← tyLatex t
  checkLatex latex t (asType := true)
  return latex

/-! ## Boxes -/

/-- The type line, `\operatorname{triangle} : \mathbb{N} \to \mathbb{N}`, checked. -/
def signatureLatex (c : Name) : TermElabM String := do
  return (← nameLatex c) ++ " : " ++ (← typeLatex (← getConstInfo c).type)

/-- A definition, `\operatorname{triangle}(n) \coloneqq …`. Both sides are checked: Lean
reads `triangle(n)` back as the definition applied to its parameters, and the right side
as the definition's value. -/
def definitionLatex (c : Name) : TermElabM String := do
  let info ← getConstInfoDefn c
  lambdaTelescope info.value fun xs body => do
    let lhsExpr := mkAppN (.const c (info.levelParams.map .param)) xs
    let lhs ← statementLatex lhsExpr
    return lhs ++ " \\coloneqq " ++ (← statementLatex body)

/-- A row of a structure or inductive type: a proposition as a formula, any other type
as a type. Checked like any formula, with the parameters and earlier fields in scope. -/
def rowLatex (type : Expr) : TermElabM String := do
  if ← isProp type then statementLatex type else typeLatex type

/-- A dictionary entry's LaTeX form, with its holes named by its arguments:
`a \mathbin{\dot{-}} b`. -/
def entryFormLatex (entry : Entry) : MetaM String := do
  let mut out := ""
  for piece in entry.pieces do
    match piece with
    | .text s => out := out ++ s
    | .hole n _ => out := out ++ (← nameLatex n)
  return out

/-- What a dictionary entry means in Lean: its definition's body, as Lean prints it, and
the Lean function it comes down to once the type classes are resolved (`Nat.sub`). -/
def entryMeaning (entry : Entry) : MetaM (String × String × String) := do
  let info ← getConstInfo entry.decl
  let some v := info.value? | throwError "{entry.decl} has no value"
  let type := (← ppExpr info.type).pretty
  lambdaTelescope v fun _ body => do
    let shown := (← ppExpr body).pretty
    -- resolve type classes only: ℕ's `-` is `Nat.sub`; `≠` stays `Ne`
    let mut core := body
    for _ in [0:8] do
      match ← unfoldProjInst? core with
      | some e => core := e.headBeta
      | none => break
    let head := match core.getAppFn with
      | .const n _ => n.toString
      | _ => if core.isArrow then "→ (implication)" else if core.isForall then "∀" else shown
    return (shown, head, type)

end Plaer.Latex
