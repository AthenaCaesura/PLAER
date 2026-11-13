module

public import Lean
public meta import Lean

public section

/-! # LaTeX, read by Lean

PLAER's LaTeX is a language Lean itself can read. This file declares its grammar: a
syntax category `latex`, and `⟪ … ⟫`, which reads LaTeX as a Lean term.

Only the parts every formula needs are built in: quantifiers, variables and names,
numerals, brackets and function application. Every symbol, such as `+`, `\land` or
`\binom{n}{k}`, is an entry of the dictionary, declared with `latex_notation`:

    /-- Subtraction in ℕ, which stops at 0 -/
    latex_notation monus (a b : ℕ) := a - b as:65 a:65 " \\mathbin{\\dot{-}} " b:66

That declares a Lean definition, `monus a b := a - b`, and the LaTeX form that means it:
Lean reads `a \mathbin{\dot{-}} b` as `monus a b`. -/

namespace Plaer.Latex

declare_syntax_cat tex
declare_syntax_cat texTy
/-- A bound variable: `x`, `\alpha`, or `\operatorname{name}`. -/
declare_syntax_cat texName

/-- LaTeX, read as a Lean term. -/
syntax "⟪" tex "⟫" : term
/-- A LaTeX type, read as a Lean type. -/
syntax "⟪" texTy "⟫ₜ" : term

/-! ## Types -/

syntax "\\mathbb{N}" : texTy
syntax "\\mathbb{Z}" : texTy
syntax "\\mathbb{R}" : texTy
syntax "\\mathbf{Prop}" : texTy
syntax "\\operatorname{" ident "}" : texTy
syntax ident : texTy
syntax "(" texTy ")" : texTy
/-- A function of several inputs: `(\mathbb{N}, \mathbb{N}) \to \mathbb{N}`. -/
syntax "(" texTy ", " texTy,+ ")" " \\to " texTy : texTy
syntax:25 texTy:26 " \\to " texTy:25 : texTy

macro_rules
  | `(⟪\mathbb{N}⟫ₜ) => `(Nat)
  | `(⟪\mathbb{Z}⟫ₜ) => `(Int)
  | `(⟪\mathbb{R}⟫ₜ) => return Lean.mkIdent `Real
  | `(⟪\mathbf{Prop}⟫ₜ) => `(Prop)
  | `(⟪\operatorname{ $x }⟫ₜ) => `($x)
  | `(⟪$x:ident⟫ₜ) => `($x)
  | `(⟪( $t )⟫ₜ) => `(⟪$t⟫ₜ)
  | `(⟪( $t, $ts,* ) \to $out⟫ₜ) => do
    let mut acc ← `(⟪$out⟫ₜ)
    for s in ts.getElems.reverse do
      acc ← `(⟪$s⟫ₜ → $acc)
    `(⟪$t⟫ₜ → $acc)
  | `(⟪$a \to $b⟫ₜ) => `(⟪$a⟫ₜ → ⟪$b⟫ₜ)

/-! ## Names, numerals, brackets, application -/

/-- A one-letter variable: `x`. -/
syntax:max ident : tex
/-- A name of more than one letter, set upright: `\operatorname{triangle}`. -/
syntax:max "\\operatorname{" ident "}" : tex
syntax:max num : tex
syntax:max "(" tex ")" : tex
/-- A value whose type nothing else determines: `(2 : \mathbb{Z})`. -/
syntax:max "(" tex " : " texTy ")" : tex
/-- Applying a function: `f(a, b)`. -/
syntax:max tex:max "(" tex,+ ")" : tex

macro_rules
  | `(⟪$x:ident⟫) => `($x)
  | `(⟪\operatorname{ $x }⟫) => `($x)
  | `(⟪$n:num⟫) => `($n)
  | `(⟪( $e )⟫) => `(⟪$e⟫)
  | `(⟪( $e : $t )⟫) => `((⟪$e⟫ : ⟪$t⟫ₜ))
  | `(⟪$f( $args,* )⟫) => do
    let args ← args.getElems.mapM fun a => `(⟪$a⟫)
    `(⟪$f⟫ $args*)

/-! ## Greek letters, as variables -/

syntax:max "\\alpha" : tex
syntax:max "\\beta" : tex
syntax:max "\\gamma" : tex
syntax "\\alpha" : texTy
syntax "\\beta" : texTy
syntax "\\gamma" : texTy

macro_rules
  -- the paper's own variables, so not hygienic
  | `(⟪\alpha⟫) => return Lean.mkIdent `α
  | `(⟪\beta⟫) => return Lean.mkIdent `β
  | `(⟪\gamma⟫) => return Lean.mkIdent `γ
  | `(⟪\alpha⟫ₜ) => return Lean.mkIdent `α
  | `(⟪\beta⟫ₜ) => return Lean.mkIdent `β
  | `(⟪\gamma⟫ₜ) => return Lean.mkIdent `γ

/-! ## Quantifiers

`\forall x, y \in T,\; P` is `∀ x y : T, P`. A variable over a type of elements reads
`x \in T`; over functions or propositions, `f : T`. -/

syntax ident : texName
syntax "\\alpha" : texName
syntax "\\beta" : texName
syntax "\\gamma" : texName
syntax "\\operatorname{" ident "}" : texName

syntax:0 "\\forall " texName,+ " \\in " texTy ",\\; " tex:0 : tex
syntax:0 "\\forall " texName,+ " : " texTy ",\\; " tex:0 : tex
syntax:0 "\\exists " texName,+ " \\in " texTy ",\\; " tex:0 : tex
syntax:0 "\\exists " texName,+ " : " texTy ",\\; " tex:0 : tex

meta def binderIdent (b : Lean.TSyntax `texName) : Lean.MacroM Lean.Ident :=
  match b with
  | `(texName| $x:ident) => pure x
  | `(texName| \alpha) => pure (Lean.mkIdent `α)
  | `(texName| \beta) => pure (Lean.mkIdent `β)
  | `(texName| \gamma) => pure (Lean.mkIdent `γ)
  | `(texName| \operatorname{ $x }) => pure x
  | _ => Lean.Macro.throwUnsupported

macro_rules
  | `(⟪\forall $xs,* \in $t,\; $p⟫) => do
    let xs ← xs.getElems.mapM binderIdent
    `(∀ ($xs* : ⟪$t⟫ₜ), ⟪$p⟫)

macro_rules
  | `(⟪\forall $xs,* : $t,\; $p⟫) => do
    let xs ← xs.getElems.mapM binderIdent
    `(∀ ($xs* : ⟪$t⟫ₜ), ⟪$p⟫)

macro_rules
  | `(⟪\exists $xs,* \in $t,\; $p⟫) => do
    let xs ← xs.getElems.mapM binderIdent
    let mut acc ← `(⟪$p⟫)
    for x in xs.reverse do
      acc ← `(∃ $x:ident : ⟪$t⟫ₜ, $acc)
    return acc

macro_rules
  | `(⟪\exists $xs,* : $t,\; $p⟫) => do
    let xs ← xs.getElems.mapM binderIdent
    let mut acc ← `(⟪$p⟫)
    for x in xs.reverse do
      acc ← `(∃ $x:ident : ⟪$t⟫ₜ, $acc)
    return acc

/-! ## Sums and products over `0, …, n`

`\sum_{i = 0}^{n} f` is `∑ i ∈ Finset.range (n + 1), f`. -/

syntax:67 "\\sum_{" ident "=0}^{" tex:0 "} " tex:67 : tex
syntax:67 "\\prod_{" ident "=0}^{" tex:0 "} " tex:67 : tex

macro_rules
  -- `Finset` is Mathlib's, found where the paper is read, not here
  | `(⟪\sum_{ $i =0}^{ $n } $f⟫) => do
    let sum := Lean.mkIdent `Finset.sum
    let range := Lean.mkIdent `Finset.range
    `($sum ($range (⟪$n⟫ + 1)) fun $i => ⟪$f⟫)
  | `(⟪\prod_{ $i =0}^{ $n } $f⟫) => do
    let prod := Lean.mkIdent `Finset.prod
    let range := Lean.mkIdent `Finset.range
    `($prod ($range (⟪$n⟫ + 1)) fun $i => ⟪$f⟫)

end Plaer.Latex
