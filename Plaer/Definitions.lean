module
public import Mathlib.Basic.Real.Basic

public section

namespace Plaer

/-- The closed unit interval, used by the document and its illustration. -/
@[expose] def I : Set ℝ := {x | 0 ≤ x ∧ x ≤ 1}

end Plaer
