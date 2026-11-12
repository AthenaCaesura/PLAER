// Check Lean-generated notation with the exact KaTeX distribution used by the paper.
const path = require('node:path');
process.chdir(path.resolve(__dirname, '../..'));
const assert = require('node:assert/strict');
const fs = require('node:fs');
const katex = require('../../.lake/packages/verso/vendored-js/katex/katex.min.js');
const fixtures = JSON.parse(fs.readFileSync('build/latex-tests.json', 'utf8'));
assert(fixtures.length >= 13, 'Run tests/lean/Latex.lean before checking KaTeX');
for (const {source, latex} of fixtures) {
  assert(!latex.includes('\\operatorname{Lean}'), `Debug fallback in ${source}`);
  const html = katex.renderToString(latex, {throwOnError: true, strict: 'error', displayMode: true});
  assert(html.includes('katex-mathml'), source);
}
console.log(`PASS: ${fixtures.length} Lean-generated formulas render with bundled KaTeX`);
