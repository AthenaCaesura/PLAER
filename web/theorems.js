(() => {
  "use strict";
  const scope = document;
  for (const [index, card] of Array.from(scope.querySelectorAll("[data-proof]")).entries()) {
    const data = JSON.parse(card.dataset.proof);
    const initial = data.report;
    const statusBox = card.querySelector(".proof-result");
    const status = card.querySelector(".proof-status");
    const runButton = card.querySelector(".verify-proof");
    runButton.setAttribute("aria-label", `Run proof: ${data.title}`);
    runButton.title = "Run proof";
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

    for (const tab of tabs) {
      const view = tab.dataset.theoremView;
      const panel = panels.find(panel => panel.dataset.statementPanel === view);
      tab.id = `theorem-${index}-${view}-tab`;
      panel.id = `theorem-${index}-${view}-panel`;
      tab.setAttribute("aria-controls", panel.id);
      panel.setAttribute("aria-labelledby", tab.id);
      tab.addEventListener("click", () => {
        tabs.forEach(candidate => candidate.setAttribute("aria-selected", String(candidate === tab)));
        panels.forEach(candidate => { candidate.hidden = candidate !== panel; });
      });
    }

    function showResult(report, saved = false) {
      statusBox.dataset.state = report.result.ok ? "verified" : "rejected";
      status.textContent = (report.result.ok ? "Proved" : "Not proved") +
        (saved ? " · from save; not run in this session" : "");
    }
    showResult(initial, true);
    runButton.addEventListener("click", async () => {
      if (!runLean || busy) return;
      busy = true;
      runButton.disabled = true;
      card.setAttribute("aria-busy", "true");
      statusBox.dataset.state = "checking";
      status.textContent = "Checking…";
      runButton.setAttribute("aria-label", `Checking proof: ${data.title}`);
      try {
        const report = await runLean(initial.name);
        if (report.name !== initial.name || report.statementHash !== initial.statementHash) {
          throw new Error("The theorem statement changed. Rebuild the document.");
        }
        showResult(report);
      } catch (error) {
        statusBox.dataset.state = "unverified";
        status.textContent = "Unavailable";
        status.setAttribute("aria-label", error.message);
      } finally {
        busy = false;
        runButton.disabled = !runLean;
        runButton.setAttribute("aria-label", `Run proof: ${data.title}`);
        card.removeAttribute("aria-busy");
      }
    });
    card.proofController = {
      attachVerifier(callback) { runLean = callback; runButton.disabled = false; },
      unavailable(message) { runButton.title = message; }
    };
  }
})();
