# Fermat example

This is one example project using the PLAER engine.

| File | Role |
| --- | --- |
| `Statements.lean` | Defines the two propositions without proving them. |
| `proofs/Last.lean` | An intentionally wrong proof attempt for `Fermat.last_statement`. |
| `proofs/Little.lean` | A proof of `Fermat.little_statement` using Mathlib. |
| `project.json` | Maps each statement to its own proof file and exported declaration. |
| `Paper.lean` | Chooses the initial boxes. |
| `notes.json` | Stores authored notes and boxes added through the interface. |

From the repository root:

```sh
python scripts/build.py --project examples/Fermat/project.json
python scripts/serve.py --project examples/Fermat/project.json
```

The last-theorem attempt fails independently; it does not stop the little
theorem's proof file from being compiled and checked.
