const path = require('node:path');
process.chdir(path.resolve(__dirname, '../..'));
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(process.env.PLAER_OUTPUT, 'index.html'), 'utf8');
const decode = text => text.replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const blocks = Array.from(html.matchAll(/data-proof="([^"]*)"/g), m => JSON.parse(decode(m[1])));
assert(blocks.length > 0);
class Element {
  constructor(dataset={}) { this.dataset=dataset; this.attributes={}; this.events={}; this.children=[]; this.hidden=false; }
  addEventListener(type,callback) { this.events[type]=callback; }
  setAttribute(name,value) { this.attributes[name]=value; }
  removeAttribute(name) { delete this.attributes[name]; }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.children=[...nodes]; }
  focus() {}
  fire(type) { return this.events[type]?.({target:this}); }
}
async function main() {
  const entries = blocks.map(data=>{
    const fields=new Map();
    const field=selector=>{if(!fields.has(selector))fields.set(selector,new Element());return fields.get(selector);};
    const tabs=['latex','lean'].map(theoremView=>new Element({theoremView}));
    const panels=['latex','lean'].map(statementPanel=>new Element({statementPanel}));
    const card=new Element({proof:JSON.stringify(data)});
    card.querySelector=field;
    card.querySelectorAll=selector=>selector==='[data-theorem-view]'?tabs:panels;
    return {card,tabs,panels,field,data};
  });
  vm.runInNewContext(fs.readFileSync('web/theorems.js','utf8'), {
    document:{querySelectorAll:()=>entries.map(e=>e.card),createElement:()=>new Element()},
    console,katex:{render:(latex,node)=>{node.textContent=latex;}}
  });
  for(const {card,field,data,tabs,panels} of entries) {
    assert(card.children.some(e=>e.className==='source-proof-details'));
    assert(field('.proof-status').textContent.endsWith('saved check'));
    tabs[1].fire('click');
    assert.equal(panels[0].hidden,true);
    assert.equal(panels[1].hidden,false);
    card.proofController.attachVerifier(async()=>data.report);
    await field('.verify-proof').fire('click');
    assert(field('.proof-status').textContent.endsWith('checked now'));
    card.proofController.attachVerifier(async()=>({...data.report,statementHash:'wrong'}));
    await field('.verify-proof').fire('click');
    assert.equal(field('.proof-status').textContent,'Unavailable');
    assert(card.children.find(e=>e.className==='proof-error').textContent.includes('statement changed'));
    card.proofController.attachVerifier(async()=>({...data.report,proofFile:'wrong.lean'}));
    await field('.verify-proof').fire('click');
    assert.equal(field('.proof-status').textContent,'Unavailable');
  }
  assert.equal(new Set(entries.map(e=>e.tabs[0].id)).size, entries.length);
  console.log('PASS: generic statement controls, source audit, independent proof mappings and visible mismatch errors');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
