# Development

See [Getting started](getting-started.md) for installation. Run these commands
from the repository root; use `python3` if that is your Python command.

## Build and serve one project

```sh
python scripts/build.py --project examples/Basics/project.json
python scripts/serve.py --project examples/Basics/project.json
```

Build and serve require a manifest, either through `--project` or
`PLAER_PROJECT`. Use `examples/Fermat/project.json` for the Fermat project.
A document build compiles its statement module and document composition;
individual proof files are checked through their explicit mappings.

After changing a statement, manifest, or paper, rebuild the project. For shared
CSS, JavaScript, SVGs, or authored notes, packaging an existing intermediate
document is enough:

```sh
python scripts/package_document.py --project examples/Basics/project.json
```

Packaging does not compile Lean or refresh formal statement data.

## Run checks

```sh
python scripts/check.py
python scripts/check.py --project examples/Basics/project.json
```

With no project flag, the check runner covers the included projects. With a
flag, it checks that project. The suite needs Node.js 22, Python, and Lean.
Checks cover Lean rendering, frontend controls, notes and branding, and actual
requests to the local proof-checking endpoint.

Use `python scripts/check.py --help` for available focused or additional
regression options. The test suite is organized under `tests/lean/`,
`tests/python/`, and `tests/js/`. Keep example-specific expectations separate
from generic UI and project-isolation checks.

For a new proof mapping, verify that the correct proof succeeds and that an
incorrect export or proof fails. Also check that a bad proof in a different
independent file does not prevent the selected proof from being checked.
Original source, generated checker, and the displayed mapping should agree.

## Inspect output

Each example's manifest selects its output directory, such as `dist/basics/`.
Inspect `index.html`, build provenance, `audit.json`, and the generated
`checks/*.lean` artifacts. The **Source & proof** control in the document exposes the
same statement-to-proof mapping and checker command.

Local intermediates belong in `build/<project-id>/`; dependency caches and
optional portable tools belong in `.lake/` and `.tools/`. Keep generated
`dist/` output consistent with its sources when committing.

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
