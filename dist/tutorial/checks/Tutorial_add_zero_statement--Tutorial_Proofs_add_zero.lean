import Plaer.Check
import Tutorial.Statements

theorem Tutorial.Proofs.add_zero : Tutorial.add_zero_statement := by
  intro n
  rfl


#plaer_check_proof Tutorial.add_zero_statement Tutorial.Proofs.add_zero
