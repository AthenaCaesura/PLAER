# Theorems, conjectures, and definitions

```lean
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Data.Nat.Choose.Basic
import Mathlib.Data.Nat.Prime.Infinite
import Mathlib.Algebra.BigOperators.Intervals
import Plaer.Latex
```

A paper holds the things Lean has: definitions, and claims. A claim is a conjecture until a proof of it is checked; then it is a theorem. PLAER shows each one in its own kind of box.

## Definition

A `def` gives a name a meaning. Switch between its LaTeX and the Lean you wrote. The $n$-th triangular number is $0 + 1 + \dots + n$:

```lean
/-- Triangular numbers -/
def Basics.triangle (n : ℕ) : ℕ := ∑ i ∈ Finset.range (n + 1), i
```

A `structure`, `class`, or `inductive` type is a definition too. It has no formula to typeset, so its box shows only the Lean.

```lean
/-- A point with natural-number coordinates -/
structure Basics.Point where
  x : ℕ
  y : ℕ
```

## Conjecture

A `def … : Prop` is a claim: Lean calls it a proposition. Writing it down does not assert it. Until a proof of it is checked, it is a **Conjecture**. Goldbach's conjecture has been checked for every even number up to $4 \times 10^{18}$, but nobody has proved it:

```lean
/-- Goldbach's conjecture -/
def Basics.goldbach : Prop :=
  ∀ n : ℕ, n > 2 → 2 ∣ n → ∃ p q : ℕ, p.Prime ∧ q.Prime ∧ p + q = n
```

A conjecture can be false. Euler noticed that $n^2 + n + 41$ is prime for $n = 0, 1, \dots, 39$, but at $n = 40$ it is $41^2$. The proof attached here is wrong, and the second proof file does not exist, so the claim stays a conjecture:

```lean
/-- Euler's prime-generating polynomial -/
def Basics.euler_statement : Prop := ∀ n : ℕ, (n ^ 2 + n + 41).Prime
-- proof: proofs/File.lean Basics.Proofs.euler
-- proof: proofs/Missing.lean Basics.Proofs.euler_missing
```

## Theorem

A `-- proof:` line attaches a proof file to a claim. When a play button checks a proof, Lean has proved the claim and the box says **Theorem**. If the check happened earlier, for example when this page was built, the box says so; press play to check it again.

Every proof rests on the axioms of Lean's logic, and the box lists the ones its proof uses. A claim can have several proofs. Gauss's formula for the triangular numbers defined above has two, both from that definition:

```lean
/-- Gauss's formula -/
def Basics.gauss_statement : Prop := ∀ n : ℕ, 2 * Basics.triangle n = n * (n + 1)
-- proof: proofs/Gauss.lean Basics.Proofs.gauss_by_induction
-- proof: proofs/Gauss.lean Basics.Proofs.gauss_by_steps
```

```lean
/-- There are infinitely many primes -/
def Basics.infinitely_many_primes : Prop := ∀ n : ℕ, ∃ p : ℕ, p ≥ n ∧ p.Prime
-- proof: proofs/Primes.lean Basics.Proofs.infinitely_many_primes
```

## A theorem that assumes a conjecture

A proof can never assume a conjecture. To build on one, put it in the claim: "if Goldbach's conjecture holds, then …". The theorem below is then honest about what it rests on, because the assumption is part of what it says:

```lean
/-- If Goldbach is right, 100 is a sum of two primes -/
def Basics.hundred_statement : Prop :=
  Basics.goldbach → ∃ p q : ℕ, p.Prime ∧ q.Prime ∧ p + q = 100
-- proof: proofs/Primes.lean Basics.Proofs.hundred
```

## Lean

All other Lean is folded into one **Lean** line, because it matters to Lean, not to the reader. That includes imports (the folded line at the top), `instance` declarations, and quick checks such as `example`. This one gives points a default value and checks that $\operatorname{triangle}(4) = 10$:

```lean
instance : Inhabited Basics.Point := ⟨⟨0, 0⟩⟩

example : Basics.triangle 4 = 10 := by simp [Basics.triangle, Finset.sum_range_succ]
```

## Not allowed in a paper

A paper states claims; proofs live in proof files. Lean refuses to build a paper that contains:

- a `theorem`, because a `theorem` carries its proof. Write it as a conjecture with a `-- proof:` line; it shows as a theorem once that proof is checked.
- an `axiom`, because every proof could then quietly assume it. Write it as a conjecture, and put it in the claims that depend on it, as above.
- `sorry`, which would pretend a claim is proved.

This sample is not compiled:

```lean ignore
theorem Basics.zero_add (n : ℕ) : 0 + n = n := by simp      -- refused: the proof belongs in a proof file
axiom Basics.goldbach_holds : Basics.goldbach                -- refused: an unproved assumption
def Basics.half : ℕ → ℕ := sorry                            -- refused: sorry
```

## Notation

The LaTeX view knows common notation, such as sums, binomial coefficients, and trigonometric functions. Two examples, proved in `proofs/Notation.lean`:

```lean
/-- Pascal's rule -/
def Basics.pascal_statement : Prop :=
  ∀ n k : ℕ, Nat.choose (n + 1) (k + 1) = Nat.choose n k + Nat.choose n (k + 1)
-- proof: proofs/Notation.lean Basics.Proofs.pascal

/-- The Pythagorean identity -/
def Basics.sin_cos_statement : Prop := ∀ x : ℝ, Real.sin x ^ 2 + Real.cos x ^ 2 = 1
-- proof: proofs/Notation.lean Basics.Proofs.sin_cos
```

## What the play button says

- **Proved**: Lean accepts the proof, it proves exactly the claim shown, and it uses no axioms beyond Lean's own. The box becomes a theorem.
- **Not proved**: anything else. The proof is wrong, its file is missing, it uses `sorry`, or it proves a different claim.
- **Not checked**: the claim changed since its proofs were last checked. Press play to check again.
- **Unavailable**: the PLAER server could not run the check, for example because it stopped.
