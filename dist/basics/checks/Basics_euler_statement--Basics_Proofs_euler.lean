import Plaer.Check
import Basics.Statements

/-- Deliberately wrong: `decide` can check one number at a time, but not every `n` at once.
(And the claim is false anyway: at n = 40 the value is 41².) -/
theorem Basics.Proofs.euler : Basics.euler_statement := by
  intro n
  decide


#plaer_check_proof Basics.euler_statement Basics.Proofs.euler
