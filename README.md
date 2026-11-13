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

PLAER turns Lean definitions and theorem statements into a readable document.
Each one appears in a box that switches between **LaTeX** and **Lean**: a
definition, a conjecture, a theorem, or an axiom. A claim is a conjecture until
one of its proofs is checked, and then it is a theorem. Readers never have to
look at a proof: a box only says where its proofs live and whether Lean
accepts them.

You write **one file per document**, `Paper.md`. It holds the definitions and
theorem statements, as Lean, and your notes and examples, as Markdown:

````markdown
# Two theorems of Fermat

```lean
import Mathlib.FieldTheory.Finite.Basic
```

```lean
/-- Fermat's little theorem -/
def Fermat.little_statement : Prop :=
  ∀ (p : ℕ) (a : ℤ), p.Prime → Int.ModEq (p : ℤ) (a ^ p) a
-- proof: proofs/Little.lean Fermat.Proofs.little
```

If $p$ is prime, every integer $a$ satisfies $a^p\equiv a\pmod p$.
````

**Proofs live in completely separate files.** A `-- proof:` line attaches one
to the statement above it, and a statement can have several. Pressing a play
button compiles that proof file and checks that it proves exactly the displayed
statement. A wrong or broken proof never stops the document from building.

A statement without a proof is a closed `Prop` definition: it says what the
claim is without asserting it. Proofs never go in the paper.

### The file you write and the Lean that is verified

PLAER writes `Statements.lean` beside `Paper.md`. It is the paper with every
line outside a `lean` block commented out, so **line 12 of the paper is line 12
of the Lean file**. That file is what Lean compiles, what proof files import,
and what Lean's error messages point into. The LaTeX in each box is produced
from Lean's elaborated expression, not from the text you typed.

```text
examples/Fermat/Paper.md          you write this
examples/Fermat/Statements.lean   generated; Lean compiles it; proofs import it
examples/Fermat/proofs/*.lean     proofs, attached with `-- proof:` lines
dist/fermat/index.html            the document, as one offline HTML file
```

## Examples

| Project | What it illustrates | Paper | Offline document |
| --- | --- | --- | --- |
| Basics | Every kind of box, with a short explanation of each, and every answer a play button can give. | [Basics/Paper.md](examples/Basics/Paper.md) | [dist/basics](dist/basics/index.html) |
| Fermat | Two statements, with an intentionally wrong last-theorem attempt and a valid little-theorem proof. | [Fermat/Paper.md](examples/Fermat/Paper.md) | [dist/fermat](dist/fermat/index.html) |

## View a document

Clone this repository, or choose **Code → Download ZIP** on GitHub and extract it.

```sh
git clone https://github.com/AthenaCaesura/PLAER.git
cd PLAER
```

Open `dist/basics/index.html` or `dist/fermat/index.html` in your browser.
Scripts, mathematical fonts, styles, and logos are embedded; viewing a document
requires no Lean installation. Offline pages show the result of the last build
and cannot run fresh Lean checks.

## Build, check, and edit

After installing Python and Lean as described in the
[setup guide](docs/getting-started.md):

Start a new paper with one command. It creates `examples/MyTopic/` with a
statement and its proof, registers it with Lean, and opens the editor:

```sh
python scripts/new.py MyTopic
```

To work on an existing paper:

```sh
python scripts/build.py examples/Basics/Paper.md
python scripts/serve.py examples/Basics/Paper.md
```

Open **http://127.0.0.1:8767/**. On macOS or Ubuntu, use `python3` if that is
your Python command. With the server running:

- every play button checks its proof file with Lean;
- **Edit** on any box changes that part of `Paper.md`; **+ Definition**,
  **+ Conjecture**, and **+ Markdown** add boxes; boxes can be moved and removed;
- Lean you type is compiled before it is saved, and rejected with Lean's
  message if it does not compile.

You can equally edit `Paper.md` in your own editor and reload the page.
Run `python scripts/check.py` to build both examples and run every test.

## Repository map

| Location | Purpose |
| --- | --- |
| [Plaer/](Plaer/) | Lean: LaTeX notation rules, declaration reports, and the exact-statement proof check. |
| [examples/](examples/) | Independent projects: a paper, its generated Lean file, and separate proofs. |
| [scripts/](scripts/) | The paper format, the build, proof checks, packaging, and the local server. |
| [web/](web/) | The page: one script, one stylesheet, logos, and bundled KaTeX and Marked. |
| [tests/](tests/) | Lean, Python, and JavaScript tests and fixtures. |
| [docs/](docs/) | Setup, authoring, architecture, and development guides. |
| [design/logo/](design/logo/) | Wordmark source and glyph provenance. |
| [vendor/LeanTeX/](vendor/LeanTeX/) | Maintained LeanTeX source fork and its license. |
| [dist/](dist/) | Per-project documents, source snapshots, checkers, and audit records. |

## Renderer and attribution

PLAER uses a local fork of [Kyle Miller's LeanTeX](https://github.com/kmill/LeanTeX),
ported to Lean 4.35.0. Mathematical notation comes from elaborated Lean
expressions. Notation without a registered LaTeX form is never guessed: that
box keeps its Lean view and says what is missing.

See the [architecture guide](docs/architecture.md),
[fork notes](vendor/LeanTeX/FORK.md), and
[third-party notices](THIRD_PARTY_NOTICES.md) for implementation and licensing.
