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

A fenced block that says exactly ` ```lean ` is Lean. Each declaration in it
becomes a box:

| You write | The document shows |
| --- | --- |
| `def name : Prop := ...` | A **Statement** box with LaTeX and Lean views and its attached proofs. |
| `theorem name : ... := ...` | A **Theorem** box. Its own proof is checked like an attached one and is never displayed. |
| any other `def` | A **Definition** box with LaTeX and Lean views. |
| `structure`, `inductive`, `axiom`, ... | A **Declaration** box with its Lean source. |
| `example`, `#eval`, other commands | A plain Lean code block. |
| `import`, `open`, `namespace`, notation rules | A folded **Lean setup** line. |

A box's title is the first line of the declaration's doc comment; further
lines become a caption. Without a doc comment the title is the name.

```lean
/-- Adding zero -/
def Basics.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
```

Represent a statement you have not proved in the paper as a closed `Prop`
definition, with every parameter bound inside the proposition. This says what
the claim is; it adds no axiom and does not claim a proof exists.

All of a paper's Lean compiles as one module, top to bottom, exactly as if the
blocks were one file. Use ` ```lean ignore ` for Lean you want to show without
compiling it.

## Attach proofs

Put each proof in its own Lean file. It imports the paper's module and proves
the statement by name:

```lean
import Basics.Statements

theorem Basics.Proofs.add_zero : Basics.add_zero_statement := by
  intro n
  exact Nat.add_zero n
```

Attach it with a comment line under the statement, inside the same block:

```lean
def Basics.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean Basics.Proofs.add_zero
-- proof: proofs/AddZeroBySimp.lean Basics.Proofs.add_zero_by_simp
```

The line gives the proof file, relative to the paper's folder, and the
declaration in it. A statement can have any number of proofs, or none. Each
gets its own play button and result.

A check compiles one proof file followed by an audit command. It succeeds only
if the named declaration proves exactly the displayed proposition, contains no
`sorry`, passes Lean's kernel, and uses no axioms beyond `propext`,
`Classical.choice`, and `Quot.sound`. A proof of a different proposition is
rejected even though it compiles. A broken proof file affects only its own row.

Proof files use ordinary `import` headers; the `module` header is not
supported in proof files.

## LaTeX for your own definitions

The LaTeX view comes from Lean's elaborated expression through registered
notation rules, and it never guesses. A statement that mentions a function with
no rule keeps its Lean view and shows what is missing. Register a rule in the
paper, after the definition:

```lean
open Lean LeanTeX in
latex_pp_app_rules (const := Basics.double)
  | _, #[n] => do
    let n ← latexPP n
    return LatexData.atomString "\\operatorname{double}" ++ n.parens
```

This needs `import Plaer.Latex` in the paper's first block. Rules for Mathlib
notation shared by all projects belong in [Plaer/Latex.lean](../Plaer/Latex.lean);
add a case to [tests/lean/Latex.lean](../tests/lean/Latex.lean) for new forms.

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
