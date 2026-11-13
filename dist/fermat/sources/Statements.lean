-- # Two theorems of Fermat

-- ```lean
import Mathlib.FieldTheory.Finite.Basic
-- ```

-- ```lean
/-- Fermat's last theorem -/
def Fermat.last_statement : Prop :=
  ∀ n a b c : ℕ, 2 < n → 0 < a → 0 < b → 0 < c → a ^ n + b ^ n ≠ c ^ n
-- proof: proofs/Last.lean Fermat.Proofs.last
-- ```

-- ## Reading the last theorem

-- For an integer exponent $n>2$, no positive integers $a,b,c$ satisfy $a^n+b^n=c^n$. All four variables are natural numbers; the positivity assumptions exclude zero.

-- For an application involving integer solutions, first match the variables and check every assumption. This note is an explanation, not a proof of that application.

-- The attached demonstration proof is deliberately wrong: from $2<n$ it tries to conclude the required inequality using only `Nat.ne_of_lt hn`. **Not proved** describes that attempt; Fermat's last theorem itself is true.

-- ```lean
/-- Fermat's little theorem -/
def Fermat.little_statement : Prop :=
  ∀ (p : ℕ) (a : ℤ), p.Prime → Int.ModEq (p : ℤ) (a ^ p) a
-- proof: proofs/Little.lean Fermat.Proofs.little
-- ```

-- ## Reading the little theorem

-- If $p$ is prime, every integer $a$ satisfies $a^p\equiv a\pmod p$. The prime $p$ specifies the modulus, and $a$ may be any integer. For example, $2^5=32\equiv2\pmod5$, which Lean confirms:

-- ```lean
example : Int.ModEq 5 (2 ^ 5) 2 := by decide
-- ```

-- When applying the statement to modular arithmetic, identify the modulus and establish that it is prime. The attached proof applies Mathlib's `Int.ModEq.pow_prime_eq_self`; its play button checks that proof against this statement.
