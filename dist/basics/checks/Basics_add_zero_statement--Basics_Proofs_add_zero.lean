import Plaer.Check
import Basics.Statements

theorem Basics.Proofs.add_zero : Basics.add_zero_statement := by
  intro n
  exact Nat.add_zero n


#plaer_check_proof Basics.add_zero_statement Basics.Proofs.add_zero
