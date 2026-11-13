import Plaer.Check
import Basics.Statements

theorem Basics.Proofs.double_eq_two_mul : Basics.double_statement := by
  intro n
  unfold Basics.double
  omega


#plaer_check_proof Basics.double_statement Basics.Proofs.double_eq_two_mul
