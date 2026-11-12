const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('build/document.html', 'utf8');
const decode = text => text.replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const blocks = Array.from(html.matchAll(/data-proof="([^"]*)"/g), match => JSON.parse(decode(match[1])));
assert.equal(blocks.length, 2);
assert.equal(blocks[0].report.name, 'Plaer.fermat_last_statement');
assert.equal(blocks[0].report.result.ok, false);
assert(!/data-point=|proof-idea|proof-details|proof-diagnostics/.test(html));
assert(!/norm_num|Proof code|About this definition|One definition · two representations/.test(html));
assert(!/\bby\b/.test(fs.readFileSync('Paper.lean', 'utf8')));

class Element {
  constructor(dataset = {}) { this.dataset = dataset; this.attributes = {}; this.events = {}; this.hidden = false; }
  addEventListener(type, callback) { this.events[type] = callback; }
  setAttribute(name, value) { this.attributes[name] = value; }
  removeAttribute(name) { delete this.attributes[name]; }
  fire(type) { return this.events[type]?.({target: this}); }
}

async function main() {
  const entries = blocks.map(data => {
    const fields = new Map();
    const field = selector => { if (!fields.has(selector)) fields.set(selector, new Element()); return fields.get(selector); };
    const tabs = ['latex', 'lean'].map(theoremView => new Element({theoremView}));
    const panels = ['latex', 'lean'].map(statementPanel => new Element({statementPanel}));
    const card = new Element({proof: JSON.stringify(data)});
    card.querySelector = field;
    card.querySelectorAll = selector => selector === '[data-theorem-view]' ? tabs : panels;
    return {card, tabs, panels, field, data};
  });
  vm.runInNewContext(fs.readFileSync('web/theorems.js', 'utf8'), {
    document: {querySelectorAll: () => entries.map(entry => entry.card)}, console,
    katex: {render: (latex, node) => { node.textContent = latex; }},
  });
  assert.notEqual(entries[0].tabs[0].id, entries[1].tabs[0].id);
  assert.equal(entries[0].field('.theorem-label').textContent, 'Statement');
  assert.equal(entries[0].field('.proof-status').textContent, 'Not proved · from save; not run in this session');
  entries[0].card.proofController.attachVerifier(async () => entries[0].data.report);
  await entries[0].field('.verify-proof').fire('click');
  assert.equal(entries[0].field('.proof-status').textContent, 'Not proved');
  const {card, tabs, panels, field, data} = entries[1];
  assert.equal(field('.verify-proof').attributes['aria-label'], `Run proof: ${data.title}`);
  assert.equal(field('.theorem-math').textContent, data.report.statementLatex);
  tabs[1].fire('click');
  assert.equal(panels[0].hidden, true);
  assert.equal(panels[1].hidden, false);
  let resolveCheck;
  card.proofController.attachVerifier(name => {
    assert.equal(name, data.report.name);
    return new Promise(resolve => { resolveCheck = resolve; });
  });
  const pending = field('.verify-proof').fire('click');
  assert.equal(field('.proof-status').textContent, 'Checking…');
  assert.equal(field('.verify-proof').disabled, true);
  assert.equal(field('.verify-proof').attributes['aria-label'], `Checking proof: ${data.title}`);
  assert.equal(entries[0].field('.proof-status').textContent, 'Not proved');
  resolveCheck(data.report);
  await pending;
  assert.equal(field('.proof-status').textContent, 'Proved');
  assert.equal(field('.verify-proof').attributes['aria-label'], `Run proof: ${data.title}`);
  card.proofController.attachVerifier(async () => ({...data.report, statementHash: 'changed'}));
  await field('.verify-proof').fire('click');
  assert.equal(field('.proof-status').textContent, 'Unavailable');
  console.log('PASS: one statement per box; no proof text; independent toggles and checks; changed statements rejected');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
