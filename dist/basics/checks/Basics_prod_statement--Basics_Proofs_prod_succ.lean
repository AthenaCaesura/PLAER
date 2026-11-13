import Plaer.Check
import Basics.Statements

/-! Proofs of the notation examples, one theorem per claim. -/

theorem Basics.Proofs.gcd_lcm : Basics.gcd_lcm_statement :=
  fun a b => Nat.gcd_mul_lcm a b

theorem Basics.Proofs.min_max : Basics.min_max_statement := by
  intro a b
  omega

theorem Basics.Proofs.triangle_inequality : Basics.triangle_inequality :=
  fun x y => abs_add_le x y

theorem Basics.Proofs.sqrt_mul : Basics.sqrt_statement :=
  fun x y hx => Real.sqrt_mul hx y

theorem Basics.Proofs.dvd_factorial : Basics.factorial_statement :=
  fun _ _ hm hmn => Nat.dvd_factorial hm hmn

theorem Basics.Proofs.pascal : Basics.pascal_statement :=
  fun n k => Nat.choose_succ_succ n k

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

theorem Basics.Proofs.exp_add : Basics.exp_statement :=
  fun x y => Real.exp_add x y

theorem Basics.Proofs.sin_cos : Basics.sin_cos_statement :=
  fun x => Real.sin_sq_add_cos_sq x

theorem Basics.Proofs.cos_pi : Basics.pi_statement :=
  Real.cos_pi


#plaer_check_proof Basics.prod_statement Basics.Proofs.prod_succ
