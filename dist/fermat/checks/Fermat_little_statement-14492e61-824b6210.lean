import Plaer.Check
import Fermat.Statements

theorem Fermat.Proofs.little : Fermat.little_statement := by
  intro p a hp
  exact Int.ModEq.pow_prime_eq_self hp a


#plaer_check_proof Fermat.little_statement Fermat.Proofs.little
