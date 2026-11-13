# Fermat example

| File | Role |
| --- | --- |
| `Paper.md` | The one file you write: both statements and the notes about them. |
| `Statements.lean` | Generated from `Paper.md`, line for line. This is what Lean compiles and what proofs import. |
| `proofs/Last.lean` | An intentionally wrong proof attempt for `Fermat.last_statement`. |
| `proofs/Little.lean` | A proof of `Fermat.little_statement` using Mathlib. |

From the repository root:

```sh
python scripts/build.py examples/Fermat/Paper.md
python scripts/serve.py examples/Fermat/Paper.md
```

The last-theorem attempt fails independently; it does not stop the little
theorem's proof file from being compiled and checked.
