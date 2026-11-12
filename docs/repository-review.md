# Repository organization review

Three independent reviews covered branding, repository structure, and onboarding.

## Findings addressed

- The GitHub landing page named the SVG files but never displayed them. The
  README now embeds a light-backed banner made from the approved SVGs, plus an
  image of the actual document.
- The introduction concentrated on proof attempts and implementation details.
  It now introduces statement reading and application notes, and identifies the
  Fermat document as the current demonstration.
- Setup instructions assumed the reader already had the source. The README and
  getting-started guide distinguish downloading/viewing from building/running.
- Setup, architecture, renderer details, and authoring competed in one README.
  Those now have separate, linked guides.
- Tests were spread between the repository root and application scripts. They
  now live under `tests/lean`, `tests/python`, and `tests/js`, with one portable
  check command used locally and in CI.
- The supported logo generator still emitted a rejected compact icon. It now
  reproduces the approved mathematical wordmark and its provenance.

## Deliberate boundaries

The small root Lean entry points and Lake configuration remain at the root.
Moving them would add import and build churn without improving the reading or
setup experience. `dist/` remains tracked because the standalone document is an
intentional deliverable that can be viewed without installing Lean.

Rejected local logo drafts and the local trademark research are not part of the
published source. The runtime branding assets in `web/assets/` are the files
used by the app; their design provenance is recorded under `design/logo/`.

## Follow-up work

The demo declarations and interval regression fixtures still share some Lean
modules. Separate the example mathematics from the reusable renderer when a
second authored document is added, with explicit example registration instead
of adding more name-based branches to the checker.

Python runtime components currently share `scripts/` with build utilities. A
dedicated runtime package becomes useful if the server grows or is distributed
as an installable application. This review avoids adding packaging machinery
solely to make the directory tree deeper.
