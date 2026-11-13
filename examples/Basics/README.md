# Definitions and statements example

| File | Role |
| --- | --- |
| `Paper.md` | The one file you write: definitions, statements, and notes. |
| `Statements.lean` | Generated from `Paper.md`, line for line. This is what Lean compiles and what proofs import. |
| `proofs/AddZero.lean`, `proofs/AddZeroBySimp.lean` | Two separate proofs attached to the adding-zero statement. |
| `proofs/Double.lean` | The proof attached to the doubling statement. |

From the repository root:

```sh
python scripts/build.py examples/Basics/Paper.md
python scripts/serve.py examples/Basics/Paper.md
```

The paper also shows how to give one of your own definitions a LaTeX form, so
statements that mention it get a LaTeX view.
