# Architecture

## One paper, separate proofs

A document has one source: `Paper.md`. Its `lean` blocks hold definitions and
statements; everything else is Markdown. Proofs are separate Lean files that
import the paper's module. Nothing else describes a project: there is no
manifest, and box titles come from doc comments.

```text
Paper.md
  │  scripts/paper.py: comment out every line outside a lean block
  ▼
Statements.lean                    same line numbers as the paper
  │  Lean REPL (scripts/lean_repl.py): one long-running Lean with the
  │                                imports loaded; the paper runs as one command
  ▼
Plaer.localReport (Lean)           every declaration: kind, lines, doc comment,
  │                                pretty-printed Lean, LaTeX from LeanTeX
  ▼
scripts/document.py                place boxes by line; attach `-- proof:` lines
  │
  ├─ scripts/verify_proof.py       each proof: one REPL command on top of the
  │                                paper, so proofs never see each other
  ▼
scripts/package_document.py        dist/<project>/index.html + audit files
```

Because the generated Lean file keeps the paper's line numbers, Lean's report
of where each declaration sits says directly where its box belongs in the
paper, and Lean's errors name lines of the paper. Python never parses Lean:
which declarations exist, what kind they are, and how they read all come from
Lean's environment.

Loading Mathlib takes seconds, so PLAER never starts Lean per job. It keeps
one [Lean REPL](https://github.com/leanprover-community/repl) per paper, with
the imports loaded once. Editing the paper reruns only the paper's Lean, and a
proof check costs about a second. A proof file that imports modules the paper
does not is checked in its own Lean process instead. `scripts/build.py` also
compiles `Statements.lean` to a module, so the offline checker files run on
their own with `lake env lean`.

## Conjectures, theorems, and axioms

A claim is a closed definition of type `Prop`:

```lean
def goldbach : Prop := ∀ n : ℕ, n > 2 → 2 ∣ n → ∃ p q : ℕ, p.Prime ∧ q.Prime ∧ p + q = n
```

This defines a proposition; it does not assert it and introduces no axiom.
The page calls it a conjecture until one of its proofs is checked, and a
theorem after. Papers may not contain `axiom`, so a proof can only rest on
Lean's own axioms; an assumption such as Goldbach's conjecture must appear in
the claim, as `goldbach → ...`.

Lean's `collectAxioms` follows every constant a proof uses, transitively,
through Mathlib down to the axioms at the bottom, so its list is complete. It
does not re-check Mathlib's proofs: each was checked by Lean's kernel when
Mathlib was compiled. The check re-runs the kernel only on the new proof.

A proof check compiles a readable checker: the complete proof file, an added
`import Plaer.Check`, and a final `#plaer_check_proof statement proof`. That
command ([Plaer/Check.lean](../Plaer/Check.lean)) requires the proof's type to
be definitionally the displayed proposition, rejects `sorry` and unresolved
metavariables, runs Lean's kernel, and audits axioms. The check's statement
hash must equal the hash of the statement the page displays.

Each check compiles only its own proof file, so a broken proof elsewhere
cannot affect it. Papers contain no proofs: a `theorem` in a paper is
rejected with a message asking for a statement and a proof file.

Saved results are reused only while the paper's Lean is unchanged. Editing
prose keeps them; editing any Lean marks every proof not checked until it runs
again.

## Mathematical notation

LaTeX is printed from elaborated Lean expressions by the maintained
[LeanTeX fork](../vendor/LeanTeX/FORK.md) with PLAER's rules in
[Plaer/Latex.lean](../Plaer/Latex.lean). Rendering is strict: an expression
without a registered form is an error rather than guessed mathematics. In a
document that error is confined to its box, which keeps its Lean view and
reports the reason. This pretty printer is not itself a formal proof that the
LaTeX is equivalent to the Lean.

## The page and the server

`web/paper.js` draws the document from a JSON state embedded in the HTML:
the paper's blocks in order, each Lean block with its boxes. Opened as a file
the page is read-only and shows saved checks.

`scripts/serve.py` serves the same page and adds two operations:

- `POST /api/verify` runs one attached proof.
- `POST /api/document` applies one edit (replace, insert, move, remove a block)
  to `Paper.md`, rebuilds, and returns the new state. If Lean rejects the
  result, the paper is restored and the error returned.

Requests are accepted only from the local page. Lean work runs one request at
a time.

## Repository responsibilities

| Location | Responsibility |
| --- | --- |
| `Plaer/` | Notation rules, declaration reports, and the proof check. No example mathematics. |
| `examples/<Name>/` | A paper, its generated Lean file, and separate proof files. |
| `scripts/` | Paper format, build, proof checks, packaging, server, and check runner. |
| `web/` | The page script and stylesheet, SVG assets, bundled KaTeX and Marked. |
| `tests/` | Engine and pipeline tests, and fixtures. |
| `vendor/LeanTeX/` | Maintained upstream source fork, provenance, and license. |
| `dist/<id>/` | The document, source snapshots, checkers, and audit records. |
| `build/<id>/` | Ignored intermediates, caches, and logs. |
| `design/logo/` | Wordmark construction and glyph provenance. |

Packaging embeds the canonical `web/assets/plaer-wordmark.svg` and
`web/assets/plaer-play.svg`. See the [asset guide](../web/assets/README.md) and
[glyph provenance](../design/logo/SVG-README.md).
