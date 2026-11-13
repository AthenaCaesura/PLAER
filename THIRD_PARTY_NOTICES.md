# Third-party notices

The Lean-to-LaTeX engine is a locally maintained source fork of Kyle Miller's
LeanTeX, based on commit `d66db4582b6cb4d9fa0b6309168103a248a5fd46`.
It is released under Apache 2.0. Its full license is retained at
`vendor/LeanTeX/LICENSE`; provenance and local modifications are documented in
`vendor/LeanTeX/UPSTREAM.json` and `vendor/LeanTeX/FORK.md`.

LeanTeX: <https://github.com/kmill/LeanTeX>

The generated standalone document includes KaTeX 0.16.22 JavaScript, styles,
and fonts, copied into `web/vendor/`. KaTeX is released under the MIT license,
retained at `web/vendor/katex.LICENSE`.

KaTeX: <https://github.com/KaTeX/KaTeX>

The document also bundles Marked 15.0.12 from `web/vendor/`. Marked is released
under the MIT license; its copyright and license notice are retained at
`web/vendor/marked.LICENSE.md`.

Marked: <https://github.com/markedjs/marked>

Lean and Mathlib are dependencies, retained with their upstream license files
in `.lake/packages` and the Lean toolchain. This prototype does not change or
relicense those projects.
