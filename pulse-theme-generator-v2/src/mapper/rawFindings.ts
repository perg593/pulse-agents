import Color from "colorjs.io";
import { PageExtractionResult } from "../extractor/extractSite.js";
import { CollectedDeclaration, ComputedSample } from "../extractor/browserCollector.js";
import { Evidence, RawFinding } from "../types.js";

interface AggregatedValue {
  value: string;
  priority: number;
  evidence: Evidence[];
  category: RawFinding["category"];
  normalizedName: string;
  name: string;
}

interface BuildOptions {
  selectorPriority: string[];
}

const CATEGORY_KEYWORDS: Record<RawFinding["category"], RegExp[]> = {
  color: [/color/i, /fill/i, /stroke/i, /^--.*color/i, /^--.*accent/i],
  font: [/font/i, /line-height/i, /letter-spacing/i, /text/i],
  spacing: [/margin/i, /padding/i, /gap/i, /space/i],
  radius: [/radius/i, /round/i],
  shadow: [/shadow/i],
  "z-index": [/z-index/i, /layer/i],
  unknown: [],
};

function inferCategory(name: string, property: string): RawFinding["category"] {
  for (const [category, patterns] of Object.entries(CATEGORY_KEYWORDS) as [RawFinding["category"], RegExp[]][]) {
    if (patterns.some((pattern) => pattern.test(name) || pattern.test(property))) {
      return category;
    }
  }
  return "unknown";
}

function normalizeNameFromProperty(property: string): string {
  return property
    .replace(/^--/, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
}

function normalizeSelectorProperty(selector: string, property: string): string {
  const normalizedSelector = selector
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .split(" ")
    .filter(Boolean)
    .map((token, index) => (index === 0 ? token.toLowerCase() : token.charAt(0).toUpperCase() + token.slice(1)))
    .join("");
  const normalizedProperty = property
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .split(" ")
    .map((token, index) => (index === 0 ? token.toLowerCase() : token.charAt(0).toUpperCase() + token.slice(1)))
    .join("");
  return `${normalizedSelector}.${normalizedProperty}`;
}

function createEvidenceFromDeclaration(declaration: CollectedDeclaration): Evidence {
  if (declaration.type === "css-var") {
    return {
      type: "css-var",
      selector: declaration.selector,
      property: declaration.property,
      value: declaration.value.trim(),
      important: declaration.important,
      href: declaration.source,
    };
  }
  return {
    type: "css-prop",
    selector: declaration.selector,
    property: declaration.property,
    value: declaration.value.trim(),
    important: declaration.important,
    href: declaration.source,
  };
}

function createEvidenceFromComputed(sample: ComputedSample, property: string, value: string): Evidence {
  return {
    type: "computed",
    selector: `${sample.selector}[${sample.sampleIndex}]`,
    property,
    value: value.trim(),
  };
}

function mergeEvidence(target: Evidence[], incoming: Evidence[]) {
  const existing = new Set(target.map((item) => JSON.stringify(item)));
  for (const item of incoming) {
    const signature = JSON.stringify(item);
    if (!existing.has(signature)) {
      target.push(item);
      existing.add(signature);
    }
  }
}

function prioritizeDeclaration(
  map: Map<string, AggregatedValue>,
  declaration: CollectedDeclaration,
  selectorPriority: Map<string, number>,
) {
  const key = declaration.type === "css-var" ? declaration.property : `${declaration.selector}::${declaration.property}`;
  const name = declaration.type === "css-var" ? declaration.property : key;
  const normalizedName =
    declaration.type === "css-var"
      ? normalizeNameFromProperty(declaration.property)
      : normalizeSelectorProperty(declaration.selector, declaration.property);
  const priorityScore =
    declaration.type === "css-var"
      ? selectorPriority.get(declaration.selector) ?? selectorPriority.size + 5
      : selectorPriority.get(declaration.selector) ?? selectorPriority.size + 20;
  const category = inferCategory(name, declaration.property);
  const evidence = [createEvidenceFromDeclaration(declaration)];

  const existing = map.get(key);
  if (!existing || priorityScore < existing.priority) {
    map.set(key, {
      name,
      normalizedName,
      category,
      value: declaration.value.trim(),
      priority: priorityScore,
      evidence,
    });
    return;
  }
  if (priorityScore === existing.priority) {
    mergeEvidence(existing.evidence, evidence);
  }
}

function prioritizeComputed(
  map: Map<string, AggregatedValue>,
  sample: ComputedSample,
  property: string,
  value: string,
  selectorPriority: Map<string, number>,
) {
  const key = `${sample.selector}::${property}`;
  const normalizedName = normalizeSelectorProperty(sample.selector, property);
  const category = inferCategory(property, property);
  const priority = (selectorPriority.get(sample.selector) ?? selectorPriority.size + 50) + sample.sampleIndex;
  const evidence = [createEvidenceFromComputed(sample, property, value)];

  const existing = map.get(key);
  if (!existing || priority < existing.priority) {
    map.set(key, {
      name: key,
      normalizedName,
      category,
      value: value.trim(),
      priority,
      evidence,
    });
    return;
  }
  if (priority === existing.priority) {
    mergeEvidence(existing.evidence, evidence);
  }
}

export function buildRawFindings(pages: PageExtractionResult[], options: BuildOptions): RawFinding[] {
  const selectorPriority = new Map<string, number>();
  options.selectorPriority.forEach((selector, index) => selectorPriority.set(selector, index));

  const aggregated = new Map<string, AggregatedValue>();

  for (const page of pages) {
    for (const declaration of page.globalDeclarations) {
      prioritizeDeclaration(aggregated, declaration, selectorPriority);
    }
    for (const declaration of page.componentDeclarations) {
      prioritizeDeclaration(aggregated, declaration, selectorPriority);
    }
    for (const sample of page.computed) {
      for (const [property, value] of Object.entries(sample.properties)) {
        if (!value) continue;
        prioritizeComputed(aggregated, sample, property, value, selectorPriority);
      }
    }
  }

  const findings = Array.from(aggregated.values()).map((entry) => ({
    name: entry.name,
    normalizedName: entry.normalizedName,
    category: entry.category,
    value: entry.value,
    sources: entry.evidence,
  }));

  const logoFindings: RawFinding[] = [];
  pages.forEach((page, pageIndex) => {
    if (!page.logos) return;
    page.logos.forEach((logo, logoIndex) => {
      logo.colors.slice(0, 3).forEach((color, colorIndex) => {
        if (!color) return;
        const role = colorIndex === 0 ? "primary" : colorIndex === 1 ? "secondary" : `accent${colorIndex - 1}`;
        logoFindings.push({
          name: `logo-${pageIndex}-${logoIndex}-${role}`,
          normalizedName: `logo.${role}`,
          category: "color",
          value: color,
          sources: [
            {
              type: "logo",
              source: logo.source,
              method: logo.method,
              value: color,
              note: logo.alt ?? undefined,
            },
          ],
        });
      });
    });
  });

  if (logoFindings.length > 0) {
    findings.push(...logoFindings);
  }

  const derived = derivePaletteIfNeeded(findings);
  return findings.concat(derived);
}

function derivePaletteIfNeeded(findings: RawFinding[]): RawFinding[] {
  const colorFindings = findings.filter((finding) => finding.category === "color");
  if (colorFindings.length === 0) return [];
  const primaryCandidate =
    colorFindings.find((finding) => /primary|brand|accent/.test(finding.normalizedName)) ?? colorFindings[0];
  if (!primaryCandidate) return [];
  if (colorFindings.length > 6) {
    return [];
  }

  try {
    const baseColor = new Color(primaryCandidate.value);
    const oklch = baseColor.to("oklch");
    const steps = [
      { suffix: "50", delta: 0.35 },
      { suffix: "100", delta: 0.25 },
      { suffix: "200", delta: 0.18 },
      { suffix: "300", delta: 0.1 },
      { suffix: "400", delta: 0.05 },
      { suffix: "500", delta: 0 },
      { suffix: "600", delta: -0.05 },
      { suffix: "700", delta: -0.1 },
      { suffix: "800", delta: -0.18 },
      { suffix: "900", delta: -0.28 },
    ];
    const derived: RawFinding[] = [];
    for (const step of steps) {
      const derivedColor = baseColor.clone();
      const newL = clamp(oklch.l + step.delta, 0.08, 0.98);
      derivedColor.set("oklch.l", newL);
      const hex = derivedColor.to("srgb").toString({ format: "hex" }).toLowerCase();
      derived.push({
        name: `${primaryCandidate.name}-${step.suffix}`,
        normalizedName: `${primaryCandidate.normalizedName}-${step.suffix}`,
        category: "color",
        value: hex,
        sources: [
          ...primaryCandidate.sources,
          {
            type: "derived",
            note: `Derived tonal scale (${step.suffix}) from ${primaryCandidate.name}`,
          },
        ],
      });
    }
    return derived;
  } catch {
    return [];
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
