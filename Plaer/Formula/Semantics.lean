module

public import Plaer.Formula.Syntax

@[expose] public section

/-! # The formula language: meaning

`denote` gives every formula its meaning as a Lean value. This file is the table a
reader trusts: each symbol's meaning is one line here. Lean's kernel checks, for every
box, that `denote` of the box's formula is exactly the declaration's statement.

A formula that does not make sense, such as `2 + 2` as a proposition, means nothing
(`none`); its box cannot be checked against any claim. -/

namespace Plaer.Formula

/-- The types a paper declares, by name: `Point`, or a type variable `α`. -/
abbrev TyEnv := List (Name × Type)

/-- The type a name stands for. An unknown name stands for the empty type. -/
def TyEnv.find : TyEnv → Name → Type
  | [], _ => PEmpty
  | (m, T) :: E, n => if m = n then T else TyEnv.find E n

/-- What a type means. -/
def Ty.den (E : TyEnv) : Ty → Type
  | .prop => Prop
  | .nat => Nat
  | .int => Int
  | .named n => E.find n
  | .fn a b => a.den E → b.den E

/-- A value of type `a`, seen at type `b`: itself if `a` and `b` are the same type. -/
def Ty.cast (E : TyEnv) (a b : Ty) (v : a.den E) : Option (b.den E) :=
  if h : a = b then some (h ▸ v) else none

/-- A constant of a paper: its displayed name, its type, and the Lean value it stands for. -/
structure Const (E : TyEnv) where
  name : Name
  ty : Ty
  val : ty.den E

/-- The variables in scope: names and types, innermost first. -/
abbrev Ctx := List (Name × Ty)

/-- Values for the variables in scope. -/
def Ctx.den (E : TyEnv) : Ctx → Type
  | [] => PUnit
  | (_, t) :: Γ => t.den E × Ctx.den E Γ

/-- A name's type and value. Variables hide constants of the same name. -/
def lookup (E : TyEnv) (C : List (Const E)) : (Γ : Ctx) → Ctx.den E Γ → Name → Option ((t : Ty) × t.den E)
  | [], _, n => (C.find? (·.name == n)).map fun c => ⟨c.ty, c.val⟩
  | (m, t) :: Γ, (v, ρ), n => if m = n then some ⟨t, v⟩ else lookup E C Γ ρ n

/-- A name's type. -/
def lookupTy (C : List (Name × Ty)) : Ctx → Name → Option Ty
  | [], n => (C.find? (·.1 == n)).map (·.2)
  | (m, t) :: Γ, n => if m = n then some t else lookupTy C Γ n

def BinOp.isLogic : BinOp → Bool
  | .implies | .iff | .or | .and => true
  | _ => false

def BinOp.isRelation : BinOp → Bool
  | .eq | .ne | .lt | .le | .gt | .ge => true
  | _ => false

/-- The type of a formula, read from the formula alone. A numeral has none: its type
comes from where it stands. -/
def infer (C : List (Name × Ty)) : Ctx → Raw → Option Ty
  | Γ, .ident n => lookupTy C Γ n
  | _, .num _ => none
  | Γ, .app f args => (infer C Γ f).bind (resultTy args.length)
  | Γ, .bin o a b =>
    if o.isLogic || o.isRelation then some .prop else (infer C Γ a).orElse fun _ => infer C Γ b
  | _, .not _ => some .prop
  | Γ, .pow a _ => infer C Γ a
  | _, .floorDiv _ _ => some .nat
  | _, .ann _ t => some t
  | _, .quant .. => some .prop
where
  /-- The result of applying a function of type `t` to `k` arguments. -/
  resultTy : Nat → Ty → Option Ty
    | 0, t => some t
    | k + 1, .fn _ b => resultTy k b
    | _ + 1, _ => none

/-- The logical connectives. -/
def logicDen : BinOp → Prop → Prop → Option Prop
  | .implies, p, q => some (p → q)
  | .iff, p, q => some (p ↔ q)
  | .or, p, q => some (p ∨ q)
  | .and, p, q => some (p ∧ q)
  | _, _, _ => none

/-- Comparisons. `=` and `≠` hold at any type; the orders at `ℕ` and `ℤ`. -/
def relationDen (E : TyEnv) : BinOp → (t : Ty) → t.den E → t.den E → Option Prop
  | .eq, _, x, y => some (x = y)
  | .ne, _, x, y => some (x ≠ y)
  | .lt, .nat, x, y => some (@LT.lt Nat _ x y)
  | .le, .nat, x, y => some (@LE.le Nat _ x y)
  | .gt, .nat, x, y => some (@GT.gt Nat _ x y)
  | .ge, .nat, x, y => some (@GE.ge Nat _ x y)
  | .lt, .int, x, y => some (@LT.lt Int _ x y)
  | .le, .int, x, y => some (@LE.le Int _ x y)
  | .gt, .int, x, y => some (@GT.gt Int _ x y)
  | .ge, .int, x, y => some (@GE.ge Int _ x y)
  | _, _, _, _ => none

/-- Arithmetic. `monus` is subtraction in `ℕ`, which stops at `0`; `sub` is subtraction
in `ℤ`. Each is shown with its own symbol. -/
def arithDen (E : TyEnv) : BinOp → (t : Ty) → t.den E → t.den E → Option (t.den E)
  | .add, .nat, x, y => some (@HAdd.hAdd Nat Nat Nat _ x y)
  | .mul, .nat, x, y => some (@HMul.hMul Nat Nat Nat _ x y)
  | .monus, .nat, x, y => some (@HSub.hSub Nat Nat Nat _ x y)
  | .add, .int, x, y => some (@HAdd.hAdd Int Int Int _ x y)
  | .mul, .int, x, y => some (@HMul.hMul Int Int Int _ x y)
  | .sub, .int, x, y => some (@HSub.hSub Int Int Int _ x y)
  | _, _, _, _ => none

/-- A numeral at a number type. -/
def numDen (E : TyEnv) : (t : Ty) → Nat → Option (t.den E)
  | .nat, k => some (show Nat from k)
  | .int, k => some (Int.ofNat k)
  | _, _ => none

/-- Powers `x ^ k` with `k ∈ ℕ`, at `ℕ` and `ℤ`. -/
def powDen (E : TyEnv) : (t : Ty) → t.den E → Nat → Option (t.den E)
  | .nat, x, k => some (@HPow.hPow Nat Nat Nat _ x k)
  | .int, x, k => some (@HPow.hPow Int Nat Int _ x k)
  | _, _, _ => none

/-- One quantifier over `t`. -/
def quantDen (E : TyEnv) (q : Quant) (t : Ty) (body : t.den E → Prop) : Prop :=
  match q with
  | .all => ∀ v, body v
  | .ex => ∃ v, body v

/-- `∀ x₁, …, xₙ ∈ t, body`: each name in turn, outermost first. `body` gives the
proposition once every name is in scope. -/
def quantFold (E : TyEnv) (q : Quant) (t : Ty) :
    List Name → (Γ : Ctx) → Ctx.den E Γ → ((Γ' : Ctx) → Ctx.den E Γ' → Prop) → Prop
  | [], Γ, ρ, body => body Γ ρ
  | x :: xs, Γ, ρ, body => quantDen E q t fun v => quantFold E q t xs ((x, t) :: Γ) (v, ρ) body

mutual
/-- The meaning of a formula at type `τ`, with `Γ` in scope, valued by `ρ`. -/
def denote (E : TyEnv) (C : List (Const E)) : (Γ : Ctx) → Ctx.den E Γ → Raw → (τ : Ty) → Option (τ.den E)
  | Γ, ρ, .ident n, τ => (lookup E C Γ ρ n).bind fun ⟨t, v⟩ => Ty.cast E t τ v
  | _, _, .num k, τ => numDen E τ k
  | Γ, ρ, .app f args, τ =>
    match infer (C.map fun c => (c.name, c.ty)) Γ f with
    | some t => (denote E C Γ ρ f t).bind fun g => denoteArgs E C Γ ρ t g args τ
    | none => none
  | Γ, ρ, .bin o a b, τ =>
    if o.isLogic then
      match τ with
      | .prop => (denote E C Γ ρ a .prop).bind fun p => (denote E C Γ ρ b .prop).bind fun q => logicDen o p q
      | _ => none
    else if o.isRelation then
      match τ, (infer (C.map fun c => (c.name, c.ty)) Γ a).orElse fun _ => infer (C.map fun c => (c.name, c.ty)) Γ b with
      | .prop, some s => (denote E C Γ ρ a s).bind fun x => (denote E C Γ ρ b s).bind fun y => relationDen E o s x y
      | _, _ => none
    else
      (denote E C Γ ρ a τ).bind fun x => (denote E C Γ ρ b τ).bind fun y => arithDen E o τ x y
  | Γ, ρ, .not a, τ =>
    match τ with
    | .prop => (denote E C Γ ρ a .prop).map Not
    | _ => none
  | Γ, ρ, .pow a b, τ => (denote E C Γ ρ a τ).bind fun x => (denote E C Γ ρ b .nat).bind fun k => powDen E τ x k
  | Γ, ρ, .floorDiv a b, τ =>
    match τ with
    | .nat => (denote E C Γ ρ a .nat).bind fun x => (denote E C Γ ρ b .nat).map fun y => @HDiv.hDiv Nat Nat Nat _ x y
    | _ => none
  | Γ, ρ, .ann e t, τ => (denote E C Γ ρ e t).bind (Ty.cast E t τ)
  | Γ, ρ, .quant q xs t body, τ =>
    -- a body that means nothing makes the proposition `False`
    match τ with
    | .prop => some (quantFold E q t xs Γ ρ fun Γ' ρ' => (denote E C Γ' ρ' body .prop).getD False)
    | _ => none

/-- `f(a₁, …, aₙ)`, where `g : t` is the meaning of `f`. -/
def denoteArgs (E : TyEnv) (C : List (Const E)) (Γ : Ctx) (ρ : Ctx.den E Γ) :
    (t : Ty) → t.den E → Args → (τ : Ty) → Option (τ.den E)
  | .fn s r, g, .one a, τ => (denote E C Γ ρ a s).bind fun x => Ty.cast E r τ (g x)
  | .fn s r, g, .cons a rest, τ => (denote E C Γ ρ a s).bind fun x => denoteArgs E C Γ ρ r (g x) rest τ
  | _, _, _, _ => none

end

end Plaer.Formula
