import Basics.Statements

/-- A second, independent proof of the same statement. -/
theorem Basics.Proofs.add_zero_by_simp : Basics.add_zero_statement := by
  intro n
  simp
