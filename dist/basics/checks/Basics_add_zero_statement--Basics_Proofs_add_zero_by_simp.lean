import Plaer.Check
import Basics.Statements

/-- A second, independent proof of the same statement. -/
theorem Basics.Proofs.add_zero_by_simp : Basics.add_zero_statement := by
  intro n
  simp


#plaer_check_proof Basics.add_zero_statement Basics.Proofs.add_zero_by_simp
