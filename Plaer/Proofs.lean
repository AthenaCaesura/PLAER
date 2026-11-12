module
public import Mathlib.Tactic.NormNum
public import Plaer.Definitions
public import Mathlib.FieldTheory.Finite.Basic

public section

namespace Plaer

theorem left_endpoint_mem : (0 : ℝ) ∈ I := by
  norm_num [I]

theorem right_endpoint_mem : (1 : ℝ) ∈ I := by
  norm_num [I]

/-- A deliberately false candidate, not an asserted theorem. -/
@[expose] def outside_point_statement : Prop := (2 : ℝ) ∈ I

/-- Kept outside the paper; Lean must reject this attempted proof. -/
meta def outside_point_attempt : String := "by\n  norm_num [Plaer.I]"

@[expose] def fermat_last_statement : Prop :=
  ∀ n a b c : ℕ, 2 < n → 0 < a → 0 < b → 0 < c → a ^ n + b ^ n ≠ c ^ n

meta def fermat_last_attempt : String :=
  "by\n  intro n a b c hn ha hb hc\n  exact Nat.ne_of_lt hn"

theorem fermat_little (p : ℕ) (a : ℤ) (hp : p.Prime) :
    Int.ModEq (p : ℤ) (a ^ p) a := by
  exact Int.ModEq.pow_prime_eq_self hp a

end Plaer
