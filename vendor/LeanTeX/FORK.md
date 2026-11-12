# PLAER's LeanTeX fork

This directory is a local source fork of <https://github.com/kmill/LeanTeX>,
based on commit `d66db4582b6cb4d9fa0b6309168103a248a5fd46`.
The original Apache 2.0 license is retained in `LICENSE`; `UPSTREAM.json`
records provenance independently of Git metadata. No hosted GitHub fork is
required to build PLAER. The root Lake project uses this directory as a
path dependency, so upgrades are explicit source changes.

Local changes:

- Target Lean 4.35.0; update string iterators, auxiliary-definition syntax,
  and module headers so the printer can be imported by current Mathlib projects.
- Keep the expression printer independent of ProofWidgets: `LeanTeX.lean`
  does not import `LeanTeX.Widget`, and the package has no dependencies.
  The upstream widget and its widget-specific test remain as reference files;
  they are not part of the supported build.
- Add `Config.strict` to reject unsupported expressions, unresolved variables,
  and constants without registered notation. Upstream permissive behavior
  remains the default for upstream examples. PLAER always enables strict mode.
- Reject parameter-introspection failures rather than silently dropping
  function arguments.

Project-specific Mathlib notation is in `Plaer/Latex.lean`, using this fork's
`latex_pp_const_rule`, `latex_pp_app_rules`, and `def_latex_binop` extension points.
There is no LLM in the conversion path. This is a pretty printer, not a formal
proof that its LaTeX output is equivalent to the input expression.

From the PLAER root, `python scripts/build.py --test` exercises the paper
and strict renderer. `node tests/js/test_latex.cjs` checks the generated formulas
with the same KaTeX distribution bundled in the paper. Upstream core examples
can be checked with `lake env lean vendor/LeanTeX/test/basic.lean` and
`lake env lean vendor/LeanTeX/test/subscript.lean`.
