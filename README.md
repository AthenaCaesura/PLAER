# PLAER

**Proof Left As an Exercise for the Reader.** A tool for understanding
definitions and theorem statements written in the Lean proof assistant, and
connecting them to your application.

Repository: [AthenaCaesura/PLAER](https://github.com/AthenaCaesura/PLAER).

The original mathematical SVG wordmark is in `web/assets/plaer-wordmark.svg`.
The circular `web/assets/plaer-play.svg` is shared by the app icon and the
buttons that run proof checks. Both are embedded in the standalone HTML.

The current paper compares Fermat’s last theorem with Fermat’s little theorem.
The last theorem is a true statement with an intentionally invalid three-line
proof attempt; **Not proved** refers to that attempt, not to the theorem itself.
The little theorem is proved for every prime p and integer a, using Mathlib’s
`Int.ModEq.pow_prime_eq_self`. Both buttons run the existing kernel checker.

The explanation notebook shows both proof snippets and explains why one fails.
The two statements are generated from Lean through the local LeanTeX fork.
Open `dist/index.html`, or use `python scripts/serve.py` for live verification.

The interval example remains in the source regression fixtures.

## Run on Windows, macOS, or Ubuntu

The generated `dist/index.html` opens offline in a browser on all three systems.
Live Lean checks require a local build and the preview server.

Install Git, Python 3.10+ (3.12 recommended), and Lean via
[elan](https://github.com/leanprover/elan#installation). The `lean-toolchain`
file selects Lean 4.35.0 automatically. Node.js 22+ is only needed for the
JavaScript regression checks. Python uses only its standard library.

On macOS and Ubuntu, after installing elan and reopening your terminal:

```sh
python3 scripts/build.py --test
python3 scripts/serve.py
```

On Windows, install elan or use the optional portable toolchain:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
python scripts/build.py --test
python scripts/serve.py
```

Visit <http://127.0.0.1:8767/>. Keep the terminal running while using live checks.
The first startup loads Mathlib and can take a few minutes; subsequent checks
reuse that Lean process. Use `--port 8768` if the default port is occupied.
Run commands from the repository root. No Git submodules are needed: the
LeanTeX fork is included as ordinary source files, including its license.

The scripts find elan in `~/.elan/bin`, or the portable Windows toolchain.
For a custom toolchain location, set `PLAER_LEAN_BIN` to its `bin` directory.
Build parallelism defaults to two threads to limit memory use; override with
`LEAN_NUM_THREADS`. Allow several GB of RAM and disk space for Mathlib.

The CI workflow builds the paper and tests the renderer, notebook persistence,
and live Lean checks on `ubuntu-latest`, `macos-latest`, and `windows-latest`.
Each successful job uploads a self-contained paper artifact. Cross-platform
CI results, rather than the local Windows test, establish platform validation.

The first build downloads dependencies. `lake-manifest.json` records exact
revisions of Verso, Mathlib, and their dependencies. Subsequent builds use them.

To test the live endpoint against the external proof module:

```powershell
python scripts/test_verification.py
```

The paper refers to a theorem by name, without including its proof:

```text
:::theoremStatement Plaer.fermat_little (title := "Fermat’s little theorem")
:::
```

The `theoremStatement` expander and the preview server share `Plaer/Check.lean`.
Both call `Plaer/Latex.lean`, which generates mathematical notation from the
elaborated expression using our local LeanTeX fork. The renderer supports
quantifiers, implications, arithmetic, fractions, functions, membership, and
set builders, with registered names for the paper's Mathlib objects. It rejects
unsupported expressions or unregistered constants instead of emitting debug
output or guessing notation.

## Lean-to-LaTeX engine

`vendor/LeanTeX` is a local source fork of [kmill/LeanTeX](https://github.com/kmill/LeanTeX),
based on commit `d66db4582b6cb4d9fa0b6309168103a248a5fd46`, ported to Lean 4.35.0.
Lake uses it as a path dependency. `vendor/LeanTeX/FORK.md` describes the changes;
its Apache 2.0 license and upstream provenance are retained. Building does not
require a hosted GitHub fork or the upstream ProofWidgets integration.

The fork provides expression traversal, precedence and parentheses, binders,
and extensible printers. `Plaer/Latex.lean` adds our Mathlib notation and
enables strict rendering. Add notation through `latex_pp_const_rule`,
`latex_pp_app_rules`, or `def_latex_binop`; keep mathematical content in Lean
declarations. Definition notation reads the declaration's actual value, while
theorem notation reads its type. Neither is reconstructed from the plot's bounds.

`python scripts/build.py --test` runs the interval and general-renderer regression
checks. `node scripts/test_latex.cjs` then validates their output with the bundled
KaTeX renderer. The upstream core examples are retained under `vendor/LeanTeX/test`.


## Current example

`Plaer/Proofs.lean` contains the last-theorem proposition and invalid attempt,
and the valid little-theorem proof. `Paper.lean` selects the two cards.
`Explanations/cells.json` contains the editable explanations and proof snippets.

The last theorem is not introduced as an axiom. Its attempted proof is elaborated
against the actual proposition and rejected. The little theorem is kernel checked
and its axiom dependencies audited. Offline HTML records saved results; the local
server performs fresh checks.

Run `node scripts/test_fermat.cjs` for the rendered example checks and
`python scripts/test_verification.py` for the actual HTTP/Lean checks.
