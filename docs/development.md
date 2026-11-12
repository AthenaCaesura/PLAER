# Development

Start with [Getting started](getting-started.md) for installation and normal
use. Run all commands below from the repository root. Use `python3` instead of
`python` on systems where that is the installed Python command.

## Build and check

```sh
python scripts/build.py
python scripts/check.py
```

The first command builds the current paper into `dist/index.html`. The second
runs the full check suite: the build and Lean renderer regressions, JavaScript
rendering and statement controls, Python notebook persistence and SVG branding,
and actual HTTP requests to the Lean verification endpoint.

The full suite needs Node.js 22 in addition to Python and the pinned Lean
toolchain. Allow time for the initial dependency download and Mathlib load.

For the additional regression that temporarily changes the proof source:

```sh
python scripts/check.py --proof-mutation
```

That check confirms a changed invalid proof is rejected, then restores the
original proof file. Avoid editing that file concurrently while it runs.

## Run focused checks

```sh
python scripts/build.py --test
node tests/js/test_latex.cjs
node tests/js/test_fermat.cjs
node tests/js/test_statement_ui.cjs
python tests/python/test_explanations.py
python tests/python/test_branding.py
python tests/python/test_verification.py
```

`build.py --test` prepares the generated fixtures and runs the Lean tests in
`tests/lean/Renderer.lean` and `tests/lean/Latex.lean`, plus the supported
vendored LeanTeX regressions. Run it before the JavaScript rendering checks.

The HTTP verification test starts its own server on an available local port
and checks the actual Lean results. It also checks rejection of undocumented
theorems and unexpected cross-origin requests.

## Work on the paper

```sh
python scripts/build.py
python scripts/serve.py
```

Rebuild after changing formal Lean sources. For CSS, JavaScript, the HTML shell,
or SVG assets, packaging an existing intermediate document is enough:

```sh
python scripts/package_document.py
```

Packaging uses `build/document.html`; it does not compile Lean or refresh the
formal statements. Use the full build whenever those statements changed.

## Toolchain and dependencies

- `lean-toolchain` selects Lean 4.35.0. `lake-manifest.json` pins dependency
  revisions; normal builds preserve that manifest.
- `vendor/LeanTeX` is an ordinary source directory used as a Lake path
  dependency. No Git submodule initialization is needed.
- Scripts look for elan in `~/.elan/bin` and for the optional portable Windows
  toolchain in `.tools/lean-4.35.0-windows/bin`.
- Set `PLAER_LEAN_BIN` to a custom Lean `bin` directory if necessary.
- `LEAN_NUM_THREADS` defaults to two to limit memory use. Compilation and the
  warm verification process still require several GB of RAM.

If Lean cannot be found, finish installing elan and reopen the terminal. On
Windows, the portable alternative is `scripts/bootstrap.ps1`. If the server
reports changed statements, rebuild the paper and reload it. If its port is
occupied, use `scripts/serve.py --port 8768`.

## Continuous integration

The [cross-platform workflow](../.github/workflows/ci.yml) runs on Windows,
macOS, and Ubuntu. Its results are available in
[GitHub Actions](https://github.com/AthenaCaesura/PLAER/actions). Each successful
platform job uploads its generated `dist/` artifact. A local Windows success
does not establish that the other platforms passed.

Keep generated `dist/` output consistent with its sources when committing
changes. Local caches and intermediate output belong in the ignored `build/`,
`.lake/`, and `.tools/` directories. Keep upstream attribution and licenses in
the vendored fork; see [third-party notices](../THIRD_PARTY_NOTICES.md).
