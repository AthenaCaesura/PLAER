import Basics.Statements

/-! Two proofs of Gauss's formula, both from the paper's definition of `Basics.triangle`. -/

/-- By induction: going from n to n + 1 adds n + 1 to the sum. -/
theorem Basics.Proofs.gauss_by_induction : Basics.gauss_statement := by
  intro n
  induction n with
  | zero => simp [Basics.triangle]
  | succ n ih =>
    unfold Basics.triangle at *
    rw [Finset.sum_range_succ, mul_add, ih]
    ring

/-- The definition gives T(n + 1) = T(n) + (n + 1). -/
theorem Basics.Proofs.triangle_succ (n : ℕ) :
    Basics.triangle (n + 1) = Basics.triangle n + (n + 1) := by
  unfold Basics.triangle
  exact Finset.sum_range_succ _ _

/-- By that step, then induction, never unfolding the sum again. -/
theorem Basics.Proofs.gauss_by_steps : Basics.gauss_statement := by
  intro n
  induction n with
  | zero => simp [Basics.triangle]
  | succ n ih => rw [Basics.Proofs.triangle_succ, mul_add, ih]; ring
