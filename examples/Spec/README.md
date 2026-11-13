# How PLAER's LaTeX is checked

| File | Role |
| --- | --- |
| `Paper.md` | What each symbol of PLAER's formula language means, pinned down by theorems in plainer symbols and worked values, and the theorem that the LaTeX determines the formula. |
| `Statements.lean` | Generated from `Paper.md`, line for line. |
| `proofs/Symbols.lean` | Proofs of the symbol theorems. |
| `proofs/RoundTrip.lean` | The round-trip theorem, from `Plaer.Formula.parse_render`. |

From the repository root:

```sh
python scripts/serve.py examples/Spec/Paper.md
```
