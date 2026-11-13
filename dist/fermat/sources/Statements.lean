module
public import Mathlib.FieldTheory.Finite.Basic

public section

namespace Fermat

/-- Fermat's last theorem, independent of any attempted proof. -/
@[expose] def last_statement : Prop :=
  ∀ n a b c : ℕ, 2 < n → 0 < a → 0 < b → 0 < c → a ^ n + b ^ n ≠ c ^ n

/-- Fermat's little theorem, with every parameter explicit. -/
@[expose] def little_statement : Prop :=
  ∀ (p : ℕ) (a : ℤ), p.Prime → Int.ModEq (p : ℤ) (a ^ p) a

end Fermat
