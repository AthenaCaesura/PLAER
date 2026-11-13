# Definitions and statements example

This small project demonstrates the engine independently of the Fermat example.

`Statements.lean` contains a doubling definition and an adding-zero proposition.
`proofs/AddZero.lean` proves the latter. The project manifest maps that proposition
to the proof file and its exported Lean declaration.

```sh
python scripts/build.py --project examples/Basics/project.json
python scripts/serve.py --project examples/Basics/project.json
```

Use **+ Definition**, **+ Theorem**, and **+ Markdown** in the local document
to add boxes. Formal boxes refer to declarations in `Statements.lean`.
Theorem boxes name their proof file and proof declaration. The notes file stores
those references; the source file remains the source of the mathematics.
