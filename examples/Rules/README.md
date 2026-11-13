# How Lean reads as mathematics

| File | Role |
| --- | --- |
| `Paper.md` | The five display rules, each applied to Mathlib's notions and to notions the paper defines itself, to show that no rule depends on a particular name. |
| `Statements.lean` | Generated from `Paper.md`, line for line. This is what Lean compiles. |

The claims have no proofs attached: they are here for how they read.

From the repository root:

```sh
python scripts/serve.py examples/Rules/Paper.md
```
