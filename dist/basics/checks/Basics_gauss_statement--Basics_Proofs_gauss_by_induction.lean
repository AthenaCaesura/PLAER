import Plaer.Check
import Basics.Statements

/-- By induction: going from n to n + 1 adds n + 1 to the sum. -/
theorem Basics.Proofs.gauss_by_induction : Basics.gauss_statement := by
  intro n
  induction n with
  | zero => simp [Basics.triangle]
  | succ n ih =>
    unfold Basics.triangle at *
    rw [Finset.sum_range_succ, mul_add, ih]
    ring

/-- From Mathlib's `Finset.sum_range_id_mul_two`. -/
theorem Basics.Proofs.gauss_from_mathlib : Basics.gauss_statement := by
  intro n
  unfold Basics.triangle
  rw [mul_comm, Finset.sum_range_id_mul_two, Nat.add_sub_cancel, mul_comm]


#plaer_check_proof Basics.gauss_statement Basics.Proofs.gauss_by_induction
