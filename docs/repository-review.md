# Repository review and resulting structure

Independent reviews covered branding, organization, and onboarding. The project
now separates its reusable engine from complete example projects.

## Implemented

- The README displays the approved SVG logo and explains the engine before the
  examples. Setup, authoring, architecture, and development have separate guides.
- `Plaer/` contains reusable Lean rendering and exact-proposition checking.
  It imports no example mathematics or proof files.
- `examples/Basics/` and `examples/Fermat/` each contain their own statements,
  paper, notes, project manifest, and individual proof files.
- A play button compiles its mapped proof file, with the complete original file
  preserved in a readable checker and an appended claim-equality/kernel audit.
  An unrelated valid proof cannot stand in for the displayed proposition.
- The reader can inspect the statement source, proof file, exported declaration,
  exact command, generated checker, and audit record under **Source & proof**.
- The document interface supports adding, editing, reordering, and removing
  definition, theorem, and Markdown boxes. Formal boxes reference Lean declarations.
- Tests are grouped by language, interval-specific mathematics lives in test
  fixtures, and one portable command is used locally and in cross-platform CI.
- Generated documents and audit artifacts are grouped under `dist/<project-id>/`.
  Local intermediate files and logs stay under ignored `build/<project-id>/`.

## Boundaries

Statement files compile normally as whole Lean modules. Independent proof files
are not imported by the statement reader. Imported dependencies still follow
normal Lean semantics. Unsupported notation fails explicitly.

Markdown notes are authored explanations. The engine does not infer application
mappings or validate mathematical claims made in Markdown. Formal boxes must
refer to declarations in the chosen project's statements file.

`lakefile.toml`, the pinned toolchain, and the small `Plaer.lean` library entry
remain at the repository root as standard Lean package infrastructure.
