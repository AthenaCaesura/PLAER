-- # How PLAER's LaTeX is checked

-- ```lean
import Mathlib.Data.Nat.Notation
import Mathlib.Data.Int.Notation
import Plaer.Formula.RoundTrip
-- ```

-- Every formula in a PLAER paper is written in a small language that Lean knows. Lean gives each formula two things: its LaTeX, and its meaning. Two checks make the LaTeX trustworthy, and this paper lets you verify both without reading any Lean.

-- 1. **Each formula means its claim.** Before a box shows LaTeX, Lean's kernel checks that the formula's meaning is exactly the claim in the paper. If the check fails, the box shows no LaTeX. So every formula you see in any paper has passed this check.
-- 2. **The LaTeX determines the formula.** Lean proves, once, that reading a formula's LaTeX back gives that formula. So two different formulas never look the same. The last section of this paper is that theorem.

-- What is left to verify is that each symbol means what you read it as. Each section below takes one symbol, says what it means, and pins it down with theorems in plainer symbols, and with worked values. Press a play button and Lean proves the theorem. If a symbol meant anything else, its theorems would fail.

-- <!-- cell -->

-- ## Subtraction in ℕ: $a \mathbin{\dot{-}} b$

-- Natural numbers have no negatives, so subtraction in $\mathbb{N}$ stops at $0$. PLAER writes it $\mathbin{\dot{-}}$, never $-$, so it cannot be mistaken for ordinary subtraction.

-- ```lean
/-- Subtracting a smaller number, then adding it back -/
def Spec.monus_add : Prop := ∀ a b : ℕ, a ≥ b → a - b + b = a
-- proof: proofs/Symbols.lean Spec.Proofs.monus_add

/-- Subtracting a larger number gives 0 -/
def Spec.monus_zero : Prop := ∀ a b : ℕ, a < b → a - b = 0
-- proof: proofs/Symbols.lean Spec.Proofs.monus_zero

/-- Worked values -/
def Spec.monus_values : Prop := 7 - 3 = 4 ∧ 3 - 7 = 0
-- proof: proofs/Symbols.lean Spec.Proofs.monus_values
-- ```

-- <!-- cell -->

-- ## Division in ℕ: $\left\lfloor \frac{a}{b} \right\rfloor$

-- Division in $\mathbb{N}$ rounds down, and dividing by $0$ gives $0$. PLAER writes it with the floor brackets, never as a plain fraction.

-- ```lean
/-- The quotient is the largest number whose multiple fits -/
def Spec.div_bounds : Prop := ∀ a b : ℕ, b > 0 → a / b * b ≤ a ∧ a < (a / b + 1) * b
-- proof: proofs/Symbols.lean Spec.Proofs.div_bounds

/-- Dividing by zero gives zero -/
def Spec.div_zero : Prop := ∀ a : ℕ, a / 0 = 0
-- proof: proofs/Symbols.lean Spec.Proofs.div_zero

/-- Worked values -/
def Spec.div_values : Prop := 7 / 2 = 3 ∧ 6 / 2 = 3 ∧ 1 / 2 = 0
-- proof: proofs/Symbols.lean Spec.Proofs.div_values
-- ```

-- <!-- cell -->

-- ## Subtraction in ℤ: $a - b$

-- In $\mathbb{Z}$, subtraction is the ordinary one, written $-$.

-- ```lean
/-- Subtracting, then adding back -/
def Spec.sub_add : Prop := ∀ a b : ℤ, a - b + b = a
-- proof: proofs/Symbols.lean Spec.Proofs.sub_add

/-- A number minus itself -/
def Spec.sub_self : Prop := ∀ a : ℤ, a - a = 0
-- proof: proofs/Symbols.lean Spec.Proofs.sub_self
-- ```

-- <!-- cell -->

-- ## Powers: $a^{n}$

-- ```lean
/-- The zeroth power is 1 -/
def Spec.pow_zero : Prop := ∀ a : ℕ, a ^ 0 = 1
-- proof: proofs/Symbols.lean Spec.Proofs.pow_zero

/-- Each further power multiplies by a once more -/
def Spec.pow_succ : Prop := ∀ a n : ℕ, a ^ (n + 1) = a ^ n * a
-- proof: proofs/Symbols.lean Spec.Proofs.pow_succ

/-- Worked values -/
def Spec.pow_values : Prop := 2 ^ 10 = 1024 ∧ 0 ^ 0 = 1
-- proof: proofs/Symbols.lean Spec.Proofs.pow_values
-- ```

-- <!-- cell -->

-- ## Comparisons: $<$, $\le$, $>$, $\ge$, $\neq$

-- $>$ and $\ge$ are $<$ and $\le$ read from the other side, and $\neq$ is "not equal".

-- ```lean
/-- Greater is less, from the other side -/
def Spec.gt_iff : Prop := ∀ a b : ℕ, a > b ↔ b < a
-- proof: proofs/Symbols.lean Spec.Proofs.gt_iff

/-- At least is at most, from the other side -/
def Spec.ge_iff : Prop := ∀ a b : ℕ, a ≥ b ↔ b ≤ a
-- proof: proofs/Symbols.lean Spec.Proofs.ge_iff

/-- At most is less than or equal -/
def Spec.le_iff : Prop := ∀ a b : ℕ, a ≤ b ↔ a < b ∨ a = b
-- proof: proofs/Symbols.lean Spec.Proofs.le_iff

/-- Not equal is the negation of equal -/
def Spec.ne_iff : Prop := ∀ a b : ℕ, a ≠ b ↔ ¬a = b
-- proof: proofs/Symbols.lean Spec.Proofs.ne_iff
-- ```

-- <!-- cell -->

-- ## Brackets

-- A formula has brackets exactly where the usual reading needs them. A chain of $+$ and $\mathbin{\dot{-}}$, or of $\cdot$, is read from the left; a chain of $\land$ or $\lor$ from the right.

-- ```lean
/-- Two subtractions in a row are read from the left -/
def Spec.left_grouping : Prop := ∀ a b c : ℕ, a - b - c = a - (b + c)
-- proof: proofs/Symbols.lean Spec.Proofs.left_grouping

/-- Worked values: brackets change the value -/
def Spec.bracket_values : Prop := (2 + 3) * 4 = 20 ∧ 2 + 3 * 4 = 14 ∧ 10 - (4 - 1) = 7 ∧ 10 - 4 - 1 = 5
-- proof: proofs/Symbols.lean Spec.Proofs.bracket_values
-- ```

-- <!-- cell -->

-- ## Functions

-- A function's box shows its domain and range, then its definition. Applying it is written $f(x)$, and a function of two inputs $f(x, y)$.

-- ```lean
/-- Twice a number -/
def Spec.double (n : ℕ) : ℕ := 2 * n

/-- The larger of two numbers -/
def Spec.larger (a b : ℕ) : ℕ := a + (b - a)

/-- Worked values -/
def Spec.function_values : Prop := Spec.double 21 = 42 ∧ Spec.larger 3 8 = 8 ∧ Spec.larger 8 3 = 8
-- proof: proofs/Symbols.lean Spec.Proofs.function_values
-- ```

-- <!-- cell -->

-- ## The LaTeX determines the formula

-- This is the theorem behind point 2 at the top. A formula can be shown when its names are valid and each quantifier binds a variable; every formula PLAER shows is such a formula. Reading back the LaTeX of a formula means splitting it into symbols and reading the symbols with the bracket rules above.

-- ```lean
/-- A formula of PLAER's formula language -/
def Spec.Formula : Type := Plaer.Formula.Raw

/-- A formula that can be shown: its names are valid, and each quantifier binds a variable -/
def Spec.showable (r : Spec.Formula) : Prop := Plaer.Formula.Raw.wf r = true

/-- Reading back the LaTeX of the formula gives the formula -/
def Spec.reads_back (r : Spec.Formula) : Prop := Plaer.Formula.parse (Plaer.Formula.render r) = some r

/-- Every formula that can be shown reads back from its LaTeX -/
def Spec.round_trip : Prop := ∀ r : Spec.Formula, Spec.showable r → Spec.reads_back r
-- proof: proofs/RoundTrip.lean Spec.Proofs.round_trip
-- ```
