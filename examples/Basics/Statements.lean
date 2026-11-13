-- # Every kind of box

-- ```lean
import Mathlib.Data.Nat.Basic
import Plaer.Latex
-- ```

-- This paper shows every kind of box PLAER makes, and every answer a play button can give.

-- The folded line above is a **Lean setup** box. Imports, `open`, and LaTeX notation rules fold away, because they matter to Lean, not to the reader.

-- ## Definition

-- A `def` that is not a claim becomes a **Definition** box. Switch between its LaTeX and the Lean you wrote.

-- ```lean
/-- Doubling a natural number -/
def Basics.double (n : ℕ) : ℕ := n + n
-- ```

-- ## Lean code

-- Lean that names nothing, such as an `example` or `#eval`, is shown as plain code, with no LaTeX. Lean still checks it whenever the paper compiles: this one confirms that doubling 3 gives 6.

-- ```lean
example : Basics.double 3 = 6 := rfl
-- ```

-- ## Statement

-- A `def … : Prop` becomes a **Statement** box: a claim written down, not assumed true. Each `-- proof:` line under it attaches a proof file, and each proof gets its own play button.

-- ```lean
/-- Adding zero -/
def Basics.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean Basics.Proofs.add_zero
-- proof: proofs/AddZeroBySimp.lean Basics.Proofs.add_zero_by_simp
-- ```

-- ## Theorem

-- A `theorem` carries its proof in the paper itself. It gets a **Theorem** box with a play button like a statement's. The proof is checked but never shown.

-- ```lean
/-- One plus a number -/
theorem Basics.one_add (n : ℕ) : 1 + n = n + 1 := Nat.add_comm 1 n
-- ```

-- ## Declaration

-- A `structure`, `inductive`, or `axiom` becomes a **Declaration** box. It shows only the Lean, because there is no formula to typeset.

-- ```lean
/-- A point with natural-number coordinates -/
structure Basics.Point where
  x : ℕ
  y : ℕ
-- ```

-- ## Notation for your own definitions

-- The LaTeX comes from Lean and never guesses. A statement that uses `Basics.double` needs a rule saying how to write it. That rule is setup, so it folds away too.

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

-- ## What the play button says

-- - **Proved**: Lean accepts the proof, and it proves exactly the statement shown. Every proof above says this.
-- - **Not proved**: anything else. The proof is wrong, its file is missing, it uses `sorry`, or it proves a different statement. The box below has a wrong proof and a missing proof file.
-- - **Not checked**: the statement changed since its proofs were last checked. Press play to check again.
-- - **Unavailable**: the PLAER server could not run the check, for example because it stopped.

-- ```lean
/-- Incorrect Theorem -/
def Namespace.name_statement : Prop :=
  ∀ n : ℕ, n + 1 = n
-- proof: proofs/File.lean Namespace.Proofs.name
-- proof: proofs/Missing.lean Namespace.Proofs.missing
-- ```

-- A statement with no `-- proof:` line has no play button. Its box says that no proof is attached.

-- ```lean
/-- Multiplying by one -/
def Basics.mul_one_statement : Prop := ∀ n : ℕ, n * 1 = n
-- ```
