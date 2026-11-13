# Theorems, conjectures, definitions, and axioms

| File | Role |
| --- | --- |
| `Paper.md` | The one file you write. It shows every kind of box (definition, conjecture, theorem, axiom, folded Lean), each with a short explanation, and every answer a play button can give. |
| `Statements.lean` | Generated from `Paper.md`, line for line. This is what Lean compiles and what proofs import. |
| `proofs/AddZero.lean`, `proofs/AddZeroBySimp.lean` | Two separate proofs of the adding-zero statement. Both are proved. |
| `proofs/Double.lean` | The proof of the doubling claim. |
| `proofs/Hundred.lean` | A proof that uses the Goldbach axiom, so its theorem names the axiom. |
| `proofs/Notation.lean` | Proofs of the notation examples. |
| `proofs/File.lean` | A deliberately wrong proof, to show **Not proved**. The paper also names a proof file that does not exist. |

From the repository root:

```sh
python scripts/serve.py examples/Basics/Paper.md
```
