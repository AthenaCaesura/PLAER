# Writing a document

A project is a folder with one paper and, separately, its proofs:

```text
examples/MyTopic/
  Paper.md           definitions, statements, and notes: the file you write
  Statements.lean    generated from Paper.md; do not edit
  proofs/*.lean      proofs
```

Create one with `python scripts/new.py MyTopic`. That writes a starter paper
with one statement and its proof, registers the folder in the `Examples`
library of `lakefile.toml`, and opens the editor. The folder name is the Lean
module name, so it must be a capitalized Lean identifier such as `MyTopic`.

## The paper

`Paper.md` is ordinary Markdown. The first `# heading` is the document title.
Write `$...$` and `$$...$$` for mathematics in your notes.

A fenced block that says exactly ` ```lean ` is Lean. The boxes are the things
Lean has: definitions, and claims, which are conjectures until proved.

| You write | The document shows |
| --- | --- |
| any `def` that is not a claim | A **Definition** box: its type, such as `triangle : ℕ → ℕ`, then its formula, with a Lean view. |
| `structure`, `class`, `inductive` | A **Definition** box with its type, then its fields (structure, class) or constructors (inductive), each with its type. |
| `def name : Prop := ...` (a proposition) | A **Conjecture** box, with a play button for each attached proof. |
| the same, once a play button proves it | A **Theorem** box. It lists the axioms of Lean's logic its proof uses, and says so if the proof was checked earlier, such as when the page was built. |
| anything else: imports, `instance`, notation rules, `example`, ... | One folded **Lean** line. |

A `theorem` in the paper is an error, because a `theorem` carries its proof:
write it as a conjecture with a proof file. An `axiom` is an error, because
every proof could quietly assume it: write it as a conjecture and put it in
the claims that depend on it, `def Q : Prop := Goldbach → ...`. `sorry` is an
error too. A proof may use only Lean's own axioms (`propext`,
`Classical.choice`, `Quot.sound`). Imports
come before all other Lean, and the editor refuses to move a box above them.

The LaTeX view knows Lean's logic and arithmetic, sets, and this Mathlib
notation: `∣`, `gcd`, `min`, `max`, `|x|`, `√x`, `n!`, `choose`, `∑` and `∏`
over a `Finset` (with limits over `Finset.range`), `exp`, `log`, `sin`,
`cos`, `π`, primes, and `≡ [ZMOD n]`. Names defined in the paper print by
their own name. Any other name shows "No LaTeX" with the Lean view, until a
rule is added (see below).

A box's title is the first line of the declaration's doc comment; further
lines become a caption. Without a doc comment the title is the name.

```lean
/-- Gauss's formula -/
def Basics.gauss_statement : Prop := ∀ n : ℕ, 2 * Basics.triangle n = n * (n + 1)
```

Write every claim as a closed `Prop` definition, with every parameter bound
inside the proposition. This says what the claim is; it adds no axiom and does
not claim a proof exists.

All of a paper's Lean compiles as one module, top to bottom, exactly as if the
blocks were one file. Use ` ```lean ignore ` for Lean you want to show without
compiling it.

## Attach proofs

Put proofs in their own Lean files. A proof file imports the paper's module
and proves the claim by name:

```lean
import Basics.Statements

theorem Basics.Proofs.triangle_succ (n : ℕ) :
    Basics.triangle (n + 1) = Basics.triangle n + (n + 1) := by
  unfold Basics.triangle
  exact Finset.sum_range_succ _ _
```

Attach it with a comment line under the claim, inside the same block:

```lean
def Basics.gauss_statement : Prop := ∀ n : ℕ, 2 * Basics.triangle n = n * (n + 1)
-- proof: proofs/Gauss.lean Basics.Proofs.gauss_by_induction
-- proof: proofs/Gauss.lean Basics.Proofs.gauss_by_steps
```

The line gives the proof file, relative to the paper's folder, and the
declaration in it. A claim can have any number of proofs, or none. Each gets
its own play button and result.

A check compiles one proof file followed by an audit command. It succeeds only
if the named declaration proves exactly the displayed proposition, contains no
`sorry`, passes Lean's kernel, and uses no axioms beyond `propext`,
`Classical.choice`, and `Quot.sound`. A proof of a different proposition is
rejected even though it compiles. A broken proof file affects only its own row.

Proof files use ordinary `import` headers; the `module` header is not
supported in proof files.

## LaTeX for your own definitions

Names the paper defines print as themselves: a claim that uses
`Basics.triangle n` reads $\operatorname{triangle}(n)$. Mathlib names need a
notation rule, and the common ones are listed above. A claim that uses a
Mathlib name with no rule keeps its Lean view and says what is missing. Rules
for Mathlib notation belong in [Plaer/Latex.lean](../Plaer/Latex.lean); add a
case to [tests/lean/Latex.lean](../tests/lean/Latex.lean) for each one.

## Write useful notes

Useful notes explain:

- What the inputs and types represent.
- Which assumptions must hold.
- What the conclusion guarantees.
- Which object or constraint in your application corresponds to each symbol.
- A concrete example, and a situation where an assumption fails.

An `example` in a `lean` block is checked by Lean when the paper compiles, so
it is a good way to back a note with a verified instance. Notes themselves are
your explanations: PLAER does not verify claims made in Markdown.

## Build and inspect

```sh
python scripts/build.py examples/MyTopic/Paper.md
python scripts/serve.py examples/MyTopic/Paper.md
```

Open **Source & proof** on a statement to inspect its source line, each proof
file, the generated checker, and the command to rerun it. The output folder
also contains `audit.json`, `checks/*.lean`, and snapshots of the sources.
