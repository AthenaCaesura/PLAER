# The dictionary: LaTeX and the Lean it means

```lean
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Algebra.BigOperators.Intervals
import Mathlib.Data.Nat.Choose.Basic
import Mathlib.Data.Nat.Prime.Defs
import Mathlib.Data.Int.ModEq
import Plaer.Latex.Print
```

Every formula PLAER shows is LaTeX that Lean itself reads. This paper is the dictionary Lean reads it with. Each box below is one entry: a piece of LaTeX, and the Lean definition it stands for.

A box's LaTeX is shown only after Lean has read it back, through this dictionary, and found exactly the claim the box is about. So to trust a formula in any paper, you need to trust only the entries below, and you can read each one here: its LaTeX, and the Lean it means.

A few forms are built into the reading itself, rather than listed here:

- $\forall x, y \in T,\; P$ and $\exists x \in T,\; P$: for all, and there is, $x$ and $y$ in $T$. A variable over functions or propositions is written $f : T$ instead.
- $\mathbb{N}$, $\mathbb{Z}$, $\mathbb{R}$ and $\mathbf{Prop}$; $(\alpha, \beta) \to \gamma$, a function of two inputs.
- $f(a, b)$, a function applied; $\operatorname{triangle}$, a name of more than one letter; numerals; brackets.
- $(p : \mathbb{Z})$: $p$ as an element of $\mathbb{Z}$.
- $\sum_{i=0}^{n} f$ and $\prod_{i=0}^{n} f$, over $i = 0, \ldots, n$.

<!-- cell -->

## Logic

```lean
/-- If p, then q -/
latex_notation Dictionary.implies (p q : Prop) := p → q as:25 p:26 " \\implies " q:26

/-- p exactly when q -/
latex_notation Dictionary.iff (p q : Prop) := p ↔ q as:25 p:26 " \\iff " q:26

/-- p or q -/
latex_notation Dictionary.or (p q : Prop) := p ∨ q as:30 p:31 " \\lor " q:30

/-- p and q -/
latex_notation Dictionary.and (p q : Prop) := p ∧ q as:35 p:36 " \\land " q:35

/-- Not p -/
latex_notation Dictionary.not (p : Prop) := ¬p as:40 "\\neg " p:40
```

<!-- cell -->

## Comparisons

```lean
/-- Equal -/
latex_notation Dictionary.eq {α : Sort u} (a b : α) := a = b as:50 a:51 " = " b:51

/-- Not equal -/
latex_notation Dictionary.ne {α : Sort u} (a b : α) := a ≠ b as:50 a:51 " \\neq " b:51

/-- Less than -/
latex_notation Dictionary.lt {α : Type} [LT α] (a b : α) := a < b as:50 a:51 " < " b:51

/-- At most -/
latex_notation Dictionary.le {α : Type} [LE α] (a b : α) := a ≤ b as:50 a:51 " \\le " b:51

/-- Greater than -/
latex_notation Dictionary.gt {α : Type} [LT α] (a b : α) := a > b as:50 a:51 " > " b:51

/-- At least -/
latex_notation Dictionary.ge {α : Type} [LE α] (a b : α) := a ≥ b as:50 a:51 " \\ge " b:51

/-- a divides b -/
latex_notation Dictionary.dvd (a b : ℕ) := a ∣ b as:50 a:51 " \\mid " b:51

/-- a and b are congruent modulo n -/
latex_notation Dictionary.modEq (n a b : ℤ) := Int.ModEq n a b as:50 a:51 " \\equiv " b:51 " \\pmod{" n:0 "}"
```

<!-- cell -->

## Arithmetic

Subtraction and division in $\mathbb{N}$ are not the ordinary ones: subtraction stops at $0$, and division rounds down. They have their own symbols, so they cannot be mistaken for the ordinary ones, which are entries only for types where they are ordinary.

```lean
/-- The types in which subtraction is the ordinary one -/
class Dictionary.OrdinarySub (α : Type) : Prop

instance : Dictionary.OrdinarySub ℤ := ⟨⟩

instance : Dictionary.OrdinarySub ℝ := ⟨⟩

/-- Addition -/
latex_notation Dictionary.add {α : Type} [Add α] (a b : α) := a + b as:65 a:65 " + " b:66

/-- Subtraction, in ℤ and ℝ -/
latex_notation Dictionary.sub {α : Type} [Sub α] [Dictionary.OrdinarySub α] (a b : α) := a - b as:65 a:65 " - " b:66

/-- Subtraction in ℕ, which stops at 0 -/
latex_notation Dictionary.monus (a b : ℕ) := a - b as:65 a:65 " \\mathbin{\\dot{-}} " b:66

/-- Multiplication -/
latex_notation Dictionary.mul {α : Type} [Mul α] (a b : α) := a * b as:70 a:70 " \\cdot " b:71

/-- Division in ℕ, rounded down -/
latex_notation Dictionary.floorDiv (a b : ℕ) := a / b as:max "\\left\\lfloor\\frac{" a:0 "}{" b:0 "}\\right\\rfloor"

/-- Division in ℝ -/
latex_notation Dictionary.div (a b : ℝ) := a / b as:max "\\frac{" a:0 "}{" b:0 "}"

/-- Powers -/
latex_notation Dictionary.pow {α : Type} [HPow α ℕ α] (a : α) (n : ℕ) := a ^ n as:75 a:76 "^{" n:0 "}"
```

<!-- cell -->

## Number theory

```lean
/-- p is prime -/
latex_notation Dictionary.prime (p : ℕ) := Nat.Prime p as:max "\\operatorname{Prime}(" p:0 ")"

/-- The number of ways to choose k things from n -/
latex_notation Dictionary.choose (n k : ℕ) := Nat.choose n k as:max "\\binom{" n:0 "}{" k:0 "}"
```

<!-- cell -->

## Real functions

```lean
/-- Sine -/
latex_notation Dictionary.sin (x : ℝ) := Real.sin x as:max "\\sin(" x:0 ")"

/-- Cosine -/
latex_notation Dictionary.cos (x : ℝ) := Real.cos x as:max "\\cos(" x:0 ")"

/-- The number π -/
latex_notation Dictionary.pi := Real.pi as:max "\\pi"
```
