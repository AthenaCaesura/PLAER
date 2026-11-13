module
public import Mathlib.Data.Nat.Basic

public section

namespace Basics

/-- Double a natural number; displaying a definition does not assert a theorem. -/
def double (n : ℕ) : ℕ := n + n

/-- A separate statement for the corresponding proof file to establish. -/
@[expose] def add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n

end Basics
