# The three kinds of box

```lean
import Mathlib.Data.Nat.Basic
import Plaer.Latex
```

This paper shows the three kinds of box PLAER makes, and every answer a play button can give.

## Statement

A `def … : Prop` becomes a **Statement** box: a claim written down, not assumed true. Each `-- proof:` line under it attaches a proof file, and each proof gets its own play button. Proofs always live in separate files.

```lean
/-- Adding zero -/
def Basics.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean Basics.Proofs.add_zero
-- proof: proofs/AddZeroBySimp.lean Basics.Proofs.add_zero_by_simp
```

## Definition

Any other `def` becomes a **Definition** box. Switch between its LaTeX and the Lean you wrote.

```lean
/-- Doubling a natural number -/
def Basics.double (n : ℕ) : ℕ := n + n
```

## Lean

All other Lean is folded into one **Lean** line, because it matters to Lean, not to the reader. That includes imports (the folded line at the top), structures, quick checks such as `example`, and LaTeX notation rules. This one checks that doubling 3 gives 6, and tells the LaTeX view how to write `Basics.double`:

```lean
example : Basics.double 3 = 6 := rfl

open Lean LeanTeX in
latex_pp_app_rules (const := Basics.double)
  | _, #[n] => do
    let n ← latexPP n
    return LatexData.atomString "\\operatorname{double}" ++ n.parens
```

With that rule, a statement about `Basics.double` has a LaTeX view:

```lean
/-- Doubling is multiplying by two -/
def Basics.double_statement : Prop := ∀ n : ℕ, Basics.double n = 2 * n
-- proof: proofs/Double.lean Basics.Proofs.double_eq_two_mul
```

## What the play button says

- **Proved**: Lean accepts the proof, and it proves exactly the statement shown. Every proof above says this.
- **Not proved**: anything else. The proof is wrong, its file is missing, it uses `sorry`, or it proves a different statement. The box below has a wrong proof and a missing proof file.
- **Not checked**: the statement changed since its proofs were last checked. Press play to check again.
- **Unavailable**: the PLAER server could not run the check, for example because it stopped.

```lean
/-- Incorrect Theorem -/
def Namespace.name_statement : Prop :=
  ∀ n : ℕ, n + 1 = n
-- proof: proofs/File.lean Namespace.Proofs.name
-- proof: proofs/Missing.lean Namespace.Proofs.missing
```

A statement with no `-- proof:` line has no play button. Its box says that no proof is attached.

```lean
/-- Multiplying by one -/
def Basics.mul_one_statement : Prop := ∀ n : ℕ, n * 1 = n
```
