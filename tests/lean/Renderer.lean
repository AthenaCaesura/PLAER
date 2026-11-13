import fixtures.Interval

open Lean Meta Plaer IntervalFixture

namespace RendererTests

def halfOpen : Set ℝ := {x | -1 < x ∧ x ≤ 2}
def unsupported : Set ℝ := {x | x = 0 ∨ x = 1}

-- Changing the formal bounds and strictness must change the generated notation.
run_meta do
  let shape ← extractInterval ``halfOpen
  unless shape.lower = -1 && shape.upper = 2 && !shape.lowerClosed && shape.upperClosed do
    throwError "Failed to extract the changed interval's bounds and endpoint conventions"
  let latex ← definitionLatex ``halfOpen
  unless latex == "halfOpen \\coloneqq \\left\\{x\\in\\mathbb{R}\\;\\middle|\\; - 1 < x \\le 2\\right\\}" do
    throwError "LaTeX did not reflect the elaborated definition: {latex}"

-- Unsupported plot shapes must fail explicitly, even when the formula can be typeset.
run_meta do
  let rejected ← try
    let _ ← extractInterval ``unsupported
    pure false
  catch _ => pure true
  unless rejected do throwError "The plot extractor silently accepted an unsupported definition"

-- These checks use the original real set, including its exact boundary semantics.
example : (0 : ℝ) ∈ I := by norm_num [I]
example : (1 : ℝ) ∈ I := by norm_num [I]
example : (-(1 : ℝ) / 100) ∉ I := by norm_num [I]
example : ((101 : ℝ) / 100) ∉ I := by norm_num [I]

end RendererTests
