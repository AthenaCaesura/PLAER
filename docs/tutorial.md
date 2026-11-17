# Your first paper, end to end

This guide takes you from nothing to a checked paper: a definition, a claim
about it, a proof, and a page you can share. It assumes you have installed
Python and Lean as in [Getting started](getting-started.md) and cloned the
repository. Run every command from the repository's folder; on macOS or
Ubuntu, use `python3` if that is your Python command.

## 1. Create the paper

```sh
python scripts/new.py Doubling --title "Doubling"
```

This creates `examples/Doubling/`:

```text
examples/Doubling/
  Paper.md          the file you write
  Statements.lean   generated from Paper.md; never edit it
  proofs/           proofs, one Lean file each
```

It also registers the folder with Lean, and opens the paper at
**http://127.0.0.1:8767/**. The first build loads Lean and Mathlib, which takes
a little while; later edits are quick.

The starter paper has one claim, $\forall n \in \mathbb{N},\; n + 0 = n$, in a
**Conjecture** box. Press its play button. Lean checks the attached proof, and
the box becomes a **Theorem**, listing the axioms the proof rests on.

## 2. Add a definition

Open `examples/Doubling/Paper.md` in any editor, or use the **Edit** and
**+ Definition** buttons on the page. Add a Lean block:

````markdown
```lean
/-- Doubling a number -/
def Doubling.double (n : ℕ) : ℕ := 2 * n
```
````

Save, and reload the page. The new **Definition** box shows the function's type,
$\operatorname{double} : \mathbb{N} \to \mathbb{N}$, and its definition,
$\operatorname{double}(n) \coloneqq 2 \cdot n$. The first line of the `/-- … -/`
comment is the box's title.

## 3. State a claim about it

A claim is a `def … : Prop`. Writing it down does not assert it: it is a
**Conjecture** until a proof of it is checked.

````markdown
```lean
/-- A double is even -/
def Doubling.double_even : Prop := ∀ n : ℕ, 2 ∣ Doubling.double n
-- proof: proofs/Double.lean Doubling.Proofs.double_even
```
````

The `-- proof:` line names the file and the theorem that proves the claim. The
box shows $\forall n \in \mathbb{N},\; 2 \mid \operatorname{double}(n)$, with a
play button that says the proof file is missing.

## 4. Prove it

Create `examples/Doubling/proofs/Double.lean`:

```lean
import Doubling.Statements

theorem Doubling.Proofs.double_even : Doubling.double_even := by
  intro n
  exact ⟨n, rfl⟩
```

Press the play button. The box becomes a **Theorem**. A proof is accepted only
if it proves exactly the displayed claim, has no `sorry`, and uses no axioms
beyond Lean's own (`propext`, `Classical.choice`, `Quot.sound`). A wrong proof
leaves the claim a conjecture and shows Lean's message.

## 5. Write the way it reads

Every formula on the page is LaTeX that Lean itself reads back, through the
[dictionary](../examples/Dictionary/Paper.md), and finds to be exactly your
claim. Lean you write in this style always reads well:

- Quantify every variable up front, with its type: `∀ n a : ℕ, …`.
- Join hypotheses with `∧` before one `→`: `n > 2 ∧ a > 0 → …`.
- State claims about values, not functions: write `∀ x : ℝ, x ^ 2 = x * x`, not
  `(fun x => x ^ 2) = (fun x => x * x)`.
- `-` and `/` on `ℕ` are shown as $\mathbin{\dot{-}}$ and
  $\left\lfloor \frac{a}{b} \right\rfloor$: subtraction stops at $0$ and
  division rounds down.

## 6. When a formula has no LaTeX

If a claim uses something the dictionary has no entry for, its box keeps its
Lean view and says what is missing, for example `No dictionary entry for
Nat.gcd`. Add an entry: one line that pairs the LaTeX with the Lean it means.

```lean
/-- Greatest common divisor -/
latex_notation Doubling.gcd (a b : ℕ) := Nat.gcd a b as:max "\\gcd(" a:0 "," b:0 ")"
```

The entry becomes a **Notation** box showing $\gcd(a,b)$ next to the Lean it
means, so a reader can check it. Now a claim such as
`∀ n : ℕ, Nat.gcd n (Doubling.double n) = n` reads
$\forall n \in \mathbb{N},\; \gcd(n,\operatorname{double}(n)) = n$. Entries
everyone needs belong in the shared dictionary, `examples/Dictionary/Paper.md`.

## 7. Share it

```sh
python scripts/build.py examples/Doubling/Paper.md
```

This compiles the paper, checks every proof, and writes
`dist/doubling/index.html`: one file with everything embedded, which anyone
can open in a browser without Lean. It shows the results of this build.

To come back to the paper later:

```sh
python scripts/serve.py examples/Doubling/Paper.md
```

For everything a paper can contain, see [Writing a document](authoring.md).
