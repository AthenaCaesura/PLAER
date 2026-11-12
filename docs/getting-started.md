# Getting started

PLAER presents Lean definitions and theorem statements as readable mathematics,
alongside editable explanations. The current example compares two Fermat
statements. It also includes proof-check buttons to demonstrate the difference
between an invalid attempt and a checked theorem.

Application-specific explanations are Markdown notes you write today.
Automatic application mapping is not implemented.

## View the example without installing Lean

1. Obtain the [repository](https://github.com/AthenaCaesura/PLAER). Use **Code →
   Download ZIP** and extract it, or clone it with Git. Access to this private
   repository is required.
2. Open `dist/index.html` from the extracted or cloned folder in your browser.

The HTML includes its fonts, mathematical renderer, logos, and interactions.
It works offline on Windows, macOS, and Ubuntu. Clicking the HTML file on
GitHub shows its source; download it before opening it as a document.

Switch each statement between **LaTeX** and **Lean**. The saved **Proved** and
**Not proved** results describe the checks performed when the paper was built.
Fresh checks require the local server below.

## Build and run live checks

Install Git, Python 3.10 or newer, and Lean through
[elan](https://github.com/leanprover/elan#installation). Python 3.12 is used in
CI. The repository's `lean-toolchain` selects Lean 4.35.0. Python scripts use
only the standard library. Node.js 22 is needed for the JavaScript tests, but
not for serving the paper.

Clone the repository, then run commands from its root:

```sh
git clone https://github.com/AthenaCaesura/PLAER.git
cd PLAER
```

On macOS or Ubuntu, reopen your terminal after installing elan, then run:

```sh
python3 scripts/build.py
python3 scripts/serve.py
```

On Windows, use elan or the included portable-toolchain bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
python scripts/build.py
python scripts/serve.py
```

Open [http://127.0.0.1:8767/](http://127.0.0.1:8767/) and leave the server
terminal running. The first build downloads pinned dependencies and needs
several GB of disk space and RAM. The server also takes time to load Mathlib
on startup; subsequent proof checks reuse that process.

If port 8767 is occupied, run `python scripts/serve.py --port 8768` and open
the corresponding address. On macOS and Ubuntu, use `python3` in place of
`python` if that is your Python command.

## Keep your explanations

Use **Edit** or **+ Markdown** to write explanations, including mathematical
notation. The formal Lean statement is separate from these notes.

| How you opened the paper | Where edits are saved |
| --- | --- |
| `dist/index.html` directly | In browser storage for that file. Use **Download paper** to keep a portable HTML copy containing the notes. |
| The local server | In `Explanations/cells.json`. Saving also updates the generated HTML in `dist/`. |

Clearing browser storage or moving the offline file can make its browser-saved
notes unavailable at the new location. Download a copy when you want to keep or
share those edits. The server writes to this checkout, so its saved notes can
be reviewed in Git like other source changes.

## Next steps

- [Author a paper](authoring.md): select declarations and add explanations.
- [Development](development.md): run checks and troubleshoot the toolchain.
- [Architecture](architecture.md): understand the source-to-document pipeline.
