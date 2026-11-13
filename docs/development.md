# Development

See [Getting started](getting-started.md) for installation. Run these commands
from the repository root; use `python3` if that is your Python command.

## Build and serve one project

```sh
python scripts/build.py examples/Basics/Paper.md
python scripts/serve.py examples/Basics/Paper.md
```

Both take a paper or its folder, or read `PLAER_PROJECT`. `build.py`
regenerates `Statements.lean`, compiles it, checks every attached proof, and
writes `dist/<project>/`. `serve.py` does the same without rerunning proofs
that are still valid, then serves the document with live checks and editing.

Changes to `web/paper.js` or `web/paper.css` reach a document the next time it
is built or the server starts.

## Run checks

```sh
python scripts/check.py
python scripts/check.py examples/Basics/Paper.md
```

The runner builds each example, then runs the tests. It needs Node.js 22,
Python, and Lean.

| Test | Covers |
| --- | --- |
| `tests/python/test_paper.py` | The paper format, the line-for-line Lean file, edits. No Lean needed. |
| `tests/python/test_document.py` | A throwaway paper through Lean: every box kind, and proofs that must be rejected. |
| `tests/python/test_server.py` | Editing and checking through the local server. |
| `tests/python/test_branding.py` | The embedded SVG assets. |
| `tests/lean/Latex.lean`, `tests/js/test_latex.cjs` | Notation rules, strict rejection, and KaTeX accepting the output. |

When you change the proof check, confirm that a correct proof succeeds and
that a proof of a different proposition, a `sorry`, and a broken file all fail.

## Inspect output

`dist/<project>/` holds `index.html`, `build.json` (the page's state and build
provenance), `audit.json`, `checks/*.lean` with a `.json` result beside each,
and `sources/` snapshots of the paper, its Lean file, and the proof files.

Local intermediates belong in `build/<project>/`; dependency caches and
optional portable tools belong in `.lake/` and `.tools/`. Keep `dist/` and each
`Statements.lean` consistent with their papers when committing;
`test_paper.py` checks the latter.

## Toolchain and dependencies

- `lean-toolchain` selects Lean 4.35.0. `lake-manifest.json` pins dependency
  revisions; normal builds preserve the manifest.
- `vendor/LeanTeX` is an ordinary source directory used as a Lake path
  dependency. No Git submodule initialization is needed.
- Scripts look for elan in `~/.elan/bin` and the optional portable Windows
  toolchain in `.tools/lean-4.35.0-windows/bin`.
- Set `PLAER_LEAN_BIN` to a custom Lean `bin` directory if necessary.
- `LEAN_NUM_THREADS` defaults to two to limit memory use. Compilation can
  still require several GB of RAM.

If Lean cannot be found, finish installing elan and reopen the terminal. On
Windows, `scripts/bootstrap.ps1` provides a portable alternative. If a
displayed statement is stale, rebuild its project. Use `--port 8768` on the
server command if the usual port is occupied.

## Continuous integration

The [cross-platform workflow](../.github/workflows/ci.yml) covers Windows,
macOS, and Ubuntu. Results are in
[GitHub Actions](https://github.com/AthenaCaesura/PLAER/actions). A successful
local run does not establish that other platforms passed. Keep upstream
attribution and licenses with the vendored source; see
[third-party notices](../THIRD_PARTY_NOTICES.md).
