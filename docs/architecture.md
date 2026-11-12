# Architecture

PLAER's current output is a self-contained mathematical paper. Lean supplies
the formal definitions and theorem statements; editable Markdown supplies the
surrounding explanations. The project does not automatically infer how a
statement applies to a user's domain.

## Source to document

```text
Lean declarations + Paper.lean
          ↓
Plaer.Document and Plaer.Latex
          ↓
build/document.html
          ↓
scripts/package_document.py + web assets + explanation cells
          ↓
dist/index.html and dist/build.json
```

`scripts/build.py` builds the Lean paper and runs `Main.lean` to produce the
intermediate document. Packaging then embeds KaTeX, fonts, Marked, SVG branding,
and browser interactions. Packaging does not reconstruct the mathematical
statements. `dist/build.json` records source hashes, dependency information,
and saved theorem-check results for the generated paper.

## Repository map

| Location | Responsibility |
| --- | --- |
| `Paper.lean` | Selects the statements and explanation area in the current paper. |
| `Main.lean` | Renders the Verso paper into the intermediate HTML. |
| `Worker.lean` | Keeps a Lean environment loaded for live checks. |
| `Plaer/Document.lean` | Defines the paper genre and document blocks. |
| `Plaer/Latex.lean` | Registers project-specific notation and enables strict expression rendering. |
| `Plaer/Extract.lean` | Extracts declaration information and the interval fixture's checked samples. |
| `Plaer/Check.lean` | Checks imported theorems and the explicitly registered candidate propositions. |
| `Plaer/Definitions.lean`, `Plaer/Proofs.lean` | Hold the current example declarations and regression fixtures. |
| `Explanations/cells.json` | Stores the paper's editable explanation cells. |
| `web/` | Contains the HTML shell, CSS, browser interactions, and canonical branding assets. |
| `scripts/` | Builds, packages, serves, and checks the project. |
| `tests/` | Groups Lean, Python, and JavaScript regressions by language. |
| `vendor/LeanTeX/` | Contains the maintained LeanTeX source fork and its upstream license. |
| `design/logo/` | Records the mathematical wordmark's glyph sources and reproducible construction. |
| `dist/` | Contains the committed browser-ready paper and its build metadata. |
| `build/`, `.lake/`, `.tools/` | Contain ignored local output, dependency caches, and optional tools. |

## Mathematical rendering

The renderer starts from elaborated Lean expressions. The local
[LeanTeX fork](../vendor/LeanTeX/FORK.md) handles expression traversal,
precedence, parentheses, binders, and extensible printers. `Plaer/Latex.lean`
adds notation for the supported Mathlib objects.

Rendering is strict: unsupported expressions and unregistered constants cause
an error instead of guessed mathematical notation. The renderer is a pretty
printer; it is not itself a formal proof that its LaTeX output is equivalent
to the Lean expression. There is no LLM in this conversion path.

## Saved and live checks

The build records results for the displayed statements. Opening the generated
HTML offline shows those saved results. The local server can check them again
using a warm Lean worker.

The HTTP endpoint accepts only declarations included in the built document.
It checks that the returned statement and notation still match that document.
Changing a formal source requires rebuilding; editing Markdown does not change
the formal declaration. The theorem response does not include proof text.

Fermat's little theorem uses Mathlib's proved result; its proof is kernel checked
and its axiom dependencies are audited. The last-theorem example is a
proposition with a deliberately invalid attempted proof; rejecting that attempt
does not reject the mathematical theorem. Candidate propositions currently
have explicit dispatch code in `Plaer/Check.lean`.

## Explanation storage and assets

In server mode, saving explanation cells updates `Explanations/cells.json`
and repackages the HTML. Offline edits use browser storage, with **Download
paper** providing a portable copy. Markdown cells can contain application notes
and mathematics. The interval fixture also supports plot cells; the current
Fermat paper does not expose an add-plot control.

The app's wordmark and play icon are canonical SVG files under `web/assets/`.
Packaging embeds them into the HTML; the play icon is shared by the header,
favicon, and proof-run controls. The wordmark uses actual KaTeX glyph outlines.
See [the asset guide](../web/assets/README.md) and
[glyph provenance](../design/logo/SVG-README.md).
