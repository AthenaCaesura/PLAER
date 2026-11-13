# Theorems, conjectures, and definitions

| File | Role |
| --- | --- |
| `Paper.md` | The one file you write. It shows every kind of box (definition, conjecture, theorem, folded Lean), each with a short explanation, and every answer a play button can give. |
| `Statements.lean` | Generated from `Paper.md`, line for line. This is what Lean compiles and what proofs import. |
| `proofs/Gauss.lean` | Two proofs of Gauss's formula, both from the paper's definition of the triangular numbers. |
| `proofs/Primes.lean` | Euclid's theorem, and a theorem that assumes Goldbach's conjecture in its statement. |
| `proofs/Notation.lean` | Proofs of the notation examples. |
| `proofs/File.lean` | A deliberately wrong proof of Euler's false claim, to show **Not proved**. The paper also names a proof file that does not exist. |

From the repository root:

```sh
python scripts/serve.py examples/Basics/Paper.md
```
