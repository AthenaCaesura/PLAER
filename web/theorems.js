(() => {
  "use strict";
  let nextIndex = 0;
  globalThis.PlaerStatements = (scope = document) => {
  const element = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  for (const card of scope.querySelectorAll("[data-proof]")) {
    if (card.proofController) continue;
    const index = nextIndex++;
    const data = JSON.parse(card.dataset.proof);
    const initial = data.report;
    const statusBox = card.querySelector(".proof-result");
    const status = card.querySelector(".proof-status");
    const runButton = card.querySelector(".verify-proof");
    const errorMessage = element("p", "proof-error");
    errorMessage.hidden = true;
    card.append(errorMessage);
    runButton.setAttribute("aria-label", "Run proof: " + data.title);
    runButton.title = initial.proofFile ? "Check " + initial.proofFile : "Run proof";
    const math = card.querySelector(".theorem-math");
    const lean = card.querySelector(".theorem-lean");
    const tabs = Array.from(card.querySelectorAll("[data-theorem-view]"));
    const panels = Array.from(card.querySelectorAll("[data-statement-panel]"));
    let runLean = null;
    let busy = false;

    card.querySelector(".theorem-title").textContent = data.title;
    card.querySelector(".theorem-label").textContent = initial.kind === "candidate" ? "Statement" : "Theorem";
    lean.textContent = initial.statementLean;
    if (initial.statementHtml) math.innerHTML = initial.statementHtml;
    else if (globalThis.katex) katex.render(initial.statementLatex, math, {displayMode: true, trust: false});
    else math.textContent = initial.statementLatex;

    function selectView(tab, focus = false) {
      tabs.forEach(candidate => {
        const selected = candidate === tab;
        candidate.setAttribute("aria-selected", String(selected));
        candidate.tabIndex = selected ? 0 : -1;
        if (selected && focus) candidate.focus();
      });
      panels.forEach(panel => { panel.hidden = panel.dataset.statementPanel !== tab.dataset.theoremView; });
    }
    for (const [tabIndex, tab] of tabs.entries()) {
      const view = tab.dataset.theoremView;
      const panel = panels.find(panel => panel.dataset.statementPanel === view);
      tab.id = "theorem-" + index + "-" + view + "-tab";
      panel.id = "theorem-" + index + "-" + view + "-panel";
      tab.setAttribute("aria-controls", panel.id);
      panel.setAttribute("aria-labelledby", tab.id);
      tab.addEventListener("click", () => selectView(tab));
      tab.addEventListener("keydown", event => {
        let next;
        if (event.key === "ArrowRight") next = (tabIndex + 1) % tabs.length;
        if (event.key === "ArrowLeft") next = (tabIndex + tabs.length - 1) % tabs.length;
        if (event.key === "Home") next = 0;
        if (event.key === "End") next = tabs.length - 1;
        if (next !== undefined) { event.preventDefault(); selectView(tabs[next], true); }
      });
    }
    selectView(tabs.find(tab => tab.dataset.theoremView === "latex") || tabs[0]);

    // Keep the math prominent; source files and independently runnable checks
    // are available on demand, without embedding proof bodies in the card.
    const audit = element("details", "source-proof-details");
    audit.append(element("summary", "", "Source & proof"));
    const rows = element("dl", "source-proof-list");
    const link = (text, href, download = false) => {
      const node = element("a", "", text);
      node.href = href;
      node.target = "_blank";
      node.rel = "noopener";
      if (download) node.download = href.split("/").pop();
      return node;
    };
    const row = (label, ...contents) => {
      const value = element("dd");
      value.append(...contents);
      rows.append(element("dt", "", label), value);
    };
    function showAudit(report) {
      rows.replaceChildren();
    row("Statement", element("code", "", report.name));
    if (report.sourceUrl) row("Source file", link(report.sourceFile || "Open statement source", report.sourceUrl));
    if (report.proofUrl) row("Proof file", link(report.proofFile || "Open proof source", report.proofUrl));
    if (report.proofDeclaration) row("Proof declaration", element("code", "", report.proofDeclaration));
    if (report.command) row("Run independently", element("code", "checker-command", report.command));
    if (report.checkerUrl) row("Checker", link("Download Lean checker", report.checkerUrl, true));
    if (report.auditUrl) row("Build record", link("Audit manifest", report.auditUrl));
    }
    showAudit(initial);
    audit.append(rows);
    card.append(audit);

    function showResult(report, saved = false) {
      data.report = report;
      card.dataset.proof = JSON.stringify(data);
      if (report.result.pending) { statusBox.dataset.state = "unverified"; status.textContent = "Not checked"; return; }
      statusBox.dataset.state = report.result.ok ? "verified" : "rejected";
      status.textContent = (report.result.ok ? "Proved" : "Not proved") +
        (saved ? " · saved check" : " · checked now");
    }
    showResult(initial, true);
    runButton.addEventListener("click", async () => {
      if (!runLean || busy) return;
      busy = true;
      errorMessage.hidden = true;
      errorMessage.textContent = "";
      runButton.disabled = true;
      card.setAttribute("aria-busy", "true");
      statusBox.dataset.state = "checking";
      status.textContent = "Checking proof file…";
      runButton.setAttribute("aria-label", "Checking proof: " + data.title);
      try {
        const report = await runLean(initial.name);
        if (report.name !== initial.name || report.statementHash !== initial.statementHash) {
          throw new Error("The theorem statement changed. Rebuild the document.");
        }
        if ((initial.proofFile && report.proofFile !== initial.proofFile) ||
            (initial.proofDeclaration && report.proofDeclaration !== initial.proofDeclaration)) {
          throw new Error("The proof source changed. Rebuild the document.");
        }
        showAudit(report);
        showResult(report);
      } catch (error) {
        statusBox.dataset.state = "unverified";
        status.textContent = "Unavailable";
        errorMessage.textContent = String(error.message || "The proof file could not be checked.").split("\n")[0].slice(0, 240);
        errorMessage.hidden = false;
      } finally {
        busy = false;
        runButton.disabled = !runLean;
        runButton.setAttribute("aria-label", "Run proof: " + data.title);
        card.removeAttribute("aria-busy");
      }
    });
    card.proofController = {
      attachVerifier(callback) { runLean = callback; runButton.disabled = false; },
      unavailable(message) { runButton.title = message; }
    };
  }
  };
  globalThis.PlaerStatements();
})();
