// Included only in the runnable document, never in a chat snapshot.
(() => {
  "use strict";
  const cards = Array.from(document.querySelectorAll("[data-proof]"));
  if (!/^https?:$/.test(location.protocol)) {
    for (const card of cards) {
      const link = document.createElement("a");
      link.className = "verify-proof";
      link.href = "http://127.0.0.1:8767/";
      link.textContent = "Open runnable document";
      card.querySelector(".verify-proof").replaceWith(link);
    }
    return;
  }
  // Always connect the button. The server queues a check while Lean is loading.
  for (const card of cards) {
    card.proofController.attachVerifier(async theorem => {
      const response = await fetch("/api/verify", {
        method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({theorem}), signal: AbortSignal.timeout(120000)
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || "Lean verification failed to run.");
      return result;
    });
  }
})();
