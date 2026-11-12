(() => {
  "use strict";
  const node = (tag, className, content) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (content !== undefined) element.textContent = content;
    return element;
  };
  const action = (label, callback, accessible = label) => {
    const button = node("button", "cell-action", label);
    button.type = "button";
    button.setAttribute("aria-label", accessible);
    button.addEventListener("click", callback);
    return button;
  };
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
    for (const link of target.querySelectorAll("a")) {
      if (!/^(https?:|mailto:|#|\/)/i.test(link.getAttribute("href") || "")) link.removeAttribute("href");
      link.rel = "noopener noreferrer";
    }
    for (const image of target.querySelectorAll("img")) {
      if (!/^(https?:|data:image\/(png|jpeg|webp);base64,)/i.test(image.getAttribute("src") || "")) image.remove();
    }
  }
  for (const notebook of document.querySelectorAll("[data-notebook-state]")) {
    let state = JSON.parse(notebook.dataset.notebookState);
    let editing = null;
    let removed = null;
    let saveQueue = Promise.resolve();
    const local = !/^https?:$/.test(location.protocol);
    const storageKey = "plaer:explanations:" + location.pathname;
    if (local) {
      try { state = JSON.parse(localStorage.getItem(storageKey)) || state; } catch {}
    }
    const cells = node("div", "explanation-cells");
    const toolbar = node("div", "notebook-toolbar");
    const status = node("span", "notebook-status");
    status.setAttribute("role", "status");
    status.setAttribute("aria-live", "polite");
    const undo = action("Undo remove", () => {
      if (!removed) return;
      state.cells.splice(removed.index, 0, removed.cell);
      removed = null;
      draw(); save();
    });
    undo.hidden = true;
    function snapshot() { notebook.dataset.notebookState = JSON.stringify(state); }
    function save() {
      const pending = structuredClone(state.cells);
      snapshot();
      status.textContent = "Saving…";
      saveQueue = saveQueue.catch(() => {}).then(async () => {
        if (local) {
          localStorage.setItem(storageKey, JSON.stringify({...state, cells: pending}));
          status.textContent = "Saved in this browser";
          return;
        }
        const response = await fetch("/api/explanations", {
          method: "POST", headers: {"Content-Type": "application/json"},
          body: JSON.stringify({cells: pending, revision: state.revision})
        });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || "Could not save explanations");
        state.revision = result.revision;
        snapshot();
        status.textContent = "Saved";
      }).catch(error => { status.textContent = error.message; });
      return saveQueue;
    }
    function add(kind) {
      const cell = {id: "cell-" + crypto.randomUUID(), kind, source: ""};
      state.cells.push(cell);
      editing = cell.id;
      draw();
    }
    function draw() {
      cells.replaceChildren();
      undo.hidden = !removed;
      for (const [index, cell] of state.cells.entries()) {
        const box = node("section", "explanation-cell");
        box.dataset.cellId = cell.id;
        box.setAttribute("aria-label", cell.kind === "plot" ? "Plot explanation" : "Markdown explanation");
        const header = node("div", "cell-heading");
        header.append(node("span", "cell-kind", cell.kind === "plot" ? "Explanation · Plot" : "Explanation · Markdown"));
        const controls = node("div", "cell-controls");
        controls.append(action("Edit", () => { editing = cell.id; draw(); }));
        for (const [label, offset] of [["↑", -1], ["↓", 1]]) {
          const button = action(label, () => {
            [state.cells[index], state.cells[index + offset]] = [state.cells[index + offset], cell];
            draw(); save();
          }, offset < 0 ? "Move explanation up" : "Move explanation down");
          button.disabled = index + offset < 0 || index + offset >= state.cells.length;
          controls.append(button);
        }
        controls.append(action("Remove", () => {
          removed = {cell: structuredClone(cell), index};
          state.cells.splice(index, 1); draw(); save();
        }));
        header.append(controls);
        box.append(header);
        const output = node("div", "cell-output");
        output.addEventListener("dblclick", () => { editing = cell.id; draw(); });
        if (cell.source) renderMarkdown(cell.source, output);
        else if (cell.kind === "markdown") output.append(node("p", "empty-explanation", "Double-click to add an explanation."));
        if (cell.kind === "plot") {
          const plot = node("div", "illustration");
          plot.innerHTML = '<div class="figure-heading"><output class="membership-result" aria-live="polite"></output></div><div class="number-line"></div><div class="slider-row"><label>x</label><input type="range" min="0" max="200" value="100" step="1" aria-label="Position on the number line"><output class="point-value"></output></div><div class="example-points" aria-label="Example positions"></div>';
          output.append(plot);
          const definition = document.querySelector("[data-definition]");
          window.PlaerPlot(plot, JSON.parse(definition.dataset.definition));
        }
        if (editing === cell.id) {
          controls.firstChild.hidden = true;
          const original = cell.source;
          const editor = node("textarea", "cell-editor");
          editor.value = cell.source;
          editor.placeholder = cell.kind === "plot" ? "Add a Markdown caption for this plot…" : "Write Markdown; use $…$ for mathematics…";
          editor.setAttribute("aria-label", cell.kind === "plot" ? "Plot caption Markdown" : "Explanation Markdown");
          editor.addEventListener("input", () => { cell.source = editor.value; });
          const render = () => { cell.source = editor.value; editing = null; draw(); save(); };
          editor.addEventListener("keydown", event => {
            if (event.key === "Enter" && (event.shiftKey || event.ctrlKey || event.metaKey)) {
              event.preventDefault(); render();
            }
            if (event.key === "Escape") { cell.source = original; editing = null; draw(); }
          });
          const editActions = node("div", "cell-edit-actions");
          editActions.append(action("Render", render), action("Cancel", () => { cell.source = original; editing = null; draw(); }),
            node("span", "cell-shortcut", "Shift+Enter"));
          box.append(editor, editActions);
          requestAnimationFrame(() => editor.focus());
        } else box.append(output);
        cells.append(box);
      }
      snapshot();
    }
    function download() {
      snapshot();
      const clone = document.documentElement.cloneNode(true);
      // Editing controls are recreated from the saved cell data on opening.
      clone.querySelectorAll(".explanation-notebook").forEach(root => root.replaceChildren());
      const url = URL.createObjectURL(new Blob(["<!doctype html>\n" + clone.outerHTML], {type: "text/html;charset=utf-8"}));
      const link = node("a");
      link.href = url; link.download = "plaer-paper.html"; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
    toolbar.append(action("+ Markdown", () => add("markdown")), ...(document.querySelector("[data-definition]") ? [action("+ Plot", () => add("plot"))] : []), undo,
      action("Download paper", download), status);
    notebook.append(cells, toolbar);
    draw();
  }
})();
