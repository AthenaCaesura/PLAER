# Architecture

PLAER is a reusable statement-reader framework. Example mathematics lives in
independent project directories. A manifest joins a statement source, document
composition, notes, output directory, and explicit statement-to-proof mappings.

## Statement and proof separation

Unproved statement inputs can be closed definitions of type `Prop`. For example:

```lean
def add_zero_statement : Prop := ∀ n : Nat, n + 0 = n
```

This defines a proposition; it does not assert that the proposition is true and
does not introduce an axiom. A proof lives in a separate file and exports a
declaration named by the project manifest.

The statement module compiles as a whole. This is not declaration slicing:
unrelated invalid code in that module can still prevent its compilation.
Separating proof files keeps a broken proof from preventing statement reading.

A play-button check compiles a readable checker containing the complete mapped
proof file, an added checker import, and a final exact-proposition audit.
The proof's exported declaration must actually prove
that proposition. Imported dependencies of the proof still compile normally.
A bad proof in another independent proof file is outside that check's imports.

## Project context

`scripts/project.py` loads each manifest into a `Project` context containing
resolved input/output paths and its statement mappings. Paths are relative to
the manifest directory and must stay inside the repository. A manifest is
chosen explicitly or through `PLAER_PROJECT`; there is no example default.

Each project has its own notes file, `build/<id>/` intermediates, output
directory, and proof mappings. Framework modules do not import example proof
files. See the [manifest guide](authoring.md#project-manifest).

## Build and inspection

```text
project manifest
  ├─ statement-only Lean module + project paper
  ├─ authored Markdown notes
  └─ statement → individual proof-file mappings
                    ↓
          Lean statement rendering
                    ↓
        project intermediate document
                    ↓
         shared browser asset packaging
                    ↓
    per-project HTML + provenance + audit
```

The build reads elaborated Lean expressions, not a browser-side reconstruction
of their mathematics. The maintained
[LeanTeX fork](../vendor/LeanTeX/FORK.md) supplies traversal, precedence,
parentheses, binders, and extensible printers. PLAER enables strict rendering:
unsupported notation causes an error instead of guessed mathematics. This
pretty printer is not itself a formal proof of the LaTeX output's equivalence.

The browser's **Source & proof** details expose the original statement source, exact
proof path, exported declaration, and generated checker command. Each output
also includes `audit.json` and `checks/*.lean` files so the mapping and checker
can be inspected independently of the interface.

Any archived proof result describes an earlier check. A live request must check
the selected proof against the displayed statement, not merely report that an
unrelated module compiled.

## Repository responsibilities

| Location | Responsibility |
| --- | --- |
| `Plaer/` | Reusable document blocks, statement extraction, notation, and checking support. |
| `examples/<name>/` | A manifest, statement source, project paper, notes, and separate proof files. |
| `scripts/` | Shared project loading, build, packaging, server, and check commands. |
| `web/` | Shared browser UI, styling, and canonical SVG assets. |
| `tests/` | Engine regressions, integration checks, and fixtures. |
| `vendor/LeanTeX/` | Maintained upstream source fork, provenance, and license. |
| `dist/<id>/` | Browser-ready project output and inspectable check artifacts. |
| `build/<id>/` | Ignored intermediate output and compilation logs. |
| `design/logo/` | Wordmark construction and mathematical-glyph provenance. |

## Notes and branding

Markdown cells provide authored explanations and application notes; the engine
does not infer domain mappings. Server saves update the selected project's
notes file and repackage its document. Offline edits use browser storage and
can be included in a downloaded HTML copy.

Packaging embeds the canonical `web/assets/plaer-wordmark.svg` and
`web/assets/plaer-play.svg`. The play SVG is shared by the header, favicon,
and proof-run controls. See the [asset guide](../web/assets/README.md) and
[glyph provenance](../design/logo/SVG-README.md).
