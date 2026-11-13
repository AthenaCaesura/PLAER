# Getting started

PLAER displays Lean definitions and theorem statements with mathematical
notation and your own notes. You can read a document without inspecting or
running a proof.

## View a document without installing Lean

1. Get the [repository](https://github.com/AthenaCaesura/PLAER): choose
   **Code → Download ZIP** and extract it, or clone it with Git.
2. Open `dist/basics/index.html` for a small example, or
   `dist/fermat/index.html` for the Fermat example.

Each HTML file includes its fonts, mathematical renderer, logos, and scripts.
It works offline on Windows, macOS, and Ubuntu. Clicking an HTML file on GitHub
shows its source; download it before opening it as a document.

Switch any box between **LaTeX** and **Lean**. Open **Source & proof** on a
statement to see its source line, each attached proof file and declaration, the
generated checker, and the command that reruns the check. Offline pages show
the checks saved by the last build.

## Build and run live checks

Install Git, Python 3.10 or newer, and Lean through
[elan](https://github.com/leanprover/elan#installation). The repository's
`lean-toolchain` selects Lean 4.35.0. The scripts use only Python's standard
library. Node.js 22 is needed for one test, not for building or serving.

```sh
git clone https://github.com/AthenaCaesura/PLAER.git
cd PLAER
python3 scripts/build.py examples/Basics/Paper.md
python3 scripts/serve.py examples/Basics/Paper.md
```

On Windows, use elan or the portable-toolchain bootstrap, and `python`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
python scripts/build.py examples/Basics/Paper.md
python scripts/serve.py examples/Basics/Paper.md
```

Open [http://127.0.0.1:8767/](http://127.0.0.1:8767/) and leave the terminal
running. If the port is occupied, add `--port 8768`.

The first build downloads Mathlib's prebuilt files and needs several GB of
disk space. Every Lean step that imports Mathlib takes roughly ten seconds.

`build.py` checks every attached proof and writes the document to
`dist/<project>/`. `serve.py` reuses those results, and lets you rerun any
check with its play button.

## Edit the document

With the server running, each box has **Edit**, **↑**, **↓**, and **Remove**,
and the bottom of the page has **+ Definition**, **+ Theorem**, and
**+ Markdown**. Every change is written to the project's `Paper.md`, and the
offline HTML is regenerated.

- Markdown saves at once.
- Lean is compiled first. If Lean rejects it, nothing is saved and you see
  Lean's message with the line in `Paper.md`.
- After Lean changes, the page reruns the attached proof checks.

You can also edit `Paper.md` in any editor; reload the page to see the result.

## Next steps

- [Write a document](authoring.md): the paper format and attaching proofs.
- [Development](development.md): run checks and troubleshoot the toolchain.
- [Architecture](architecture.md): how a paper becomes a checked document.
