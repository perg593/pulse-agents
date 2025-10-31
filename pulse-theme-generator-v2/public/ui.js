const statusSummary = document.getElementById("schema-summary");
const busyIndicator = document.getElementById("busy-indicator");
const form = document.getElementById("extract-form");
const submitButton = document.getElementById("submit-button");
const resultsPanel = document.getElementById("results-panel");
const resultMessage = document.getElementById("result-message");
const statsList = document.getElementById("stats-list");
const downloadList = document.getElementById("download-list");
const errorsContainer = document.getElementById("errors-container");
const errorsList = document.getElementById("errors-list");
const previewDetails = document.getElementById("preview-details");
const themePreview = document.getElementById("theme-preview");
const colorsSection = document.getElementById("colors-section");
const colorGrid = document.getElementById("color-swatches");
const cssCard = document.getElementById("css-card");
const cssSnippetEl = document.getElementById("css-snippet");
const copyCssButton = document.getElementById("copy-css-button");
const summaryCard = document.getElementById("summary-card");
const summaryFont = document.getElementById("summary-font");
const summaryColorElements = (() => {
  const nodes = document.querySelectorAll(".summary-color");
  const map = new Map();
  nodes.forEach((node) => {
    const role = node.getAttribute("data-role");
    const swatch = node.querySelector(".swatch");
    const code = node.querySelector("code");
    if (role && swatch && code) {
      map.set(role, { swatch, code });
    }
  });
  return map;
})();
const summaryLogo = document.getElementById("summary-logo");
const summaryLogoGrid = document.getElementById("summary-logo-grid");
const summaryCurated = document.getElementById("summary-curated");
const paletteCard = document.getElementById("palette-card");
const paletteForm = document.getElementById("palette-form");
const paletteSelectPrimary = document.getElementById("palette-primary");
const paletteSelectSecondary = document.getElementById("palette-secondary");
const paletteSelectBackground = document.getElementById("palette-background");
const paletteSelectText = document.getElementById("palette-text");
const paletteApplyButton = document.getElementById("apply-palette");
const paletteStatus = document.getElementById("palette-status");
const paletteDefaultList = document.getElementById("palette-default-list");
const resetPaletteButton = document.getElementById("reset-palette");
const palettePreviewItems = new Map(
  Array.from(document.querySelectorAll(".preview-item"))
    .map((node) => {
      const swatch = node.querySelector(".swatch");
      const code = node.querySelector("code");
      return [node.getAttribute("data-preview") ?? "", { node, swatch, code }];
    })
    .filter(([key]) => key),
);
const statTemplate = document.getElementById("stat-item-template");

const PALETTE_GROUPS = [
  {
    id: "bodyPrimary",
    label: "Body + Primary pair",
    description: "$color-1 & $color-1-alt",
    entries: [
      { target: "text", label: "Body text", colorName: "color-1" },
      { target: "primary", label: "Primary accents", colorName: "color-1-alt" },
    ],
  },
  {
    id: "surfaceSecondary",
    label: "Surface + Secondary pair",
    description: "$color-2 & $color-2-font",
    entries: [
      { target: "background", label: "Surface background", colorName: "color-2" },
      { target: "secondary", label: "Secondary text", colorName: "color-2-font" },
    ],
  },
];

const paletteConfig = [
  { target: "text", select: paletteSelectText, colorName: "color-1", group: "bodyPrimary", label: "Body text" },
  { target: "primary", select: paletteSelectPrimary, colorName: "color-1-alt", group: "bodyPrimary", label: "Primary accents" },
  { target: "background", select: paletteSelectBackground, colorName: "color-2", group: "surfaceSecondary", label: "Surface background" },
  { target: "secondary", select: paletteSelectSecondary, colorName: "color-2-font", group: "surfaceSecondary", label: "Secondary text" },
];

let latestCssSnippet = "";
let resetCopyTimeout;
let latestRawFindings = null;
let availablePaletteColors = [];
let latestSummary = null;
let isApplyingPalette = false;
let colorDefaults = [];
let currentPaletteDefaults = null;
let initialPaletteSelections = null;
const paletteControlMap = new Map();

async function hydrateStatus() {
  try {
    const response = await fetch("/api/status");
    if (!response.ok) {
      throw new Error(`Status request failed (${response.status})`);
    }
    const payload = await response.json();
    if (!payload.ok) {
      throw new Error(payload.error ?? "Schema unavailable");
    }
    statusSummary.textContent = `${payload.tokens} tokens across ${payload.groups} groups`;
    setBusy(payload.busy);
    colorDefaults = Array.isArray(payload.colorDefaults) ? payload.colorDefaults : [];
    renderDefaultColorPairs();
  } catch (error) {
    statusSummary.textContent = `Error loading schema: ${(error.message ?? error)}`;
  }
}

function setBusy(busy) {
  busyIndicator.textContent = busy ? "Running…" : "Idle";
  busyIndicator.classList.toggle("busy", busy);
  submitButton.disabled = busy;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const formData = new FormData(form);
  const payload = {
    url: formData.get("url"),
    scheme: formData.get("scheme"),
    pages: Number.parseInt(formData.get("pages"), 10),
  };

  setBusy(true);
  resultMessage.textContent = "Starting extraction…";
  resultsPanel.classList.remove("hidden");
  statsList.innerHTML = "";
  downloadList.innerHTML = "";
  errorsContainer.classList.add("hidden");
  previewDetails.classList.add("hidden");
  themePreview.textContent = "";
  colorsSection.classList.add("hidden");
  colorGrid.innerHTML = "";
  if (cssCard) cssCard.classList.add("hidden");
  if (cssSnippetEl) cssSnippetEl.textContent = "";
  latestCssSnippet = "";
  if (copyCssButton) copyCssButton.disabled = true;
  resetCopyButton();
  renderThemeSummary(null);

  try {
    const response = await fetch("/api/extract", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const body = await response.json();
    if (!response.ok || !body.ok) {
      throw new Error(body.error ?? `Request failed with status ${response.status}`);
    }

    renderResults(body);
  } catch (error) {
    resultMessage.innerHTML = `<span class="error">Extraction failed: ${error.message ?? error}</span>`;
  } finally {
    setBusy(false);
  }
});

function renderResults(data) {
  const { job, outputs, stats } = data;
  if (Array.isArray(data.colorDefaults)) {
    colorDefaults = data.colorDefaults;
  }

  const pageCountText = job.pages === 1 ? "1 page" : `${job.pages} pages`;
  resultMessage.innerHTML = `
    <div>
      Extracted <strong>${job.url}</strong> (${pageCountText}, scheme <code>${job.scheme}</code>).
      Files saved in <code>${outputs.directory}</code>.
    </div>
  `;

  const statEntries = [
    ["Raw findings", stats.rawFindings],
    ["Total tokens", stats.totalTokens],
    ["Mapped tokens", stats.mappedTokens],
    ["High confidence (≥0.85)", stats.highConfidence],
    ["Medium confidence (0.55–0.84)", stats.mediumConfidence],
    ["Low / fallback", stats.lowConfidence],
  ];
  statsList.innerHTML = "";
  for (const [label, value] of statEntries) {
    const node = statTemplate.content.cloneNode(true);
    node.querySelector("dt").textContent = label;
    node.querySelector("dd").textContent = value;
    statsList.appendChild(node);
  }

  const downloadEntries = [
    ["theme.json", outputs.theme],
    ["theme.report.json", outputs.report],
    ["raw-findings.json", outputs.raw],
    ["theme.css", outputs.css],
    ["legacy-tokens.json", outputs.legacyTokens],
  ];
  downloadList.innerHTML = "";
  for (const [label, href] of downloadEntries) {
    const listItem = document.createElement("li");
    const link = document.createElement("a");
    link.href = href;
    link.textContent = label;
    link.target = "_blank";
    link.rel = "noopener";
    listItem.appendChild(link);
    downloadList.appendChild(listItem);
  }

  const colors = data.visuals && Array.isArray(data.visuals.colors) ? data.visuals.colors : [];
  renderColors(colors);
  initialPaletteSelections = buildInitialSelections(data.summary ?? latestSummary);
  currentPaletteDefaults = { ...initialPaletteSelections };
  renderDefaultColorPairs();
  renderThemeSummary(data.summary);
  latestSummary = data.summary ?? null;
  latestRawFindings = Array.isArray(data.rawFindings) ? data.rawFindings : null;
  availablePaletteColors = buildPaletteColors(data, colors);
  renderPaletteControls();
  renderCssSnippet(data.snippets?.css);

  if (job.errors && job.errors.length > 0) {
    errorsContainer.classList.remove("hidden");
    errorsList.innerHTML = "";
    for (const message of job.errors) {
      const li = document.createElement("li");
      li.textContent = message;
      errorsList.appendChild(li);
    }
  } else {
    errorsContainer.classList.add("hidden");
  }

  loadThemePreview(outputs.theme).catch(() => {
    previewDetails.classList.add("hidden");
  });
}

async function loadThemePreview(themePath) {
  try {
    const response = await fetch(themePath);
    if (!response.ok) {
      throw new Error(`Unable to fetch theme: ${response.status}`);
    }
    const json = await response.json();
    const text = JSON.stringify(json, null, 2);
    const truncated = text.length > 4000 ? `${text.slice(0, 4000)}\n… (truncated)` : text;
    themePreview.textContent = truncated;
    previewDetails.classList.remove("hidden");
  } catch (error) {
    themePreview.textContent = `Preview unavailable: ${error.message ?? error}`;
    previewDetails.classList.remove("hidden");
  }
}

function renderColors(colors) {
  if (!colors || colors.length === 0) {
    colorsSection.classList.add("hidden");
    colorGrid.innerHTML = "";
    return;
  }
  colorsSection.classList.remove("hidden");
  colorGrid.innerHTML = "";
  for (const color of colors) {
    const chip = document.createElement("div");
    chip.className = "color-chip";
    const swatch = document.createElement("div");
    swatch.className = "color-swatch";
    swatch.style.background = color;
    chip.appendChild(swatch);
    const label = document.createElement("code");
    label.textContent = color;
    chip.appendChild(label);
    colorGrid.appendChild(chip);
  }
}

function renderThemeSummary(summary) {
  if (!summaryCard || !summaryFont || summaryColorElements.size === 0) {
    return;
  }
  if (!summary || !summary.colors) {
    summaryCard.classList.add("hidden");
    summaryFont.textContent = "—";
    summaryFont.style.fontFamily = "inherit";
    summaryColorElements.forEach(({ swatch, code }) => {
      swatch.style.background = "transparent";
      code.textContent = "—";
    });
    if (summaryLogo && summaryLogoGrid) {
      summaryLogo.classList.add("hidden");
      summaryLogoGrid.innerHTML = "";
    }
    if (summaryCurated) {
      summaryCurated.classList.add("hidden");
    }
    return;
  }

  summaryCard.classList.remove("hidden");
  if (summaryCurated) {
    const curated = summary.curatedStructure !== false;
    summaryCurated.textContent = curated ? "Curated template compatible" : "Manual review required";
    summaryCurated.classList.toggle("warning", !curated);
    summaryCurated.classList.remove("hidden");
  }
  const colors = summary.colors ?? {};
  ["primary", "secondary", "background", "text"].forEach((role) => {
    const entry = summaryColorElements.get(role);
    if (!entry) return;
    const value = colors[role];
    if (value) {
      entry.swatch.style.background = value;
      entry.code.textContent = value;
    } else {
      entry.swatch.style.background = "transparent";
      entry.code.textContent = "—";
    }
  });

  if (summary.typography && summary.typography.fontFamily) {
    summaryFont.textContent = summary.typography.fontFamily;
    summaryFont.style.fontFamily = summary.typography.fontFamily;
  } else {
    summaryFont.textContent = "—";
    summaryFont.style.fontFamily = "inherit";
  }

  if (summaryLogo && summaryLogoGrid) {
    const logoColors = Array.isArray(summary.logoColors) ? summary.logoColors : [];
    if (logoColors.length === 0) {
      summaryLogo.classList.add("hidden");
      summaryLogoGrid.innerHTML = "";
    } else {
      summaryLogo.classList.remove("hidden");
      summaryLogoGrid.innerHTML = "";
      logoColors.slice(0, 8).forEach((color) => {
        const chip = document.createElement("div");
        chip.className = "summary-logo-chip";
        const swatch = document.createElement("div");
        swatch.className = "swatch";
        swatch.style.background = color;
        chip.appendChild(swatch);
        const label = document.createElement("code");
        label.textContent = color;
        chip.appendChild(label);
        summaryLogoGrid.appendChild(chip);
      });
    }
  }
}

function renderCssSnippet(snippet) {
  if (!cssCard || !cssSnippetEl || !copyCssButton) return;
  latestCssSnippet = typeof snippet === "string" ? snippet.trim() : "";
  if (!latestCssSnippet) {
    cssCard.classList.add("hidden");
    cssSnippetEl.textContent = "";
    copyCssButton.disabled = true;
    resetCopyButton();
    return;
  }
  cssCard.classList.remove("hidden");
  cssSnippetEl.textContent = latestCssSnippet;
  copyCssButton.disabled = false;
  resetCopyButton();
}

if (copyCssButton) {
  copyCssButton.addEventListener("click", async () => {
    if (!latestCssSnippet) return;
    try {
      await navigator.clipboard.writeText(latestCssSnippet);
      copyCssButton.textContent = "Copied!";
    } catch (error) {
      console.error("Failed to copy CSS snippet", error);
      copyCssButton.textContent = "Copy failed";
    }
    if (resetCopyTimeout) {
      clearTimeout(resetCopyTimeout);
    }
    resetCopyTimeout = setTimeout(resetCopyButton, 2000);
  });
}

function resetCopyButton() {
  if (copyCssButton) {
    copyCssButton.textContent = "Copy CSS";
  }
}

hydrateStatus();
setInterval(hydrateStatus, 10000);

function buildPaletteColors(data, colors) {
  const set = new Set(
    (colors || []).map((value) => value.trim().toLowerCase()).filter(Boolean),
  );
  if (data.summary?.colors) {
    Object.values(data.summary.colors).forEach((value) => {
      if (typeof value === "string" && value.trim()) {
        set.add(value.trim().toLowerCase());
      }
    });
  }
  if (Array.isArray(data.summary?.logoColors)) {
    data.summary.logoColors.forEach((value) => {
      if (typeof value === "string" && value.trim()) {
        set.add(value.trim().toLowerCase());
      }
    });
  }
  colorDefaults.forEach((group) => {
    (group.entries ?? []).forEach((entry) => {
      if (entry.value) {
        set.add(entry.value.trim().toLowerCase());
      }
    });
  });
  const list = Array.from(set);
  return list;
}

function renderPaletteControls() {
  if (!paletteCard || !paletteForm || !latestSummary) {
    if (paletteCard) paletteCard.classList.add("hidden");
    return;
  }
  if (!latestRawFindings || !availablePaletteColors.length) {
    paletteCard.classList.add("hidden");
    return;
  }
  paletteCard.classList.remove("hidden");
  paletteStatus?.classList.add("hidden");

  paletteControlMap.clear();

  const groupHeaders = new Map([
    ["bodyPrimary", document.querySelector('[data-palette-group="bodyPrimary"] header p')],
    ["surfaceSecondary", document.querySelector('[data-palette-group="surfaceSecondary"] header p')],
  ]);

  paletteConfig.forEach(({ select, colorName, label, group, target }) => {
    if (!select) return;
    const labelElement = select.previousElementSibling;
    const defaultValue = normalizeColorValue(getSassDefaultValue(colorName));
    if (labelElement) {
      labelElement.textContent = defaultValue ? `${label} — default ${defaultValue.toUpperCase()}` : label;
    }
    const groupDescription = groupHeaders.get(group);
    if (groupDescription) {
      const baseText = group === "bodyPrimary" ? "$color-1 & $color-1-alt" : "$color-2 & $color-2-font";
      groupDescription.textContent = `${baseText}${defaultValue ? ` · default ${defaultValue.toUpperCase()}` : ""}`;
    }
  });

  const defaults = initialPaletteSelections ?? buildInitialSelections(latestSummary);
  currentPaletteDefaults = { ...defaults };

  const fillSelect = (select, value) => {
    if (!select) return;
    select.innerHTML = "";
    availablePaletteColors.forEach((color) => {
      const option = document.createElement("option");
      option.value = color;
      option.textContent = color.toUpperCase();
      option.style.background = color;
      option.style.color = "#111";
      option.style.fontFamily = "monospace";
      if (color === value) {
        option.selected = true;
      }
      select.appendChild(option);
    });
    if (value && !availablePaletteColors.includes(value)) {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = value.toUpperCase();
      option.selected = true;
      select.appendChild(option);
    }
  };

  paletteConfig.forEach(({ target, select }) => {
    const normalized = currentPaletteDefaults?.[target] ?? "";
    fillSelect(select, normalized);
    if (select) {
      select.dataset.defaultValue = normalized;
      reflectSelectionState(select);
      select.onchange = () => {
        reflectSelectionState(select);
        paletteStatus?.classList.add("hidden");
        updatePaletteActions();
        updatePalettePreview();
      };
      paletteControlMap.set(target, { select });
    }
  });

  updatePaletteActions();
  updatePalettePreview();
}

paletteForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (isApplyingPalette || !latestRawFindings) return;
  if (!paletteApplyButton) return;
  const selections = {};
  paletteControlMap.forEach(({ select }, target) => {
    const selected = select?.value ?? "";
    selections[target] = selected ? selected : null;
  });
  isApplyingPalette = true;
  paletteApplyButton.disabled = true;
  paletteStatus?.classList.add("hidden");
  try {
    const response = await fetch("/api/generate", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        rawFindings: latestRawFindings,
        selections,
      }),
    });
    const body = await response.json();
    if (!response.ok || !body.ok) {
      throw new Error(body.error ?? `Request failed with status ${response.status}`);
    }
    latestSummary = body.summary ?? null;
    if (Array.isArray(body.colorDefaults)) {
      colorDefaults = body.colorDefaults;
      renderDefaultColorPairs();
    }
    if (builderHasProperty(body, "summary")) {
      renderThemeSummary(body.summary);
    }
    if (builderHasProperty(body, "snippets") && body.snippets.css) {
      renderCssSnippet(body.snippets.css);
    }
    renderDefaultColorPairs();
    renderPaletteControls();
    paletteStatus?.classList.remove("hidden");
    if (paletteStatus) {
      paletteStatus.textContent = "Palette applied. Copy the refreshed CSS below.";
    }
  } catch (error) {
    if (paletteStatus) {
      paletteStatus.classList.remove("hidden");
      paletteStatus.textContent = `Failed to apply palette: ${error.message ?? error}`;
    }
  } finally {
    isApplyingPalette = false;
    updatePaletteActions();
  }
});

resetPaletteButton?.addEventListener("click", () => {
  if (!currentPaletteDefaults) return;
  paletteControlMap.forEach(({ select }, target) => {
    if (!select) return;
    const defaultValue = currentPaletteDefaults?.[target] ?? "";
    if (!Array.from(select.options).some((option) => option.value === defaultValue)) {
      const option = document.createElement("option");
      option.value = defaultValue;
      option.textContent = defaultValue.toUpperCase();
      select.appendChild(option);
    }
    select.value = defaultValue;
    reflectSelectionState(select);
  });
  paletteStatus?.classList.add("hidden");
  updatePalettePreview();
  updatePaletteActions();
});

function builderHasProperty(data, key) {
  return typeof data === "object" && data !== null && key in data;
}

function getSassDefaultValue(name) {
  for (const group of colorDefaults) {
    for (const entry of group.entries ?? []) {
      if (entry.name === name && entry.value) {
        return entry.value;
      }
    }
  }
  return "";
}

function normalizeColorValue(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function buildInitialSelections(summary) {
  const colors = summary?.colors ?? {};
  return {
    text: normalizeColorValue(colors.text ?? getSassDefaultValue("color-1")),
    primary: normalizeColorValue(colors.primary ?? getSassDefaultValue("color-1-alt")),
    background: normalizeColorValue(colors.background ?? getSassDefaultValue("color-2")),
    secondary: normalizeColorValue(colors.secondary ?? getSassDefaultValue("color-2-font")),
  };
}

function renderDefaultColorPairs() {
  if (!paletteDefaultList) return;
  paletteDefaultList.innerHTML = "";
  if (!Array.isArray(colorDefaults) || colorDefaults.length === 0) {
    const empty = document.createElement("p");
    empty.textContent = "Color defaults unavailable";
    empty.className = "palette-status";
    paletteDefaultList.appendChild(empty);
    return;
  }

  const reference = initialPaletteSelections ?? buildInitialSelections(latestSummary);

  PALETTE_GROUPS.forEach((group) => {
    const item = document.createElement("div");
    item.className = "palette-default-item";
    const details = document.createElement("div");
    details.className = "palette-default-meta";
    details.innerHTML = `<div class=\"palette-default-title\">${group.label}</div><div class=\"palette-default-comment\">${group.description}</div>`;

    const swatches = document.createElement("div");
    swatches.className = "palette-default-swatches";
    group.entries.forEach((entry) => {
      const defaultValue = getSassDefaultValue(entry.colorName);
      const currentValue = (reference?.[entry.target] ?? defaultValue || "").toUpperCase();
      const swatchWrapper = document.createElement("div");
      swatchWrapper.className = "palette-default-swatch";
      const swatch = document.createElement("div");
      swatch.className = "swatch";
      swatch.style.background = currentValue || "transparent";
      swatchWrapper.appendChild(swatch);
      const label = document.createElement("div");
      label.innerHTML = `<code>${entry.colorName}</code><span>Current ${currentValue || "--"} · Default ${defaultValue.toUpperCase()}</span>`;
      swatchWrapper.appendChild(label);
      swatches.appendChild(swatchWrapper);
    });

    item.appendChild(details);
    item.appendChild(swatches);
    paletteDefaultList.appendChild(item);
  });
}

function reflectSelectionState(select) {
  const parent = select.closest(".palette-field");
  const defaultValue = select.dataset.defaultValue ?? "";
  if (!parent) return;
  if ((select.value || "").toLowerCase() !== defaultValue) {
    parent.classList.add("modified");
  } else {
    parent.classList.remove("modified");
  }
}

function getCurrentSelections() {
  const selections = {};
  paletteControlMap.forEach(({ select }, target) => {
    if (!select) return;
    selections[target] = normalizeColorValue(select.value);
  });
  return selections;
}

function updatePalettePreview() {
  const selections = getCurrentSelections();
  const base = initialPaletteSelections ?? buildInitialSelections(latestSummary);
  const merged = {
    primary: selections.primary || base.primary || "",
    secondary: selections.secondary || base.secondary || "",
    background: selections.background || base.background || "",
    text: selections.text || base.text || "",
  };

  for (const [key, entry] of palettePreviewItems.entries()) {
    const value = merged[key] ?? "";
    if (entry.swatch) {
      entry.swatch.style.background = value || "transparent";
    }
    if (entry.code) {
      entry.code.textContent = value ? value.toUpperCase() : "--";
    }
  }
}

function updatePaletteActions() {
  const hasChanges = Array.from(paletteControlMap.values()).some(({ select }) => {
    if (!select) return false;
    const defaultValue = select.dataset.defaultValue ?? "";
    return normalizeColorValue(select.value) !== defaultValue;
  });
  if (paletteApplyButton) {
    paletteApplyButton.disabled = !hasChanges;
  }
  if (resetPaletteButton) {
    resetPaletteButton.disabled = !hasChanges;
  }
}
