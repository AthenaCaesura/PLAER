# Authoring a paper

A paper selects formal Lean declarations and places editable explanations
beside them. Use those notes to describe assumptions, examples, and how a
definition or theorem relates to your application. PLAER does not generate
that application-specific explanation automatically.

## Select a theorem

The current paper lives in `Paper.lean`. Its existing theorem block is:

```text
:::theoremStatement Plaer.fermat_little (title := "Fermat’s little theorem")
:::
```

The block takes a declaration name. It obtains the theorem's actual type and
renders that statement; the paper does not duplicate the proof source.

To add another theorem:

1. Add or import the declaration in the Lean sources. The current examples are
   in `Plaer/Proofs.lean`, imported by `Plaer/Document.lean` and the live worker.
2. Add a `theoremStatement` block to `Paper.lean` with that declaration's name
   and a readable title.
3. Run `python scripts/build.py` and inspect the generated paper.
4. Add explanations through the local server or `Explanations/cells.json`.
5. Run `python scripts/check.py` before committing.

Use `python3` on macOS or Ubuntu if that is your Python command. Start the
local server with `python scripts/serve.py` for fresh proof checks and notes
saved back into the checkout.

## Supported notation

The renderer supports registered mathematical notation; it does not yet
render arbitrary Mathlib statements. An unsupported expression fails the
build instead of being displayed with guessed notation.

Project-specific rules are in `Plaer/Latex.lean`. Extend them through the
vendored LeanTeX registration mechanisms: `latex_pp_const_rule`,
`latex_pp_app_rules`, or `def_latex_binop`. Add a meaningful rendering fixture
in `tests/lean/Latex.lean` and check it with the bundled KaTeX renderer.

Keep mathematical content in the Lean declaration. A definition's notation
comes from its value; a theorem's notation comes from its type. The real
interval in `Plaer/Definitions.lean` remains a definition and plot regression
fixture, although the current Fermat paper displays only theorem statements.

## Write explanations

With the local server running, use **+ Markdown** and **Edit** in the paper.
Markdown supports inline mathematics with `$...$` and display mathematics with
`$$...$$`. Code fences can illustrate source when useful.

Good statement-focused notes answer concrete questions:

- What are the inputs and their types?
- Which assumptions must hold?
- What does the conclusion say about those inputs?
- Which object or constraint in your application corresponds to each symbol?
- What is one example, and where would an assumption fail?

These are authored notes, separate from the checked formal statement. Editing
them does not modify a theorem or prove a claim about your application. See
[saving explanations](getting-started.md#keep-your-explanations) for the
difference between server and offline storage.

## Candidate propositions

The last-theorem demonstration deliberately stores an invalid proof attempt
for a proposition. It is not declared as an axiom or as a successfully proved
theorem. The displayed **Not proved** result refers to that attempt.

Ordinary theorem declarations use the generic named-theorem checker. Adding
a new candidate proposition with its own attempt currently requires explicit
dispatch in `Plaer/Check.lean`; copying a candidate block in the paper alone
does not register a new attempt. Keep proof-checking examples secondary to the
statement and its explanation.
