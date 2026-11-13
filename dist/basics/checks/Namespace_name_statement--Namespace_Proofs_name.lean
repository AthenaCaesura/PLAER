import Plaer.Check
import Basics.Statements

/-- Deliberately incorrect, written as a chain of equalities.
Lean checks each step; the first one is wrong, because `1` is not `0`. -/
theorem Namespace.Proofs.name : Namespace.name_statement := by
  intro n
  calc n + 1 = n + 0 := by rfl            -- wrong step: claims 1 = 0
    _ = n := by rw [Nat.add_zero]         -- correct step: adding zero changes nothing


#plaer_check_proof Namespace.name_statement Namespace.Proofs.name
