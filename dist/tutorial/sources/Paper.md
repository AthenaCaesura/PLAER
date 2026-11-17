# Doubling

```lean
import Mathlib.Data.Nat.Basic
import Dictionary.Statements
```

Write notes in Markdown, with $...$ for mathematics. Every Lean declaration
becomes a box. Add more with the **+ Markdown**, **+ Definition**, **+ Conjecture**
and **+ Lean** buttons between boxes.

```lean
/-- Adding zero -/
def Tutorial.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean Tutorial.Proofs.add_zero
```

For every natural number $n$, $n + 0 = n$. Press the play button to check the proof.

```lean
/-- Doubling a number -/
def Tutorial.double (n : ℕ) : ℕ := 2 * n

/-- A double is even -/
def Tutorial.double_even : Prop := ∀ n : ℕ, 2 ∣ Tutorial.double n
-- proof: proofs/Double.lean Tutorial.Proofs.double_even
```

```lean
/-- Greatest common divisor -/
latex_notation Tutorial.gcd (a b : ℕ) := Nat.gcd a b as:max "\\gcd(" a:0 "," b:0 ")"

/-- The gcd of a number and its double -/
def Tutorial.gcd_double : Prop := ∀ n : ℕ, Nat.gcd n (Tutorial.double n) = n
```
