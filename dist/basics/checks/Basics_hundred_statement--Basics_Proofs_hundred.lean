import Plaer.Check
import Basics.Statements

/-- Euclid's theorem, from Mathlib. -/
theorem Basics.Proofs.infinitely_many_primes : Basics.infinitely_many_primes :=
  fun n => Nat.exists_infinite_primes n

/-- Apply the assumed conjecture to 100: it is even and greater than 2. -/
theorem Basics.Proofs.hundred : Basics.hundred_statement :=
  fun goldbach => goldbach 100 (by decide) ⟨50, rfl⟩


#plaer_check_proof Basics.hundred_statement Basics.Proofs.hundred
