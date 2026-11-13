import Plaer.Check
import Spec.Statements

theorem Spec.Proofs.monus_add : Spec.monus_add := by
  intro a b h; omega
theorem Spec.Proofs.monus_zero : Spec.monus_zero := by
  intro a b h; omega
theorem Spec.Proofs.monus_values : Spec.monus_values := by
  unfold Spec.monus_values; decide
theorem Spec.Proofs.div_bounds : Spec.div_bounds := by
  intro a b hb
  constructor
  · exact Nat.div_mul_le_self a b
  · rw [Nat.add_mul, Nat.one_mul]
    have := Nat.lt_div_mul_add (a := a) hb
    omega
theorem Spec.Proofs.div_zero : Spec.div_zero := by
  intro a; exact Nat.div_zero a
theorem Spec.Proofs.div_values : Spec.div_values := by
  unfold Spec.div_values; decide
theorem Spec.Proofs.sub_add : Spec.sub_add := by
  intro a b; omega
theorem Spec.Proofs.sub_self : Spec.sub_self := by
  intro a; omega
theorem Spec.Proofs.pow_zero : Spec.pow_zero := by
  intro a; exact Nat.pow_zero a
theorem Spec.Proofs.pow_succ : Spec.pow_succ := by
  intro a n; exact Nat.pow_succ ..
theorem Spec.Proofs.pow_values : Spec.pow_values := by
  unfold Spec.pow_values; decide
theorem Spec.Proofs.gt_iff : Spec.gt_iff := by
  intro a b; exact Iff.rfl
theorem Spec.Proofs.ge_iff : Spec.ge_iff := by
  intro a b; exact Iff.rfl
theorem Spec.Proofs.le_iff : Spec.le_iff := by
  intro a b; omega
theorem Spec.Proofs.ne_iff : Spec.ne_iff := by
  intro a b; exact Iff.rfl
theorem Spec.Proofs.left_grouping : Spec.left_grouping := by
  intro a b c; omega
theorem Spec.Proofs.bracket_values : Spec.bracket_values := by
  unfold Spec.bracket_values; decide
theorem Spec.Proofs.function_values : Spec.function_values := by
  unfold Spec.function_values; decide


#plaer_check_proof Spec.monus_add Spec.Proofs.monus_add
