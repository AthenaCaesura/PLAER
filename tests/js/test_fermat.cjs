const path = require('node:path');
process.chdir(path.resolve(__dirname, '../..'));
const assert = require('node:assert/strict');
const fs = require('node:fs');
const katex = require('../../.lake/packages/verso/vendored-js/katex/katex.min.js');
const output = process.env.PLAER_OUTPUT;
assert(output, 'Choose PLAER_OUTPUT');
const build = JSON.parse(fs.readFileSync(path.join(output, 'build.json'), 'utf8'));
if (build.project !== 'fermat') {
  console.log('SKIP: Fermat-specific example checks for another project');
} else {
  const reports = build.theorem_checks;
  assert.deepEqual(reports.map(r=>r.name), ['Fermat.last_statement', 'Fermat.little_statement']);
  assert.equal(reports[0].result.ok, false);
  assert.equal(reports[1].result.ok, true);
  assert.notEqual(reports[0].proofFile, reports[1].proofFile);
  for(const r of reports) {
    katex.renderToString(r.statementLatex,{throwOnError:true,strict:'error'});
    assert(fs.existsSync(path.join(output,r.checkerUrl)));
    assert(fs.existsSync(path.join(output,r.auditUrl)));
  }
  assert(!fs.readFileSync(path.join(output,'index.html'),'utf8').includes('One famous name'));
  console.log('PASS: Fermat is one example with two independent proof files and correct results');
}
