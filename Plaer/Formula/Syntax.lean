module

@[expose] public section

/-! # The formula language: syntax

PLAER shows a claim as a formula of this language, never as a print-out of Lean's
expression. A formula's LaTeX (`Plaer.Formula.render`) and its meaning
(`Plaer.Formula.denote`) are both functions of the formula. Lean's kernel checks that
the meaning is the claim, and `Plaer.Formula.parse_render` proves that the LaTeX
determines the formula. A paper is written in the style this language can express.

Names are lists of characters, so that the kernel compares them directly. -/

namespace Plaer.Formula

/-- A displayed name: a variable, a paper's constant, or a type. -/
abbrev Name := List Char

/-- Types. `fn a b` is `a → b`; Lean's `α → β → γ` is `fn α (fn β γ)`, which is shown
`(α, β) → γ`. `named n` is a type the paper declares, or a type variable. -/
inductive Ty where
  | prop
  | nat
  | int
  | named (n : Name)
  | fn (a b : Ty)
  deriving DecidableEq, Repr, Inhabited

/-- Binary operations. Each one has a fixed meaning (`BinOp.denote`) and a fixed symbol. -/
inductive BinOp where
  | implies | iff | or | and
  | eq | ne | lt | le | gt | ge
  | add | sub | monus | mul
  deriving DecidableEq, Repr

inductive Quant where
  | all | ex
  deriving DecidableEq, Repr

mutual
/-- Formulas. `app f args` is `f(a₁, …, aₙ)`. `quant q xs t body` binds the names `xs`, in
order, each ranging over `t`: `∀ a, b ∈ ℕ, body`. `ann e t` is `e` as an element of `t`,
written `(e : t)`, for a value whose type nothing else in the formula determines. -/
inductive Raw where
  | ident (n : Name)
  | num (k : Nat)
  | app (f : Raw) (args : Args)
  | bin (o : BinOp) (a b : Raw)
  | not (a : Raw)
  | pow (a b : Raw)
  | floorDiv (a b : Raw)
  | ann (e : Raw) (t : Ty)
  | quant (q : Quant) (xs : List Name) (t : Ty) (body : Raw)

/-- The arguments of an application: at least one. -/
inductive Args where
  | one (a : Raw)
  | cons (a : Raw) (rest : Args)
end

instance : Inhabited Raw := ⟨.num 0⟩

def Args.length : Args → Nat
  | .one _ => 1
  | .cons _ rest => rest.length + 1

end Plaer.Formula
