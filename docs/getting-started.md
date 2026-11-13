# Getting started

PLAER displays formal Lean statements with mathematical notation and editable
explanations. A project's statement module is separate from its proof files.
You can read the document without inspecting or running a proof.

Application-specific explanations are Markdown notes you write today.
Automatic application mapping is not implemented.

## View a document without installing Lean

1. Obtain the [repository](https://github.com/AthenaCaesura/PLAER). Choose
   **Code → Download ZIP** and extract it, or clone it with Git. Access to this
   private repository is required.
2. Open `dist/basics/index.html` for a small example, or
   `dist/fermat/index.html` for the Fermat example.

Each HTML file includes its fonts, mathematical renderer, logos, and browser
interactions. It works offline on Windows, macOS, and Ubuntu. Clicking an HTML
file on GitHub shows source; download it before opening it as a document.

Switch a statement between **LaTeX** and **Lean**. Open **Source & proof** to inspect its
original source, mapped proof file, exported proof declaration, and generated
checker command. Offline pages cannot perform a fresh Lean check; any archived
status describes a previous check.

## Build and run live checks

Install Git, Python 3.10 or newer, and Lean through
[elan](https://github.com/leanprover/elan#installation). Python 3.12 is used in
CI. The repository's `lean-toolchain` selects Lean 4.35.0. Python scripts use
only the standard library. Node.js 22 is needed for JavaScript tests, but not
for serving a document.

Clone the repository and run commands from its root:

```sh
git clone https://github.com/AthenaCaesura/PLAER.git
cd PLAER
```

On macOS or Ubuntu, reopen your terminal after installing elan, then run:

```sh
python3 scripts/build.py --project examples/Basics/project.json
python3 scripts/serve.py --project examples/Basics/project.json
```

On Windows, use elan or the portable-toolchain bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
python scripts/build.py --project examples/Basics/project.json
python scripts/serve.py --project examples/Basics/project.json
```

Open [http://127.0.0.1:8767/](http://127.0.0.1:8767/) and leave the terminal
running. Use the play button to compile and check that statement's mapped proof
file. Building the statement document does not require a successful proof of
each proposition.

To run the other example, replace the manifest with
`examples/Fermat/project.json`. If the port is occupied, add `--port 8768`
to the server command and open the corresponding address.

The first build downloads pinned dependencies and needs several GB of disk
space and RAM. Preparing Lean for a project can also take time. Statements and
proofs remain separate: the statement module compiles as a whole; the tool does
not extract selected declarations from an arbitrary broken Lean file.

## Choose a project

Build, serve, and packaging commands require `--project <manifest.json>` or
the `PLAER_PROJECT` environment variable. There is no built-in default example.
Manifest paths are interpreted relative to the manifest's own directory.

For example, set the variable for the current terminal:

```sh
export PLAER_PROJECT=examples/Basics/project.json
python3 scripts/build.py
python3 scripts/serve.py
```

In PowerShell:

```powershell
$env:PLAER_PROJECT = "examples/Basics/project.json"
python scripts/build.py
python scripts/serve.py
```

## Keep your explanations

Use **+ Definition**, **+ Theorem**, or **+ Markdown** to add boxes. Formal
boxes select existing declarations from the statements file; theorem boxes also
map their proof file. See [adding boxes](authoring.md#add-boxes-in-the-document).
Use **Edit**, move, and remove controls to arrange your content.

| How you opened the document | Where edits are saved |
| --- | --- |
| An HTML file directly | In browser storage for that file. Use **Download paper** to keep a portable HTML copy containing the notes. |
| The local server | In the notes file named by the selected manifest, such as `examples/Basics/notes.json`. Saving also updates that project's generated HTML. |

Clearing browser storage or moving the offline file can make its browser-saved
notes unavailable at the new location. Download a copy to keep or share edits.
Server-saved notes can be reviewed in Git like other source changes. A downloaded
HTML copy preserves rendered formal boxes; keep the complete output folder if
you also want its linked source files and audit records.

## Next steps

- [Author a project](authoring.md): map your statements, proofs, and notes.
- [Development](development.md): run checks and troubleshoot the toolchain.
- [Architecture](architecture.md): understand project isolation and the pipeline.
