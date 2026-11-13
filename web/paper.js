// The PLAER page. It draws the document from the state the build embedded:
// Markdown blocks, and Lean blocks whose declarations became boxes.
//
// Opened as a file, the page is read-only. Served by scripts/serve.py, the play
// buttons check proofs with Lean and every block can be edited; edits are
// written back to the paper's Markdown file at once, and Lean compiles them in
// the background. Proofs are checked only when their play button is pressed.
(() => {
  "use strict";

  let state = JSON.parse(document.getElementById("plaer-state").textContent);
  const root = document.getElementById("plaer-document");
  let live = false;        // scripts/serve.py is answering
  let editing = null;      // index of the block being edited, or "new"
  let draft = null;        // a box being added: {kind, text}
  let leanEdit = null;     // a declaration being edited in its Lean tab: {name, text}
  const chosenView = new Map();   // declaration name → the tab last chosen for it
  let removed = null;      // the last removed block, for Undo
  let watching = false;    // polling the server while Lean compiles
  let nextId = 0;
  const status = node("span", "notebook-status");
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");

  // ── Small helpers ─────────────────────────────────────────────────────────

  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }

  function action(label, callback, accessible = label) {
    const button = node("button", "cell-action", label);
    button.type = "button";
    button.setAttribute("aria-label", accessible);
    button.addEventListener("click", callback);
    return button;
  }

  function link(text, href) {
    const anchor = node("a", "", text);
    anchor.href = href;
    anchor.target = "_blank";
    anchor.rel = "noopener";
    return anchor;
  }

  async function api(path, body) {
    const response = await fetch(path, body === undefined ? {} : {
      method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body), signal: AbortSignal.timeout(600000)
    });
    const result = await response.json();
    if (!response.ok) throw Object.assign(new Error(result.error || "The PLAER server could not do that."), {fromServer: true});
    return result;
  }

  // ── Markdown and Lean text ────────────────────────────────────────────────

  // Markdown permits mathematics but not executable HTML or unsafe link URLs.
  const mathHtml = (text, displayMode = false) => katex.renderToString(
    text.replace(/&lt;/g, "<").replace(/&gt;/g, ">"), {displayMode, throwOnError: false, trust: false});
  marked.use({extensions: [{
    name: "inlineMath", level: "inline", start: source => source.indexOf("$"),
    tokenizer(source) {
      const match = /^\$([^$\n]+)\$/.exec(source);
      if (match) return {type: "inlineMath", raw: match[0], text: match[1]};
    },
    renderer: token => mathHtml(token.text)
  }, {
    name: "displayMath", level: "block", start: source => source.indexOf("$$"),
    tokenizer(source) {
      const match = /^\$\$\s*\n?([\s\S]+?)\$\$(?:\n|$)/.exec(source);
      if (match) return {type: "displayMath", raw: match[0], text: match[1]};
    },
    renderer: token => mathHtml(token.text, true)
  }]});

  function renderMarkdown(source, target) {
    target.innerHTML = marked.parse(source.replace(/</g, "&lt;").replace(/>/g, "&gt;"));
    for (const anchor of target.querySelectorAll("a")) {
      if (!/^(https?:|mailto:|#|\/)/i.test(anchor.getAttribute("href") || "")) anchor.removeAttribute("href");
      anchor.rel = "noopener noreferrer";
    }
    for (const image of target.querySelectorAll("img")) {
      if (!/^(https?:|data:image\/(png|jpeg|webp);base64,)/i.test(image.getAttribute("src") || "")) image.remove();
    }
    for (const code of target.querySelectorAll("code.language-lean")) highlightLean(code, code.textContent);
  }

  // Highlight known tokens using text nodes, preserving the exact Lean source.
  function highlightLean(target, text) {
    const pattern = /(--.*$)|(\b(?:def|abbrev|theorem|lemma|example|structure|class|inductive|instance|axiom|where|fun|let|in|by|import|open|namespace|end|variable)\b)|(\b\d+\b)/gm;
    let previous = 0;
    target.replaceChildren();
    for (const match of text.matchAll(pattern)) {
      target.append(document.createTextNode(text.slice(previous, match.index)));
      target.append(node("span", match[1] ? "comment" : match[2] ? "keyword" : "numeral", match[0]));
      previous = match.index + match[0].length;
    }
    target.append(document.createTextNode(text.slice(previous)));
  }

  function renderLatex(latex, target) {
    try {
      katex.render(latex, target, {displayMode: true, throwOnError: true, trust: false, output: "htmlAndMathml"});
    } catch (error) {
      target.textContent = "Mathematical rendering unavailable. Select Lean to read the statement.";
    }
  }

  // ── The LaTeX / Lean switch shared by every formal box ────────────────────

  // Returns the switch and its two panels. Without LaTeX from Lean, the box
  // opens on its Lean view and says why.
  // A box's tabs: LaTeX first, then Lean panels such as "Lean" and "Reprint".
  function views(name, label, latex, latexError, mathClass, others) {
    const id = "box-" + nextId++;
    const toggle = node("div", "view-toggle");
    toggle.setAttribute("role", "tablist");
    toggle.setAttribute("aria-label", label);
    const mathPanel = node("div", "definition-panel math-panel");
    const math = node("div", mathClass);
    mathPanel.append(math);
    if (latex) renderLatex(latex, math);
    else math.append(node("p", "latex-missing", "Lean could not typeset this in LaTeX: " +
      String(latexError || "unsupported notation").split("\n")[0]));
    const all = [{key: "latex", label: "LaTeX", panel: mathPanel}, ...others];
    const tabs = all.map(({key, label: text, panel}) => {
      const tab = node("button", "", text);
      tab.type = "button";
      tab.id = `${id}-${key}-tab`;
      tab.dataset.view = key;
      tab.setAttribute("role", "tab");
      tab.setAttribute("aria-controls", `${id}-${key}-panel`);
      panel.id = `${id}-${key}-panel`;
      panel.setAttribute("role", "tabpanel");
      panel.setAttribute("aria-labelledby", tab.id);
      return tab;
    });
    function select(view, focus = false) {
      all.forEach(({key, panel}, index) => {
        const selected = key === view;
        tabs[index].setAttribute("aria-selected", String(selected));
        tabs[index].tabIndex = selected ? 0 : -1;
        if (selected && focus) tabs[index].focus();
        panel.hidden = !selected;
      });
    }
    tabs.forEach((tab, index) => {
      tab.addEventListener("click", () => { chosenView.set(name, tab.dataset.view); select(tab.dataset.view); });
      tab.addEventListener("keydown", event => {
        const last = tabs.length - 1;
        const next = {ArrowRight: index === last ? 0 : index + 1, ArrowLeft: index === 0 ? last : index - 1,
                      Home: 0, End: last}[event.key];
        if (next !== undefined) {
          event.preventDefault();
          chosenView.set(name, tabs[next].dataset.view);
          select(tabs[next].dataset.view, true);
        }
      });
    });
    toggle.append(...tabs);
    const remembered = leanEdit?.name === name ? "lean" : chosenView.get(name);
    select(all.some(v => v.key === remembered) ? remembered : latex ? "latex" : "lean");
    return {toggle, mathPanel};
  }

  // The Lean tab: the declaration exactly as written in the paper. Served by
  // scripts/serve.py, it can be edited in place; saving replaces those lines.
  function leanSourcePanel(item, blockIndex) {
    const panel = node("div", "definition-panel lean-panel");
    if (leanEdit?.name === item.name) {
      const area = node("textarea", "cell-editor lean-inline-editor");
      area.value = leanEdit.text;
      area.spellcheck = false;
      area.rows = Math.max(3, leanEdit.text.split("\n").length + 1);
      area.setAttribute("aria-label", "Lean source of " + item.title);
      area.addEventListener("input", () => { leanEdit.text = area.value; });
      const problem = node("pre", "proof-error edit-error");
      problem.hidden = true;
      const cancel = () => { leanEdit = null; draw(); };
      const save = async () => {
        saveButton.disabled = true;
        const outcome = await send({op: "replace_lines", index: blockIndex, start: item.offset,
                                    count: item.lines, text: area.value}, "Saving…");
        if (outcome === true) return;
        problem.textContent = outcome;
        problem.hidden = false;
        saveButton.disabled = false;
      };
      const saveButton = action("Save", save);
      area.addEventListener("keydown", event => {
        if (event.key === "Enter" && (event.shiftKey || event.ctrlKey || event.metaKey)) { event.preventDefault(); save(); }
        if (event.key === "Escape") cancel();
      });
      const actions = node("div", "cell-edit-actions");
      actions.append(saveButton, action("Cancel", cancel), node("span", "cell-shortcut", "Shift+Enter"));
      panel.append(area, problem, actions);
      requestAnimationFrame(() => area.focus());
      return panel;
    }
    const pre = node("pre");
    const code = node("code", "lean-source");
    highlightLean(code, item.source);
    pre.append(code);
    panel.append(pre);
    if (live) {
      const edit = action("Edit", () => { leanEdit = {name: item.name, text: item.source}; chosenView.set(item.name, "lean"); draw(); },
        "Edit the Lean of " + item.title);
      edit.classList.add("lean-edit-button");
      panel.append(edit);
      pre.addEventListener("dblclick", () => edit.click());
    }
    return panel;
  }


  function heading(className, eyebrow, eyebrowClass, title, toggle) {
    const box = node("div", className);
    const text = node("div");
    text.append(node("p", "eyebrow " + eyebrowClass, eyebrow), node("h2", "theorem-title", title));
    box.append(text);
    if (toggle) box.append(toggle);
    return box;
  }

  const sourceLink = item => link(`${state.sourceFile}:${item.line}`, state.sourceUrl);

  // ── Definition boxes ──────────────────────────────────────────────────────

  function definitionBox(item, blockIndex) {
    const card = node("section", "definition");
    card.setAttribute("aria-label", item.title);
    const leanPanel = leanSourcePanel(item, blockIndex);
    const body = node("div", "definition-body");
    if (item.kind === "definition") {
      const {toggle, mathPanel} = views(item.name, "Definition representation", item.latex, item.latexError, "display-math",
        [{key: "lean", label: "Lean", panel: leanPanel}]);
      card.append(heading("definition-heading", "Definition", "", item.title, toggle));
      body.append(mathPanel, leanPanel);
    } else {   // a structure, inductive type, axiom…: Lean only
      card.append(heading("definition-heading", "Declaration", "", item.title));
      body.append(leanPanel);
    }
    if (item.caption) card.append(caption(item.caption));
    card.append(body);
    const details = node("details", "source-proof-details");
    details.append(node("summary", "", "Source"), sourceLink(item));
    card.append(details);
    return card;
  }

  function caption(text) {
    const box = node("div", "box-caption");
    renderMarkdown(text, box);
    return box;
  }

  // ── Statement boxes: the statement, and the proofs attached to it ─────────
  // Keep the math prominent. A proof appears only as where it lives and
  // whether Lean accepts it; proof bodies are never embedded in the card.

  function statementBox(item, blockIndex) {
    const card = node("section", "proof-check");
    card.setAttribute("aria-label", "Statement and proof checks: " + item.title);
    const leanPanel = leanSourcePanel(item, blockIndex);
    // Lean's own printing of the statement it checks: one line, implicit details shown.
    const reprintPanel = node("div");
    reprintPanel.append(node("pre", "theorem-lean", item.statementLean));
    const {toggle, mathPanel} = views(item.name, "Statement representation", item.statementLatex, item.latexError, "theorem-math",
      [{key: "lean", label: "Lean", panel: leanPanel}, {key: "reprint", label: "Reprint", panel: reprintPanel}]);
    card.append(heading("proof-heading", item.kind === "candidate" ? "Statement" : "Theorem", "theorem-label", item.title, toggle));
    if (item.caption) card.append(caption(item.caption));
    const statement = node("div", "theorem-statement");
    statement.append(mathPanel, leanPanel, reprintPanel);
    card.append(statement);

    if (!item.proofs.length) {
      card.append(node("p", "proof-none", "No proof attached. Add a line such as “-- proof: proofs/File.lean Namespace.name” under the statement."));
    }
    item.proofs.forEach((proof, index) => card.append(proofRow(item, proof, index)));
    const details = node("details", "source-proof-details");
    details.append(node("summary", "", "Source"), sourceLink(item));
    card.append(details);
    return card;
  }

  function proofRow(item, proof, index) {
    const row = node("div", "proof-actions");
    const where = proof.inline ? "proved in the paper" : proof.file;
    const run = node("button", "verify-proof", "Run proof");
    run.type = "button";
    run.setAttribute("aria-label", `Run proof ${proof.declaration}: ${item.title}`);
    run.title = live ? "Check " + where : "Start the local PLAER server to check this proof.";
    run.disabled = !live;
    const result = node("span", "proof-result");
    result.setAttribute("role", "status");
    result.setAttribute("aria-live", "polite");
    const text = node("span", "proof-status");
    result.append(text);
    const label = node("span", "proof-where");
    label.append(node("code", "", proof.declaration), document.createTextNode(" · " + where));
    const error = node("p", "proof-error");
    error.hidden = true;
    const wrapper = node("div", "proof-row");
    row.append(run, result, label);
    wrapper.append(row, error);

    function show() {
      error.hidden = true;
      if (proof.result.pending) { result.dataset.state = "unverified"; text.textContent = "Not checked"; return; }
      result.dataset.state = proof.result.ok ? "verified" : "rejected";
      text.textContent = (proof.result.ok ? "Proved" : "Not proved") + (proof.checkedNow ? " · checked now" : " · saved check");
    }
    show();
    async function check() {
      run.disabled = true;
      error.hidden = true;
      result.dataset.state = "checking";
      text.textContent = "Checking proof file…";
      try {
        const report = await api("/api/verify", {theorem: item.name, proof: index});
        if (report.name !== item.name || report.statementHash !== item.statementHash) {
          throw new Error("The statement changed. Reload the document.");
        }
        Object.assign(proof, report, {checkedNow: true});
        show();
      } catch (problem) {
        result.dataset.state = "unverified";
        text.textContent = "Unavailable";
        error.textContent = String(problem.message || "The proof file could not be checked.").split("\n")[0].slice(0, 240);
        error.hidden = false;
      } finally {
        run.disabled = false;
      }
    }
    run.addEventListener("click", check);
    return wrapper;
  }



  // ── Other Lean in a block: imports, examples, commands ────────────────────

  // Lines that matter to Lean, not to the reader: imports, namespaces, and
  // LaTeX notation rules. A block made only of these is folded away.
  const SETUP_COMMAND = /^(--|import|open|namespace|section|end|universe|variable|set_option|noncomputable section|latex_pp_\w+|def_latex_\w+)\b/;
  const isSetup = text => text.split("\n").every(line => !line.trim() || /^\s/.test(line) || SETUP_COMMAND.test(line));

  function codeBlock(item) {
    const pre = node("pre", "lean-code");
    const code = node("code", "lean-source");
    highlightLean(code, item.text);
    pre.append(code);
    if (!isSetup(item.text)) return pre;
    const details = node("details", "lean-setup");
    details.append(node("summary", "", "Lean setup"), pre);
    return details;
  }

  function blockContent(block, index) {
    const output = node("div", block.kind === "markdown" ? "cell-output prose" : "lean-block");
    if (block.kind === "markdown") { renderMarkdown(block.text, output); return output; }
    if (block.pending) {
      output.classList.add("lean-pending");
      output.append(node("p", "lean-pending-note", state.leanError ? "Not compiled: Lean rejected the paper (see above)"
        : "Lean is compiling this box…"));
    }
    for (const item of block.items) {
      output.append(item.type === "code" ? codeBlock(item)
        : item.statement ? statementBox(item, index) : definitionBox(item, index));
    }
    return output;
  }

  // ── Editing (only when served by scripts/serve.py) ────────────────────────

  const TEMPLATES = {
    definition: {kind: "lean", text: "/-- Title of the definition -/\ndef Namespace.name (n : ℕ) : ℕ := n"},
    theorem: {kind: "lean", text: "/-- Title of the statement -/\ndef Namespace.name_statement : Prop :=\n  ∀ n : ℕ, n + 0 = n\n-- proof: proofs/File.lean Namespace.Proofs.name"},
    markdown: {kind: "markdown", text: ""}
  };

  // Saving never waits for Lean. While Lean compiles in the background, ask the
  // server every second and draw its boxes when they are ready, unless a box
  // is open for editing (that redraw happens when the editor closes).
  async function watch() {
    if (watching || !state.compiling) return;
    watching = true;
    try {
      while (state.compiling) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        const latest = await api("/api/document");
        if (latest.revision !== state.revision) break;   // another edit took over
        state = latest;
      }
      if (!state.compiling) {
        if (editing === null && !draft && !leanEdit) draw();
        status.textContent = state.leanError ? "Saved. Lean rejected the paper (see above)" : "Saved and compiled";
      }
    } catch (problem) {
      status.textContent = "Lost contact with the PLAER server";
    } finally {
      watching = false;
    }
    watch();
  }

  async function send(request, waiting) {
    status.textContent = waiting;
    try {
      state = await api("/api/document", {...request, revision: state.revision});
      editing = null;
      draft = null;
      leanEdit = null;
      draw();
      status.textContent = "Saved to " + state.paperFile + (state.compiling ? ". Lean is compiling…" : "");
      watch();
      return true;
    } catch (problem) {
      status.textContent = "Not saved";
      return problem.message;
    }
  }

  function editor(block, index) {
    const box = node("div", "cell-edit");
    const area = node("textarea", "cell-editor");
    area.value = block.text;
    area.spellcheck = block.kind === "markdown";
    area.rows = Math.max(5, block.text.split("\n").length + 1);
    area.placeholder = block.kind === "lean"
      ? "Write Lean declarations. Attach proofs with: -- proof: proofs/File.lean Namespace.name"
      : "Write Markdown; use $…$ for mathematics…";
    area.setAttribute("aria-label", block.kind === "lean" ? "Lean source" : "Markdown source");
    const problem = node("pre", "proof-error edit-error");
    problem.hidden = true;
    const cancel = () => { editing = null; draft = null; draw(); };
    const save = async () => {
      problem.hidden = true;
      saveButton.disabled = true;
      const request = index === "new"
        ? {op: "insert", index: state.blocks.length, kind: block.kind, text: area.value}
        : {op: "replace", index, text: area.value};
      const outcome = await send(request, "Saving…");
      if (outcome !== true) { problem.textContent = outcome; problem.hidden = false; saveButton.disabled = false; }
    };
    const saveButton = action(block.kind === "lean" ? "Save" : "Render", save);
    area.addEventListener("keydown", event => {
      if (event.key === "Enter" && (event.shiftKey || event.ctrlKey || event.metaKey)) { event.preventDefault(); save(); }
      if (event.key === "Escape") cancel();
    });
    const actions = node("div", "cell-edit-actions");
    actions.append(saveButton, action("Cancel", cancel), node("span", "cell-shortcut", "Shift+Enter"));
    box.append(area, problem, actions);
    requestAnimationFrame(() => area.focus());
    return box;
  }

  function controls(block, index) {
    const header = node("div", "cell-heading");
    header.append(node("span", "cell-kind", block.kind === "lean" ? "Lean" : "Markdown"));
    const buttons = node("div", "cell-controls");
    buttons.append(action("Edit", () => { editing = index; draft = null; draw(); }));
    for (const [label, offset] of [["↑", -1], ["↓", 1]]) {
      const move = action(label, () => send({op: "move", index, offset}, "Saving…").then(report),
        offset < 0 ? "Move box up" : "Move box down");
      move.disabled = index + offset < 0 || index + offset >= state.blocks.length;
      buttons.append(move);
    }
    buttons.append(action("Remove", async () => {
      const copy = {index, kind: block.kind, text: block.text};
      if (report(await send({op: "remove", index}, "Saving…"))) { removed = copy; draw(); }
    }));
    header.append(buttons);
    return header;
  }

  // Show why an edit made outside an editor was refused.
  function report(outcome) {
    if (outcome !== true) status.textContent = String(outcome).split("\n")[0].slice(0, 240);
    return outcome === true;
  }

  function toolbar() {
    const bar = node("div", "notebook-toolbar");
    for (const [label, template] of [["+ Definition", "definition"], ["+ Theorem", "theorem"], ["+ Markdown", "markdown"]]) {
      bar.append(action(label, () => { draft = {...TEMPLATES[template]}; editing = "new"; draw(); }));
    }
    if (removed) {
      bar.append(action("Undo remove", async () => {
        const {index, kind, text} = removed;
        if (report(await send({op: "insert", index: Math.min(index, state.blocks.length), kind, text}, "Saving…"))) {
          removed = null;
          draw();
        }
      }));
    }
    bar.append(status);
    return bar;
  }

  // ── Drawing ───────────────────────────────────────────────────────────────

  function draw() {
    root.replaceChildren();
    if (live && state.leanError) root.append(node("pre", "build-error", "Lean rejected the paper:\n\n" + state.leanError));
    state.blocks.forEach((block, index) => {
      const cell = node("section", "block" + (live ? " editable" : ""));
      if (live) cell.append(controls(block, index));
      if (editing === index) cell.append(editor(block, index));
      else {
        const content = blockContent(block, index);
        if (live && block.kind === "markdown") content.addEventListener("dblclick", () => { editing = index; draw(); });
        cell.append(content);
      }
      root.append(cell);
    });
    if (draft) {
      const cell = node("section", "block editable");
      cell.append(editor(draft, "new"));
      root.append(cell);
    }
    if (live) root.append(toolbar());
  }

  document.querySelector(".print-button").addEventListener("click", () => window.print());
  draw();
  if (/^https?:$/.test(location.protocol)) {
    api("/api/document").then(current => { state = current; live = true; draw(); watch(); }, problem => {
      // A static host has no API and stays read-only. The PLAER server answers
      // with a reason, for example that Lean rejects the paper as it is on disk.
      if (problem.fromServer) root.prepend(node("pre", "build-error", problem.message));
    });
  }
})();
