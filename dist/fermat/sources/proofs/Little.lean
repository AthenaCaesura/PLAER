import Fermat.Statements

theorem Fermat.Proofs.little : Fermat.little_statement := by
  intro p a hp
  exact Int.ModEq.pow_prime_eq_self hp a
