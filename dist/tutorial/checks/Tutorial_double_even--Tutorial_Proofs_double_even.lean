import Plaer.Check
import Tutorial.Statements

theorem Tutorial.Proofs.double_even : Tutorial.double_even := by
  intro n
  exact ⟨n, rfl⟩


#plaer_check_proof Tutorial.double_even Tutorial.Proofs.double_even
