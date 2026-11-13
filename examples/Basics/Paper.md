# Theorems, conjectures, definitions, and axioms

```lean
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Data.Nat.Choose.Basic
import Mathlib.Data.Nat.Prime.Defs
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Plaer.Latex
```

A paper has the same four kinds of thing Lean has: definitions, claims, proved claims, and assumptions. PLAER shows each one in its own kind of box.

## Definition

A `def` gives a name a meaning. Switch between its LaTeX and the Lean you wrote.

```lean
/-- Doubling a natural number -/
def Basics.double (n : ℕ) : ℕ := n + n
```

A `structure`, `class`, or `inductive` type is a definition too. It has no formula to typeset, so its box shows only the Lean.

```lean
/-- A point with natural-number coordinates -/
structure Basics.Point where
  x : ℕ
  y : ℕ
```

## Conjecture

A `def … : Prop` is a claim: Lean calls it a proposition. Writing it down does not assert it. Until a proof of it is checked, it is a **Conjecture**.

```lean
/-- Multiplying by one -/
def Basics.mul_one_statement : Prop := ∀ n : ℕ, n * 1 = n
```

A conjecture can be false. This one has a wrong proof and a proof file that does not exist, so it stays a conjecture.

```lean
/-- A false claim -/
def Namespace.name_statement : Prop :=
  ∀ n : ℕ, n + 1 = n
-- proof: proofs/File.lean Namespace.Proofs.name
-- proof: proofs/Missing.lean Namespace.Proofs.missing
```

## Theorem

A `-- proof:` line attaches a proof file to a claim. When a play button checks a proof, Lean has proved the claim, and the box says **Theorem**. If the check happened earlier, for example when this page was built, the box says so; press play to check it again. A claim can have several proofs.

```lean
/-- Adding zero -/
def Basics.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean Basics.Proofs.add_zero
-- proof: proofs/AddZeroBySimp.lean Basics.Proofs.add_zero_by_simp
```

## Axiom

An `axiom` is a claim Lean accepts without proof: an assumption. Its box is marked as assumed. Here, Goldbach's conjecture, which nobody has proved, is taken as an axiom:

```lean
/-- Goldbach's conjecture, assumed -/
axiom Basics.goldbach : ∀ n : ℕ, n > 2 → 2 ∣ n → ∃ p q : ℕ, p.Prime ∧ q.Prime ∧ p + q = n
```

A theorem whose proof uses an axiom is only as sure as the axiom, so its box names the axiom it assumes. This proof applies Goldbach's conjecture to 100 instead of finding the two primes:

```lean
/-- 100 is a sum of two primes -/
def Basics.hundred_statement : Prop := ∃ p q : ℕ, p.Prime ∧ q.Prime ∧ p + q = 100
-- proof: proofs/Hundred.lean Basics.Proofs.hundred
```

## Lean

All other Lean is folded into one **Lean** line, because it matters to Lean, not to the reader. That includes imports (the folded line at the top), `instance` declarations, quick checks such as `example`, and LaTeX notation rules. This one gives points a default value, checks that doubling 3 gives 6, and tells the LaTeX view how to write `Basics.double`:

```lean
instance : Inhabited Basics.Point := ⟨⟨0, 0⟩⟩

example : Basics.double 3 = 6 := rfl

open Lean LeanTeX in
latex_pp_app_rules (const := Basics.double)
  | _, #[n] => do
    let n ← latexPP n
    return LatexData.atomString "\\operatorname{double}" ++ n.parens
```

With that rule, a claim about `Basics.double` has a LaTeX view:

```lean
/-- Doubling is multiplying by two -/
def Basics.double_statement : Prop := ∀ n : ℕ, Basics.double n = 2 * n
-- proof: proofs/Double.lean Basics.Proofs.double_eq_two_mul
```

## Not allowed in a paper

A paper states claims; proofs live in proof files. Lean refuses to build a paper with a `theorem`, because a `theorem` contains its proof. Write it as a conjecture with a `-- proof:` line instead; it shows as a theorem once that proof is checked. A paper also may not use `sorry`, which would pretend a claim is proved. This sample is not compiled:

```lean ignore
theorem Basics.zero_add (n : ℕ) : 0 + n = n := by simp       -- refused: the proof belongs in a proof file
def Basics.half : ℕ → ℕ := sorry                             -- refused: sorry
```

## Notation

The LaTeX view knows common mathematical notation. Each theorem below is proved in `proofs/Notation.lean`.

```lean
/-- Divisibility and the greatest common divisor -/
def Basics.gcd_dvd_statement : Prop := ∀ a b : ℕ, Nat.gcd a b ∣ a
-- proof: proofs/Notation.lean Basics.Proofs.gcd_dvd

/-- Minimum and maximum -/
def Basics.min_le_max_statement : Prop := ∀ a b : ℕ, min a b ≤ max a b
-- proof: proofs/Notation.lean Basics.Proofs.min_le_max

/-- Absolute value -/
def Basics.abs_statement : Prop := ∀ x : ℝ, |x| ≥ 0
-- proof: proofs/Notation.lean Basics.Proofs.abs_nonneg

/-- Square roots -/
def Basics.sqrt_statement : Prop := ∀ x : ℝ, x ≥ 0 → Real.sqrt x * Real.sqrt x = x
-- proof: proofs/Notation.lean Basics.Proofs.sqrt_mul_self

/-- Factorials -/
def Basics.factorial_statement : Prop := ∀ n : ℕ, Nat.factorial (n + 1) = (n + 1) * Nat.factorial n
-- proof: proofs/Notation.lean Basics.Proofs.factorial_succ

/-- Binomial coefficients -/
def Basics.choose_statement : Prop := ∀ n : ℕ, Nat.choose n 1 = n
-- proof: proofs/Notation.lean Basics.Proofs.choose_one

/-- Sums -/
def Basics.sum_statement : Prop := ∀ n : ℕ, ∑ i ∈ Finset.range n, (2 * i + 1) = n ^ 2
-- proof: proofs/Notation.lean Basics.Proofs.sum_odd

/-- Products -/
def Basics.prod_statement : Prop := ∀ n : ℕ, ∏ i ∈ Finset.range n, (i + 1) = Nat.factorial n
-- proof: proofs/Notation.lean Basics.Proofs.prod_succ

/-- Exponential and logarithm -/
def Basics.log_exp_statement : Prop := ∀ x : ℝ, Real.log (Real.exp x) = x
-- proof: proofs/Notation.lean Basics.Proofs.log_exp

/-- Sine and cosine -/
def Basics.sin_cos_statement : Prop := ∀ x : ℝ, Real.sin x ^ 2 + Real.cos x ^ 2 = 1
-- proof: proofs/Notation.lean Basics.Proofs.sin_cos

/-- Pi -/
def Basics.pi_statement : Prop := Real.pi > 0
-- proof: proofs/Notation.lean Basics.Proofs.pi_pos
```

## What the play button says

- **Proved**: Lean accepts the proof, and it proves exactly the claim shown. The box becomes a theorem.
- **Not proved**: anything else. The proof is wrong, its file is missing, it uses `sorry`, or it proves a different claim.
- **Not checked**: the claim changed since its proofs were last checked. Press play to check again.
- **Unavailable**: the PLAER server could not run the check, for example because it stopped.
