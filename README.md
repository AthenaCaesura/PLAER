<p align="center">
  <img src="docs/assets/plaer-banner.svg" width="640" alt="PLAER — mathematical wordmark and circular play logo">
</p>

<p align="center"><strong>Proof Left As an Exercise for the Reader.</strong></p>
<p align="center">Read Lean definitions and theorem statements, with mathematical notation and your own application notes.</p>

<p align="center">
  <a href="docs/getting-started.md">Get started</a> ·
  <a href="docs/authoring.md">Write a document</a> ·
  <a href="docs/architecture.md">How it works</a> ·
  <a href="docs/development.md">Development</a>
</p>

## A reader for formal statements

PLAER turns named Lean statements into readable mathematical documents. Each
statement has a Lean view, space for authored explanations and application
notes, and a play button for checking its separately mapped proof.

Statements and proofs live in different files. An unproved statement can be a
closed `Prop` definition: it describes a proposition without asserting that it
has been proved. Ordinary theorem declarations are also supported. A project
manifest maps each initially displayed statement to one proof
file and the declaration that file should export.

The build compiles the statement module as a whole. It does not slice arbitrary
Lean files or compile every example's proofs. A play-button check compiles the
mapped proof file and checks its exported declaration against the displayed
proposition. **Source & proof** details show that mapping and the generated checker
command; exported audit files make the check inspectable.

PLAER is a prototype. It supports registered mathematical notation and authored
Markdown notes. Application connections are notes you write yourself; PLAER
does not infer them automatically.

## Examples

The engine has no built-in demonstration. Choose a project explicitly:

| Project | What it illustrates | Manifest | Offline document |
| --- | --- | --- | --- |
| Basics | A small statement with one separate proof. | [Basics/project.json](examples/Basics/project.json) | [Adding zero](dist/basics/index.html) |
| Fermat | Two statements, with an intentionally wrong last-theorem attempt and a valid little-theorem proof. | [Fermat/project.json](examples/Fermat/project.json) | [Fermat document](dist/fermat/index.html) |

```text
Statements.lean       → Definition and theorem boxes
proofs/<claim>.lean   → Play: check that claim's proof
notes.json           → Markdown and user-added boxes
```

The document interface has **+ Definition**, **+ Theorem**, and **+ Markdown**.
Formal boxes select declarations from the source file; theorem boxes map their
own proof file. New boxes can be edited, reordered, removed, and saved.

## View a document

Clone this repository, or choose **Code → Download ZIP** on GitHub and extract it.

```sh
git clone https://github.com/AthenaCaesura/PLAER.git
cd PLAER
```

Open `dist/basics/index.html` or `dist/fermat/index.html` from that folder
in your browser. Scripts, mathematical fonts, styles, and logos are embedded;
viewing a document requires no Lean installation. GitHub's HTML file viewer
shows source, so download the repository to open the actual document.

Offline pages cannot perform fresh Lean checks. Any archived result describes
an earlier check, not a check performed in your browser.

## Build and run a project

After installing Python and Lean as described in the
[setup guide](docs/getting-started.md):

```sh
python scripts/build.py --project examples/Basics/project.json
python scripts/serve.py --project examples/Basics/project.json
```

Open **http://127.0.0.1:8767/**. On macOS or Ubuntu, use `python3` if that
is your Python command. The first build downloads pinned dependencies, and
checking a proof compiles that proof file with Lean.

Use the Fermat manifest instead to run that example. There is no implicit
example selection: pass `--project` or set `PLAER_PROJECT`. Run
`python scripts/check.py` to check all included projects, or add
`--project <manifest>` to check one. The suite requires Node.js as well as
Python and Lean. Windows, macOS, and Ubuntu are covered by the
[cross-platform workflow](https://github.com/AthenaCaesura/PLAER/actions/workflows/ci.yml).

## Repository map

| Location | Purpose |
| --- | --- |
| [Plaer/](Plaer/) | Reusable Lean statement rendering and checking framework. |
| [examples/](examples/) | Independent projects, each with statements, individual proofs, paper, notes, and manifest. |
| [web/](web/) | Shared browser interface and canonical SVG branding assets. |
| [scripts/](scripts/) | Project loading, builds, packaging, serving, and checks. |
| [tests/](tests/) | Lean, Python, and JavaScript regressions and test fixtures. |
| [docs/](docs/) | Setup, authoring, architecture, and development guides. |
| [design/logo/](design/logo/) | Reproducible wordmark source and glyph provenance. |
| [vendor/LeanTeX/](vendor/LeanTeX/) | Maintained LeanTeX source fork and its license. |
| [dist/](dist/) | Per-project documents, source/check audits, and build provenance. |

Local intermediate files go under `build/<project-id>/`; readable checker files
and their audit records accompany each document in `dist/<project-id>/`.
Lake configuration and the pinned Lean toolchain stay at the repository root.

## Renderer and attribution

PLAER uses a local fork of [Kyle Miller's LeanTeX](https://github.com/kmill/LeanTeX),
ported to Lean 4.35.0. Mathematical notation comes from elaborated Lean
expressions. Unsupported notation is rejected rather than guessed.

See the [architecture guide](docs/architecture.md),
[fork notes](vendor/LeanTeX/FORK.md), and
[third-party notices](THIRD_PARTY_NOTICES.md) for implementation and licensing.
