import Plaer.Check
import Basics.Statements

/-! Proofs of the notation examples. -/

theorem Basics.Proofs.pascal : Basics.pascal_statement :=
  fun n k => Nat.choose_succ_succ n k

theorem Basics.Proofs.sin_cos : Basics.sin_cos_statement :=
  fun x => Real.sin_sq_add_cos_sq x


#plaer_check_proof Basics.sin_cos_statement Basics.Proofs.sin_cos
