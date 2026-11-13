import Basics.Statements

/-- Apply the assumed conjecture to 100: it is even and greater than 2. -/
theorem Basics.Proofs.hundred : Basics.hundred_statement :=
  fun goldbach => goldbach 100 (by decide) ⟨50, rfl⟩
