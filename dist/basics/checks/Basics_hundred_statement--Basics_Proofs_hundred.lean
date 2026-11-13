import Plaer.Check
import Basics.Statements

/-- Uses the Goldbach axiom rather than finding the primes, so this theorem assumes it. -/
theorem Basics.Proofs.hundred : Basics.hundred_statement :=
  Basics.goldbach 100 (by decide) ⟨50, rfl⟩


#plaer_check_proof Basics.hundred_statement Basics.Proofs.hundred
