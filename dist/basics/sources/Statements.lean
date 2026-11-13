-- # Definitions and statements

-- ```lean
import Mathlib.Data.Nat.Basic
import Plaer.Latex
-- ```

-- ```lean
/-- Doubling a natural number -/
def Basics.double (n : ℕ) : ℕ := n + n
-- ```

-- A definition box shows what a name means. Displaying it does not assert a theorem. Lean can still compute with it, so a quick example is a good way to show a definition at work:

-- ## Read the statement

-- For every natural number $n$, adding zero leaves $n$ unchanged: $n+0=n$. The variable ranges over nonnegative whole numbers.

-- For a counter in an application, $n$ could represent the current count and $0$ an update with no additional items. That correspondence is a note you supply; the formal statement remains about natural-number addition.

-- Two proofs are attached to this statement, each in its own file. A play button checks one proof against the statement above; it never changes the statement.

-- ## A statement about your own definition

-- The LaTeX view is produced from Lean's own expression, and it refuses to guess. To use `Basics.double` inside a statement, first say how it should be typeset:

-- ```lean
example : Basics.double 3 = 6 := rfl
-- ```

-- ```lean
/-- Adding zero -/
def Basics.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean Basics.Proofs.add_zero
-- proof: proofs/AddZeroBySimp.lean Basics.Proofs.add_zero_by_simp
-- ```

-- ```lean
open Lean LeanTeX in
latex_pp_app_rules (const := Basics.double)
  | _, #[n] => do
    let n ← latexPP n
    return LatexData.atomString "\\operatorname{double}" ++ n.parens
-- ```

-- ```lean
/-- Doubling is multiplying by two -/
def Basics.double_statement : Prop := ∀ n : ℕ, Basics.double n = 2 * n
-- proof: proofs/Double.lean Basics.Proofs.double_eq_two_mul
-- ```

-- ```lean
/-- Title of the definition -/
def Namespace.name (n : ℕ) : ℕ := n
-- ```

-- ```lean
/-- Incorrect Theorem -/
def Namespace.name_statement : Prop :=
  ∀ n : ℕ, n + 1 = n
-- proof: proofs/File.lean Namespace.Proofs.name
-- ```
