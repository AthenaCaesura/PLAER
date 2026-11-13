import Fermat.Statements

/-- Deliberately wrong: n > 2 does not establish the equation's impossibility. -/
theorem Fermat.Proofs.last : Fermat.last_statement := by
  intro n a b c hn ha hb hc
  exact Nat.ne_of_lt hn
