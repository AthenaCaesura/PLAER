-- # How Lean reads as mathematics

-- ```lean
import Mathlib.Algebra.Group.Defs
import Mathlib.Data.Fintype.Card
import Mathlib.Data.ZMod.Defs
import Mathlib.Algebra.Order.Floor.Defs
import Mathlib.Topology.Instances.Real.Lemmas
import Mathlib.Order.Filter.AtTopBot.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Plaer.Latex
-- ```

-- Lean's notation is built for a type checker, not for a reader. PLAER prints Lean as a mathematician would write it, using five rules. Each rule looks only at the *shape* of an expression and at its types, never at a particular name, and none of them drops information: every variable keeps its type, and every conversion between types is shown. To show that the rules are general, each is applied to Mathlib's own notions and to notions this paper defines itself, which no rule has ever heard of.

-- The claims here have no proofs attached; they are here for how they read. Switch any box to **Lean** to see what was written.

-- <!-- cell -->

-- ## 1. A structure on a type comes with the type

-- In Lean, `[Group G]` is not a true-or-false condition: it is a group structure on $G$, a choice of multiplication, and the claim holds for every such choice. So it reads as mathematicians write it, "for every type $G$ *with* a group structure". Every class prints as its own name.

-- ```lean
/-- In a finite group, every element to the group's order is 1 -/
def Rules.pow_card : Prop :=
  ∀ (G : Type) [Group G] [Fintype G] (g : G), g ^ Fintype.card G = 1

/-- The smaller of two elements is at most either -/
def Rules.min_le : Prop := ∀ (α : Type) [LinearOrder α] (a b : α), min a b ≤ a
-- ```

-- The same rule, for a class this paper defines. `Sized α` is not true or false either: it is a choice of size function on $\alpha$, and $\mathbb{N}$ has many (such as $n \mapsto n$ and $n \mapsto 0$).

-- ```lean
/-- Something with a size -/
class Rules.Sized (α : Type) where
  size : α → ℕ

/-- Two equal things have the same size -/
def Rules.size_eq : Prop :=
  ∀ (α : Type) [Rules.Sized α] (a b : α), a = b → Rules.Sized.size a = Rules.Sized.size b
-- ```

-- Some classes *are* true or false: Lean declares them as propositions, such as `Nonempty α`, "$\alpha$ has an element". Those are hypotheses, and read with $\implies$:

-- ```lean
/-- A type with an element has an element equal to itself -/
def Rules.nonempty : Prop := ∀ (α : Type) [Nonempty α], ∃ x : α, x = x
-- ```

-- <!-- cell -->

-- ## 2. Lean's encodings read as what they encode

-- Lean builds familiar objects out of functions and types. When an encoding is exactly a standard object, it prints as that object.

-- **Several inputs.** Lean's `ℝ → ℝ → ℝ` takes one input and returns a function. A mathematician writes a function of two inputs:

-- ```lean
/-- A commutative operation on the reals -/
def Rules.commutative : Prop := ∀ f : ℝ → ℝ → ℝ, (∀ x y, f x y = f y x) → f 1 2 = f 2 1
-- ```

-- **Functions given by a formula.** Lean writes `fun x : ℝ => x ^ 2`; a mathematician writes $x \mapsto x^2$, with $x$'s type stated, since over $\mathbb{N}$ it would be a different function:

-- ```lean
/-- Squaring is multiplying by itself -/
def Rules.square : Prop := (fun x : ℝ => x ^ 2) = (fun x => x * x)
-- ```

-- **Sets used as types.** `Fin n` and `{x // p x}` are sets of numbers that Lean treats as types. Their elements are not themselves numbers, so using one as a number is a conversion, and shows (see rule 4):

-- ```lean
/-- Every element of Fin 5 is below 5 -/
def Rules.fin_lt : Prop := ∀ i : Fin 5, (i : ℕ) < 5

/-- A positive number is at least 1 -/
def Rules.positive : Prop := ∀ n : {n : ℕ // n > 0}, (n : ℕ) ≥ 1
-- ```

-- **Values of a structure are tuples.** The same rule handles a structure this paper defines. A field that is a proof is never shown: any two proofs of the same claim are interchangeable, so a `Digit`, a number with a proof that it is below 10, is determined by its number, and the type line says it is a `Digit`. A field read from a value is written as a function of it, $\operatorname{value}(d)$:

-- ```lean
/-- A point in the plane, with integer coordinates -/
structure Rules.Point where
  x : ℤ
  y : ℤ

/-- The origin -/
def Rules.origin : Rules.Point := ⟨0, 0⟩

/-- A number below 10 -/
structure Rules.Digit where
  value : ℕ
  small : value < 10

/-- Seven, as a digit -/
def Rules.seven : Rules.Digit := ⟨7, by decide⟩

/-- Every digit is below 10 -/
def Rules.digit_lt : Prop := ∀ d : Rules.Digit, d.value < 10
-- ```

-- **Limits.** Mathlib states limits with filters: `Tendsto f atTop (𝓝 a)`. That is $\lim_{x \to \infty} f(x) = a$, with the variable's type kept, since a sequence ($n \in \mathbb{N}$) and a function on $\mathbb{R}$ have different limits:

-- ```lean
/-- 1/n tends to 0 -/
def Rules.inverse_limit : Prop := Filter.Tendsto (fun n : ℕ => 1 / (n : ℝ)) Filter.atTop (nhds 0)

/-- Squares eventually pass 100 -/
def Rules.eventually_large : Prop := ∀ᶠ n in Filter.atTop, n ^ 2 > (100 : ℕ)
-- ```

-- <!-- cell -->

-- ## 3. An unusual operation looks unusual

-- Some of Lean's operations differ from the textbook ones on ordinary inputs. They never print with the textbook symbol, and the box says what the symbol means.

-- ```lean
/-- Subtracting and adding back can overshoot -/
def Rules.sub_add : Prop := ∀ n m : ℕ, n - m + m ≥ n

/-- Gauss's formula, with division in ℕ -/
def Rules.gauss_div : Prop := ∀ n : ℕ, ∑ i ∈ Finset.range (n + 1), i = n * (n + 1) / 2

/-- Division with remainder in ℤ -/
def Rules.div_mod : Prop := ∀ a b : ℤ, b * (a / b) + a % b = a

/-- Dividing a real number by itself -/
def Rules.div_self : Prop := ∀ x : ℝ, x ≠ 0 → x / x = 1
-- ```

-- <!-- cell -->

-- ## 4. Conversions are always shown

-- In Lean, $3 \in \mathbb{N}$ and $3 \in \mathbb{R}$ are different things, and moving a value from one type to another is a function, a conversion. It prints as Lean writes one, $(x : T)$, "$x$ as an element of $T$", so the type of every operation is visible. The rule covers every function Lean itself marks as a conversion. In the first claim below, $n \in \mathbb{N}$ is halved in $\mathbb{N}$ on the left and in $\mathbb{R}$ on the right. A conversion into $\mathbb{Z}/n\mathbb{Z}$ can make different numbers equal, and the box says so.

-- ```lean
/-- Half of n, in ℕ and in ℝ -/
def Rules.half : Prop := ∀ n : ℕ, ((n / 2 : ℕ) : ℝ) ≤ (n : ℝ) / 2

/-- Modulo 3, 1 and 4 are the same -/
def Rules.mod_three : Prop := ((1 : ℤ) : ZMod 3) = ((4 : ℤ) : ZMod 3)

/-- The floor of x is at most x -/
def Rules.floor_le : Prop := ∀ x : ℝ, (⌊x⌋ : ℝ) ≤ x
-- ```

-- <!-- cell -->

-- ## 5. Elements are written as elements

-- A variable that ranges over the elements of a type reads $x \in T$, and one that ranges over subsets reads $S \subseteq T$. A variable that is itself a function, a type, or a proposition keeps $x : T$, because it is not an element of a set of numbers.

-- ```lean
/-- Every real square is nonnegative -/
def Rules.sq_nonneg : Prop := ∀ x : ℝ, x ^ 2 ≥ 0

/-- Every set of naturals contains its own elements -/
def Rules.subset_refl : Prop := ∀ s : Set ℕ, s ⊆ s

/-- Every function has a value at 0 -/
def Rules.value_at_zero : Prop := ∀ f : ℕ → ℕ, ∃ n : ℕ, f 0 = n

/-- Every type's elements equal themselves -/
def Rules.refl : Prop := ∀ (α : Type) (x : α), x = x
-- ```
