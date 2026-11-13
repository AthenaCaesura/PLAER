# Every kind of box

| File | Role |
| --- | --- |
| `Paper.md` | The one file you write. It shows every kind of box, each with a short explanation, and every answer a play button can give. |
| `Statements.lean` | Generated from `Paper.md`, line for line. This is what Lean compiles and what proofs import. |
| `proofs/AddZero.lean`, `proofs/AddZeroBySimp.lean` | Two separate proofs of the adding-zero statement. Both are proved. |
| `proofs/Double.lean` | The proof of the doubling statement. |
| `proofs/File.lean` | A deliberately wrong proof, to show **Not proved**. The paper also names a proof file that does not exist. |

From the repository root:

```sh
python scripts/serve.py examples/Basics/Paper.md
```
