module

public import Lean
public import Plaer.Formula.Semantics
public import Plaer.Formula.Latex
public meta import Plaer.Formula.Semantics
public meta import Plaer.Formula.Latex

public meta section

/-! # From a declaration to a checked formula

`Reflect` reads a Lean statement as a formula of the language. It is not trusted:
whatever formula it produces, a box shows it only after Lean's kernel has checked that
the formula's meaning (`denote`) is exactly the statement. A statement outside the
language has no formula, and its box shows no LaTeX. -/

open Lean Meta

namespace Plaer.Formula

/-- What a formula refers to besides its bound variables. -/
structure Scope where
  /-- Bound variables in scope, with their displayed names. -/
  vars : Array (FVarId × Name) := #[]
  /-- The paper's constants used: Lean name, displayed name, type. -/
  consts : Array (Lean.Name × Name × Ty) := #[]
  /-- Named types used: displayed name and the Lean type. -/
  types : Array (Name × Expr) := #[]

abbrev ReflectM := StateT Scope MetaM

def nameOf (s : String) : Name := s.toList

/-- A displayed name the language can show, or a failure. -/
def displayName (s : String) : ReflectM Name := do
  let n := nameOf s
  unless Name.valid n do throwError "The name {s} cannot be shown"
  return n

/-- A displayed name, outside a formula. -/
def displayNameM (s : String) : MetaM Name := do
  let n := nameOf s
  unless Name.valid n do throwError "The name {s} cannot be shown"
  return n

/-- Whether a constant was declared by the paper itself, rather than imported. -/
def isPaperConst (c : Lean.Name) : MetaM Bool := return (← findModuleOf? c).isNone

/-- A Lean type as a type of the language. -/
partial def reflectTy (e : Expr) : ReflectM Ty := do
  let e ← instantiateMVars e
  if e.isProp then return .prop
  if e.isConstOf ``Nat then return .nat
  if e.isConstOf ``Int then return .int
  if e.isArrow then
    return .fn (← reflectTy e.bindingDomain!) (← reflectTy e.bindingBody!)
  match e with
  | .fvar id =>
    let decl ← id.getDecl
    unless (← whnf decl.type).isType do throwError "{e} is not a type"
    let n ← displayName decl.userName.toString
    modify fun s => if s.types.any (·.1 == n) then s else { s with types := s.types.push (n, e) }
    return .named n
  | .const c [] =>
    unless ← isPaperConst c do throwError "No notation for the type {c}"
    let n ← displayName c.getString!
    modify fun s => if s.types.any (·.1 == n) then s else { s with types := s.types.push (n, e) }
    return .named n
  | _ => throwError "No notation for the type {e}"

/-- The number type an arithmetic operation is at, from its type argument. -/
def numberTy (α : Expr) : ReflectM Ty := do
  match ← reflectTy α with
  | .nat => return .nat
  | .int => return .int
  | _ => throwError "No notation for arithmetic in {α}"

/-- A binary operation by its Lean function and number of arguments. -/
def binOpOf? (fn : Lean.Name) (nargs : Nat) : Option BinOp :=
  match fn, nargs with
  | ``Iff, 2 => some .iff
  | ``Or, 2 => some .or
  | ``And, 2 => some .and
  | ``Eq, 3 => some .eq
  | ``Ne, 3 => some .ne
  | ``LT.lt, 4 => some .lt
  | ``LE.le, 4 => some .le
  | ``GT.gt, 4 => some .gt
  | ``GE.ge, 4 => some .ge
  | ``HAdd.hAdd, 6 => some .add
  | ``HMul.hMul, 6 => some .mul
  | ``HSub.hSub, 6 => some .sub
  | _, _ => none

/-- Whether the formula determines `r`'s type, as `infer` does: a numeral alone does not. -/
def selfTyped : Raw → Bool
  | .num _ => false
  | .bin o a b => o.isLogic || o.isRelation || selfTyped a || selfTyped b
  | .pow a _ => selfTyped a
  | _ => true

mutual
/-- A Lean expression as a formula. -/
partial def reflect (e : Expr) : ReflectM Raw := do
  let e ← instantiateMVars e
  match e with
  | .mdata _ e => reflect e
  | .fvar id =>
    let some (_, n) := (← get).vars.find? (·.1 == id) | throwError "Unknown variable {e}"
    return .ident n
  | .lit (.natVal k) => return .num k
  | .forallE .. => reflectForall e
  | _ =>
  let fn := e.getAppFn
  let args := e.getAppArgs
  match fn with
  | .const c _ =>
    if c == ``OfNat.ofNat && args.size == 3 then
      let _ ← numberTy args[0]!
      let some k := args[1]!.rawNatLit? | throwError "Not a numeral: {e}"
      return .num k
    if c == ``Not && args.size == 1 then return .not (← reflect args[0]!)
    if c == ``Exists && args.size == 2 then return ← reflectExists args[0]! args[1]!
    if c == ``HPow.hPow && args.size == 6 then
      let _ ← numberTy args[0]!
      unless (← reflectTy args[1]!) == .nat do throwError "No notation for powers with exponent in {args[1]!}"
      return .pow (← reflect args[4]!) (← reflect args[5]!)
    if c == ``HDiv.hDiv && args.size == 6 then
      unless (← numberTy args[0]!) == .nat do throwError "No notation for division in {args[0]!}"
      return .floorDiv (← reflect args[4]!) (← reflect args[5]!)
    if let some o := binOpOf? c args.size then
      -- the type argument decides which operation it is
      let o ← match o with
        | .sub => do
          match ← numberTy args[0]! with
          | .nat => pure BinOp.monus
          | _ => pure BinOp.sub
        | .add | .mul => do let _ ← numberTy args[0]!; pure o
        | .lt | .le | .gt | .ge => do let _ ← numberTy args[0]!; pure o
        | _ => pure o
      let a ← reflect args[args.size - 2]!
      let b ← reflect args[args.size - 1]!
      -- a comparison of numerals alone, `2 = 2`, says at which type: `(2 : ℕ) = 2`
      if o.isRelation && !selfTyped a && !selfTyped b then
        return .bin o (.ann a (← reflectTy args[0]!)) b
      return .bin o a b
    unless ← isPaperConst c do throwError "No notation for {c}"
    let n ← displayName c.getString!
    let info ← getConstInfo c
    unless info.levelParams.isEmpty do throwError "{c} has universe parameters"
    let t ← reflectTy info.type
    modify fun s => if s.consts.any (·.1 == c) then s else { s with consts := s.consts.push (c, n, t) }
    reflectCall (.ident n) args
  | .fvar _ => reflectCall (← reflect fn) args
  | _ => throwError "No notation for {e}"

/-- `f(a, b)`. Every argument must be explicit: the language has no hidden arguments. -/
partial def reflectCall (f : Raw) (args : Array Expr) : ReflectM Raw := do
  if args.isEmpty then return f
  let rs ← args.mapM reflect
  let mut acc := Args.one rs.back!
  for r in rs.pop.reverse do
    acc := .cons r acc
  return .app f acc

/-- `∀`: a quantifier over a type, or an implication. Consecutive variables over the
same type share one quantifier, `∀ a, b ∈ ℕ`. -/
partial def reflectForall (e : Expr) : ReflectM Raw := do
  if e.isArrow && (← isProp e.bindingDomain!) then
    return .bin .implies (← reflect e.bindingDomain!) (← reflect e.bindingBody!)
  unless e.binderInfo == .default do throwError "No notation for an implicit or instance argument"
  let t ← reflectTy e.bindingDomain!
  if t == .prop then throwError "No notation for a quantifier over propositions"
  let domain := e.bindingDomain!
  withLocalDecl e.bindingName! .default domain fun x => do
    let n ← displayName e.bindingName!.toString
    modify fun s => { s with vars := s.vars.push (x.fvarId!, n) }
    let body ← reflect (e.bindingBody!.instantiate1 x)
    match body with
    | .quant .all xs t' b => if t' == t then return .quant .all (n :: xs) t b else return .quant .all [n] t body
    | _ => return .quant .all [n] t body

/-- `∃ x ∈ T, P`. -/
partial def reflectExists (α p : Expr) : ReflectM Raw := do
  let t ← reflectTy α
  let .lam name _ body _ := p | throwError "No notation for {p}"
  withLocalDecl name .default α fun x => do
    let n ← displayName name.toString
    modify fun s => { s with vars := s.vars.push (x.fvarId!, n) }
    let b ← reflect (body.instantiate1 x)
    match b with
    | .quant .ex xs t' b' => if t' == t then return .quant .ex (n :: xs) t b' else return .quant .ex [n] t b
    | _ => return .quant .ex [n] t b
end

/-! ## Formulas as Lean expressions, to state the check -/

def nameExpr (n : Name) : Expr := toExpr n

partial def tyExpr : Ty → Expr
  | .prop => mkConst ``Ty.prop
  | .nat => mkConst ``Ty.nat
  | .int => mkConst ``Ty.int
  | .named n => mkApp (mkConst ``Ty.named) (nameExpr n)
  | .fn a b => mkApp2 (mkConst ``Ty.fn) (tyExpr a) (tyExpr b)

def binOpExpr (o : BinOp) : Expr :=
  mkConst <| match o with
  | .implies => ``BinOp.implies | .iff => ``BinOp.iff | .or => ``BinOp.or | .and => ``BinOp.and
  | .eq => ``BinOp.eq | .ne => ``BinOp.ne | .lt => ``BinOp.lt | .le => ``BinOp.le
  | .gt => ``BinOp.gt | .ge => ``BinOp.ge | .add => ``BinOp.add | .sub => ``BinOp.sub
  | .monus => ``BinOp.monus | .mul => ``BinOp.mul

mutual
partial def rawExpr : Raw → Expr
  | .ident n => mkApp (mkConst ``Raw.ident) (nameExpr n)
  | .num k => mkApp (mkConst ``Raw.num) (mkRawNatLit k)
  | .app f args => mkApp2 (mkConst ``Raw.app) (rawExpr f) (argsExpr args)
  | .bin o a b => mkApp3 (mkConst ``Raw.bin) (binOpExpr o) (rawExpr a) (rawExpr b)
  | .not a => mkApp (mkConst ``Raw.not) (rawExpr a)
  | .pow a b => mkApp2 (mkConst ``Raw.pow) (rawExpr a) (rawExpr b)
  | .floorDiv a b => mkApp2 (mkConst ``Raw.floorDiv) (rawExpr a) (rawExpr b)
  | .ann e t => mkApp2 (mkConst ``Raw.ann) (rawExpr e) (tyExpr t)
  | .quant q xs t body =>
    mkApp4 (mkConst ``Raw.quant) (mkConst (match q with | .all => ``Quant.all | .ex => ``Quant.ex))
      (toExpr xs) (tyExpr t) (rawExpr body)

partial def argsExpr : Args → Expr
  | .one a => mkApp (mkConst ``Args.one) (rawExpr a)
  | .cons a rest => mkApp2 (mkConst ``Args.cons) (rawExpr a) (argsExpr rest)
end

/-- The named types, as a `TyEnv`. -/
def tyEnvExpr (types : Array (Name × Expr)) : Expr :=
  let pairTy := mkApp2 (mkConst ``Prod [0, 1]) (mkApp (mkConst ``List [0]) (mkConst ``Char)) (mkSort 1)
  types.foldr (init := mkApp (mkConst ``List.nil [1]) pairTy) fun (n, t) acc =>
    mkApp3 (mkConst ``List.cons [1]) pairTy
      (mkApp4 (mkConst ``Prod.mk [0, 1]) (mkApp (mkConst ``List [0]) (mkConst ``Char)) (mkSort 1) (nameExpr n) t) acc

/-- The constants, as a `List (Const E)`. -/
def constEnvExpr (E : Expr) (consts : Array (Lean.Name × Name × Ty)) : Expr :=
  let constTy := mkApp (mkConst ``Const) E
  consts.foldr (init := mkApp (mkConst ``List.nil [0]) constTy) fun (c, n, t) acc =>
    mkApp3 (mkConst ``List.cons [0]) constTy (mkApp4 (mkConst ``Const.mk) E (nameExpr n) (tyExpr t) (mkConst c)) acc

/-! ## The kernel check

Every check states an equation between the meaning of what is shown and the
declaration, closed over the variables in scope, and adds it as a theorem whose proof
is `rfl`. Lean's kernel accepts it only if the two sides are the same. -/

def nameTyExpr : Expr := mkApp2 (mkConst ``Prod [0, 0]) (mkApp (mkConst ``List [0]) (mkConst ``Char)) (mkConst ``Ty)

/-- `Γ`, innermost first, as an expression. -/
def ctxExpr (Γ : List (Name × Ty)) : Expr :=
  Γ.foldr (init := mkApp (mkConst ``List.nil [0]) nameTyExpr) fun (n, t) acc =>
    mkApp3 (mkConst ``List.cons [0]) nameTyExpr
      (mkApp4 (mkConst ``Prod.mk [0, 0]) (mkApp (mkConst ``List [0]) (mkConst ``Char)) (mkConst ``Ty) (nameExpr n) (tyExpr t)) acc

/-- Values for `Γ`: `(v₁, (v₂, …, ()))`. -/
def valsExpr (E : Expr) : List (Name × Ty × Expr) → Expr
  | [] => mkConst ``PUnit.unit [1]
  | (_, t, v) :: rest =>
    let restΓ := ctxExpr (rest.map fun (n, t, _) => (n, t))
    mkApp4 (mkConst ``Prod.mk [0, 0]) (mkApp2 (mkConst ``Ty.den) E (tyExpr t))
      (mkApp2 (mkConst ``Ctx.den) E restΓ) v (valsExpr E rest)

/-- Add `∀ bound, type` as a theorem proved by `rfl`, and discard it. -/
def kernelCheck (bound : Array Expr) (lhs rhs : Expr) : MetaM Unit := do
  let type ← mkForallFVars bound (← mkEq lhs rhs)
  let proof ← mkLambdaFVars bound (← mkEqRefl lhs)
  withoutModifyingEnv do
    addDecl (Declaration.thmDecl { name := `Plaer.Formula.boxCheck, levelParams := [], type, value := proof })

/-- Check `∀ bound, denote E C Γ ρ r τ = some value`. `Γ` lists the variables in
scope, innermost first, with their values. -/
def checkDenote (scope : Scope) (bound : Array Expr) (Γ : List (Name × Ty × Expr)) (r : Raw) (τ : Ty)
    (value : Expr) : MetaM Unit := do
  let E := tyEnvExpr scope.types
  let C := constEnvExpr E scope.consts
  let lhs := mkAppN (mkConst ``denote) #[E, C, ctxExpr (Γ.map fun (n, t, _) => (n, t)), valsExpr E Γ, rawExpr r, tyExpr τ]
  let rhs := mkApp2 (mkConst ``Option.some [0]) (mkApp2 (mkConst ``Ty.den) E (tyExpr τ)) value
  kernelCheck bound lhs rhs

/-- Check `∀ bound, Ty.den E t = type`. -/
def checkTy (scope : Scope) (bound : Array Expr) (t : Ty) (type : Expr) : MetaM Unit := do
  kernelCheck bound (mkApp2 (mkConst ``Ty.den) (tyEnvExpr scope.types) (tyExpr t)) type

/-- LaTeX for tokens. -/
def latexOf (ts : List Tok) : String := String.ofList (print ts)

/-! ## Boxes -/

/-- A statement's checked formula and its LaTeX. -/
def statementFormula (statement : Expr) : MetaM (Raw × String) := do
  let (r, scope) ← (reflect statement).run {}
  checkDenote scope #[] [] r .prop statement
  return (r, latexOf r.toks)

/-- A constant's displayed name. -/
def constName (c : Lean.Name) : MetaM Name := do
  let n := nameOf c.getString!
  unless Name.valid n do throwError "The name {c} cannot be shown"
  return n

/-- The type line, `triangle : ℕ → ℕ`. -/
def signatureLatex (c : Lean.Name) : MetaM String := do
  let info ← getConstInfo c
  let (t, scope) ← (reflectTy info.type).run {}
  checkTy scope #[] t info.type
  return latexOf (.name (← constName c) :: .sym .colon :: t.toks)

/-- Bring the parameters `xs` into scope: types as named types, values as variables.
Returns the variables, innermost first. A type's own parameters (`implicitOk`) may be
implicit in its constructors: the type line names them. -/
def bindParams (xs : Array Expr) (implicitOk := false) : ReflectM (List (Name × Ty × Expr)) := do
  let mut vars := []
  for x in xs do
    let decl ← x.fvarId!.getDecl
    unless implicitOk || decl.binderInfo == .default do throwError "No notation for an implicit or instance argument"
    if (← whnf decl.type).isType then
      let _ ← reflectTy x
    else
      let t ← reflectTy decl.type
      let n ← displayName decl.userName.toString
      modify fun s => { s with vars := s.vars.push (x.fvarId!, n) }
      vars := (n, t, x) :: vars
  return vars

/-- A definition, `triangle(n) ≔ …`: the formula's meaning is checked to be the value. -/
def definitionLatex (c : Lean.Name) : MetaM String := do
  let info ← getConstInfoDefn c
  unless info.levelParams.isEmpty do throwError "{c} has universe parameters"
  lambdaTelescope info.value fun xs body => do
    let ((vars, r, τ), scope) ← (do
        let vars ← bindParams xs
        let r ← reflect body
        let τ ← reflectTy (← inferType body)
        return (vars, r, τ)).run {}
    checkDenote scope xs vars r τ (mkAppN (mkConst c) xs)
    let name := Raw.ident (← constName c)
    -- `f(x₁, …, xₙ)`, the parameters in order
    let names : List Name := vars.reverse.map (·.1)
    let lhs : Raw := match names.reverse with
      | [] => name
      | last :: earlier => .app name (earlier.foldl (fun acc n => Args.cons (.ident n) acc) (Args.one (.ident last)))
    return latexOf lhs.toks ++ " \\coloneqq " ++ latexOf r.toks

/-- A row of a structure or inductive type: a field or constructor, and its type. A
type of propositions is shown as a formula, checked like a statement; any other as a
type. `bound` are the parameters and earlier fields, `vars` those that are variables. -/
def rowLatex (scope : Scope) (bound : Array Expr) (vars : List (Name × Ty × Expr)) (type : Expr) :
    MetaM String := do
  if ← isProp type then
    let (r, scope) ← (reflect type).run scope
    checkDenote scope bound vars r .prop type
    return latexOf r.toks
  else
    let (t, scope) ← (reflectTy type).run scope
    checkTy scope bound t type
    return latexOf t.toks

mutual
/-- Notes on symbols a reader could misread, for each kind used in `r`. -/
partial def notesGo : Raw → Array String → Array String
  | .bin .monus a b, acc => notesGo b (notesGo a (acc.push "$a \\mathbin{\\dot{-}} b$ is subtraction in $\\mathbb{N}$: it is $0$ when $b > a$."))
  | .floorDiv a b, acc => notesGo b (notesGo a (acc.push "$\\left\\lfloor \\frac{a}{b} \\right\\rfloor$ is division in $\\mathbb{N}$, rounded down; dividing by $0$ gives $0$."))
  | .bin _ a b, acc => notesGo b (notesGo a acc)
  | .pow a b, acc => notesGo b (notesGo a acc)
  | .not a, acc => notesGo a acc
  | .ann a _, acc => notesGo a acc
  | .quant _ _ _ a, acc => notesGo a acc
  | .app f args, acc => notesArgs args (notesGo f acc)
  | _, acc => acc
partial def notesArgs : Args → Array String → Array String
  | .one a, acc => notesGo a acc
  | .cons a rest, acc => notesArgs rest (notesGo a acc)
end

def notesOf (r : Raw) : Array String := (notesGo r #[]).toList.eraseDups.toArray

end Plaer.Formula
