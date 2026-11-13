import Plaer.Check
import Basics.Statements

/-! Proofs of the notation examples, one theorem per statement. -/

theorem Basics.Proofs.gcd_dvd : Basics.gcd_dvd_statement :=
  fun a b => Nat.gcd_dvd_left a b

theorem Basics.Proofs.min_le_max : Basics.min_le_max_statement :=
  fun _ _ => _root_.min_le_max

theorem Basics.Proofs.abs_nonneg : Basics.abs_statement :=
  fun x => _root_.abs_nonneg x

theorem Basics.Proofs.sqrt_mul_self : Basics.sqrt_statement :=
  fun x hx => Real.mul_self_sqrt hx

theorem Basics.Proofs.factorial_succ : Basics.factorial_statement :=
  fun n => Nat.factorial_succ n

theorem Basics.Proofs.choose_one : Basics.choose_statement :=
  fun n => Nat.choose_one_right n

theorem Basics.Proofs.sum_odd : Basics.sum_statement := by
  intro n
  induction n with
  | zero => simp
  | succ n ih => rw [Finset.sum_range_succ, ih]; ring

theorem Basics.Proofs.prod_succ : Basics.prod_statement := by
  intro n
  induction n with
  | zero => simp
  | succ n ih => rw [Finset.prod_range_succ, ih, Nat.factorial_succ]; ring

theorem Basics.Proofs.log_exp : Basics.log_exp_statement :=
  fun x => Real.log_exp x

theorem Basics.Proofs.sin_cos : Basics.sin_cos_statement :=
  fun x => Real.sin_sq_add_cos_sq x

theorem Basics.Proofs.pi_pos : Basics.pi_statement :=
  Real.pi_pos


#plaer_check_proof Basics.gcd_dvd_statement Basics.Proofs.gcd_dvd
