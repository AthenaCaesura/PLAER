"use strict";

// Presentation and navigation only. Optional plot samples come from the build.
let nextDefinitionIndex = 0;
globalThis.PlaerDefinitions = (root = document) => {
for (const card of root.querySelectorAll("[data-definition]")) {
  if (card.dataset.plaerInitialized) continue;
  card.dataset.plaerInitialized = "true";
  const cardIndex = nextDefinitionIndex++;
  const declaration = JSON.parse(card.dataset.definition);
  if (declaration.sourceUrl) {
    const details = document.createElement("details"); details.className = "source-proof-details";
    const summary = document.createElement("summary"); summary.textContent = "Source";
    const link = document.createElement("a"); link.href = declaration.sourceUrl;
    link.target = "_blank"; link.rel = "noopener";
    link.textContent = declaration.sourceFile || declaration.sourceModule;
    details.append(summary, link); card.append(details);
  }
  const tabs = Array.from(card.querySelectorAll('[role="tab"]'));
  const panels = Array.from(card.querySelectorAll('[role="tabpanel"]'));
  const math = card.querySelector("[data-latex]");
  tabs.forEach((tab, index) => {
    const view = tab.dataset.view;
    const panel = panels[index];
    tab.id = `definition-${cardIndex}-${view}-tab`;
    panel.id = `definition-${cardIndex}-${view}-panel`;
    panel.dataset.definitionView = view;
    tab.setAttribute("aria-controls", panel.id);
    panel.setAttribute("aria-labelledby", tab.id);
  });

  try {
    katex.render(math.dataset.latex, math, {displayMode: true, throwOnError: true, trust: false, output: "htmlAndMathml"});
  } catch (error) {
    math.textContent = "Mathematical rendering unavailable. Select Lean to inspect the definition.";
    console.error("Mathematical rendering failed", error);
  }

  function selectView(view, focus = false) {
    for (const tab of tabs) {
      const selected = tab.dataset.view === view;
      tab.setAttribute("aria-selected", String(selected));
      tab.tabIndex = selected ? 0 : -1;
      if (selected && focus) tab.focus();
    }
    for (const panel of panels) panel.hidden = panel.dataset.definitionView !== view;
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => selectView(tab.dataset.view));
    tab.addEventListener("keydown", event => {
      let next;
      if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
      if (event.key === "ArrowLeft") next = (index + tabs.length - 1) % tabs.length;
      if (event.key === "Home") next = 0;
      if (event.key === "End") next = tabs.length - 1;
      if (next !== undefined) {
        event.preventDefault();
        selectView(tabs[next].dataset.view, true);
      }
    });
  });
  selectView("latex");

  // Highlight known tokens using text nodes, preserving the exact Lean source.
  const source = card.querySelector(".lean-source");
  const sourceText = source.textContent;
  const tokenPattern = /(\b(?:def|abbrev|theorem|structure|where|fun|let|in)\b|\d+)/g;
  let previous = 0;
  source.replaceChildren();
  for (const match of sourceText.matchAll(tokenPattern)) {
    source.append(document.createTextNode(sourceText.slice(previous, match.index)));
    const token = document.createElement("span");
    token.className = /^\d+$/.test(match[0]) ? "numeral" : "keyword";
    token.textContent = match[0];
    source.append(token);
    previous = match.index + match[0].length;
  }
  source.append(document.createTextNode(sourceText.slice(previous)));
}

};
globalThis.PlaerDefinitions();

// Explanation cells can reuse the certified samples without changing the definition.
window.PlaerPlot = function (card, data) {
  if (!Array.isArray(data.samples) || data.samples.length < 2 || !data.shape) return false;
  const label = data.name ? data.name.split(".").pop() : "the set";
  const ns = "http://www.w3.org/2000/svg";
  function svgElement(name, attributes, content) {
    const node = document.createElementNS(ns, name);
    for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, String(value));
    if (content !== undefined) node.textContent = content;
    return node;
  }
  const samples = data.samples;
  const numeric = sample => sample.numerator / sample.denominator;
  const minimum = numeric(samples[0]);
  const maximum = numeric(samples[samples.length - 1]);
  if (!Number.isFinite(minimum) || !Number.isFinite(maximum) || maximum <= minimum) return false;
  const px = value => 46 + (value - minimum) / (maximum - minimum) * 608;
  const svg = svgElement("svg", {viewBox: "0 0 700 148", role: "img", "aria-label": `The interval from ${data.shape.lower} to ${data.shape.upper}, with a movable point`});
  const description = svgElement("desc", {}, "Filled endpoints belong to the set. Use the slider below to explore membership at exact rational positions.");
  svg.append(description);
  svg.append(svgElement("line", {x1: 28, y1: 82, x2: 672, y2: 82, class: "axis"}));
  svg.append(svgElement("path", {d: "M33 78 L28 82 L33 86 M667 78 L672 82 L667 86", fill: "none", class: "axis"}));
  for (let tick = minimum; tick <= maximum + .0001; tick += .5) {
    svg.append(svgElement("line", {x1: px(tick), y1: 77, x2: px(tick), y2: 88, class: "tick"}));
    svg.append(svgElement("text", {x: px(tick), y: 110, "text-anchor": "middle", class: "tick-label"}, String(tick).replace("-", "−")));
  }
  svg.append(svgElement("line", {x1: px(data.shape.lower), y1: 82, x2: px(data.shape.upper), y2: 82, class: "interval-band"}));
  for (const [bound, closed] of [[data.shape.lower, data.shape.lowerClosed], [data.shape.upper, data.shape.upperClosed]]) {
    svg.append(svgElement("circle", {cx: px(bound), cy: 82, r: 5, class: `endpoint${closed ? "" : " open"}`}));
  }
  svg.append(svgElement("text", {x: px((data.shape.lower + data.shape.upper) / 2), y: 136, "text-anchor": "middle", class: "interval-label"}, label));
  const guide = svgElement("line", {x1: 0, y1: 47, x2: 0, y2: 77, class: "probe-guide"});
  const probe = svgElement("circle", {cx: 0, cy: 43, r: 7, class: "probe"});
  const probeLabel = svgElement("text", {x: 0, y: 24, "text-anchor": "middle", class: "probe-label"}, "x");
  svg.append(guide, probe, probeLabel);
  card.querySelector(".number-line").append(svg);

  const slider = card.querySelector('input[type="range"]');
  slider.max = String(samples.length - 1);
  const result = card.querySelector(".membership-result");
  const pointValue = card.querySelector(".point-value");
  const examples = card.querySelector(".example-points");
  const exampleButtons = [];
  const displayNumber = value => value.toFixed(2).replace("-", "−");

  function setPoint(index) {
    index = Math.max(0, Math.min(samples.length - 1, Math.round(index)));
    slider.value = String(index);
    const sample = samples[index];
    const value = numeric(sample);
    const x = px(value);
    guide.setAttribute("x1", String(x));
    guide.setAttribute("x2", String(x));
    probe.setAttribute("cx", String(x));
    probeLabel.setAttribute("x", String(x));
    probe.classList.toggle("outside", !sample.member);
    probeLabel.classList.toggle("outside", !sample.member);
    result.classList.toggle("outside", !sample.member);
    result.textContent = `x ${sample.member ? "∈" : "∉"} ${label}`;
    result.setAttribute("aria-label", `${displayNumber(value)} ${sample.member ? "belongs to" : "does not belong to"} ${label}`);
    pointValue.textContent = `x = ${displayNumber(value)}`;
    slider.setAttribute("aria-valuetext", `${displayNumber(value)}, ${sample.member ? "inside" : "outside"} the interval`);
    description.textContent = `Selected point ${sample.numerator}/${sample.denominator}: ${sample.member ? "belongs to" : "does not belong to"} ${label}. This membership result was checked by Lean during the build.`;
    for (const [button, sampleIndex] of exampleButtons) button.setAttribute("aria-pressed", String(index === sampleIndex));
  }
  for (const value of new Set([minimum, data.shape.lower, (data.shape.lower + data.shape.upper) / 2, data.shape.upper, maximum])) {
    const index = samples.findIndex(sample => numeric(sample) === value);
    if (index < 0) continue;
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = String(value).replace("-", "−");
    button.setAttribute("aria-label", `Select x = ${value}`);
    button.setAttribute("aria-pressed", "false");
    button.addEventListener("click", () => setPoint(index));
    examples.append(button);
    exampleButtons.push([button, index]);
  }
  slider.addEventListener("input", () => setPoint(Number(slider.value)));
  // Clicking/dragging the figure selects the nearest certified position.
  let dragging = false;
  function selectFromPointer(event) {
    const rect = svg.getBoundingClientRect();
    const svgX = (event.clientX - rect.left) / rect.width * 700;
    const fraction = (svgX - 46) / 608;
    setPoint(fraction * (samples.length - 1));
  }
  svg.addEventListener("pointerdown", event => {
    if (event.button !== 0) return;
    dragging = true;
    svg.setPointerCapture(event.pointerId);
    selectFromPointer(event);
  });
  svg.addEventListener("pointermove", event => { if (dragging) selectFromPointer(event); });
  svg.addEventListener("pointerup", () => { dragging = false; });
  svg.addEventListener("pointercancel", () => { dragging = false; });
  setPoint(Math.floor((samples.length - 1) / 2));
  return true;
};
document.querySelector(".print-button").addEventListener("click", () => window.print());
